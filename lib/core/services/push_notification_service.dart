import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../network/api_client.dart';
import '../network/api_config.dart';
import 'native_call_service.dart';
import '../../features/auth/services/auth_storage_service.dart';

class PushNotificationService {
  PushNotificationService._internal();
  static final PushNotificationService instance =
      PushNotificationService._internal();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  ApiClient? _apiClient;
  void Function(Map<String, dynamic> data)? _onNotificationTap;
  void Function(RemoteMessage message)? _onForegroundMessage;
  Map<String, dynamic>? _pendingNotificationTap;
  final List<RemoteMessage> _pendingForegroundMessages = [];
  bool _initialized = false;
  Future<Map<String, String?>>? _deviceMetadataFuture;

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

      debugPrint(
        'PushNotifications: permission=${settings.authorizationStatus.name} '
        'alert=${settings.alert.name} badge=${settings.badge.name} '
        'sound=${settings.sound.name}',
      );
    } catch (e) {
      debugPrint('Notification Permission Error: $e');
    }

    // Foreground messages are rendered by Griot's in-app notification UI in
    // app.dart. Disable iOS's automatic foreground alert here so an iPhone
    // does not show both a native banner and Griot's in-app notification.
    // Background/terminated notification presentation remains enabled by the
    // notification payload sent by Firebase.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
    }

    // 2. Listen for foreground messages.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

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
    unawaited(_logTokenReadiness());

    _fcm
        .getInitialMessage()
        .then((message) {
          if (message != null) {
            _pendingNotificationTap = message.data;
            // If router is already configured, handle it now
            if (_onNotificationTap != null) {
              _handleNotificationTap(message.data);
            }
          }
        })
        .catchError((e) => debugPrint('Error checking initial message: $e'));
  }

  Future<String?> getToken() => _fcm.getToken();

  Future<void> _logTokenReadiness() async {
    try {
      if (_isApplePlatform) {
        final apnsToken = await _waitForApnsToken();
        debugPrint(
          'PushNotifications: APNs token ${apnsToken == null ? "missing" : "ready"}',
        );
        if (apnsToken == null) return;
      }

      final token = await _fcm.getToken();
      debugPrint(
        'PushNotifications: FCM token ${token == null ? "missing" : "ready"}'
        '${token == null ? "" : " (length=${token.length})"}',
      );
    } catch (e) {
      debugPrint('PushNotifications: token readiness check failed: $e');
    }
  }

  void configure({
    required ApiClient apiClient,
    required void Function(Map<String, dynamic> data) onNotificationTap,
    required void Function(RemoteMessage message) onForegroundMessage,
  }) {
    _apiClient = apiClient;
    _onNotificationTap = onNotificationTap;
    _onForegroundMessage = onForegroundMessage;

    // configure() can run after startup's one-shot sync attempt. Retry here
    // so an authenticated device that obtained its FCM token slightly later
    // is still registered with the backend.
    unawaited(syncTokenWithBackend());

    final pendingTap = _pendingNotificationTap;
    if (pendingTap != null) {
      _pendingNotificationTap = null;
      _handleNotificationTap(pendingTap);
    }

    final pendingMessages = List<RemoteMessage>.from(
      _pendingForegroundMessages,
    );
    _pendingForegroundMessages.clear();
    for (final message in pendingMessages) {
      _handleForegroundMessage(message);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final handler = _onForegroundMessage;
    if (handler == null) {
      _pendingForegroundMessages.add(message);
      return;
    }
    handler(message);
  }

  Future<void> syncTokenWithBackend() async {
    final apiClient = _apiClient;
    if (apiClient == null) return;

    try {
      // Device registration is a protected endpoint. Do not attempt it while
      // the app is still on the welcome/authentication flow; an expected 401
      // must not be treated as an expired session.
      final accessToken = await AuthStorageService().getAccessToken();
      if (accessToken == null || accessToken.isEmpty) return;
      await NativeCallService.instance.syncVoipTokenWithBackend();

      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        // Firebase requires the APNs token before making FCM API calls on
        // Apple platforms. Do not register an FCM token that cannot be backed
        // by a usable APNs token.
        final apnsToken = await _waitForApnsToken();
        if (apnsToken == null) {
          debugPrint(
            'PushNotifications: APNs token unavailable; deferred device registration.',
          );
          Future.delayed(const Duration(seconds: 5), () {
            unawaited(syncTokenWithBackend());
          });
          return;
        }
      }
      final token = await _fcm.getToken();
      if (token == null || token.isEmpty) {
        debugPrint(
          'PushNotifications: FCM token unavailable; registration deferred.',
        );
        Future.delayed(const Duration(seconds: 5), () {
          unawaited(syncTokenWithBackend());
        });
        return;
      }

      final metadata = await _deviceMetadata();

      await apiClient.post(
        ApiConfig.notificationDevices,
        body: {
          'token': token,
          'platform': _platformName,
          'deviceId': metadata['deviceId'],
          'appVersion': metadata['appVersion'],
          'locale': PlatformDispatcher.instance.locale.toLanguageTag(),
        },
      );
      debugPrint(
        'PushNotifications: Device registered with backend '
        '(platform=$_platformName, tokenLength=${token.length}).',
      );
    } catch (error) {
      // Authentication may not exist yet, or the backend may be offline.
      // Startup and token refresh will retry later.
      debugPrint('PushNotifications: Device registration deferred: $error');
    }
  }

  Future<void> unregisterCurrentDevice() async {
    final apiClient = _apiClient;
    if (apiClient == null) return;

    await NativeCallService.instance.unregisterCurrentVoipDevice();
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

  bool get _isApplePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<String?> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final token = await _fcm.getAPNSToken();
      if (token != null && token.isNotEmpty) return token;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  Future<Map<String, String?>> _deviceMetadata() {
    return _deviceMetadataFuture ??= _loadDeviceMetadata();
  }

  Future<Map<String, String?>> _loadDeviceMetadata() async {
    try {
      final package = await PackageInfo.fromPlatform();
      String? deviceId;
      if (!kIsWeb) {
        final info = DeviceInfoPlugin();
        if (defaultTargetPlatform == TargetPlatform.android) {
          deviceId = (await info.androidInfo).id;
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          deviceId = (await info.iosInfo).identifierForVendor;
        }
      }
      return {
        'deviceId': deviceId,
        'appVersion': '${package.version}+${package.buildNumber}',
      };
    } catch (error) {
      debugPrint('PushNotifications: device metadata unavailable: $error');
      return {'deviceId': null, 'appVersion': null};
    }
  }
}
