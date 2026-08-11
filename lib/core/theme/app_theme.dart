// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text.dart';
import 'theme_controller.dart';

class AppTheme {
  static ThemeData theme({
    required AppThemeStyle style,
    required Brightness brightness,
  }) {
    final dark = brightness == Brightness.dark;

    final colors = _colors(style, dark);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppText.fontFamily,

      // ============================================================
      // BACKGROUND
      // ============================================================

      scaffoldBackgroundColor: colors.background,

      // ============================================================
      // COLOR SCHEME
      // ============================================================

      colorScheme: ColorScheme(
        brightness: brightness,

        primary: colors.primary,

        onPrimary: dark
            ? Colors.black
            : Colors.white,

        secondary: colors.primary,

        onSecondary: dark
            ? Colors.black
            : Colors.white,

        error: AppColors.error,

        onError: Colors.white,

        surface: colors.surface,

        onSurface: dark
            ? AppColors.darkTextPrimary
            : AppColors.lightTextPrimary,
      ),

      // ============================================================
      // TEXT
      // ============================================================

      textTheme: TextTheme(
        displayLarge: AppText.displayLarge.copyWith(
          color: dark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
        ),

        displayMedium: AppText.displayMedium.copyWith(
          color: dark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
        ),

        headlineLarge: AppText.heading.copyWith(
          color: dark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
        ),

        headlineMedium: AppText.headingSmall.copyWith(
          color: dark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
        ),

        titleLarge: AppText.subheading.copyWith(
          color: dark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
        ),

        titleMedium: AppText.subheadingSmall.copyWith(
          color: dark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),

        bodyLarge: AppText.bodyLarge.copyWith(
          color: dark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
        ),

        bodyMedium: AppText.body.copyWith(
          color: dark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),

        bodySmall: AppText.bodySmall.copyWith(
          color: dark
              ? AppColors.darkTextMuted
              : AppColors.lightTextMuted,
        ),

        labelLarge: AppText.button.copyWith(
          color: dark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
        ),

        labelSmall: AppText.caption.copyWith(
          color: dark
              ? AppColors.darkTextMuted
              : AppColors.lightTextMuted,
        ),
      ),

      // ============================================================
      // APP BAR
      // ============================================================

      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,

        foregroundColor: dark
            ? AppColors.darkTextPrimary
            : AppColors.lightTextPrimary,

        elevation: 0,

        centerTitle: true,

        surfaceTintColor: Colors.transparent,

        // ==========================================================
        // STATUS BAR + NAVIGATION BAR
        // ==========================================================

        systemOverlayStyle: SystemUiOverlayStyle(
          // Status bar background follows theme
          statusBarColor: colors.background,

          // Android status bar icons
          statusBarIconBrightness: dark
              ? Brightness.light
              : Brightness.dark,

          // iOS status bar appearance
          statusBarBrightness: dark
              ? Brightness.dark
              : Brightness.light,

          // Navigation bar follows theme
          systemNavigationBarColor: colors.background,

          // Navigation bar icons
          systemNavigationBarIconBrightness: dark
              ? Brightness.light
              : Brightness.dark,

          systemNavigationBarDividerColor:
          colors.background,
        ),
      ),

      // ============================================================
      // CARD
      // ============================================================

      cardTheme: CardThemeData(
        color: colors.surface,

        elevation: 0,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),

      // ============================================================
      // INPUTS
      // ============================================================

      inputDecorationTheme: InputDecorationTheme(
        filled: true,

        fillColor: colors.variant,

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),

