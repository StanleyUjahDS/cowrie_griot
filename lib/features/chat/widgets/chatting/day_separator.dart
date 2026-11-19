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

/// Keeps the date currently being read visible while the message list moves.
/// This is intentionally compact so it does not cover the conversation or
/// compete with the app bar.
class StickyDateHeader extends StatelessWidget {
  final DateTime date;
  final ColorScheme colorScheme;

  const StickyDateHeader({
    super.key,
    required this.date,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final localDate = date.toLocal();
    final today = DateUtils.dateOnly(DateTime.now());
    final dateOnly = DateUtils.dateOnly(localDate);
    final label = dateOnly == today
        ? 'Today'
        : dateOnly == today.subtract(const Duration(days: 1))
        ? 'Yesterday'
        : DateFormat('d MMMM yyyy').format(localDate);

    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: .12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

/// Marks the point where messages received while the user was away begin.
/// It is intentionally distinct from a date separator so the user can scan
/// directly to unread content without relying only on the conversation badge.
class NewMessagesSeparator extends StatelessWidget {
  const NewMessagesSeparator({
    super.key,
    required this.colorScheme,
    this.count,
  });

  final ColorScheme colorScheme;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: colorScheme.primary.withValues(alpha: 0.45),
              thickness: 1.5,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              count != null && count! > 0
                  ? 'New messages · $count'
                  : 'New messages',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: colorScheme.primary.withValues(alpha: 0.45),
              thickness: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
