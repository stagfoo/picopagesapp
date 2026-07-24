import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'palette.dart';

const kIconEmojiChoices = [
  '🎮', '🧩', '📝', '🎲', '🧠', '⚡', '🎨', '📊',
  '🔧', '🧪', '📚', '🕹️', '🗂️', '⏱️', '🧮', '🎯',
];

/// Result of the icon picker: either an emoji or a path to a copied image
/// file. Exactly one of the two will be set.
class IconPickResult {
  final String? emoji;
  final String? imagePath;
  IconPickResult.emoji(this.emoji) : imagePath = null;
  IconPickResult.image(this.imagePath) : emoji = null;
}

Future<IconPickResult?> showIconPicker(BuildContext context) {
  return showModalBottomSheet<IconPickResult>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose an icon', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pick image from gallery'),
              onTap: () async {
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.gallery);
                if (picked != null && context.mounted) {
                  Navigator.pop(context, IconPickResult.image(picked.path));
                }
              },
            ),
            const Divider(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kIconEmojiChoices
                  .map((emoji) => InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => Navigator.pop(context, IconPickResult.emoji(emoji)),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(emoji, style: const TextStyle(fontSize: 28)),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Fills its parent — used as the full background+content of a grid tile.
/// Background color/glow is deterministic per [id] so the grid reads like a
/// personalized home menu instead of one flat color.
class AppIconWidget extends StatelessWidget {
  final String id;
  final String? emoji;
  final String? imagePath;
  final String fallbackTitle;
  final bool showLabel;
  final bool bigLabel;
  final Color? backgroundColor;

  const AppIconWidget({
    super.key,
    required this.id,
    required this.fallbackTitle,
    this.emoji,
    this.imagePath,
    this.showLabel = true,
    this.bigLabel = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = paletteFor(id);

    Widget emojiOrImage;
    if (imagePath != null) {
      emojiOrImage = ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.file(File(imagePath!), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
      );
    } else if (emoji != null) {
      emojiOrImage = Center(child: Text(emoji!, style: const TextStyle(fontSize: 40)));
    } else {
      final letter = fallbackTitle.isNotEmpty ? fallbackTitle[0].toUpperCase() : '?';
      emojiOrImage = Center(
        child: Text(letter, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1),
        color: backgroundColor,
        gradient: backgroundColor == null
            ? LinearGradient(
                colors: [palette.light, palette.dark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        boxShadow: [
          BoxShadow(color: backgroundColor ?? palette.glow, blurRadius: 16, spreadRadius: 1),
          const BoxShadow(color: Color(0x33241836), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: EdgeInsets.all(imagePath != null ? 0 : 6),
            child: emojiOrImage,
          ),
          if (showLabel && bigLabel)
            Positioned(
              left: 8,
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  fallbackTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
