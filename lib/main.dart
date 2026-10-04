import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/services/ad_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/native_call_service.dart';
import 'core/theme/theme_controller.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final type = message.data['type']?.toString();
  final status = message.data['status']?.toString().toLowerCase();
  final callId = (message.data['callId'] ?? message.data['call_id'])
      ?.toString()
      .trim();
  if (type == 'call_log' &&
      callId != null &&
      callId.isNotEmpty &&
      const {'ended', 'declined', 'missed', 'failed'}.contains(status)) {
    // Clear any Android/iOS native ringing surface when the terminal push is
    // delivered while the Flutter UI is not running.
    await NativeCallService.instance.end(callId);
  } else if (type == 'incoming_call') {
    try {
      await NativeCallService.instance.showIncoming(message.data);
    } catch (error) {
      debugPrint('NativeCallService: background FCM call failed: $error');
    }
  }
  debugPrint('Handling a background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize notification service - don't let it block startup
    unawaited(PushNotificationService.instance.initialize());
    unawaited(NativeCallService.instance.initialize());
  } catch (e) {
    debugPrint('Firebase Initialization Error: $e');
  }

  // Keep development builds on Google's test units. Release builds select the
  // production AdMob units from AppConfig automatically.
  debugPrint(
    'Ads: ${AppConfig.adsEnabled ? (AppConfig.usesTestAds ? 'test' : 'production') : 'disabled'} units',
  );
  // Mediation adapters must finish initialization before any ad widget makes
  // its first request; otherwise Ad Inspector can report no adapters.
  await AdService.instance.initialize();

  // Load theme - also non-blocking if possible,
  // but GriotCowrieApp needs it for initial build.
  // We'll keep it awaited for now as it's just SharedPreferences.
  await ThemeController.instance.load();

  // ==========================================================
  // START APP
  // ==========================================================

  runApp(const ToastificationWrapper(child: GriotCowrieApp()));
}
