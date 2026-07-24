import 'dart:io';

import 'package:flutter/material.dart';

import '../models/sticker_entry.dart';

/// Visual content for a sticker's grid cell — sizing/interaction is handled
/// by the OrganizeTile wrapper around this. Purely decorative, no label.
class StickerTileContent extends StatelessWidget {
  final StickerEntry sticker;

  const StickerTileContent({super.key, required this.sticker});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.75),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.white.withValues(alpha: 0.8), blurRadius: 14, spreadRadius: 1),
          const BoxShadow(color: Color(0x1A241836), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: sticker.imagePath != null
            ? Image.file(File(sticker.imagePath!), fit: BoxFit.cover, width: double.infinity, height: double.infinity)
            : Center(child: Text(sticker.emoji ?? '?', style: const TextStyle(fontSize: 36))),
      ),
    );
  }
}
