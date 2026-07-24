import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';

import '../models/app_entry.dart';
import 'app_repository.dart';

class ImportService {
  final AppRepository repository;

  ImportService(this.repository);

  /// Opens a file picker for a single .html file or a .zip bundle, imports
  /// it into its own app folder, and registers it. Returns null if the user
  /// cancelled the picker.
  Future<AppEntry?> importFromPicker() async {
    final picked = await _pickHtmlOrZip();
    if (picked == null) return null;

    final entry = await repository.registerApp(title: _titleFromFileName(picked.name));
    final folder = repository.folderFor(entry);
    await folder.create(recursive: true);
    await _installInto(folder, picked);
    return entry;
  }

  /// Replaces an existing app's served files (a new version of the same
  /// app) while leaving its identity intact: the Hive storage box is keyed
  /// by the app's id (untouched here), and the `uploads/` folder — the
  /// app's own sandbox-uploaded files — is preserved rather than wiped.
  /// Returns false if the user cancelled the picker.
  Future<bool> updateAppFiles(AppEntry entry) async {
    final picked = await _pickHtmlOrZip();
    if (picked == null) return false;

    final folder = repository.folderFor(entry);
    await _clearFolderExceptUploads(folder);
    await _installInto(folder, picked);
    return true;
  }

  Future<_PickedFile?> _pickHtmlOrZip() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['html', 'htm', 'zip'],
    );
    if (result == null || result.files.single.path == null) return null;
    final file = result.files.single;
    return _PickedFile(File(file.path!), file.name);
  }

  Future<void> _installInto(Directory folder, _PickedFile picked) async {
    final ext = picked.name.split('.').last.toLowerCase();
    if (ext == 'zip') {
      await _extractZip(picked.file, folder);
      await _flattenIfNested(folder);
    } else {
      await picked.file.copy('${folder.path}/index.html');
    }
  }

  /// Deletes everything in [folder] except the `uploads` subfolder, so
  /// updating an app's files doesn't destroy what it saved through the
  /// sandbox's upload endpoint.
  Future<void> _clearFolderExceptUploads(Directory folder) async {
    if (!await folder.exists()) {
      await folder.create(recursive: true);
      return;
    }
    await for (final entity in folder.list()) {
      final segments = entity.uri.pathSegments.where((s) => s.isNotEmpty);
      if (segments.isEmpty) continue;
      if (segments.last == 'uploads') continue;
      await entity.delete(recursive: true);
    }
  }

  Future<void> _extractZip(File zipFile, Directory destination) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      final outPath = '${destination.path}/${file.name}';
      if (file.isFile) {
        final outFile = File(outPath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }
  }

  /// If the zip contained a single top-level folder wrapping everything
  /// (e.g. `my-app/index.html`) instead of files at the root, hoist its
  /// contents up so the server's root always has index.html directly in it.
  /// Ignores an existing `uploads/` folder when deciding this, since an
  /// app update preserves that alongside whatever the new zip contains.
  Future<void> _flattenIfNested(Directory folder) async {
    final indexAtRoot = File('${folder.path}/index.html');
    if (await indexAtRoot.exists()) return;

    final entries = await folder.list().toList();
    final relevant = entries.where((e) {
      final segments = e.uri.pathSegments.where((s) => s.isNotEmpty);
      return segments.isNotEmpty && segments.last != 'uploads';
    }).toList();
    if (relevant.length == 1 && relevant.first is Directory) {
      final nested = relevant.first as Directory;
      final nestedIndex = File('${nested.path}/index.html');
      if (await nestedIndex.exists()) {
        for (final child in await nested.list().toList()) {
          final newPath = '${folder.path}/${child.uri.pathSegments.last}';
          await child.rename(newPath);
        }
        await nested.delete(recursive: true);
      }
    }
  }

  String _titleFromFileName(String fileName) {
    final base = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    return base
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

class _PickedFile {
  final File file;
  final String name;
  _PickedFile(this.file, this.name);
}
