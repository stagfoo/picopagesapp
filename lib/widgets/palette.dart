import 'package:flutter/material.dart';

class TilePalette {
  final Color light;
  final Color dark;
  final Color glow;
  const TilePalette(this.light, this.dark, this.glow);
}

const _palette = [
  TilePalette(Color(0xFFFFD7A8), Color(0xFFFF9D5C), Color(0x99FF9D5C)), // orange
  TilePalette(Color(0xFFA8E4FF), Color(0xFF4FB2E8), Color(0x994FB2E8)), // sky blue
  TilePalette(Color(0xFFC9F7C0), Color(0xFF5EC96B), Color(0x8C5EC96B)), // green
  TilePalette(Color(0xFFFFC2DD), Color(0xFFFF6FA5), Color(0x99FF6FA5)), // pink
  TilePalette(Color(0xFFD9C9FF), Color(0xFF8E6FE0), Color(0x998E6FE0)), // purple
  TilePalette(Color(0xFFFFF2A8), Color(0xFFF5C542), Color(0x99F5C542)), // yellow
  TilePalette(Color(0xFFC0F0EA), Color(0xFF3ECBB8), Color(0x8C3ECBB8)), // teal
  TilePalette(Color(0xFFFFB3AB), Color(0xFFFF6B5C), Color(0x99FF6B5C)), // red
];

/// Deterministic pastel-to-vivid palette per id, so the grid reads like a
/// personalized home menu rather than one flat color.
TilePalette paletteFor(String id) {
  var hash = 0;
  for (final unit in id.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return _palette[hash % _palette.length];
}
