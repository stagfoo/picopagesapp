import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

/// Lets the user pick a custom tile background color, including alpha, so
/// e.g. a semi-transparent white or brown can replace the automatic palette
/// color. Returns null for "use automatic color" (reset), or the picked
/// Color otherwise. Returns via the outer Navigator.pop with a sentinel: the
/// caller distinguishes "cancelled" (no pop value change) from "reset" via
/// the dedicated reset button.
Future<Color?> showBackgroundColorPicker(BuildContext context, Color initial) {
  Color picked = initial;
  return showDialog<Color?>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Tile background color'),
      content: SingleChildScrollView(
        child: ColorPicker(
          pickerColor: initial,
          enableAlpha: true,
          displayThumbColor: true,
          labelTypes: const [ColorLabelType.rgb, ColorLabelType.hsv],
          onColorChanged: (color) => picked = color,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, const Color(0x00000000)),
          child: const Text('Reset to default'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, picked),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}
