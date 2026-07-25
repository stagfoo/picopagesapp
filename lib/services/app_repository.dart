import 'dart:async';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/app_entry.dart';
import '../models/grid_item.dart';
import '../models/sticker_entry.dart';
import 'grid_placement.dart';
import 'storage_root.dart';

/// Owns the registry of imported apps/stickers and their on-disk folders.
/// Each app's storage lives in its own Hive box, keyed by app id, kept
/// separate from whatever the WebView engine itself decides to cache.
/// Everything — imported app files, stickers, and the Hive database files
/// themselves — lives under one browsable "picopages" root folder.
class AppRepository {
  static const _registryBoxName = 'app_registry';
  static const _stickersBoxName = 'stickers';
  static const _uuid = Uuid();

  final Directory root;
  late Box _registryBox;
  late Box _stickersBox;
  Directory? _appsRootDir;
  Directory? _stickersRootDir;

  AppRepository({required this.root});

  Future<void> init() async {
    _registryBox = await Hive.openBox(_registryBoxName);
    _stickersBox = await Hive.openBox(_stickersBoxName);
    _appsRootDir = Directory('${root.path}/apps');
    if (!await _appsRootDir!.exists()) {
      await _appsRootDir!.create(recursive: true);
    }
    _stickersRootDir = Directory('${root.path}/stickers');
    if (!await _stickersRootDir!.exists()) {
      await _stickersRootDir!.create(recursive: true);
    }
  }

  Directory get appsRootDir => _appsRootDir!;
  Directory get stickersRootDir => _stickersRootDir!;

  Directory folderFor(AppEntry entry) =>
      Directory('${appsRootDir.path}/${entry.folderName}');

  List<AppEntry> listApps() {
    return _registryBox.values.map((v) => AppEntry.fromMap(v as Map)).toList();
  }

  List<StickerEntry> listStickers() {
    return _stickersBox.values.map((v) => StickerEntry.fromMap(v as Map)).toList();
  }

  /// Apps and stickers combined, sorted by grid position. Any item that has
  /// never had a real (row, col) — newly created, or left over from before
  /// grid positions existed — gets one assigned here (first-fit, in
  /// creation order) and persisted so this only happens once per item.
  List<GridItem> listGridItems() {
    final items = <GridItem>[
      ...listApps().map(AppGridItem.new),
      ...listStickers().map(StickerGridItem.new),
    ];
    final newlyPlaced = const GridPlacement().assignMissingPositions(items);
    for (final item in newlyPlaced) {
      switch (item) {
        case AppGridItem(:final app):
          unawaited(updateApp(app));
        case StickerGridItem(:final sticker):
          unawaited(updateSticker(sticker));
      }
    }
    items.sort((a, b) {
      final rowCompare = a.row.compareTo(b.row);
      return rowCompare != 0 ? rowCompare : a.col.compareTo(b.col);
    });
    return items;
  }

  int _nextOrder() {
    final orders = [
      ...listApps().map((a) => a.order),
      ...listStickers().map((s) => s.order),
    ];
    if (orders.isEmpty) return 0;
    return orders.reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<AppEntry> registerApp({required String title}) async {
    final id = _uuid.v4();
    // Human-readable so the folder makes sense when browsed outside the
    // app; the id suffix keeps it unique even if titles collide.
    final folderName = '${slugify(title)}_${id.substring(0, 8)}';
    final entry = AppEntry(
      id: id,
      title: title,
      folderName: folderName,
      importedAt: DateTime.now(),
      order: _nextOrder(),
    );
    await _registryBox.put(id, entry.toMap());
    return entry;
  }

  Future<void> updateApp(AppEntry entry) async {
    await _registryBox.put(entry.id, entry.toMap());
  }

  Future<void> deleteApp(AppEntry entry) async {
    await _registryBox.delete(entry.id);
    final folder = folderFor(entry);
    if (await folder.exists()) {
      await folder.delete(recursive: true);
    }
    // The per-app storage box mirrors what would have been localStorage;
    // drop it too so deleting an app doesn't leave orphaned data behind.
    final storageBoxName = 'storage_${entry.id}';
    if (await Hive.boxExists(storageBoxName)) {
      await Hive.deleteBoxFromDisk(storageBoxName);
    } else if (Hive.isBoxOpen(storageBoxName)) {
      final box = Hive.box(storageBoxName);
      await box.deleteFromDisk();
    }
  }

  Future<StickerEntry> addSticker({String? emoji, String? imagePath}) async {
    final id = _uuid.v4();
    final entry = StickerEntry(
      id: id,
      order: _nextOrder(),
      emoji: emoji,
      imagePath: imagePath,
    );
    await _stickersBox.put(id, entry.toMap());
    return entry;
  }

  Future<void> updateSticker(StickerEntry entry) async {
    await _stickersBox.put(entry.id, entry.toMap());
  }

  Future<void> deleteSticker(StickerEntry entry) async {
    await _stickersBox.delete(entry.id);
    if (entry.imagePath != null) {
      final file = File(entry.imagePath!);
      if (await file.exists()) await file.delete();
    }
  }
}
