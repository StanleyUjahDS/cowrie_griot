import 'package:flutter/material.dart';
import 'app_theme_extension.dart';

class AppButtons {
  // PRIMARY BUTTON
  static ButtonStyle primary(BuildContext context) {
    final theme = Theme.of(context).extension<AppThemeExtension>()!;

    return ElevatedButton.styleFrom(
      backgroundColor: theme.primaryButton.withValues(alpha: 0.9),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
    );
  }

  // SECONDARY BUTTON
  static ButtonStyle secondary(BuildContext context) {
    final theme = Theme.of(context).extension<AppThemeExtension>()!;

    return ElevatedButton.styleFrom(
      backgroundColor: theme.secondaryButton.withValues(alpha: 0.9),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
    );
  }

  // ACCENT BUTTON
  static ButtonStyle accent(BuildContext context) {
    final theme = Theme.of(context).extension<AppThemeExtension>()!;

    return ElevatedButton.styleFrom(
      backgroundColor: theme.accentButton.withValues(alpha: 0.9),
      foregroundColor: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
    );
  }

  // =========================
  // FLOATING ACTION BUTTON
  // =========================
  static FloatingActionButtonThemeData fab(BuildContext context) {
    final theme = Theme.of(context).extension<AppThemeExtension>()!;

    return FloatingActionButtonThemeData(
      backgroundColor: theme.primaryButton.withValues(alpha: 0.95),
      foregroundColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}