import 'package:flutter/foundation.dart';
import '../../features/auth/services/auth_session_service.dart';
import '../../features/users/providers/user_provider.dart';

class AppStartupService {
  final AuthSessionService _authSessionService;
  final UserProvider _userProvider;

  AppStartupService({
    required AuthSessionService authSessionService,
    required UserProvider userProvider,
  })  : _authSessionService = authSessionService,
        _userProvider = userProvider;

  // ============================================================
  // INITIALIZE APPLICATION
  // ============================================================

  Future<void> initialize() async {
    try {
      // 1. Restore local user state immediately
      await _userProvider.loadLocalUser();

      // 2. Establish backend session in background
      final sessionRestored = await _authSessionService.restoreSession();

      if (sessionRestored) {
        // 3. Synchronize user data if session is active
        await _userProvider.loadUser();
      }

      // TODO: Initialize other services (messaging, sockets, etc.)
      
    } catch (e) {
      debugPrint('AppStartupService initialization error: $e');
      // We don't rethrow here because the app can still work 
      // partially with local data or prompt for login if needed.
    }
  }
}
