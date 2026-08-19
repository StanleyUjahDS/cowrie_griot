import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:overlay_support/overlay_support.dart';

import 'app.dart';
import 'core/theme/theme_controller.dart';
import 'core/services/ad_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  AdService.instance.loadRewardedAd();

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