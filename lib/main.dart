import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:toastification/toastification.dart';

import 'app.dart';
import 'core/theme/theme_controller.dart';
import 'core/services/ad_service.dart';
import 'core/services/connectivity_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  AdService.instance.loadRewardedAd();
  ConnectivityService.instance.initialize();

  // ==========================================================
  // LOAD SAVED THEME SETTINGS
  // ==========================================================

  await ThemeController.instance.load();

  // ==========================================================
  // START APP
  // ==========================================================

  runApp(
    const ToastificationWrapper(
      child: GriotCowrieApp(),
    ),
  );
}