// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text.dart';
import 'theme_controller.dart';

class AppTheme {
  /// Returns the actual primary color used by a theme style.
  ///
  /// Keep this public so previews and settings can use the same source of
  /// truth as the active Material theme.
  static Color primaryColor(AppThemeStyle style, Brightness brightness) {
    return _colors(style, brightness == Brightness.dark).primary;
  }

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

      shadowColor: dark
          ? Colors.black.withValues(alpha: 0.5)
          : Colors.black.withValues(alpha: 0.08),

      // ============================================================
      // COLOR SCHEME
      // ============================================================
      colorScheme: ColorScheme(
        brightness: brightness,

        primary: colors.primary,

        onPrimary: colors.primary.computeLuminance() > 0.4
            ? Colors.black87
            : Colors.white,

        secondary: colors.primary,

        onSecondary: colors.primary.computeLuminance() > 0.4
            ? Colors.black87
            : Colors.white,

        error: AppColors.error,

        onError: Colors.white,

        surface: colors.surface,

        onSurface: dark
            ? AppColors.darkTextPrimary
            : AppColors.lightTextPrimary,

        onSurfaceVariant: dark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,

        surfaceContainerLow: colors.surface,
        surfaceContainer: colors.variant,
        surfaceContainerHigh: colors.variant,
        surfaceContainerHighest: colors.variant,

        outline: colors.border,
        outlineVariant: colors.border.withValues(alpha: 0.5),
      ),

      // ============================================================
      // TEXT
      // ============================================================
      textTheme: TextTheme(
        displayLarge: AppText.displayLarge.copyWith(
          color: dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),

        displayMedium: AppText.displayMedium.copyWith(
          color: dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),

        headlineLarge: AppText.heading.copyWith(
          color: dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),

        headlineMedium: AppText.headingSmall.copyWith(
          color: dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),

        titleLarge: AppText.subheading.copyWith(
          color: dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),

        titleMedium: AppText.subheadingSmall.copyWith(
          color: dark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),

        bodyLarge: AppText.bodyLarge.copyWith(
          color: dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),

        bodyMedium: AppText.body.copyWith(
          color: dark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),

        bodySmall: AppText.bodySmall.copyWith(
          color: dark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        ),

        labelLarge: AppText.button.copyWith(
          color: dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),

        labelSmall: AppText.caption.copyWith(
          color: dark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        ),
      ),

      // ============================================================
      // APP BAR
      // ============================================================
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,

        foregroundColor: dark
            ? AppColors.darkTextPrimary
            : AppColors.lightTextPrimary,

        elevation: 0,

        centerTitle: true,

