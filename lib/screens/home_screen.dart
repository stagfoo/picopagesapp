import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/app_entry.dart';
import '../models/grid_item.dart';
import '../models/sticker_entry.dart';
import '../services/app_repository.dart';
import '../services/grid_placement.dart';
import '../services/import_service.dart';
import '../widgets/app_tile.dart';
import '../widgets/color_picker_sheet.dart';
import '../widgets/icon_picker.dart';
import '../widgets/organize_tile.dart';
import '../widgets/palette.dart';
import '../widgets/pink_bloom_background.dart';
import '../widgets/sticker_picker.dart';
import '../widgets/sticker_tile.dart';
import 'data_viewer_screen.dart';
import 'sandbox_docs_screen.dart';
import 'webview_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppRepository repository;

  const HomeScreen({super.key, required this.repository});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _crossAxisCount = 4;
  static const _mainAxisSpacing = 14.0;
  static const _crossAxisSpacing = 12.0;

  late List<GridItem> _items;
  late ImportService _importService;
  bool _importing = false;
  bool _updatingFiles = false;
  bool _organizing = false;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _importService = ImportService(widget.repository);
    _items = widget.repository.listGridItems();
  }

  void _refresh() {
    setState(() => _items = widget.repository.listGridItems());
  }

  Future<void> _addApp() async {
    setState(() => _importing = true);
    try {
      final entry = await _importService.importFromPicker();
      if (entry != null) _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _addSticker() async {
    final sticker = await showStickerPicker(context, widget.repository);
    if (sticker != null) _refresh();
  }

  Future<void> _showAddMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.web_outlined),
              title: const Text('Import HTML app'),
              onTap: () => Navigator.pop(context, 'app'),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Add a sticker'),
              onTap: () => Navigator.pop(context, 'sticker'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'app') await _addApp();
    if (choice == 'sticker') await _addSticker();
  }

  void _openApp(AppEntry entry) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WebviewScreen(entry: entry, repository: widget.repository),
    ));
  }

  void _toggleOrganizing() {
    setState(() {
      _organizing = !_organizing;
      if (!_organizing) _selectedId = null;
    });
  }

  void _onTileTap(GridItem item, {AppEntry? app}) {
    if (_organizing) {
      setState(() => _selectedId = _selectedId == item.id ? null : item.id);
    } else if (app != null) {
      _openApp(app);
    }
  }

  void _onTileLongPress(String id) {
    if (_organizing) return;
    setState(() {
      _organizing = true;
      _selectedId = id;
    });
  }

  Future<void> _setColSpan(GridItem item, int value) async {
    if (!const GridPlacement().canResize(_items, item, value, item.rowSpan)) {
      _showResizeBlockedHint();
      return;
    }
    item.colSpan = value;
    await _persist(item);
  }

  Future<void> _setRowSpan(GridItem item, int value) async {
    if (!const GridPlacement().canResize(_items, item, item.colSpan, value)) {
      _showResizeBlockedHint();
      return;
    }
    item.rowSpan = value;
    await _persist(item);
  }

  void _showResizeBlockedHint() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Not enough room — move the tile(s) in the way first'),
    ));
  }

  Future<void> _persist(GridItem item) async {
    switch (item) {
      case AppGridItem(:final app):
        await widget.repository.updateApp(app);
      case StickerGridItem(:final sticker):
        await widget.repository.updateSticker(sticker);
    }
    setState(() {});
  }

  Future<void> _onSwipeMove(GridItem item, int dRow, int dCol) async {
    final moved = const GridPlacement().moveByDelta(_items, item, dRow, dCol);
    if (moved.isEmpty) return;
    setState(() {});
    for (final changed in moved) {
      switch (changed) {
        case AppGridItem(:final app):
          await widget.repository.updateApp(app);
        case StickerGridItem(:final sticker):
          await widget.repository.updateSticker(sticker);
      }
    }
  }

  Future<void> _renameApp(AppEntry entry) async {
    final controller = TextEditingController(text: entry.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename app'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newTitle != null && newTitle.isNotEmpty) {
      entry.title = newTitle;
      await widget.repository.updateApp(entry);
      _refresh();
    }
  }

  Future<void> _changeIcon(AppEntry entry) async {
    final result = await showIconPicker(context);
    if (result == null) return;
    entry.iconEmoji = result.emoji;
    entry.iconImagePath = result.imagePath;
    await widget.repository.updateApp(entry);
    _refresh();
  }

  Future<void> _changeColor(AppEntry entry) async {
    final current = entry.backgroundColor != null
        ? Color(entry.backgroundColor!)
        : paletteFor(entry.id).light;
    final picked = await showBackgroundColorPicker(context, current);
    if (picked == null) return;
    // Sentinel from the "Reset to default" action.
    entry.backgroundColor = picked.toARGB32() == 0 ? null : picked.toARGB32();
    await widget.repository.updateApp(entry);
    _refresh();
  }

  Future<void> _updateAppFiles(AppEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update app files?'),
        content: Text(
            'Pick a new HTML file or zip for "${entry.title}". Its saved data and uploaded files will be kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _updatingFiles = true);
    try {
      final updated = await _importService.updateAppFiles(entry);
      if (mounted && updated) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App files updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _updatingFiles = false);
    }
  }

  Future<void> _deleteApp(AppEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete app?'),
        content: Text('This removes "${entry.title}" and its saved data. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.repository.deleteApp(entry);
      setState(() => _selectedId = null);
      _refresh();
    }
  }

  Future<void> _deleteSticker(StickerEntry sticker) async {
    await widget.repository.deleteSticker(sticker);
    setState(() => _selectedId = null);
    _refresh();
  }

  Widget _buildTile(GridItem item) {
    final selected = _selectedId == item.id;
    return switch (item) {
      AppGridItem(:final app) => OrganizeTile(
          key: ValueKey(item.id),
          id: item.id,
          organizing: _organizing,
          selected: selected,
          onTap: () => _onTileTap(item, app: app),
          onLongPress: () => _onTileLongPress(item.id),
          onSwipeMove: (dRow, dCol) => _onSwipeMove(item, dRow, dCol),
          child: AppTileContent(entry: app),
        ),
      StickerGridItem(:final sticker) => OrganizeTile(
          key: ValueKey(item.id),
          id: item.id,
          organizing: _organizing,
          selected: selected,
          onTap: () => _onTileTap(item),
          onLongPress: () => _onTileLongPress(item.id),
          onSwipeMove: (dRow, dCol) => _onSwipeMove(item, dRow, dCol),
          child: StickerTileContent(sticker: sticker),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    GridItem? selectedItem;
    for (final item in _items) {
      if (item.id == _selectedId) {
        selectedItem = item;
        break;
      }
    }

    return Scaffold(
      body: PinkBloomBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildTitlePill(selectedItem),
              Expanded(child: _buildGrid()),
              _buildDock(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitlePill(GridItem? selectedItem) {
    final showEditBanner = selectedItem != null && _organizing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SizeTransition(sizeFactor: animation, axis: Axis.vertical, child: child),
        ),
        child: showEditBanner
            ? _buildEditBanner(selectedItem, key: ValueKey('edit-${selectedItem.id}'))
            : _buildNormalTitlePill(key: const ValueKey('normal')),
      ),
    );
  }

  Widget _buildNormalTitlePill({Key? key}) {
    final hint = _organizing
        ? 'Tap a tile to select it, swipe to move'
        : 'Long-press a tile to organize';
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 24),
          const BoxShadow(color: Color(0x26B43C8C), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('PicoPages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF3F3A52))),
          Text(hint, style: const TextStyle(fontSize: 11, color: Color(0xFF8A879B))),
        ],
      ),
    );
  }

  Widget _buildEditBanner(GridItem item, {Key? key}) {
    final AppEntry? app = item is AppGridItem ? item.app : null;
    final StickerEntry? sticker = item is StickerGridItem ? item.sticker : null;
    final title = app?.title ?? 'Sticker';

    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
              if (app != null) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Rename',
                  onPressed: () => _renameApp(app),
                ),
                IconButton(
                  icon: const Icon(Icons.image_outlined, size: 18),
                  tooltip: 'Change icon',
                  onPressed: () => _changeIcon(app),
                ),
                IconButton(
                  icon: const Icon(Icons.palette_outlined, size: 18),
                  tooltip: 'Change background color',
                  onPressed: () => _changeColor(app),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                tooltip: 'Delete',
                onPressed: () => app != null ? _deleteApp(app) : _deleteSticker(sticker!),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 4),
              _dimDropdown('Columns', item.colSpan, (v) => _setColSpan(item, v)),
              const SizedBox(width: 16),
              _dimDropdown('Rows', item.rowSpan, (v) => _setRowSpan(item, v)),
              if (app != null) ...[
                const Spacer(),
                TextButton.icon(
                  onPressed: _updatingFiles ? null : () => _updateAppFiles(app),
                  icon: _updatingFiles
                      ? const SizedBox(
                          width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.system_update_alt_outlined, size: 16),
                  label: const Text('Update files', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF8E6FE0),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _dimDropdown(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8A879B))),
        const SizedBox(width: 6),
        DropdownButton<int>(
          value: value,
          dropdownColor: Colors.white,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF3F3A52)),
          underline: const SizedBox(),
          isDense: true,
          items: const [1, 2, 3, 4].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }

  Widget _buildGrid() {
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.widgets_outlined, size: 64, color: Color(0xFF8A879B)),
            const SizedBox(height: 12),
            const Text('No apps yet'),
            const SizedBox(height: 4),
            const Text('Tap + to import an HTML file or zip', style: TextStyle(color: Color(0xFF8A879B))),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellExtent =
              (constraints.maxWidth - (_crossAxisCount - 1) * _crossAxisSpacing) / _crossAxisCount;
          final rowStep = cellExtent + _mainAxisSpacing;
          final colStep = cellExtent + _crossAxisSpacing;

          final maxRow = _items.map((i) => i.row + i.rowSpan).fold(0, math.max);
          final contentHeight = maxRow * rowStep - _mainAxisSpacing;
          final gridHeight = math.max(contentHeight, constraints.maxHeight);

          return SingleChildScrollView(
            child: SizedBox(
              width: constraints.maxWidth,
              height: gridHeight,
              child: Stack(
                children: [
                  if (_organizing)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _OrganizeGridPainter(
                            crossAxisCount: _crossAxisCount,
                            cellExtent: cellExtent,
                            crossAxisSpacing: _crossAxisSpacing,
                            mainAxisSpacing: _mainAxisSpacing,
                          ),
                        ),
                      ),
                    ),
                  for (final item in _items)
                    AnimatedPositioned(
                      key: ValueKey(item.id),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      left: item.col * colStep,
                      top: item.row * rowStep,
                      width: item.colSpan * cellExtent + (item.colSpan - 1) * _crossAxisSpacing,
                      height: item.rowSpan * cellExtent + (item.rowSpan - 1) * _mainAxisSpacing,
                      child: _buildTile(item),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDock() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 6, 28, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 24),
            const BoxShadow(color: Color(0x26B43C8C), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _dockPill(
                  label: _organizing ? 'Done' : 'Edit',
                  active: _organizing,
                  onTap: _toggleOrganizing,
                ),
              ),
            ),
            _dockIconButton(
              icon: Icons.storage_outlined,
              tooltip: 'View stored data',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DataViewerScreen(apps: widget.repository.listApps()),
              )),
            ),
            _dockIconButton(
              icon: Icons.integration_instructions_outlined,
              tooltip: 'Sandbox API docs',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SandboxDocsScreen(),
              )),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: _dockIconButton(
                  icon: Icons.add,
                  tooltip: 'Add app or sticker',
                  filled: true,
                  loading: _importing,
                  onTap: _importing ? null : _showAddMenu,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dockPill({required String label, required bool active, VoidCallback? onTap}) {
    return Material(
      color: active ? const Color(0xFF8E6FE0) : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: active ? Colors.white : const Color(0xFF8E6FE0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dockIconButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
    bool filled = false,
    bool loading = false,
  }) {
    return Material(
      color: filled ? const Color(0xFF8E6FE0) : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: filled ? Colors.white : const Color(0xFF8E6FE0),
                  ),
                )
              : Tooltip(
                  message: tooltip,
                  child: Icon(icon, size: 22, color: filled ? Colors.white : const Color(0xFF8E6FE0)),
                ),
        ),
      ),
    );
  }
}

