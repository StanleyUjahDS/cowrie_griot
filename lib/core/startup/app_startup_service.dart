// app_startup_service.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/auth/services/auth_session_service.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/users/providers/user_provider.dart';
import '../../features/chat/providers/messaging_provider.dart';
import '../services/push_notification_service.dart';
import '../../features/wallet/providers/wallet_provider.dart';
import '../../features/miner/providers/mining_provider.dart';
import '../../features/miner/providers/referral_provider.dart';
import '../../features/miner/providers/reputation_provider.dart';
import '../services/deep_link_service.dart';

class AppStartupService {
  final AuthSessionService _authSessionService;
  final AuthController _authController;
  final UserProvider _userProvider;
  final MessagingProvider _messagingProvider;
  final WalletProvider _walletProvider;
  final MiningProvider _miningProvider;
  final ReferralProvider _referralProvider;
  final ReputationProvider _reputationProvider;

  AppStartupService({
    required AuthSessionService authSessionService,
    required AuthController authController,
    required UserProvider userProvider,
    required MessagingProvider messagingProvider,
    required WalletProvider walletProvider,
    required MiningProvider miningProvider,
    required ReferralProvider referralProvider,
    required ReputationProvider reputationProvider,
  }) : _authSessionService = authSessionService,
       _authController = authController,
       _userProvider = userProvider,
       _messagingProvider = messagingProvider,
       _walletProvider = walletProvider,
       _miningProvider = miningProvider,
       _referralProvider = referralProvider,
       _reputationProvider = reputationProvider;

  Future<bool> initialize() async {
    try {
      debugPrint('AppStartup: Starting initialization...');
      // Deep-link setup must never hold the splash screen hostage.
      unawaited(DeepLinkService.instance.initialize());

      // 1. Restore Local Data (Immediate UI)
      await _userProvider.loadLocalUser();

      // 2. Sync Auth State (Storage -> Memory)
      await _authController.restoreSession();

      // 3. Restore Session (Network Check/Refresh)
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

          // Warm data in the background. Navigation must not wait for APIs.
          unawaited(_warmAppData());

          unawaited(PushNotificationService.instance.syncTokenWithBackend());
          unawaited(_messagingProvider.loadBlocks());
        } catch (e) {
          debugPrint('AppStartup: Profile sync failed: $e');

          // If the failure was a 401 (Unauthorized), then our assumed
          // session is actually invalid. Fallback to unauthenticated.
          final errorStr = e.toString();
          if (errorStr.contains('401') || errorStr.toLowerCase().contains('unauthorized')) {
            debugPrint('AppStartup: Session proved invalid (401). Falling back to login.');
            status = AuthSessionStatus.unauthenticated;
          }
        }
      }

      // Check status AGAIN if it fell back above
      if (status == AuthSessionStatus.unauthenticated) {
        debugPrint('AppStartup: Wallet exists but no session found. Redirection to login required.');
        return false;
      }

      if (status == AuthSessionStatus.offline) {
         debugPrint('AppStartup: App is offline. Proceeding with local data.');
      }

      // CONTRACT: If a wallet exists and status is not 'needsRegistration' or 'unauthenticated',
      // we enter the app.
      return true;
    } catch (e) {
      debugPrint('AppStartup: Critical initialization error: $e');
      return false;
    }
  }

  Future<void> _warmAppData() async {
    await Future.wait([
      _walletProvider.loadWallet(force: true),
      _messagingProvider.loadConversations(),
      _messagingProvider.loadRequests(),
      _messagingProvider.loadFriends(),
      _miningProvider.loadStatus(),
      _referralProvider.loadReferralStatus(),
      _reputationProvider.loadReputation(),
    ]);
  }
}
