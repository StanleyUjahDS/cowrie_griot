import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../router/app_router.dart';
import '../../features/chat/providers/messaging_provider.dart';
import '../../features/chat/models/conversation_model.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/users/providers/user_provider.dart';

class DeepLinkService {
  DeepLinkService._();
  static final instance = DeepLinkService._();

  final AppLinks _links = AppLinks();
  StreamSubscription<Uri>? _subscription;
  bool _initialized = false;
  Uri? _lastHandledUri;
  DateTime? _lastHandledAt;

  static const _pendingReferralKey = 'pending_referral_code';
  static const _pendingReferralSavedAtKey = 'pending_referral_saved_at';
  static const _pendingPlusKey = 'pending_plus_intent';
  static const _pendingDestinationKey = 'pending_deep_link_destination';
  static const _pendingDestinationSavedAtKey =
      'pending_deep_link_destination_saved_at';
  static const _pendingReferralLifetime = Duration(days: 30);

  bool _routerHasMatch() {
    try {
      return AppRouter.router.routerDelegate.currentConfiguration.matches.isNotEmpty;
    } catch (_) {
      // During Router restoration GoRouter briefly exposes an empty match
      // list. Navigation in that window triggers RouteMatchList.last and
      // crashes the whole app.
      return false;
    }
  }

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

  Future<void> handleUri(Uri uri, {bool force = false}) async {
    final host = uri.host.toLowerCase();
    final isCustomScheme = uri.scheme.toLowerCase() == 'griot';
    if (!isCustomScheme &&
        host != 'griot.network' &&
        host != 'www.griot.network') {
      return;
    }

    // Ensure path is consistent (no trailing slash, starts with /)
    var path = uri.path;
    if (isCustomScheme && host.isNotEmpty) {
      // Custom-scheme fallback links use forms such as
      // griot://join?ref=..., griot://profile/name, and
      // griot://channel/name. Convert the authority back into the same
      // canonical path used by HTTPS App Links.
      path = host == 'join' || host == 'plus' ? '/$host' : '/$host$path';
    }
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    // Store and de-duplicate the canonical HTTPS shape. For a custom link
    // such as `griot://profile/stargie`, uri.path is only `/stargie`; saving
    // that raw value would lose the `profile` destination while the user is
    // signed out and the link could not be replayed after authentication.
    final canonicalUri = Uri(
      scheme: 'https',
      host: 'griot.network',
      path: path,
      query: uri.hasQuery ? uri.query : null,
    );

    // Normalize path to lower case for routing
    final normalizedPath = path.toLowerCase();
    if (path.isEmpty || (!force && _isDuplicate(canonicalUri, path))) return;

    if (normalizedPath == '/call/join') {
      final invite = uri.queryParameters['invite']?.trim();
      if (invite == null || invite.isEmpty) return;
      await _savePendingDestination(canonicalUri);
      _openCallWhenReady(invite);
      return;
    }

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

    if (normalizedPath.startsWith('/profile/')) {
      final identifier = _lastPathSegment(path);
      if (identifier.isEmpty) return;

      await _savePendingDestination(canonicalUri);
      final cleanIdentifier = _withoutDisplayPrefix(identifier);
      final isUsername =
          identifier.startsWith('@') || !_looksLikeUserId(cleanIdentifier);
      _resolveAndOpenProfile(cleanIdentifier, isUsername);
      return;
    }

    if (_isConversationPath(normalizedPath)) {
      final isGroup =
          normalizedPath.startsWith('/group/') ||
          normalizedPath.startsWith('/circle/');
      final type = isGroup ? ConversationType.group : ConversationType.channel;
      final username = _withoutDisplayPrefix(_lastPathSegment(path));
      if (username.isEmpty) return;

      await _savePendingDestination(canonicalUri);
      _resolveAndOpen(username, type);
    }
  }

  bool _isDuplicate(Uri uri, String path) {
    final now = DateTime.now();
    final normalized = uri.replace(path: path);
    final isDuplicate =
        _lastHandledUri == normalized &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < const Duration(seconds: 3);
    _lastHandledUri = normalized;
    _lastHandledAt = now;
    return isDuplicate;
  }

  String _lastPathSegment(String path) {
    final segment = path.split('/').last.trim();
    try {
      return Uri.decodeComponent(segment);
    } catch (_) {
      return segment;
    }
  }

  Future<void> _savePendingDestination(Uri uri) async {
    final path = uri.path.isEmpty ? '/' : uri.path;
    final value = uri.hasQuery ? '$path?${uri.query}' : path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingDestinationKey, value);
    await prefs.setInt(
      _pendingDestinationSavedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<String?> _getPendingDestination() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_pendingDestinationKey)?.trim();
    final savedAtMillis = prefs.getInt(_pendingDestinationSavedAtKey);
    if (value == null || value.isEmpty || savedAtMillis == null) return null;