          borderSide: BorderSide.none,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),

          borderSide: BorderSide(
            color: colors.border,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),

          borderSide: BorderSide(
            color: colors.primary,

            width: 1.5,
          ),
        ),

        hintStyle: TextStyle(
          color: dark
              ? AppColors.darkTextMuted
              : AppColors.lightTextMuted,
        ),
      ),

      // ============================================================
      // DIVIDER
      // ============================================================

      dividerTheme: DividerThemeData(
        color: colors.border,

        thickness: 1,

        space: 1,
      ),

      // ============================================================
      // DIALOG
      // ============================================================

      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),

      // ============================================================
      // SNACKBAR
      // ============================================================

      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.variant,

        contentTextStyle: TextStyle(
          color: dark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,

          fontFamily: AppText.fontFamily,
        ),

        actionTextColor: colors.primary,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),

      // ============================================================
      // SWITCH
      // ============================================================

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
              (states) {
            if (states.contains(
              WidgetState.selected,
            )) {
              return colors.primary;
            }

            return dark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary;
          },
        ),

        trackColor: WidgetStateProperty.resolveWith(
              (states) {
            if (states.contains(
              WidgetState.selected,
            )) {
              return colors.primary.withValues(
                alpha: 0.30,
              );
            }

            return colors.variant;
          },
        ),
      ),

      // ============================================================
      // PROGRESS
      // ============================================================

      progressIndicatorTheme:
      ProgressIndicatorThemeData(
        color: colors.primary,
      ),
    );
  }

  // ============================================================
  // THEME COLORS
  // ============================================================

  static _ThemeColors _colors(
      AppThemeStyle style,
      bool dark,
      ) {
    switch (style) {

    // ==========================================================
    // GRIOT
    //
    // OFFICIAL GRIOT BRAND
    // Deep sea-green + gold
    // ==========================================================

      case AppThemeStyle.griot:
        return _ThemeColors(
          primary: dark
              ? AppColors.griotPrimary
              : AppColors.griotPrimaryDark,

          background: dark
              ? AppColors.griotDarkBackground
              : AppColors.griotLightBackground,

          surface: dark
              ? AppColors.griotDarkSurface
              : AppColors.griotLightSurface,

          variant: dark
              ? AppColors.griotDarkVariant
              : AppColors.griotLightVariant,

          border: dark
              ? const Color(0xFF29453D)
              : AppColors.lightBorder,
        );

    // ==========================================================
    // OCEAN
    //
    // FACEBOOK / MESSENGER INSPIRED
    // ==========================================================

      case AppThemeStyle.ocean:
        return _ThemeColors(
          primary: dark
              ? AppColors.messengerPrimary
              : AppColors.messengerPrimaryDark,

          background: dark
              ? AppColors.messengerDarkBackground
              : AppColors.messengerLightBackground,

          surface: dark
              ? AppColors.messengerDarkSurface
              : AppColors.messengerLightSurface,

          variant: dark
              ? AppColors.messengerDarkVariant
              : AppColors.messengerLightVariant,

          border: dark
              ? const Color(0xFF4A4B4C)
              : const Color(0xFFD7D9DD),
        );

    // ==========================================================
    // EMERALD
    //
    // WHATSAPP INSPIRED
    // ==========================================================

      case AppThemeStyle.emerald:
        return _ThemeColors(
          primary: dark
              ? AppColors.whatsappPrimary
              : AppColors.whatsappPrimaryDark,

          background: dark
              ? AppColors.whatsappDarkBackground
              : AppColors.whatsappLightBackground,

          surface: dark
              ? AppColors.whatsappDarkSurface
              : AppColors.whatsappLightSurface,

          variant: dark
              ? AppColors.whatsappDarkVariant
              : AppColors.whatsappLightVariant,

          border: dark
              ? const Color(0xFF394A53)
              : const Color(0xFFD9D5CF),
        );

    // ==========================================================
    // VIOLET
    //
    // MODERN PURPLE
    // ==========================================================

      case AppThemeStyle.violet:
        return _ThemeColors(
          primary: dark
              ? const Color(0xFF8B6CFF)
              : const Color(0xFF6548D8),

          background: dark
              ? const Color(0xFF08070D)
              : const Color(0xFFF9F8FF),

          surface: dark
              ? const Color(0xFF111019)
              : Colors.white,

          variant: dark
              ? const Color(0xFF1A1827)
              : const Color(0xFFF0EDFF),

          border: dark
              ? const Color(0xFF302C46)
              : const Color(0xFFE0DAF7),
        );

    // ==========================================================
    // LAVENDER
    //
    // SOFT PURPLE / PASTEL
    // ==========================================================

      case AppThemeStyle.lavender:
        return _ThemeColors(
          primary: dark
              ? const Color(0xFFB59CFF)
              : const Color(0xFF8064D8),

          background: dark
              ? const Color(0xFF0A0910)
              : const Color(0xFFFAF8FF),

          surface: dark
              ? const Color(0xFF14111C)
              : Colors.white,

          variant: dark
              ? const Color(0xFF211C2B)
              : const Color(0xFFF1ECFF),

          border: dark
              ? const Color(0xFF352E45)
              : const Color(0xFFE2D9F5),
        );

    // ==========================================================
    // ROSE
    //
    // FEMININE PINK / ROSE
    // ==========================================================

      case AppThemeStyle.rose:
        return _ThemeColors(
          primary: dark
              ? const Color(0xFFFF4F87)
              : const Color(0xFFD92F68),

          background: dark
              ? const Color(0xFF0D070A)
              : const Color(0xFFFFF8FB),

          surface: dark
              ? const Color(0xFF160C11)
              : Colors.white,

          variant: dark
              ? const Color(0xFF24121A)
              : const Color(0xFFFCEBF2),

          border: dark
              ? const Color(0xFF43202D)
              : const Color(0xFFF0D5E0),
        );

    // ==========================================================
    // GOLD
    //
    // PREMIUM GOLD
    // Separate from Griot
    // ==========================================================

      case AppThemeStyle.gold:
        return _ThemeColors(
          primary: dark
              ? const Color(0xFFE2B85B)
              : const Color(0xFF9A6F24),

          background: dark
              ? const Color(0xFF0B0A07)
              : const Color(0xFFFFFCF5),

          surface: dark
              ? const Color(0xFF15120C)
              : Colors.white,

          variant: dark
              ? const Color(0xFF211B0F)
              : const Color(0xFFF8F0D9),

          border: dark
              ? const Color(0xFF40351E)
              : const Color(0xFFE8D9B4),
        );

    // ==========================================================
    // MIDNIGHT
    //
    // DARK BLUE / INDIGO
    // ==========================================================

      case AppThemeStyle.midnight:
        return _ThemeColors(
          primary: dark
              ? const Color(0xFF6D8CFF)
              : const Color(0xFF5069D8),

          background: dark
              ? const Color(0xFF070912)
              : const Color(0xFFF8F9FF),

          surface: dark
              ? const Color(0xFF0E1220)
              : Colors.white,

          variant: dark
              ? const Color(0xFF171D30)
              : const Color(0xFFEEF1FF),

          border: dark
              ? const Color(0xFF29324D)
              : const Color(0xFFDCE1F5),
        );

    // ==========================================================
    // SLATE
    //
    // NEUTRAL MODERN
    // ==========================================================

      case AppThemeStyle.slate:
        return _ThemeColors(
          primary: dark
              ? const Color(0xFFB0B7C3)
              : const Color(0xFF59636F),

          background: dark
              ? const Color(0xFF090A0B)
              : const Color(0xFFF8F9FA),

          surface: dark
              ? const Color(0xFF121416)
              : Colors.white,

          variant: dark
              ? const Color(0xFF1B1E21)
              : const Color(0xFFEEF0F2),

          border: dark
              ? const Color(0xFF2C3034)
              : const Color(0xFFDDE4E8),
        );
    }
  }
}

// ============================================================
// INTERNAL THEME COLOR MODEL
// ============================================================

class _ThemeColors {
  final Color primary;
  final Color background;
  final Color surface;
  final Color variant;
  final Color border;

  const _ThemeColors({
    required this.primary,
    required this.background,
    required this.surface,
    required this.variant,
    required this.border,
  });
}