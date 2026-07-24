import 'dart:ui';

import 'package:flutter/material.dart';

/// Pink checkerboard + soft blurred pastel bloom blobs, behind the grid.
class PinkBloomBackground extends StatelessWidget {
  final Widget child;

  const PinkBloomBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _CheckerboardPainter()),
        const _BloomBlobs(),
        child,
      ],
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  static const double tile = 22;
  static const _base = Color(0xFFFFE3EF);
  static const _dark = Color(0xFFFFCFE4);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _base);
    final paint = Paint()..color = _dark;
    for (double y = 0; y < size.height; y += tile) {
      for (double x = 0; x < size.width; x += tile) {
        final col = (x / tile).floor();
        final row = (y / tile).floor();
        if ((col + row) % 2 == 0) {
          canvas.drawRect(Rect.fromLTWH(x, y, tile, tile), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BloomBlobs extends StatelessWidget {
  const _BloomBlobs();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Opacity(
          opacity: 0.7,
          child: Stack(
            children: [
              _blob(top: -60, left: -40, color: const Color(0xFFFFE08A)),
              _blob(top: -20, right: -60, color: const Color(0xFF9BE8FF)),
              _blob(bottom: -60, left: 40, color: const Color(0xFFBAFFD9)),
              _blob(bottom: -80, right: -40, color: const Color(0xFFFFB3E0)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blob({double? top, double? bottom, double? left, double? right, required Color color}) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
