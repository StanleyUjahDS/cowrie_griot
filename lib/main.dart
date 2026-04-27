import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import 'app.dart';

void main() {
  runApp(
    OverlaySupport.global(
      child: const GriotCowrieApp(),
    ),
  );
}