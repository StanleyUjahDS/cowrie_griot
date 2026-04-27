import 'package:flutter/material.dart';

class AppColors {
  // 🌑 DARK THEME BASE (stable + depth-safe)
  static const Color darkPrimary = Color(0xFF00211A);
  static const Color darkSecondary = Color(0xFF004D3A);

  // 🔥 Better depth surface (prevents flat look + M3 artifacts)
  static const Color darkSurface = Color(0xFF0D231D);

  // ☀ LIGHT THEME BASE
  static const Color lightPrimary = Color(0xFFFFFFFF);
  static const Color lightSecondary = Color(0xFFFFFFFF);

  static const Color lightBackground = Color(0xFFFFFFFF);

  // 🔥 FIXED: avoids Material 3 tint artifacts
  static const Color lightSurface = Color(0xFFFDFDFD);

  // 🧱 Slightly softer UI separation (better than harsh grey)
  static const Color lightSurfaceVariant = Color(0xFFF3F4F6);

  static const Color lightBorder = Color(0xFFEAECEF);

  // 📝 TEXT COLORS
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF6B7280);

  // 🚨 STATUS COLORS
  static const Color lightError = Color(0xFFEF4444);
  static const Color lightSuccess = Color(0xFF16A34A);

  // 🌟 ACCENTS (unchanged)
  static const Color gold = Color(0xFFD49224);
  static const Color green = Color(0xFF00C896);
  static const Color earth = Color(0xFF6A682B);
}