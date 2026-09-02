import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final initial = await _links.getInitialLink();
      if (initial != null) _handle(initial);
      _subscription = _links.uriLinkStream.listen(_handle);
    } catch (e) {
      debugPrint('DeepLink: initialization failed: $e');
    }
  }

  void _handle(Uri uri) {
    if (uri.host != 'griot.network') return;

    final path = uri.path;
    if (path == '/join') {
      final code = uri.queryParameters['ref']?.trim();
      if (code == null || code.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppRouter.router.go('/settings/referrals?ref=${Uri.encodeQueryComponent(code)}');
      });
      return;
    }

    if (path.startsWith('/group/@') || path.startsWith('/channel/@')) {
      final isGroup = path.startsWith('/group/');
      final type = isGroup ? ConversationType.group : ConversationType.channel;
      final username = path.split('@').last.trim();
      if (username.isEmpty) return;

      _resolveAndOpen(username, type);
    }
  }

  void _resolveAndOpen(String username, ConversationType type) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = AppRouter.router.routerDelegate.navigatorKey.currentContext;
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
          title: 'Resolving ${type == ConversationType.group ? "Group" : "Channel"}',
          message: 'Connecting to Griot network...',
          icon: type == ConversationType.group ? Icons.groups_rounded : Icons.campaign_rounded,
          operation: () => messagingProvider.resolveConversationByUsername(username, type),
          onSuccess: (ctx, result) {
            if (result is Conversation) {
              AppRouter.router.push('/conversation/${result.id}', extra: result);
            }
          },
        ),
      );
    });
  }

  Future<void> dispose() async => _subscription?.cancel();
}
