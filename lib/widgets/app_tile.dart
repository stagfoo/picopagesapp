import 'package:flutter/material.dart';

import '../models/app_entry.dart';
import 'icon_picker.dart';

/// Visual content for an app's grid cell — sizing/interaction is handled by
/// the OrganizeTile wrapper around this.
class AppTileContent extends StatelessWidget {
  final AppEntry entry;

  const AppTileContent({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return AppIconWidget(
      id: entry.id,
      fallbackTitle: entry.title,
      emoji: entry.iconEmoji,
      imagePath: entry.iconImagePath,
      bigLabel: entry.colSpan > 1 || entry.rowSpan > 1,
      backgroundColor: entry.backgroundColor != null ? Color(entry.backgroundColor!) : null,
    );
  }
}
