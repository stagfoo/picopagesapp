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
}
