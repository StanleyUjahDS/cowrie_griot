import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import '../network/api_config.dart';

class PushNotificationService {
  PushNotificationService._internal();
  static final PushNotificationService instance =
      PushNotificationService._internal();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  ApiClient? _apiClient;
  void Function(Map<String, dynamic> data)? _onNotificationTap;
  Map<String, dynamic>? _pendingNotificationTap;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Request Permission (for iOS/Android 13+)
    // We await this to ensure the user sees the prompt early.
    try {
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted notification permission');
      } else {
        debugPrint('User declined or has not accepted notification permission');
      }
    } catch (e) {
      debugPrint('Notification Permission Error: $e');
    }

    // 2. Listen for foreground messages.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');

      if (message.notification != null) {
        debugPrint(
          'Message also contained a notification: ${message.notification?.title}',
        );
      }
    });

    // 3. Keep the backend updated whenever Firebase rotates this token.
    _fcm.onTokenRefresh.listen((_) {
      unawaited(syncTokenWithBackend());
    });

    // 4. Handle warm-start notification taps.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message.data);
    });

    // 5. Non-blocking check for token and cold-start tap.
    // We don't await these to prevent blocking app startup on iOS.
    _fcm.getToken().then((token) {
      if (token != null) debugPrint('FCM Token retrieved.');
    }).catchError((e) => debugPrint('Error getting token: $e'));

    _fcm.getInitialMessage().then((message) {
      if (message != null) {
        _pendingNotificationTap = message.data;
        // If router is already configured, handle it now
        if (_onNotificationTap != null) {
          _handleNotificationTap(message.data);
        }
      }
    }).catchError((e) => debugPrint('Error checking initial message: $e'));
  }

  Future<String?> getToken() => _fcm.getToken();

  void configure({
    required ApiClient apiClient,
    required void Function(Map<String, dynamic> data) onNotificationTap,
  }) {
    _apiClient = apiClient;
    _onNotificationTap = onNotificationTap;

    final pendingTap = _pendingNotificationTap;
    if (pendingTap != null) {
      _pendingNotificationTap = null;
      _handleNotificationTap(pendingTap);
    }
  }

  Future<void> syncTokenWithBackend() async {
    final apiClient = _apiClient;
    if (apiClient == null) return;

    try {
      final token = await _fcm.getToken();
      if (token == null || token.isEmpty) return;

      await apiClient.post(
        ApiConfig.notificationDevices,
        body: {
          'token': token,
          'platform': _platformName,
          'locale': PlatformDispatcher.instance.locale.toLanguageTag(),
        },
      );
      debugPrint('PushNotifications: Device registered with backend.');
    } catch (error) {
      // Authentication may not exist yet, or the backend may be offline.
      // Startup and token refresh will retry later.
      debugPrint('PushNotifications: Device registration deferred: $error');
    }
  }

  Future<void> unregisterCurrentDevice() async {
    final apiClient = _apiClient;
    if (apiClient == null) return;

    try {
      final token = await _fcm.getToken();
      if (token == null || token.isEmpty) return;
      await apiClient.delete(
        ApiConfig.notificationDevices,
        body: {'token': token},
      );
    } catch (error) {
      // Logout must still complete when the backend is unavailable.
      debugPrint('PushNotifications: Device unregister failed: $error');
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final handler = _onNotificationTap;
    if (handler == null) {
      _pendingNotificationTap = data;
      return;
    }
    handler(data);
  }

  String get _platformName {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => 'ios',
      _ => 'android',
    };
  }
}
