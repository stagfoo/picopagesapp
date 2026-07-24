import 'app_entry.dart';
import 'sticker_entry.dart';

/// A slot in the home grid: either a launchable app or a decorative sticker.
sealed class GridItem {
  String get id;
  int get order;
  set order(int value);
  int get colSpan;
  set colSpan(int value);
  int get rowSpan;
  set rowSpan(int value);
}

class AppGridItem implements GridItem {
  final AppEntry app;
  AppGridItem(this.app);

  @override
  String get id => app.id;
  @override
  int get order => app.order;
  @override
  set order(int value) => app.order = value;
  @override
  int get colSpan => app.colSpan;
  @override
  set colSpan(int value) => app.colSpan = value;
  @override
  int get rowSpan => app.rowSpan;
  @override
  set rowSpan(int value) => app.rowSpan = value;
}

class StickerGridItem implements GridItem {
  final StickerEntry sticker;
  StickerGridItem(this.sticker);

  @override
  String get id => sticker.id;
  @override
  int get order => sticker.order;
  @override
  set order(int value) => sticker.order = value;
  @override
  int get colSpan => sticker.colSpan;
  @override
  set colSpan(int value) => sticker.colSpan = value;
  @override
  int get rowSpan => sticker.rowSpan;
  @override
  set rowSpan(int value) => sticker.rowSpan = value;
}
