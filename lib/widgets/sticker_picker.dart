import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/sticker_entry.dart';
import '../services/app_repository.dart';

const kStickerEmojiChoices = [
  '✨', '🌟', '🎉', '🐱', '🐶', '🍕', '🌈', '💫',
  '🔥', '❤️', '👾', '🍩', '🌸', '🚀', '🎈', '⭐',
];

/// Lets the user drop a purely decorative tile into the grid: a gif/image
/// picked from storage, or a fun emoji. Handles copying the file and
/// registering it with the repository, returning the new sticker.
Future<StickerEntry?> showStickerPicker(BuildContext context, AppRepository repository) {
  return showModalBottomSheet<StickerEntry>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add a sticker', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.gif_outlined),
              title: const Text('Pick a gif or image'),
              onTap: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['gif', 'png', 'jpg', 'jpeg', 'webp'],
                );
                final path = result?.files.single.path;
                if (path == null) return;
                final ext = path.split('.').last.toLowerCase();
                final destPath = '${repository.stickersRootDir.path}/${const Uuid().v4()}.$ext';
                await result!.files.single.xFile.saveTo(destPath);
                final sticker = await repository.addSticker(imagePath: destPath);
                if (context.mounted) Navigator.pop(context, sticker);
              },
            ),
            const Divider(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kStickerEmojiChoices
                  .map((emoji) => InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () async {
                          final sticker = await repository.addSticker(emoji: emoji);
                          if (context.mounted) Navigator.pop(context, sticker);
                        },
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
