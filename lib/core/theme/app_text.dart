import 'package:flutter/material.dart';

class AppText {
  static const String fontFamily = "Poppins";

  // 🔥Display (big brand text / splash / hero titles)
  static const TextStyle displayLarge = TextStyle(
    fontSize: 45, // was 36
    fontWeight: FontWeight.bold,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 34, // was 32
    fontWeight: FontWeight.bold,
  );

  //  Headings
  static const TextStyle heading = TextStyle(
    fontSize: 30, // was 28
    fontWeight: FontWeight.bold,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 26, // was 24
    fontWeight: FontWeight.w600,
  );

  //  Subheadings
  static const TextStyle subheading = TextStyle(
    fontSize: 20, // was 18
    fontWeight: FontWeight.w600,
  );

  static const TextStyle subheadingSmall = TextStyle(
    fontSize: 18, // was 16
    fontWeight: FontWeight.w600,
  );

  //  Body text
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18, // was 16
    fontWeight: FontWeight.w400,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16, // was 14
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 14, // was 12
    fontWeight: FontWeight.w400,
  );

  //  Caption / helper text
  static const TextStyle caption = TextStyle(
    fontSize: 13, // was 11
    fontWeight: FontWeight.w400,
  );

  //  Button text
  static const TextStyle button = TextStyle(
    fontSize: 18, // was 16
    fontWeight: FontWeight.w600,
  );
}