import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// The one folder everything lives under: imported apps, stickers, and the
/// Hive database files. Uses the app's own external-storage directory so
/// it's a real, browsable path (e.g. via a file manager or Syncthing)
/// instead of buried in Android's private app sandbox — no extra runtime
/// permission is needed for an app's own external files directory.
Future<Directory> resolvePicoPagesRoot() async {
  final external = await getExternalStorageDirectory();
  final base = external ?? await getApplicationSupportDirectory();
  final root = Directory('${base.path}/picopages');
  if (!await root.exists()) {
    await root.create(recursive: true);
  }
  return root;
}

/// Turns a title into a filesystem-safe, human-readable slug, e.g.
/// "Thistledown!" -> "thistledown". Falls back to "app" if nothing survives.
String slugify(String input) {
  final lower = input.toLowerCase().trim();
  final slug = lower
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'app' : slug;
}
