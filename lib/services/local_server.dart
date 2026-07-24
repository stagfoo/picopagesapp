import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';

/// Serves one imported HTML app's folder over http://127.0.0.1 so relative
/// links (css/js/images) resolve normally, and gives every app its own
/// origin (distinct port) so the WebView's own storage is naturally
/// partitioned per app.
///
/// On top of that, served HTML pages get a small JS shim injected that
/// replaces `window.localStorage` with calls back into this server, which
/// persists into a Hive box on disk. That way app data survives even if
/// Android evicts the WebView's own storage under pressure.
///
/// It also exposes a tiny "sandbox API" beyond localStorage — currently
/// `/uploads` — so an app's own prompt/instructions can tell an AI to save
/// files through a real endpoint instead of only client-side storage. Every
/// endpoint here is scoped to this app's own folder; there is no path that
/// reaches another app's data.
class LocalAppServer {
  static const _maxUploadBytes = 25 * 1024 * 1024;

  final String appId;
  final Directory rootDir;

  HttpServer? _server;
  Box? _storageBox;

  LocalAppServer({required this.appId, required this.rootDir});

  int get port => _server!.port;

  Future<int> start() async {
    _storageBox = await Hive.openBox('storage_$appId');
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handleRequest);
    return _server!.port;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    await _storageBox?.close();
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;
      if (path.startsWith('/__storage/')) {
        await _handleStorageRequest(request);
        return;
      }
      if (path == '/uploads' && (request.method == 'GET' || request.method == 'POST')) {
        await _handleUploadsRequest(request);
        return;
      }
      if (path.startsWith('/uploads/') && request.method == 'DELETE') {
        await _handleUploadsRequest(request);
        return;
      }
      await _handleStaticFile(request);
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Server error: $e');
      await request.response.close();
    }
  }

  Future<void> _handleStorageRequest(HttpRequest request) async {
    final box = _storageBox!;
    final segment = request.uri.path.substring('/__storage/'.length);
    request.response.headers.set('Access-Control-Allow-Origin', '*');

    switch (segment) {
      case 'all':
        final map = {for (final k in box.keys) k.toString(): box.get(k)};
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(map));
        break;
      case 'set':
        final body = jsonDecode(await utf8.decodeStream(request));
        await box.put(body['key'] as String, body['value'] as String);
        request.response.write('ok');
        break;
      case 'remove':
        final body = jsonDecode(await utf8.decodeStream(request));
        await box.delete(body['key'] as String);
        request.response.write('ok');
        break;
      case 'clear':
        await box.clear();
        request.response.write('ok');
        break;
      default:
        request.response.statusCode = HttpStatus.notFound;
    }
    await request.response.close();
  }

  Directory get _uploadsDir => Directory('${rootDir.path}/uploads');

  /// Only allows a bare filename — rejects anything with a path separator or
  /// `..`, so an app can never write/read/delete outside its own uploads
  /// folder.
  String? _sanitizeFilename(String raw) {
    final decoded = Uri.decodeComponent(raw);
    if (decoded.isEmpty || decoded.contains('..') || decoded.contains('/') || decoded.contains(r'\')) {
      return null;
    }
    return decoded;
  }

  Future<void> _handleUploadsRequest(HttpRequest request) async {
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.contentType = ContentType.json;

    if (request.method == 'GET') {
      if (!await _uploadsDir.exists()) {
        request.response.write(jsonEncode({'files': []}));
        await request.response.close();
        return;
      }
      final names = await _uploadsDir
          .list()
          .where((e) => e is File)
          .map((e) => e.uri.pathSegments.last)
          .toList();
      names.sort();
      request.response.write(jsonEncode({
        'files': [for (final n in names) {'name': n, 'url': '/uploads/$n'}],
      }));
      await request.response.close();
      return;
    }

    if (request.method == 'POST') {
      final rawName = request.uri.queryParameters['filename'] ?? request.headers.value('x-filename');
      final safeName = rawName == null ? null : _sanitizeFilename(rawName);
      if (safeName == null) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write(jsonEncode({'error': 'filename query param (or X-Filename header) required'}));
        await request.response.close();
        return;
      }

      final builder = BytesBuilder();
      var tooLarge = false;
      await for (final chunk in request) {
        builder.add(chunk);
        if (builder.length > _maxUploadBytes) tooLarge = true;
      }
      if (tooLarge) {
        request.response.statusCode = HttpStatus.requestEntityTooLarge;
        request.response.write(jsonEncode({'error': 'file too large (max 25MB)'}));
        await request.response.close();
        return;
      }

      await _uploadsDir.create(recursive: true);
      final bytes = builder.takeBytes();
      await File('${_uploadsDir.path}/$safeName').writeAsBytes(bytes);
      request.response.write(jsonEncode({'name': safeName, 'url': '/uploads/$safeName', 'size': bytes.length}));
      await request.response.close();
      return;
    }

    // DELETE /uploads/<name>
    final rawName = request.uri.path.substring('/uploads/'.length);
    final safeName = _sanitizeFilename(rawName);
    if (safeName == null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({'error': 'invalid filename'}));
      await request.response.close();
      return;
    }
    final file = File('${_uploadsDir.path}/$safeName');
    if (await file.exists()) await file.delete();
    request.response.write(jsonEncode({'ok': true}));
    await request.response.close();
  }

  Future<void> _handleStaticFile(HttpRequest request) async {
    var relativePath = request.uri.path;
    if (relativePath == '/') relativePath = '/index.html';
    final file = File('${rootDir.path}$relativePath');

    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Not found: $relativePath');
      await request.response.close();
      return;
    }

    final contentType = _contentTypeFor(file.path);
    request.response.headers.contentType = contentType;

    if (contentType.mimeType == 'text/html') {
      final html = await file.readAsString();
      request.response.write(_injectShim(html));
    } else {
      await request.response.addStream(file.openRead());
    }
    await request.response.close();
  }

  String _injectShim(String html) {
    final shim = '<script>$_jsShim</script>';
    if (html.contains('</head>')) {
      return html.replaceFirst('</head>', '$shim</head>');
    }
    return shim + html;
  }

  ContentType _contentTypeFor(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'html':
      case 'htm':
        return ContentType.html;
      case 'js':
      case 'mjs':
        return ContentType('text', 'javascript', charset: 'utf-8');
      case 'css':
        return ContentType('text', 'css', charset: 'utf-8');
      case 'json':
        return ContentType.json;
      case 'png':
        return ContentType('image', 'png');
      case 'jpg':
      case 'jpeg':
        return ContentType('image', 'jpeg');
      case 'gif':
        return ContentType('image', 'gif');
      case 'svg':
        return ContentType('image', 'svg+xml');
      case 'woff':
        return ContentType('font', 'woff');
      case 'woff2':
        return ContentType('font', 'woff2');
      default:
        return ContentType.binary;
    }
  }

  static const _jsShim = r'''
(function () {
  function req(method, path, body) {
    var xhr = new XMLHttpRequest();
    xhr.open(method, path, false); // synchronous: matches localStorage's sync contract
    if (body !== undefined) {
      xhr.setRequestHeader('Content-Type', 'application/json');
      xhr.send(JSON.stringify(body));
    } else {
      xhr.send();
    }
    return xhr.responseText;
  }

  var cache = {};
  try {
    cache = JSON.parse(req('GET', '/__storage/all')) || {};
  } catch (e) {}

  var nativeStorage = {
    getItem: function (key) {
      return Object.prototype.hasOwnProperty.call(cache, key) ? cache[key] : null;
    },
    setItem: function (key, value) {
      value = String(value);
      cache[key] = value;
      req('POST', '/__storage/set', { key: key, value: value });
    },
    removeItem: function (key) {
      delete cache[key];
      req('POST', '/__storage/remove', { key: key });
    },
    clear: function () {
      cache = {};
      req('POST', '/__storage/clear');
    },
    key: function (index) {
      var keys = Object.keys(cache);
      return index >= 0 && index < keys.length ? keys[index] : null;
    },
    get length() {
      return Object.keys(cache).length;
    },
  };

  try {
    Object.defineProperty(window, 'localStorage', {
      value: nativeStorage,
      configurable: false,
      writable: false,
    });
  } catch (e) {
    window.localStorage = nativeStorage;
  }
})();
''';
}
