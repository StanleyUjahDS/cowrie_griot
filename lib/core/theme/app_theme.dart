import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text.dart';
import 'app_theme_extension.dart';

class AppTheme {
  // 🌑 DARK THEME
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: AppText.fontFamily,
    scaffoldBackgroundColor: AppColors.darkPrimary,

    colorScheme: const ColorScheme.dark(
      primary: AppColors.gold,                 // 🔥 accent only
      secondary: AppColors.darkSecondary,
      surface: AppColors.darkSurface,

      onPrimary: Colors.black,                // text on gold buttons
      onSecondary: Colors.white,
      onSurface: Colors.white,
    ),

    textTheme: TextTheme(
      displayLarge: AppText.displayLarge.copyWith(color: Colors.white),
      displayMedium: AppText.displayMedium.copyWith(color: Colors.white),

      headlineLarge: AppText.heading.copyWith(color: Colors.white),
      headlineMedium: AppText.headingSmall.copyWith(color: Colors.white),

      titleLarge: AppText.subheading.copyWith(color: Colors.white),
      titleMedium: AppText.subheadingSmall.copyWith(color: Colors.white70),

      bodyLarge: AppText.bodyLarge.copyWith(color: Colors.white),
      bodyMedium: AppText.body.copyWith(color: Colors.white70),
      bodySmall: AppText.bodySmall.copyWith(color: Colors.white60),

      labelLarge: AppText.button.copyWith(color: Colors.white),
      labelSmall: AppText.caption.copyWith(color: Colors.white60),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkPrimary,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: Colors.white),
    ),

    extensions: const [
      AppThemeExtension(
        primaryButton: AppColors.gold,
        secondaryButton: AppColors.earth,
        accentButton: AppColors.green,
      )
    ],
  );

  // ☀️ LIGHT THEME
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: AppText.fontFamily,
    scaffoldBackgroundColor: AppColors.lightPrimary,

    colorScheme: const ColorScheme.light(
      primary: AppColors.gold,                // 🔥 accent only
      secondary: AppColors.lightSecondary,
      surface: AppColors.lightSurface,

      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: Colors.black,
    ),

    textTheme: TextTheme(
      displayLarge: AppText.displayLarge.copyWith(color: Colors.black),
      displayMedium: AppText.displayMedium.copyWith(color: Colors.black),

      headlineLarge: AppText.heading.copyWith(color: Colors.black),
      headlineMedium: AppText.headingSmall.copyWith(color: Colors.black),

      titleLarge: AppText.subheading.copyWith(color: Colors.black),
      titleMedium: AppText.subheadingSmall.copyWith(color: Colors.black87),

      bodyLarge: AppText.bodyLarge.copyWith(color: Colors.black),
      bodyMedium: AppText.body.copyWith(color: Colors.black87),
      bodySmall: AppText.bodySmall.copyWith(color: Colors.black54),

      labelLarge: AppText.button.copyWith(color: Colors.black),
      labelSmall: AppText.caption.copyWith(color: Colors.black54),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightPrimary,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: Colors.black),
    ),

    extensions: const [
      AppThemeExtension(
        primaryButton: AppColors.gold,
        secondaryButton: AppColors.earth,
        accentButton: AppColors.green,
      )
    ],
  );
}