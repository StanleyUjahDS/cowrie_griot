import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

class NotificationService {
  static void showSuccess(BuildContext context, String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showSimpleNotification(
      Text(
        message,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      leading: Icon(Icons.check_circle_rounded, color: colorScheme.primary),
      background: colorScheme.surface,
      foreground: colorScheme.onSurface,
      duration: const Duration(seconds: 3),
      position: NotificationPosition.top,
    );
  }

  static void showError(BuildContext context, String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showSimpleNotification(
      Text(
        message,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      leading: Icon(Icons.error_outline_rounded, color: colorScheme.error),
      background: colorScheme.surface,
      foreground: colorScheme.onSurface,
      duration: const Duration(seconds: 4),
      position: NotificationPosition.top,
    );
  }

  static void showInfo(BuildContext context, String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showSimpleNotification(
      Text(
        message,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      leading: Icon(Icons.info_outline_rounded, color: colorScheme.primary),
      background: colorScheme.surface,
      foreground: colorScheme.onSurface,
      duration: const Duration(seconds: 3),
      position: NotificationPosition.top,
    );
  }
}
