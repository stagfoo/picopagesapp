/// A purely decorative grid tile — a gif, image, or emoji dropped between
/// app icons, like stickers on a 3DS/Wii U home menu. Not launchable.
class StickerEntry {
  final String id;
  int order;
  String? emoji;
  String? imagePath;
  int colSpan;
  int rowSpan;

  StickerEntry({
    required this.id,
    required this.order,
    this.emoji,
    this.imagePath,
    this.colSpan = 1,
    this.rowSpan = 1,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'order': order,
        'emoji': emoji,
        'imagePath': imagePath,
        'colSpan': colSpan,
        'rowSpan': rowSpan,
      };

  factory StickerEntry.fromMap(Map<dynamic, dynamic> map) => StickerEntry(
        id: map['id'] as String,
        order: map['order'] as int? ?? 0,
        emoji: map['emoji'] as String?,
        imagePath: map['imagePath'] as String?,
        colSpan: map['colSpan'] as int? ?? 1,
        rowSpan: map['rowSpan'] as int? ?? 1,
      );
}
