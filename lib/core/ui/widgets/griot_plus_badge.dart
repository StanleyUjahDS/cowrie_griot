import 'package:flutter/material.dart';

/// A small, consistent indicator for users with an active Griot Plus plan.
class GriotPlusBadge extends StatelessWidget {
  final bool isPlus;
  final bool compact;

  const GriotPlusBadge({super.key, required this.isPlus, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (!isPlus) return const SizedBox.shrink();

    const gold = Color(0xFFFFC247);
    // Plus is represented by a standalone star so it aligns naturally with
    // the user's name and never looks like a second status pill.
    return Icon(
      Icons.star_rounded,
      size: compact ? 19 : 23,
      color: gold,
      shadows: const [Shadow(color: Color(0x66F5A623), blurRadius: 5)],
      semanticLabel: 'Griot Plus',
    );
  }
}
