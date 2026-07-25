import 'package:flutter/material.dart';

/// Wraps a tile's visual content with the shared "organize mode" chrome:
/// wiggle animation, selection highlight, and drag-to-reorder. Resize and
/// delete controls for the selected tile live in the edit banner instead of
/// on the tile itself.
class OrganizeTile extends StatefulWidget {
  final String id;
  final Widget child;
  final bool organizing;
  final bool selected;
  final double feedbackWidth;
  final double feedbackHeight;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final void Function(String draggedId) onDroppedOnto;

  const OrganizeTile({
    super.key,
    required this.id,
    required this.child,
    required this.organizing,
    required this.selected,
    required this.feedbackWidth,
    required this.feedbackHeight,
    required this.onTap,
    required this.onLongPress,
    required this.onDroppedOnto,
  });

  @override
  State<OrganizeTile> createState() => _OrganizeTileState();
}

class _OrganizeTileState extends State<OrganizeTile> with SingleTickerProviderStateMixin {
  late final AnimationController _wiggleController;

  @override
  void initState() {
    super.initState();
    _wiggleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
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
    super.dispose();
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

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != widget.id,
      onAcceptWithDetails: (details) => widget.onDroppedOnto(details.data),
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<String>(
          data: widget.id,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.9,
              child: SizedBox(
                width: widget.feedbackWidth,
                height: widget.feedbackHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [BoxShadow(color: Color(0x552D1B4E), blurRadius: 16, offset: Offset(0, 6))],
                  ),
                  child: _decoratedTile(),
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: content),
          child: GestureDetector(onTap: widget.onTap, child: content),
        );
      },
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
