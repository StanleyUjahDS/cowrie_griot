import 'dart:math' as math;

import 'package:flutter/material.dart';

Future<void> showConversationActionsSheet({
  required BuildContext context,
  required bool isPinned,
  VoidCallback? onPinToggle,
  VoidCallback? onRemove,
  required String removeLabel,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Conversation actions',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (sheetContext, animation, secondaryAnimation) {
      final theme = Theme.of(sheetContext);
      final colorScheme = theme.colorScheme;
      final width = math.min(MediaQuery.sizeOf(sheetContext).width * 0.88, 360.0);

      Widget action({
        required IconData icon,
        required String label,
        required VoidCallback onPressed,
        bool destructive = false,
      }) {
        final foreground = destructive
            ? colorScheme.error
            : colorScheme.onSurface;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.of(sheetContext).pop();
              onPressed();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, color: foreground, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: foreground.withValues(alpha: 0.45),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return Align(
        alignment: Alignment.centerRight,
        child: SafeArea(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: width,
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(24),
                ),
                border: Border(
                  left: BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.55),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(-8, 0),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Conversation actions',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (onPinToggle != null)
                    action(
                      icon: isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      label: isPinned ? 'Unpin from top' : 'Pin to top',
                      onPressed: onPinToggle,
                    ),
                  if (onRemove != null) ...[
                    const SizedBox(height: 4),
                    action(
                      icon: Icons.delete_outline_rounded,
                      label: removeLabel,
                      onPressed: onRemove,
                      destructive: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}
