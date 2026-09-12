import 'package:flutter/material.dart';

/// A small, consistent indicator for users with an active Griot Plus plan.
class GriotPlusBadge extends StatelessWidget {
  final bool isPlus;
  final bool compact;

  const GriotPlusBadge({super.key, required this.isPlus, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (!isPlus) return const SizedBox.shrink();

    const gold = Color(0xFFF5B942);
    const ink = Color(0xFF8A5A00);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: gold.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: compact ? 12 : 14, color: ink),
          if (!compact) ...[
            const SizedBox(width: 3),
            const Text(
              'PLUS',
              style: TextStyle(
                color: ink,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