    final savedAt = DateTime.fromMillisecondsSinceEpoch(savedAtMillis);
    if (DateTime.now().difference(savedAt) > _pendingReferralLifetime) {
      unawaited(_clearPendingDestination());
      return null;
    }
    return value;
  }

  Future<void> _clearPendingDestination() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingDestinationKey);
    await prefs.remove(_pendingDestinationSavedAtKey);
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

  void _openPlusWhenReady({int contextAttempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context =
          AppRouter.router.routerDelegate.navigatorKey.currentContext;
      if (context == null) {
        if (contextAttempt < 25) {
          Future<void>.delayed(
            const Duration(milliseconds: 200),
            () => _openPlusWhenReady(contextAttempt: contextAttempt + 1),
          );
        }
        return;
      }

      final authController = context.read<AuthController>();
      if (!authController.hasValidSession) {
        AppRouter.router.go('/login');
        return;
      }

      await clearPendingPlusIntent();
      _pushWithStableBackStack('/settings/griot-plus');
    });
  }

  void _openReferralWhenReady(String code, {int contextAttempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context =
          AppRouter.router.routerDelegate.navigatorKey.currentContext;
      if (context == null) {
        if (contextAttempt < 25) {
          Future<void>.delayed(
            const Duration(milliseconds: 200),
            () => _openReferralWhenReady(
              code,
              contextAttempt: contextAttempt + 1,
            ),
          );
        }
        return;
      }

      final authController = context.read<AuthController>();
      if (!authController.hasValidSession) {
        AppRouter.router.go('/login');
        return;
      }

      await clearPendingReferralCode();
      _pushWithStableBackStack(
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
      _pushWithStableBackStack(
        '/settings/referrals?ref=${Uri.encodeQueryComponent(code)}',
        forceHomeBase: true,
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
      _pushWithStableBackStack('/settings/griot-plus', forceHomeBase: true);
    });
  }

  /// Replays a profile, group, or channel link received before login.
  Future<void> openPendingDestinationIfAuthenticated() async {
    final value = await _getPendingDestination();
    if (value == null) return;

    final uri = Uri.tryParse(value);
    if (uri == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context =
          AppRouter.router.routerDelegate.navigatorKey.currentContext;
      if (context == null || !context.read<AuthController>().hasValidSession) {
        return;
      }

      unawaited(_clearPendingDestination());
      await _processUri(uri, savePending: false, forceHomeBase: true);
    });
  }

  void _openCallWhenReady(String invite, {int contextAttempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context =
          AppRouter.router.routerDelegate.navigatorKey.currentContext;
      if (context == null) {
        if (contextAttempt < 25) {
          Future<void>.delayed(
            const Duration(milliseconds: 200),
            () => _openCallWhenReady(invite, contextAttempt: contextAttempt + 1),
          );
        }
        return;
      }
      if (!context.read<AuthController>().hasValidSession) {
        AppRouter.router.go('/login');
        return;
      }
      await _clearPendingDestination();
      _pushWithStableBackStack(
        '/call/join?invite=${Uri.encodeQueryComponent(invite)}',
        forceHomeBase: true,
      );
    });
  }

  Future<void> _processUri(
    Uri uri, {
    required bool savePending,
    bool forceHomeBase = false,
  }) async {
    // This method is reserved for replaying saved destinations. Keeping the
    // public parser in handleUri avoids recursively re-saving the same link.
    final path = uri.path;
    final normalizedPath = path.toLowerCase();
    if (normalizedPath.startsWith('/profile/')) {
      final identifier = _lastPathSegment(path);
      if (identifier.isEmpty) return;
      final cleanIdentifier = _withoutDisplayPrefix(identifier);
      final isUsername =
          identifier.startsWith('@') || !_looksLikeUserId(cleanIdentifier);
      if (savePending) await _savePendingDestination(uri);
      _resolveAndOpenProfile(
        cleanIdentifier,
        isUsername,
        forceHomeBase: forceHomeBase,
      );
      return;
    }

    if (normalizedPath == '/call/join') {
      final invite = uri.queryParameters['invite']?.trim();
      if (invite == null || invite.isEmpty) return;
      if (savePending) await _savePendingDestination(uri);
      _openCallWhenReady(invite);
      return;
    }

    if (_isConversationPath(normalizedPath)) {
      final isGroup =
          normalizedPath.startsWith('/group/') ||
          normalizedPath.startsWith('/circle/');
      if (savePending) await _savePendingDestination(uri);
      _resolveAndOpen(
        _withoutDisplayPrefix(_lastPathSegment(path)),
        isGroup ? ConversationType.group : ConversationType.channel,
        forceHomeBase: forceHomeBase,
      );
    }
  }

  bool _isConversationPath(String normalizedPath) {
    return normalizedPath.startsWith('/group/') ||
        normalizedPath.startsWith('/circle/') ||
        normalizedPath.startsWith('/channel/');
  }

  String _withoutDisplayPrefix(String value) {
    final trimmed = value.trim();
    return trimmed.startsWith('@') ? trimmed.substring(1).trim() : trimmed;
  }

  bool _looksLikeUserId(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  bool _isPublicLinkLocation() {
    final path = AppRouter.router.routeInformationProvider.value.uri.path
        .toLowerCase();
    return path == '/join' ||
        path == '/plus' ||
        path == '/call/join' ||
        path.startsWith('/profile/') ||
        path.startsWith('/group/') ||
        path.startsWith('/circle/') ||
        path.startsWith('/channel/');
  }

  void _pushWithStableBackStack(
    String location, {
    Object? extra,
    bool forceHomeBase = false,
    int attempt = 0,
  }) {
    if (!_routerHasMatch()) {
      if (attempt < 25) {
        Future<void>.delayed(
          const Duration(milliseconds: 200),
          () => _pushWithStableBackStack(
            location,
            extra: extra,
            forceHomeBase: forceHomeBase,
            attempt: attempt + 1,
          ),
        );
      }
      return;
    }
    if (forceHomeBase || _isPublicLinkLocation()) {
      AppRouter.router.go('/chat');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppRouter.router.push(location, extra: extra);
      });
      return;
    }
    AppRouter.router.push(location, extra: extra);
  }

  void _openResolvedDestination(
    String location, {
    Object? extra,
    int attempt = 0,
  }) {
    if (!_routerHasMatch()) {
      if (attempt < 25) {
        Future<void>.delayed(
          const Duration(milliseconds: 200),
          () => _openResolvedDestination(
            location,
            extra: extra,
            attempt: attempt + 1,
          ),
        );
      }
      return;
    }
    // A router recovery route is only a cold-start handoff. Establish a real
    // home page beneath the destination so Back never returns to the resolver.
    if (_isPublicLinkLocation()) {
      AppRouter.router.go('/chat');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppRouter.router.push(location, extra: extra);
      });
      return;
    }
    // When Griot is already open, push instead of replace so the originating
    // screen remains available on the back stack.
    AppRouter.router.push(location, extra: extra);
  }

  void _resolveAndOpen(
    String username,
    ConversationType type, {
    bool forceHomeBase = false,
    int contextAttempt = 0,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context =
          AppRouter.router.routerDelegate.navigatorKey.currentContext;
      if (context == null) {
        if (contextAttempt < 25) {
          Future<void>.delayed(
            const Duration(milliseconds: 200),
            () => _resolveAndOpen(
              username,
              type,
              forceHomeBase: forceHomeBase,
              contextAttempt: contextAttempt + 1,
            ),
          );
        }
        return;
      }

      final authController = context.read<AuthController>();
      if (!authController.hasValidSession) {
        AppRouter.router.go('/login');
        return;
      }

      // Once authenticated, the pending value is no longer needed. Clearing
      // it before the network request prevents a failed or abandoned loader
      // from reopening the same destination on a later app launch.
      unawaited(_clearPendingDestination());

      final messagingProvider = context.read<MessagingProvider>();

      // Keep the originating screen underneath the temporary resolver. This
      // lets Back cancel the lookup and return to where the user came from.
      try {
        final result = await messagingProvider.resolveConversationByUsername(username, type);
        unawaited(_clearPendingDestination());
        _openResolvedDestination('/chat/community/${result.id}', extra: result);
      } catch (error) {
        debugPrint('DeepLink: unable to resolve community: $error');
      }
    });
  }

  void _resolveAndOpenProfile(
    String identifier,
    bool isUsername, {
    bool forceHomeBase = false,
    int contextAttempt = 0,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context =
          AppRouter.router.routerDelegate.navigatorKey.currentContext;
      if (context == null) {
        if (contextAttempt < 25) {
          Future<void>.delayed(
            const Duration(milliseconds: 200),
            () => _resolveAndOpenProfile(
              identifier,
              isUsername,
              forceHomeBase: forceHomeBase,
              contextAttempt: contextAttempt + 1,
            ),
          );
        }
        return;
      }

      final authController = context.read<AuthController>();
      if (!authController.hasValidSession) {
        AppRouter.router.go('/login');
        return;
      }

      unawaited(_clearPendingDestination());

      final userProvider = context.read<UserProvider>();
      // Keep the originating screen underneath the temporary resolver so
      // Back can cancel the lookup and return to it.
      try {
        final result = isUsername
            ? await userProvider.userApiService.getUserByUsername(identifier)
            : await userProvider.userApiService.getUserById(identifier);
        unawaited(_clearPendingDestination());
        _openResolvedDestination('/user/profile', extra: result);
      } catch (error) {
        debugPrint('DeepLink: unable to resolve profile: $error');
      }
    });
  }

  Future<void> dispose() async => _subscription?.cancel();
}
