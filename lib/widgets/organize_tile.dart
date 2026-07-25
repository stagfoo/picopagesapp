import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Minimum fling velocity (px/s) for a gesture on a selected tile to count
/// as a move swipe rather than an accidental wobble.
const _swipeVelocityThreshold = 200.0;

/// Wraps a tile's visual content with the shared "organize mode" chrome:
/// wiggle animation, selection highlight, and (when selected) swipe-to-move
/// — swipe in a direction to shift the tile one grid cell that way,
/// swapping with whatever tile is already there. Resize (via the edit
/// banner's dropdowns) and delete live off the tile itself.
class OrganizeTile extends StatefulWidget {
  final String id;
  final Widget child;
  final bool organizing;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final void Function(int dRow, int dCol)? onSwipeMove;

  const OrganizeTile({
    super.key,
    required this.id,
    required this.child,
    required this.organizing,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    this.onSwipeMove,
  });

  @override
  State<OrganizeTile> createState() => _OrganizeTileState();
}

class _OrganizeTileState extends State<OrganizeTile> with TickerProviderStateMixin {
  late final AnimationController _wiggleController;
  late final AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _wiggleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _bounceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 160));
    _syncWiggle();
  }

  @override
  void didUpdateWidget(OrganizeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncWiggle();
  }

  void _syncWiggle() {
    final shouldWiggle = widget.organizing && !widget.selected;
    if (shouldWiggle && !_wiggleController.isAnimating) {
      _wiggleController.repeat(reverse: true);
    } else if (!shouldWiggle && _wiggleController.isAnimating) {
      _wiggleController.stop();
      _wiggleController.value = 0.5;
    }
  }

  @override
  void dispose() {
    _wiggleController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _handleSwipe(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;
    if (velocity.distance < _swipeVelocityThreshold) return;
    final isHorizontal = velocity.dx.abs() > velocity.dy.abs();
    final dRow = isHorizontal ? 0 : (velocity.dy > 0 ? 1 : -1);
    final dCol = isHorizontal ? (velocity.dx > 0 ? 1 : -1) : 0;
    widget.onSwipeMove?.call(dRow, dCol);
    HapticFeedback.selectionClick();
    _bounceController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final content = AnimatedBuilder(
      animation: _wiggleController,
      builder: (context, child) {
        final angle = widget.organizing && !widget.selected
            ? (_wiggleController.value - 0.5) * 0.05
            : 0.0;
        return Transform.rotate(angle: angle, child: child);
      },
      child: _decoratedTile(),
    );

    if (!widget.organizing) {
      return GestureDetector(onTap: widget.onTap, onLongPress: widget.onLongPress, child: content);
    }

    if (!widget.selected) {
      return GestureDetector(onTap: widget.onTap, child: content);
    }

    return GestureDetector(
      onTap: widget.onTap,
      onPanEnd: _handleSwipe,
      child: AnimatedBuilder(
        animation: _bounceController,
        builder: (context, child) {
          final scale = 1 + 0.08 * math.sin(math.pi * _bounceController.value);
          return Transform.scale(scale: scale, child: child);
        },
        child: content,
      ),
    );
  }

  Widget _decoratedTile() {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (widget.organizing)
          Positioned(
            top: 5,
            right: 5,
            child: AnimatedOpacity(
              opacity: widget.selected ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFD166)),
                alignment: Alignment.center,
                child: const Text('✓', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4A3200))),
              ),
            ),
          ),
      ],
    );
  }
}
