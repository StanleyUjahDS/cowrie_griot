import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:toastification/toastification.dart';

import 'app.dart';
import 'core/theme/theme_controller.dart';
import 'core/services/ad_service.dart';
import 'core/services/push_notification_service.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Handling a background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    
    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Initialize notification service
    await PushNotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Firebase Initialization Error: $e');
  }

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
    const ToastificationWrapper(
      child: GriotCowrieApp(),
    ),
  );
}
