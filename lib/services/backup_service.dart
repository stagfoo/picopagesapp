import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';

/// Backs up and restores everything PicoPages has stored — imported apps,
/// their uploaded/set files, stickers, and all Hive data (the app registry
/// and every app's localStorage-equivalent) — as a single zip. Works
/// because all of it already lives under one root folder (see
/// storage_root.dart), so a backup is just "zip the whole folder" and a
/// restore is "unzip it back over the folder."
class BackupService {
  final Directory root;

  BackupService({required this.root});

  /// Zips the entire root folder and lets the user save it wherever they
  /// like via the native save dialog. Returns the saved path, or null if
  /// the user cancelled.
  Future<String?> exportBackup() async {
    final archive = Archive();
    await _addDirectoryToArchive(root, root.path, archive);
    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw StateError('failed to encode backup zip');
    }

    final timestamp = DateTime.now().toIso8601String().split('T').first;
    return FilePicker.platform.saveFile(
      fileName: 'picopages-backup-$timestamp.zip',
      type: FileType.custom,
      allowedExtensions: ['zip'],
      bytes: Uint8List.fromList(zipBytes),
    );
  }

  Future<void> _addDirectoryToArchive(Directory dir, String rootPath, Archive archive) async {
    await for (final entity in dir.list(recursive: false)) {
      if (entity is Directory) {
        await _addDirectoryToArchive(entity, rootPath, archive);
      } else if (entity is File) {
        final relativePath = entity.path.substring(rootPath.length + 1);
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
      }
    }
  }

  /// Lets the user pick a backup zip, closes every open Hive box (so
  /// overwriting their files on disk is safe), then extracts the zip over
  /// the root folder — replacing everything currently there. Returns true
  /// if a restore happened; the app is left in a state that only a full
  /// restart makes safe to use again, since every box this session had
  /// open is now closed out from under it. Returns false if the user
  /// cancelled the picker.
  Future<bool> importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.single.path == null) return false;

    final zipFile = File(result.files.single.path!);
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    await Hive.close();

    // A restore replaces everything currently there rather than merging —
    // otherwise stale files for apps/data not present in the backup (e.g.
    // an app deleted after the backup was made) would linger alongside the
    // restored state.
    await for (final entity in root.list()) {
      await entity.delete(recursive: true);
    }

    for (final file in archive) {
      final outPath = '${root.path}/${file.name}';
      if (file.isFile) {
        final outFile = File(outPath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }
    return true;
  }
}
