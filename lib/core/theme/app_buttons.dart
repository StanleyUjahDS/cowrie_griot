import 'package:flutter/material.dart';
import 'app_theme_extension.dart';

class AppButtons {
  // 🟡 PRIMARY BUTTON (MAIN CTA)
  static ButtonStyle primary(BuildContext context) {
    final theme = Theme.of(context).extension<AppThemeExtension>()!;

    return ElevatedButton.styleFrom(
      backgroundColor: theme.primaryButton,
      foregroundColor: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  // 🟫 SECONDARY BUTTON
  static ButtonStyle secondary(BuildContext context) {
    final theme = Theme.of(context).extension<AppThemeExtension>()!;

    return ElevatedButton.styleFrom(
      backgroundColor: theme.secondaryButton,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  // 🟢 ACCENT BUTTON
  static ButtonStyle accent(BuildContext context) {
    final theme = Theme.of(context).extension<AppThemeExtension>()!;

    return ElevatedButton.styleFrom(
      backgroundColor: theme.accentButton,
      foregroundColor: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}