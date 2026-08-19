import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

class NotificationService {
  static void showSuccess(String message) {
    showSimpleNotification(
      Text(
        message,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      leading: const Icon(Icons.check_circle_rounded, color: Colors.white),
      background: const Color(0xFF22C55E), // Success green
      foreground: Colors.white,
      duration: const Duration(seconds: 3),
      position: NotificationPosition.top,
    );
  }

  static void showError(String message) {
    showSimpleNotification(
      Text(
        message,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      leading: const Icon(Icons.error_outline_rounded, color: Colors.white),
      background: const Color(0xFFEF4444), // Error red
      foreground: Colors.white,
      duration: const Duration(seconds: 4),
      position: NotificationPosition.top,
    );
  }

  static void showInfo(String message) {
    showSimpleNotification(
      Text(
        message,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      leading: const Icon(Icons.info_outline_rounded, color: Colors.white),
      background: const Color(0xFF3B82F6), // Info blue
      foreground: Colors.white,
      duration: const Duration(seconds: 3),
      position: NotificationPosition.top,
    );
  }
}
