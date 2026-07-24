class AppEntry {
  final String id;
  String title;
  String? iconEmoji;
  String? iconImagePath;
  final String folderName;
  final DateTime importedAt;
  int order;
  int colSpan;
  int rowSpan;
  /// ARGB32 value of a user-picked background color (supports transparency).
  /// Null means use the automatic hashed palette color.
  int? backgroundColor;

  AppEntry({
    required this.id,
    required this.title,
    required this.folderName,
    required this.importedAt,
    required this.order,
    this.iconEmoji,
    this.iconImagePath,
    this.colSpan = 1,
    this.rowSpan = 1,
    this.backgroundColor,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'iconEmoji': iconEmoji,
        'iconImagePath': iconImagePath,
        'folderName': folderName,
        'importedAt': importedAt.toIso8601String(),
        'order': order,
        'colSpan': colSpan,
        'rowSpan': rowSpan,
        'backgroundColor': backgroundColor,
      };

  factory AppEntry.fromMap(Map<dynamic, dynamic> map) => AppEntry(
        id: map['id'] as String,
        title: map['title'] as String,
        folderName: map['folderName'] as String,
        importedAt: DateTime.parse(map['importedAt'] as String),
        order: map['order'] as int? ?? 0,
        iconEmoji: map['iconEmoji'] as String?,
        iconImagePath: map['iconImagePath'] as String?,
        colSpan: map['colSpan'] as int? ?? 1,
        rowSpan: map['rowSpan'] as int? ?? 1,
        backgroundColor: map['backgroundColor'] as int?,
      );
}
