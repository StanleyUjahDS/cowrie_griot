import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

import 'app.dart';
import 'core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==========================================================
  // LOAD SAVED THEME SETTINGS
  // ==========================================================

  await ThemeController.instance.load();

  // ==========================================================
  // START APP
  // ==========================================================

  runApp(
    OverlaySupport.global(
      child: const GriotCowrieApp(),
    ),
  );
}