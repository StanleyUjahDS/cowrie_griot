import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DaySeparator extends StatelessWidget {
  final DateTime date;
  final ColorScheme colorScheme;

  const DaySeparator({
    super.key,
    required this.date,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final localDate = date.toLocal();
    final today = DateTime.now();
    final todayOnly = DateUtils.dateOnly(today);
    final dateOnly = DateUtils.dateOnly(localDate);
    final label = dateOnly == todayOnly
        ? 'Today'
        : dateOnly == todayOnly.subtract(const Duration(days: 1))
            ? 'Yesterday'
            : DateFormat('d MMMM yyyy').format(localDate);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