        surfaceTintColor: Colors.transparent,

        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          fontFamily: AppText.fontFamily,
          color: dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),

        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: colors.surface,

          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,

          statusBarBrightness: dark ? Brightness.dark : Brightness.light,

          systemNavigationBarColor: colors.background,

          systemNavigationBarIconBrightness: dark
              ? Brightness.light
              : Brightness.dark,

          systemNavigationBarDividerColor: colors.background,
        ),
      ),

      // ============================================================
      // CARD
      // ============================================================
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
          borderSide: BorderSide(color: colors.border),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),

        hintStyle: TextStyle(
          color: dark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),

      // ============================================================
      // SNACKBAR
      // ============================================================
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.variant,

        contentTextStyle: TextStyle(
          color: dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          fontFamily: AppText.fontFamily,
        ),

        actionTextColor: colors.primary,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      // ============================================================
      // ACTIONS AND SURFACES
      // ============================================================
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colorSchemeOn(colors.primary),
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppText.button.copyWith(fontFamily: AppText.fontFamily),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colorSchemeOn(colors.primary),
          elevation: 0,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppText.button.copyWith(fontFamily: AppText.fontFamily),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: BorderSide(color: colors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppText.button.copyWith(fontFamily: AppText.fontFamily),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppText.button.copyWith(fontFamily: AppText.fontFamily),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: dark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: colorSchemeOn(colors.primary),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primary.withValues(alpha: 0.16),
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStatePropertyAll(
          AppText.caption.copyWith(
            fontFamily: AppText.fontFamily,
            fontWeight: FontWeight.w600,
            color: dark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: colors.border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: colors.variant,
        selectedColor: colors.primary.withValues(alpha: 0.16),
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: TextStyle(
          fontFamily: AppText.fontFamily,
          color: dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: TextStyle(
          fontFamily: AppText.fontFamily,
          color: dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: dark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      // ============================================================
      // SWITCH
      // ============================================================
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primary;
          }

          return dark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary;
        }),

        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.primary.withValues(alpha: 0.30);
          }

          return colors.variant;
        }),
      ),

      // ============================================================
      // PROGRESS
      // ============================================================
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.primary),
    );
  }

  static Color colorSchemeOn(Color color) {
    return color.computeLuminance() > 0.4 ? Colors.black87 : Colors.white;
  }

  // ============================================================
  // THEME COLORS
  // ============================================================

  static _ThemeColors _colors(AppThemeStyle style, bool dark) {
    switch (style) {
      // ==========================================================
      // GRIOT
      //
      // OFFICIAL GRIOT BRAND
      // Deep sea-green + gold
      // ==========================================================

      case AppThemeStyle.griot:
        return _ThemeColors(
          primary: dark ? AppColors.griotPrimary : AppColors.griotPrimaryDark,

          background: dark
              ? AppColors.griotDarkBackground
              : AppColors.griotLightBackground,

          surface: dark
              ? AppColors.griotDarkSurface
              : AppColors.griotLightSurface,

          variant: dark
              ? AppColors.griotDarkVariant
              : AppColors.griotLightVariant,

          border: dark ? const Color(0xFF29453D) : AppColors.lightBorder,
        );

      // ==========================================================
      // SKY
      //
      // FACEBOOK / MESSENGER INSPIRED
      // ==========================================================

      case AppThemeStyle.sky:
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

          border: dark ? const Color(0xFF4A4B4C) : const Color(0xFFD7D9DD),
        );

      // ==========================================================
      // FOREST
      //
      // WHATSAPP INSPIRED
      // ==========================================================

      case AppThemeStyle.forest:
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

          border: dark ? const Color(0xFF394A53) : const Color(0xFFD9D5CF),
        );

      // ==========================================================
      // VIOLET
      // ==========================================================

      case AppThemeStyle.violet:
        return _ThemeColors(
          primary: dark ? AppColors.violetPrimary : AppColors.violetPrimaryDark,

          background: dark ? const Color(0xFF08070D) : const Color(0xFFF9F8FF),

          surface: dark ? const Color(0xFF111019) : Colors.white,

          variant: dark ? const Color(0xFF1A1827) : AppColors.violetPrimarySoft,

          border: dark ? const Color(0xFF302C46) : const Color(0xFFE0DAF7),
        );

      // ==========================================================
      // LAVENDER
      // ==========================================================

      case AppThemeStyle.lavender:
        return _ThemeColors(
          primary: dark
              ? AppColors.lavenderPrimary
              : AppColors.lavenderPrimaryDark,

          background: dark ? const Color(0xFF0A0910) : const Color(0xFFFAF8FF),

          surface: dark ? const Color(0xFF14111C) : Colors.white,

          variant: dark
              ? const Color(0xFF211C2B)
              : AppColors.lavenderPrimarySoft,

          border: dark ? const Color(0xFF352E45) : const Color(0xFFE2D9F5),
        );

      // ==========================================================
      // ROSE
      // ==========================================================

      case AppThemeStyle.rose:
        return _ThemeColors(
          primary: dark ? AppColors.rosePrimary : AppColors.rosePrimaryDark,

          background: dark
              ? AppColors.roseDarkBackground
              : AppColors.roseLightBackground,

          surface: dark
              ? AppColors.roseDarkSurface
              : AppColors.roseLightSurface,

          variant: dark
              ? AppColors.roseDarkVariant
              : AppColors.roseLightVariant,

          border: dark ? const Color(0xFF43202D) : const Color(0xFFF0D5E0),
        );

      // ==========================================================
      // GOLD
      //
      // PREMIUM GOLD
      // Separate from Griot
      // ==========================================================

      case AppThemeStyle.gold:
        return _ThemeColors(
          primary: dark ? AppColors.goldPrimary : AppColors.goldPrimaryDark,

          background: dark
              ? AppColors.goldDarkBackground
              : AppColors.goldLightBackground,

          surface: dark
              ? AppColors.goldDarkSurface
              : AppColors.goldLightSurface,

          variant: dark
              ? AppColors.goldDarkVariant
              : AppColors.goldLightVariant,

          border: dark ? const Color(0xFF40351E) : const Color(0xFFE8D9B4),
        );

      // ==========================================================
      // MIDNIGHT
      // ==========================================================

      case AppThemeStyle.midnight:
        return _ThemeColors(
          primary: dark
              ? AppColors.midnightPrimary
              : AppColors.midnightPrimaryDark,

          background: dark ? const Color(0xFF070912) : const Color(0xFFF8F9FF),

          surface: dark ? const Color(0xFF0E1220) : Colors.white,

          variant: dark
              ? const Color(0xFF171D30)
              : AppColors.midnightPrimarySoft,

          border: dark ? const Color(0xFF29324D) : const Color(0xFFDCE1F5),
        );

      // ==========================================================
      // SLATE
      // ==========================================================

      case AppThemeStyle.slate:
        return _ThemeColors(
          primary: dark ? AppColors.slatePrimary : AppColors.slatePrimaryDark,

          background: dark ? const Color(0xFF090A0B) : const Color(0xFFF8F9FA),

          surface: dark ? const Color(0xFF121416) : Colors.white,

          variant: dark ? const Color(0xFF1B1E21) : AppColors.slatePrimarySoft,

          border: dark ? const Color(0xFF2C3034) : const Color(0xFFDDE4E8),
        );

      // ==========================================================
      // AZURE
      // Familiar messaging blue
      // ==========================================================

      case AppThemeStyle.azure:
        return _ThemeColors(
          primary: dark
              ? AppColors.telegramPrimary
              : AppColors.telegramPrimaryDark,

          background: dark
              ? AppColors.telegramDarkBackground
              : AppColors.telegramLightBackground,

          surface: dark
              ? AppColors.telegramDarkSurface
              : AppColors.telegramLightSurface,

          variant: dark
              ? AppColors.telegramDarkVariant
              : AppColors.telegramLightVariant,

          border: dark ? const Color(0xFF394A5A) : const Color(0xFFD6E1E8),
        );

      // ==========================================================
      // INDIGO
      // Clean communication blue
      // ==========================================================

      case AppThemeStyle.indigo:
        return _ThemeColors(
          primary: dark ? AppColors.signalPrimary : AppColors.signalPrimaryDark,

          background: dark
              ? AppColors.signalDarkBackground
              : AppColors.signalLightBackground,

          surface: dark
              ? AppColors.signalDarkSurface
              : AppColors.signalLightSurface,

          variant: dark
              ? AppColors.signalDarkVariant
              : AppColors.signalLightVariant,

          border: dark ? const Color(0xFF3A3A3A) : const Color(0xFFDCE0E7),
        );

      // ==========================================================
      // AURORA
      // Modern indigo
      // ==========================================================

      case AppThemeStyle.aurora:
        return _ThemeColors(
          primary: dark
              ? AppColors.discordPrimary
              : AppColors.discordPrimaryDark,

          background: dark
              ? AppColors.discordDarkBackground
              : AppColors.discordLightBackground,

          surface: dark
              ? AppColors.discordDarkSurface
              : AppColors.discordLightSurface,

          variant: dark
              ? AppColors.discordDarkVariant
              : AppColors.discordLightVariant,

          border: dark ? const Color(0xFF44464C) : const Color(0xFFD9DBDF),
        );

      // ==========================================================
      // TEAL
      // Classic modern communication teal
      // ==========================================================

      case AppThemeStyle.teal:
        return _ThemeColors(
          primary: dark ? AppColors.tealPrimary : AppColors.tealPrimaryDark,

          background: dark
              ? AppColors.tealDarkBackground
              : AppColors.tealLightBackground,

          surface: dark
              ? AppColors.tealDarkSurface
              : AppColors.tealLightSurface,

          variant: dark
              ? AppColors.tealDarkVariant
              : AppColors.tealLightVariant,

          border: dark ? const Color(0xFF2E4744) : const Color(0xFFD3E5E2),
        );

      // ==========================================================
      // ORANGE
      // Warm and energetic
      // ==========================================================

      case AppThemeStyle.orange:
        return _ThemeColors(
          primary: dark ? AppColors.orangePrimary : AppColors.orangePrimaryDark,

          background: dark
              ? AppColors.orangeDarkBackground
              : AppColors.orangeLightBackground,

          surface: dark
              ? AppColors.orangeDarkSurface
              : AppColors.orangeLightSurface,

          variant: dark
              ? AppColors.orangeDarkVariant
              : AppColors.orangeLightVariant,

          border: dark ? const Color(0xFF49341F) : const Color(0xFFF0D7C0),
        );

      // ==========================================================
      // RED
      // Classic strong communication colour
      // ==========================================================

      case AppThemeStyle.red:
        return _ThemeColors(
          primary: dark ? AppColors.redPrimary : AppColors.redPrimaryDark,

          background: dark
              ? AppColors.redDarkBackground
              : AppColors.redLightBackground,

          surface: dark ? AppColors.redDarkSurface : AppColors.redLightSurface,

          variant: dark ? AppColors.redDarkVariant : AppColors.redLightVariant,

          border: dark ? const Color(0xFF4A2929) : const Color(0xFFF0D4D3),
        );

      case AppThemeStyle.cyber:
        return _ThemeColors(
          primary: AppColors.cyberPrimary,
          background: dark
              ? AppColors.cyberDarkBackground
              : const Color(0xFFF0FDFF),
          surface: dark ? AppColors.cyberDarkSurface : Colors.white,
          variant: dark ? AppColors.cyberDarkVariant : const Color(0xFFE0F9FF),
          border: dark ? const Color(0xFF1A3D40) : const Color(0xFFD0F0F5),
        );

      case AppThemeStyle.onyx:
        return _ThemeColors(
          primary: dark ? Colors.white : Colors.black,
          background: dark ? Colors.black : Colors.white,
          surface: dark ? const Color(0xFF000000) : Colors.white,
          variant: dark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F8F8),
          border: dark ? const Color(0xFF1A1A1A) : const Color(0xFFE8E8E8),
        );

      case AppThemeStyle.cappuccino:
        return _ThemeColors(
          primary: AppColors.cappuccinoPrimary,
          background: dark
              ? AppColors.cappuccinoDarkBackground
              : const Color(0xFFFAF7F2),
          surface: dark ? AppColors.cappuccinoDarkSurface : Colors.white,
          variant: dark
              ? AppColors.cappuccinoDarkVariant
              : const Color(0xFFF2ECE4),
          border: dark ? const Color(0xFF3D322D) : const Color(0xFFE5DDD3),
        );

      case AppThemeStyle.mint:
        return _ThemeColors(
          primary: AppColors.mintPrimary,
          background: dark
              ? AppColors.mintDarkBackground
              : const Color(0xFFF2FAF5),
          surface: dark ? AppColors.mintDarkSurface : Colors.white,
          variant: dark ? AppColors.mintDarkVariant : const Color(0xFFE6F5EE),
          border: dark ? const Color(0xFF1B3D2F) : const Color(0xFFD5E8DF),
        );

      case AppThemeStyle.mono:
        return _ThemeColors(
          primary: dark ? Colors.white : Colors.black,
          background: dark ? const Color(0xFF111111) : Colors.white,
          surface: dark ? const Color(0xFF1A1A1A) : const Color(0xFFF9F9F9),
          variant: dark ? const Color(0xFF222222) : const Color(0xFFF0F0F0),
          border: dark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
        );

      case AppThemeStyle.noir:
        return _ThemeColors(
          primary: dark ? const Color(0xFFE0E0E0) : const Color(0xFF1A1C1E),
          background: dark ? const Color(0xFF0B0C0D) : const Color(0xFFF0F1F2),
          surface: dark ? const Color(0xFF151718) : Colors.white,
          variant: dark ? const Color(0xFF1E2022) : const Color(0xFFE8EAEB),
          border: dark ? const Color(0xFF2D2F31) : const Color(0xFFD1D4D6),
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
