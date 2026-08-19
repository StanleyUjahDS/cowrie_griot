// app_startup_service.dart

import 'package:flutter/foundation.dart';

import '../../features/auth/services/auth_session_service.dart';
import '../../features/users/providers/user_provider.dart';

// ============================================================
// APP STARTUP SERVICE
// ============================================================
//
// THIS IS NOW THE SINGLE OWNER OF APPLICATION STARTUP.
//
// Startup:
//
// 1. Load local user
// 2. Restore backend session
// 3. Load current user from backend
//
// There is NO second restoreSession() elsewhere during startup.
//
// ============================================================

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

  Future<bool> initialize() async {
    try {
      // --------------------------------------------------------
      // STEP 1
      // RESTORE LOCAL USER
      // --------------------------------------------------------

      await _userProvider.loadLocalUser();

      // --------------------------------------------------------
      // STEP 2
      // RESTORE BACKEND SESSION
      // --------------------------------------------------------
      //
      // This happens exactly once.
      //
      // AuthSessionService internally:
      //
      // refresh token
      //      ↓
      // if failed
      //      ↓
      // wallet authentication
      //
      // --------------------------------------------------------

      final sessionRestored =
      await _authSessionService.restoreSession();

      if (!sessionRestored) {
        // ------------------------------------------------------
        // No valid backend session could be established.
        //
        // We do not delete the wallet or local user.
        // ------------------------------------------------------

        return false;
      }

      // --------------------------------------------------------
      // STEP 3
      // LOAD CURRENT USER
      // --------------------------------------------------------
      //
      // At this point ApiClient has a valid access token.
      //
      // GET /users/me
      //
      // --------------------------------------------------------

      await _userProvider.loadUser();

      if (!_userProvider.hasUser) {
        return false;
      }

      // --------------------------------------------------------
      // STEP 4
      // STARTUP SUCCESSFUL
      // --------------------------------------------------------

      // TODO:
      // Initialize messaging.
      // Initialize sockets.
      // Initialize notifications.
      // Initialize wallet live-data services.
      // etc.

      return true;
    } catch (e) {
      debugPrint(
        'AppStartupService initialization error: $e',
      );

      return false;
    }
  }
}