/// Faint rounded-cell grid drawn behind the tiles while organizing, so it's
/// clear where each column/row lands as you drag a tile around.
class _OrganizeGridPainter extends CustomPainter {
  final int crossAxisCount;
  final double cellExtent;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  _OrganizeGridPainter({
    required this.crossAxisCount,
    required this.cellExtent,
    required this.crossAxisSpacing,
    required this.mainAxisSpacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (cellExtent <= 0) return;
    final paint = Paint()
      ..color = const Color(0xFF8E6FE0).withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    const radius = Radius.circular(14);

    final rowStep = cellExtent + mainAxisSpacing;
    final colStarts = [
      for (var i = 0; i < crossAxisCount; i++) i * (cellExtent + crossAxisSpacing),
    ];

    var y = 0.0;
    while (y < size.height) {
      for (final x in colStarts) {
        final rect = Rect.fromLTWH(x, y, cellExtent, cellExtent);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
      }
      y += rowStep;
    }
  }

  @override
  bool shouldRepaint(covariant _OrganizeGridPainter oldDelegate) {
    return oldDelegate.crossAxisCount != crossAxisCount ||
        oldDelegate.cellExtent != cellExtent ||
        oldDelegate.crossAxisSpacing != crossAxisSpacing ||
        oldDelegate.mainAxisSpacing != mainAxisSpacing;
  }
}
