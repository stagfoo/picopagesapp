import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive/hive.dart';
import 'package:share_plus/share_plus.dart';

/// Serves one imported HTML app's folder over http://127.0.0.1 so relative
/// links (css/js/images) resolve normally, and gives every app its own
/// origin (distinct port) so the WebView's own storage is naturally
/// partitioned per app.
///
/// On top of that, served HTML pages get a viewport meta tag (when they
/// declare none) and a small JS shim injected — the shim
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
  FlutterTts? _tts;

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
    await _tts?.stop();
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
      if (path == '/sets' && request.method == 'GET') {
        await _handleListSets(request);
        return;
      }
      if (path == '/sets/import' && request.method == 'POST') {
        await _handleImportSet(request);
        return;
      }
      if (request.method == 'GET' || request.method == 'DELETE') {
        final setMatch = RegExp(r'^/sets/([^/]+)$').firstMatch(path);
        if (setMatch != null) {
          await _handleSetRequest(request, setMatch.group(1)!);
          return;
        }
      }
      if (path == '/share' && request.method == 'POST') {
        await _handleShare(request);
        return;
      }
      if (path == '/speak' && request.method == 'POST') {
        await _handleSpeak(request);
        return;
      }
      if (path == '/speak/stop' && request.method == 'POST') {
        await _handleSpeakStop(request);
        return;
      }
      if (path == '/speak/languages' && request.method == 'GET') {
        await _handleSpeakLanguages(request);
        return;
      }
      // Falls through to here for GET /sets/<name>/<file> — an actual set
      // image, served the same as any other file under rootDir.
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

  Directory get _setsDir => Directory('${rootDir.path}/sets');

  static const _imageExtensions = {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp'};

  String _extOf(String path) {
    final dot = path.lastIndexOf('.');
    return dot == -1 ? '' : path.substring(dot).toLowerCase();
  }

  String _basenameOf(String path) {
    final normalized = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final slash = normalized.lastIndexOf('/');
    return slash == -1 ? normalized : normalized.substring(slash + 1);
  }

  Future<void> _handleListSets(HttpRequest request) async {
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.contentType = ContentType.json;
    if (!await _setsDir.exists()) {
      request.response.write(jsonEncode({'sets': []}));
      await request.response.close();
      return;
    }
    final sets = <Map<String, dynamic>>[];
    await for (final entity in _setsDir.list()) {
      if (entity is Directory) {
        final count = await entity.list().where((e) => e is File).length;
        sets.add({'name': _basenameOf(entity.path), 'count': count});
      }
    }
    sets.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    request.response.write(jsonEncode({'sets': sets}));
    await request.response.close();
  }

  /// Triggers Android's real native folder browser (Storage Access
  /// Framework) via file_picker, imports every image file found directly
  /// inside the picked folder (not recursively) into a named set, and
  /// serves them back at `/sets/<name>/<file>`. The set name defaults to
  /// the picked folder's own name, or can be overridden with `?name=`.
  Future<void> _handleImportSet(HttpRequest request) async {
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.contentType = ContentType.json;

    final requestedName = request.uri.queryParameters['name'];
    if (requestedName != null && _sanitizeFilename(requestedName) == null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({'error': 'invalid name'}));
      await request.response.close();
      return;
    }

    final pickedPath = await FilePicker.platform.getDirectoryPath();
    if (pickedPath == null || pickedPath == '/') {
      // file_picker returns null if the user cancelled, or "/" for some
      // protected Android locations (e.g. Downloads) it can't resolve a
      // real path for — both look the same to the app, so both get treated
      // as "nothing usable was picked" rather than trying to read from "/".
      request.response.write(jsonEncode({'cancelled': true}));
      await request.response.close();
      return;
    }

    List<File> imageFiles;
    try {
      final sourceDir = Directory(pickedPath);
      imageFiles = await sourceDir
          .list()
          .where((e) => e is File && _imageExtensions.contains(_extOf(e.path)))
          .cast<File>()
          .toList();
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write(jsonEncode({
        'error': 'could not read that folder ($e) — some Android folders (like Downloads) '
            'are protected; try a folder under Pictures or one you created yourself',
      }));
      await request.response.close();
      return;
    }

    if (imageFiles.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({'error': 'no image files found in that folder'}));
      await request.response.close();
      return;
    }

    final setName = _sanitizeFilename(requestedName ?? _basenameOf(pickedPath)) ?? 'set';
    final destDir = Directory('${_setsDir.path}/$setName');
    await destDir.create(recursive: true);

    final imported = <Map<String, String>>[];
    for (final file in imageFiles) {
      final name = file.uri.pathSegments.last;
      await file.copy('${destDir.path}/$name');
      imported.add({'name': name, 'url': '/sets/$setName/$name'});
    }

    request.response.write(jsonEncode({'name': setName, 'files': imported}));
    await request.response.close();
  }

  Future<void> _handleSetRequest(HttpRequest request, String rawName) async {
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.contentType = ContentType.json;

    final name = _sanitizeFilename(rawName);
    if (name == null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({'error': 'invalid name'}));
      await request.response.close();
      return;
    }
    final dir = Directory('${_setsDir.path}/$name');

    if (request.method == 'DELETE') {
      if (await dir.exists()) await dir.delete(recursive: true);
      request.response.write(jsonEncode({'ok': true}));
      await request.response.close();
      return;
    }

    // GET: list files in the set.
    if (!await dir.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write(jsonEncode({'error': 'no such set'}));
      await request.response.close();
      return;
    }
    final names = await dir.list().where((e) => e is File).map((e) => _basenameOf(e.path)).toList();
    names.sort();
    request.response.write(jsonEncode({
      'files': [for (final n in names) {'name': n, 'url': '/sets/$name/$n'}],
    }));
    await request.response.close();
  }

  /// Resolves a sandbox-relative URL like "/uploads/photo.png" or
  /// "/sets/Sunsets/a.jpg" to a real file under rootDir. Rejects anything
  /// containing ".." rather than trying to canonicalize the path — the only
  /// URLs this is meant to accept are ones the server itself just handed
  /// back to the app (from /uploads or /sets responses), so a plain
  /// substring check is enough to close off a JS-supplied path escaping
  /// this app's own folder.
  File? _resolveSandboxUrl(String url) {
    if (!url.startsWith('/') || url.contains('..')) return null;
    return File('${rootDir.path}$url');
  }

  Future<void> _handleShare(HttpRequest request) async {
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.contentType = ContentType.json;

    Map<String, dynamic> body;
    try {
      body = jsonDecode(await utf8.decodeStream(request)) as Map<String, dynamic>;
    } catch (e) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({'error': 'invalid JSON body'}));
      await request.response.close();
      return;
    }

    final text = body['text'] as String?;
    final fileUrl = body['url'] as String?;
    if ((text == null || text.isEmpty) && fileUrl == null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({'error': "provide 'text' and/or 'url'"}));
      await request.response.close();
      return;
    }

    List<XFile>? files;
    if (fileUrl != null) {
      final file = _resolveSandboxUrl(fileUrl);
      if (file == null || !await file.exists()) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write(jsonEncode({'error': 'no such file: $fileUrl'}));
        await request.response.close();
        return;
      }
      files = [XFile(file.path)];
    }

    final result = await SharePlus.instance.share(ShareParams(text: text, files: files));
    request.response.write(jsonEncode({'status': result.status.name}));
    await request.response.close();
  }

  FlutterTts get _ttsInstance => _tts ??= FlutterTts();

  Future<void> _handleSpeak(HttpRequest request) async {
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.contentType = ContentType.json;

    Map<String, dynamic> body;
    try {
      body = jsonDecode(await utf8.decodeStream(request)) as Map<String, dynamic>;
    } catch (e) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({'error': 'invalid JSON body'}));
      await request.response.close();
      return;
    }

    final text = body['text'] as String?;
    if (text == null || text.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({'error': "'text' is required"}));
      await request.response.close();
      return;
    }

    final language = body['language'] as String?;
    if (language != null) {
      await _ttsInstance.setLanguage(language);
    }
    await _ttsInstance.speak(text);
    request.response.write(jsonEncode({'ok': true}));
    await request.response.close();
  }

  Future<void> _handleSpeakStop(HttpRequest request) async {
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.contentType = ContentType.json;
    await _ttsInstance.stop();
    request.response.write(jsonEncode({'ok': true}));
    await request.response.close();
  }

  Future<void> _handleSpeakLanguages(HttpRequest request) async {
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.contentType = ContentType.json;
    final languages = await _ttsInstance.getLanguages;
    request.response.write(jsonEncode({
      'languages': (languages as List).map((l) => l.toString()).toList(),
    }));
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

  /// The viewport tag every phone page needs. Android's WebView otherwise
  /// lays a page out at a notional 980px wide and scales the result down, so
  /// an app written against the real screen size — which is what the Sandbox
  /// API prompt tells the AI to do — comes out shrunken and unreadable.
  /// Injected only when the page declares no viewport of its own, so an app
  /// that deliberately sets one keeps it.
  static const _viewportMeta =
      '<meta name="viewport" content="width=device-width, initial-scale=1">';

  static final _viewportPattern =
      RegExp(r'''<meta[^>]+name\s*=\s*["']?viewport''', caseSensitive: false);

  String _injectShim(String html) {
    final shim = '<script>$_jsShim</script>';
    final head = _viewportPattern.hasMatch(html) ? shim : '$_viewportMeta$shim';
    if (html.contains('</head>')) {
      return html.replaceFirst('</head>', '$head</head>');
    }
    return head + html;
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
