import 'package:flutter/material.dart';

@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color primaryButton;
  final Color secondaryButton;
  final Color accentButton;

  const AppThemeExtension({
    required this.primaryButton,
    required this.secondaryButton,
    required this.accentButton,
  });

  @override
  AppThemeExtension copyWith({
    Color? primaryButton,
    Color? secondaryButton,
    Color? accentButton,
  }) {
    return AppThemeExtension(
      primaryButton: primaryButton ?? this.primaryButton,
      secondaryButton: secondaryButton ?? this.secondaryButton,
      accentButton: accentButton ?? this.accentButton,
    );
  }

  @override
  AppThemeExtension lerp(
      ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;

    return AppThemeExtension(
      primaryButton: Color.lerp(primaryButton, other.primaryButton, t)!,
      secondaryButton: Color.lerp(secondaryButton, other.secondaryButton, t)!,
      accentButton: Color.lerp(accentButton, other.accentButton, t)!,
    );
  }
}