import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:picopages/services/local_server.dart';

void main() {
  late Directory tempDir;
  late Directory appDir;
  late LocalAppServer server;
  late int port;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('picopages_test_');
    Hive.init(tempDir.path);
    appDir = Directory('${tempDir.path}/app')..createSync();
    File('${appDir.path}/index.html').writeAsStringSync('<html><head></head><body>hi</body></html>');
    server = LocalAppServer(appId: 'test-app', rootDir: appDir);
    port = await server.start();
  });

  tearDown(() async {
    await server.stop();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Uri url(String path) => Uri.parse('http://127.0.0.1:$port$path');

  Future<String> fetchHtml(String path, String html) async {
    File('${appDir.path}$path').writeAsStringSync(html);
    final client = HttpClient();
    final res = await (await client.getUrl(url(path))).close();
    final body = await res.transform(utf8.decoder).join();
    client.close();
    return body;
  }

  group('viewport injection', () {
    test('adds a viewport meta tag to a page that declares none', () async {
      final body = await fetchHtml('/index.html',
          '<html><head><title>x</title></head><body>hi</body></html>');
      expect(body,
          contains('<meta name="viewport" content="width=device-width, initial-scale=1">'));
    });

    test('leaves a page that sets its own viewport alone', () async {
      // An app that deliberately picks a fixed viewport must keep it —
      // overriding it would silently break a layout that was working.
      final body = await fetchHtml('/own.html',
          '<html><head><meta name="viewport" content="width=320"></head><body>hi</body></html>');
      expect(body, contains('content="width=320"'));
      expect('viewport'.allMatches(body).length, 1);
    });

    test('recognises an existing tag whatever its quoting and order', () async {
      final body = await fetchHtml('/odd.html',
          "<html><head><meta content='width=400' NAME=viewport></head><body>hi</body></html>");
      expect(body, isNot(contains('width=device-width')));
    });

    test('injects into a page with no head at all', () async {
      final body = await fetchHtml('/bare.html', '<body>hi</body>');
      expect(body, contains('width=device-width'));
      expect(body, contains('<script>'));
    });

    test('the tag lands inside head, ahead of the closing tag', () async {
      final body = await fetchHtml('/ordered.html',
          '<html><head><title>x</title></head><body>hi</body></html>');
      expect(body.indexOf('width=device-width'), lessThan(body.indexOf('</head>')));
    });

    test('still injects the localStorage shim alongside it', () async {
      final body = await fetchHtml('/shim.html',
          '<html><head></head><body>hi</body></html>');
      expect(body, contains('width=device-width'));
      expect(body, contains('localStorage'));
    });
  });

  test('uploads a file and can list and fetch it back', () async {
    final client = HttpClient();
    final postReq = await client.postUrl(url('/uploads?filename=photo.png'));
    postReq.add(utf8.encode('fake-image-bytes'));
    final postRes = await postReq.close();
    expect(postRes.statusCode, 200);
    final postBody = jsonDecode(await postRes.transform(utf8.decoder).join());
    expect(postBody['name'], 'photo.png');
    expect(postBody['url'], '/uploads/photo.png');

    final listRes = await (await client.getUrl(url('/uploads'))).close();
    final listBody = jsonDecode(await listRes.transform(utf8.decoder).join());
    expect(listBody['files'], [
      {'name': 'photo.png', 'url': '/uploads/photo.png'},
    ]);

    final fetchRes = await (await client.getUrl(url('/uploads/photo.png'))).close();
    expect(fetchRes.statusCode, 200);
    expect(await fetchRes.transform(utf8.decoder).join(), 'fake-image-bytes');

    client.close(force: true);
  });

  test('rejects path traversal in the upload filename', () async {
    final client = HttpClient();
    final req = await client.postUrl(url('/uploads?filename=..%2F..%2Fescaped.txt'));
    req.add(utf8.encode('malicious'));
    final res = await req.close();
    expect(res.statusCode, 400);

    // Confirm nothing was written outside the app's own folder.
    expect(File('${tempDir.path}/escaped.txt').existsSync(), isFalse);
    client.close(force: true);
  });

  test('deletes an uploaded file', () async {
    final client = HttpClient();
    final postReq = await client.postUrl(url('/uploads?filename=note.txt'));
    postReq.add(utf8.encode('hello'));
    await (await postReq.close()).drain();

    final delRes = await (await client.deleteUrl(url('/uploads/note.txt'))).close();
    expect(delRes.statusCode, 200);

    final fetchRes = await (await client.getUrl(url('/uploads/note.txt'))).close();
    expect(fetchRes.statusCode, 404);
    client.close(force: true);
  });

  test('lists no sets when none exist', () async {
    final client = HttpClient();
    final res = await (await client.getUrl(url('/sets'))).close();
    final body = jsonDecode(await res.transform(utf8.decoder).join());
    expect(body['sets'], isEmpty);
    client.close(force: true);
  });

  test('lists, serves, and deletes a manually-populated set', () async {
    // Bypasses the actual native folder picker (untestable off-device) and
    // exercises everything downstream of it directly, the same way
    // _handleImportSet itself would populate the folder.
    final setDir = Directory('${appDir.path}/sets/Sunsets')..createSync(recursive: true);
    File('${setDir.path}/a.jpg').writeAsStringSync('fake-jpg-bytes');
    File('${setDir.path}/b.png').writeAsStringSync('fake-png-bytes');

    final client = HttpClient();

    final listSetsRes = await (await client.getUrl(url('/sets'))).close();
    final listSetsBody = jsonDecode(await listSetsRes.transform(utf8.decoder).join());
    expect(listSetsBody['sets'], [
      {'name': 'Sunsets', 'count': 2},
    ]);

    final listFilesRes = await (await client.getUrl(url('/sets/Sunsets'))).close();
    final listFilesBody = jsonDecode(await listFilesRes.transform(utf8.decoder).join());
    expect(listFilesBody['files'], [
      {'name': 'a.jpg', 'url': '/sets/Sunsets/a.jpg'},
      {'name': 'b.png', 'url': '/sets/Sunsets/b.png'},
    ]);

    final fetchRes = await (await client.getUrl(url('/sets/Sunsets/a.jpg'))).close();
    expect(fetchRes.statusCode, 200);
    expect(await fetchRes.transform(utf8.decoder).join(), 'fake-jpg-bytes');

    final delRes = await (await client.deleteUrl(url('/sets/Sunsets'))).close();
    expect(delRes.statusCode, 200);

    final afterDeleteRes = await (await client.getUrl(url('/sets'))).close();
    final afterDeleteBody = jsonDecode(await afterDeleteRes.transform(utf8.decoder).join());
    expect(afterDeleteBody['sets'], isEmpty);

    client.close(force: true);
  });

  test('rejects path traversal in a set name', () async {
    final client = HttpClient();
    // Verified empirically (not assumed) that dart:io's HttpServer leaves
    // %2F un-decoded in request.uri.path — so this arrives as one opaque
    // path segment, matches the /sets/<name> route, and only gets decoded
    // (and rejected) once _sanitizeFilename runs Uri.decodeComponent on it.
    // A literal ".." or %2e%2e-encoded dots, by contrast, get normalized
    // away by the HTTP stack before the request handler ever sees them —
    // verified that too, and it's *not* a traversal risk as a result.
    final res = await (await client.getUrl(url('/sets/..%2F..%2Fescaped'))).close();
    expect(res.statusCode, 400);
    client.close(force: true);
  });

  // The remaining /share and /speak tests only cover validation that
  // returns before touching the actual platform plugin (SharePlus/
  // FlutterTts) — those plugins need a real device/platform channel and
  // aren't invokable from a plain `flutter test` VM run.

  test('rejects /share with neither text nor url', () async {
    final client = HttpClient();
    final req = await client.postUrl(url('/share'));
    req.write('{}');
    final res = await req.close();
    expect(res.statusCode, 400);
    client.close(force: true);
  });

  test('rejects /share with a url that does not exist', () async {
    final client = HttpClient();
    final req = await client.postUrl(url('/share'));
    req.write(jsonEncode({'url': '/uploads/nonexistent.png'}));
    final res = await req.close();
    expect(res.statusCode, 400);
    client.close(force: true);
  });

  test('rejects /share with a path-traversal url', () async {
    final client = HttpClient();
    final req = await client.postUrl(url('/share'));
    req.write(jsonEncode({'url': '/uploads/../../escaped.png'}));
    final res = await req.close();
    expect(res.statusCode, 400);
    client.close(force: true);
  });

  test('rejects /speak with no text', () async {
    final client = HttpClient();
    final req = await client.postUrl(url('/speak'));
    req.write('{}');
    final res = await req.close();
    expect(res.statusCode, 400);
    client.close(force: true);
  });
}
