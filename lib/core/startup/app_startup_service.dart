// app_startup_service.dart

import 'package:flutter/foundation.dart';

import '../../features/auth/services/auth_session_service.dart';
import '../../features/users/providers/user_provider.dart';
import '../../features/chat/providers/messaging_provider.dart';
import '../services/push_notification_service.dart';

class AppStartupService {
  final AuthSessionService _authSessionService;
  final UserProvider _userProvider;
  final MessagingProvider _messagingProvider;

  AppStartupService({
    required AuthSessionService authSessionService,
    required UserProvider userProvider,
    required MessagingProvider messagingProvider,
  }) : _authSessionService = authSessionService,
       _userProvider = userProvider,
       _messagingProvider = messagingProvider;

  Future<bool> initialize() async {
    try {
      debugPrint('AppStartup: Starting initialization...');

      // 1. Restore Local Data (Immediate UI)
      await _userProvider.loadLocalUser();

      // 2. Restore Session (Network)
      AuthSessionStatus status = await _authSessionService.restoreSession();

      if (status == AuthSessionStatus.needsRegistration) {
        debugPrint('AppStartup: Identity missing. Redirection required.');
        return false; 
      }

      // 3. Sync Profile and Init Real-time
      if (status == AuthSessionStatus.authenticated) {
        debugPrint('AppStartup: Authenticated. Syncing profile...');
        try {
          await _userProvider.loadUser();
          
          final accessToken = await _authSessionService.getAccessToken();
          if (accessToken != null) {
            _messagingProvider.initSocket(accessToken);
          }

          await PushNotificationService.instance.syncTokenWithBackend();
          _messagingProvider.loadBlocks();
        } catch (e) {
          debugPrint('AppStartup: Profile sync failed (Backend unreachable).');
        }
      } else {
        debugPrint('AppStartup: Continuing in ${status.name} mode.');
      }

      // CONTRACT: If a wallet exists, always return true to enter the app.
      return true; 
    } catch (e) {
      debugPrint('AppStartup: Critical initialization error: $e');
      return false;
    }
  }
}
