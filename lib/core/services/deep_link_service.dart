import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../router/app_router.dart';
import '../../features/chat/providers/messaging_provider.dart';
import '../../features/chat/models/conversation_model.dart';
import '../../features/auth/auth_controller.dart';
import '../ui/screens/app_loading_screen.dart';

class DeepLinkService {
  DeepLinkService._();
  static final instance = DeepLinkService._();

  final AppLinks _links = AppLinks();
  StreamSubscription<Uri>? _subscription;
  bool _initialized = false;

  static const _pendingReferralKey = 'pending_referral_code';
  static const _pendingReferralSavedAtKey = 'pending_referral_saved_at';
  static const _pendingPlusKey = 'pending_plus_intent';
  static const _pendingReferralLifetime = Duration(days: 30);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final initial = await _links.getInitialLink();
      if (initial != null) unawaited(handleUri(initial));
      _subscription = _links.uriLinkStream.listen(handleUri);
    } catch (e) {
      debugPrint('DeepLink: initialization failed: $e');
    }
  }

  Future<void> handleUri(Uri uri) async {
    final host = uri.host.toLowerCase();
    if (host != 'griot.network' && host != 'www.griot.network') return;

    // Ensure path is consistent (no trailing slash, starts with /)
    var path = uri.path;
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    // Normalize path to lower case for routing
    final normalizedPath = path.toLowerCase();

    if (normalizedPath == '/join') {
      final code = uri.queryParameters['ref']?.trim();
      if (code == null || code.isEmpty) return;
      await savePendingReferralCode(code);
      _openReferralWhenReady(code);
      return;
    }

    if (normalizedPath == '/plus') {
      await savePendingPlusIntent();
      _openPlusWhenReady();
      return;
    }

    if (normalizedPath.startsWith('/group/@') ||
        normalizedPath.startsWith('/circle/@') ||
        normalizedPath.startsWith('/channel/@')) {
      final isGroup =
          normalizedPath.startsWith('/group/') ||
          normalizedPath.startsWith('/circle/');
      final type = isGroup ? ConversationType.group : ConversationType.channel;
      final username = path.split('@').last.trim();
      if (username.isEmpty) return;

      _resolveAndOpen(username, type);
    }
  }

  /// Stores a referral opened before authentication or account creation.
  /// This also covers the common "install/open, then sign up" flow.
  Future<void> savePendingReferralCode(String code) async {
    final normalized = code.trim();
    if (normalized.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingReferralKey, normalized);
    await prefs.setInt(
      _pendingReferralSavedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<String?> getPendingReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_pendingReferralKey)?.trim();
    final savedAtMillis = prefs.getInt(_pendingReferralSavedAtKey);

    if (code == null || code.isEmpty || savedAtMillis == null) return null;

    final savedAt = DateTime.fromMillisecondsSinceEpoch(savedAtMillis);
    if (DateTime.now().difference(savedAt) > _pendingReferralLifetime) {
      await clearPendingReferralCode();
      return null;
    }

    return code;
  }

  Future<void> clearPendingReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingReferralKey);
    await prefs.remove(_pendingReferralSavedAtKey);
  }

  Future<void> savePendingPlusIntent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingPlusKey, true);
  }

  Future<bool> getPendingPlusIntent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingPlusKey) ?? false;
  }

  Future<void> clearPendingPlusIntent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingPlusKey);
  }

  void _openPlusWhenReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context =
          AppRouter.router.routerDelegate.navigatorKey.currentContext;
      if (context == null) return;

      final authController = context.read<AuthController>();
      if (!authController.hasValidSession) {
        AppRouter.router.go('/login');
        return;
      }

      await clearPendingPlusIntent();
      AppRouter.router.go('/settings/griot-plus');
    });
  }

  void _openReferralWhenReady(String code) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context =
          AppRouter.router.routerDelegate.navigatorKey.currentContext;
      if (context == null) return;

      final authController = context.read<AuthController>();
      if (!authController.hasValidSession) {
        AppRouter.router.go('/login');
        return;
      }

      await clearPendingReferralCode();
      AppRouter.router.go(
        '/settings/referrals?ref=${Uri.encodeQueryComponent(code)}',
      );
    });
  }

  /// Replays a referral captured before signup/login once the app is ready.
  Future<void> openPendingReferralIfAuthenticated() async {
    final code = await getPendingReferralCode();
    if (code == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context =
          AppRouter.router.routerDelegate.navigatorKey.currentContext;
      if (context == null || !context.read<AuthController>().hasValidSession) {
        return;
      }

      await clearPendingReferralCode();
      AppRouter.router.go(
        '/settings/referrals?ref=${Uri.encodeQueryComponent(code)}',
      );
    });
  }

  Future<void> openPendingPlusIfAuthenticated() async {
    if (!await getPendingPlusIntent()) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context =
          AppRouter.router.routerDelegate.navigatorKey.currentContext;
      if (context == null || !context.read<AuthController>().hasValidSession) {
        return;
      }

      await clearPendingPlusIntent();
      AppRouter.router.go('/settings/griot-plus');
    });
  }

  void _resolveAndOpen(String username, ConversationType type) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context =
          AppRouter.router.routerDelegate.navigatorKey.currentContext;
      if (context == null) return;

      final authController = context.read<AuthController>();
      if (!authController.hasValidSession) {
        AppRouter.router.go('/login');
        return;
      }

      final messagingProvider = context.read<MessagingProvider>();

      AppRouter.router.push(
        '/loading',
        extra: AppLoadingRouteData(
          title:
              'Resolving ${type == ConversationType.group ? "Group" : "Channel"}',
          message: 'Connecting to Griot network...',
          icon: type == ConversationType.group
              ? Icons.groups_rounded
              : Icons.campaign_rounded,
          operation: () =>
              messagingProvider.resolveConversationByUsername(username, type),
          onSuccess: (ctx, result) {
            if (result is Conversation) {
              AppRouter.router.push(
                '/conversation/${result.id}',
                extra: result,
              );
            }
          },
        ),
      );
    });
  }

  Future<void> dispose() async => _subscription?.cancel();
}
