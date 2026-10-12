import 'package:flutter/material.dart';

class ReplySwipe extends StatefulWidget {
  final Widget child;
  final Widget background;
  final VoidCallback onReply;

  const ReplySwipe({
    super.key,
    required this.child,
    required this.background,
    required this.onReply,
  });

  @override
  State<ReplySwipe> createState() => _ReplySwipeState();
}

class _ReplySwipeState extends State<ReplySwipe> {
  static const _maxDistance = 56.0;
  static const _triggerDistance = 38.0;
  double _offset = 0;

  void _onDragUpdate(DragUpdateDetails details) {
    if (details.delta.dx <= 0) return;
    setState(() {
      _offset = (_offset + details.delta.dx).clamp(0.0, _maxDistance);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final shouldReply = _offset >= _triggerDistance;
    setState(() => _offset = 0);
    if (shouldReply) widget.onReply();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: (_offset / _maxDistance).clamp(0.0, 1.0),
              child: widget.background,
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_offset, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
