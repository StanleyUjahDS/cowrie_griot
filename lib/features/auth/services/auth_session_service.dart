// auth_session_service.dart

import 'package:flutter/foundation.dart';

import 'auth_api_service.dart';
import 'auth_storage_service.dart';
import 'wallet_auth_service.dart';
import '../../wallet/services/wallet_service.dart';
import '../../local_auth/services/app_lock_service.dart';
import '../../local_auth/services/biometric_service.dart';
import '../../local_auth/services/pin_storage_service.dart';
import '../../../core/services/push_notification_service.dart';

enum AuthSessionStatus {
  authenticated,
  unauthenticated,
  offline,
  needsRegistration,
}

class AuthSessionService {
  final WalletService _walletService;
  final AuthApiService _authApiService;
  final AuthStorageService _authStorageService;
  final WalletAuthService _walletAuthService;

  // Security services for full wipe
  final AppLockService _appLockService;
  final BiometricService _biometricService;
  final PinStorageService _pinStorageService;

  // ============================================================
  // AUTHENTICATION LOCK
  // ============================================================

  bool _isAuthenticating = false;

  AuthSessionService({
    required WalletService walletService,
    required AuthApiService authApiService,
    required AuthStorageService authStorageService,
    required WalletAuthService walletAuthService,
    AppLockService? appLockService,
    BiometricService? biometricService,
    PinStorageService? pinStorageService,
  }) : _walletService = walletService,
       _authApiService = authApiService,
       _authStorageService = authStorageService,
       _walletAuthService = walletAuthService,
       _appLockService = appLockService ?? AppLockService(),
       _biometricService = biometricService ?? BiometricService(),
       _pinStorageService = pinStorageService ?? const PinStorageService();

  // ============================================================
  // HAS WALLET
  // ============================================================

  Future<bool> hasWallet() async {
    final wallet = await _walletService.loadWallet();

    return wallet != null;
  }

  // ============================================================
  // HAS REFRESH SESSION
  // ============================================================

  Future<bool> hasRefreshSession() async {
    final refreshToken = await _authStorageService.getRefreshToken();

    return refreshToken != null && refreshToken.isNotEmpty;
  }

  // ============================================================
  // RESTORE SESSION
  // ============================================================
  //
  // This is the ONLY automatic backend session restoration
  // method used during application startup.
  //
  // IMPORTANT:
  //
  // We ONLY attempt restoration via the refresh token here.
  //
  // We DO NOT automatically trigger wallet authentication
  // (nonce signing) because it may be unexpected for the user
  // and can cause duplicate signature requests.
  //
  // ============================================================

  Future<AuthSessionStatus> restoreSession() async {
    // 1. Verify local wallet
    final wallet = await _walletService.loadWallet();
    if (wallet == null) {
      debugPrint('AuthSession: No local wallet found.');
      return AuthSessionStatus.needsRegistration;
    }

    // 2. Try refresh token
    final refreshToken = await _authStorageService.getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        debugPrint('AuthSession: Attempting refresh...');
        await _authApiService.refreshSession(refreshToken: refreshToken);
        debugPrint('AuthSession: Authenticated.');
        return AuthSessionStatus.authenticated;
      } catch (e) {
        debugPrint('AuthSession: Refresh failed: $e');

        // Check if it's a 401/403 (Invalid Token) or Network Error
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('unable to connect') || 
            errorString.contains('500') || 
            errorString.contains('502') || 
            errorString.contains('503')) {
          debugPrint('AuthSession: Server unreachable, keeping existing tokens.');
          return AuthSessionStatus.offline;
        }

        debugPrint('AuthSession: Token expired/invalid, clearing.');
        await _authStorageService.clearSession();
      }
    }

    return AuthSessionStatus.unauthenticated;
  }

  // ============================================================
  // REAUTHENTICATE WALLET
  // ============================================================
  //
  // Explicit wallet authentication.
  //
  // This involves:
  // 1. Requesting a nonce
  // 2. Signing the nonce with the wallet
  // 3. Verifying the signature
  //
  // ============================================================

  Future<bool> reauthenticateWallet() async {
    if (_isAuthenticating) {
      debugPrint(
        'AuthSession: Already authenticating, ignoring duplicate request.',
      );
      return false;
    }

    _isAuthenticating = true;

    try {
      debugPrint('AuthSession: Starting wallet authentication...');
      await _walletAuthService.authenticateWallet();
      debugPrint('AuthSession: Wallet authentication successful.');
      await PushNotificationService.instance.syncTokenWithBackend();
      return true;
    } catch (e) {
      debugPrint('AuthSession: Wallet authentication failed: $e');
      return false;
    } finally {
      _isAuthenticating = false;
    }
  }

  // ============================================================
  // SIGN OUT (SESSION ONLY)
  // ============================================================
  //
  // ONLY clears the backend session and local tokens.
  //
  // DOES NOT delete:
  // - Wallet / Mnemonic
  // - Security Settings (PIN, Biometrics)
  //
  // ============================================================

  Future<void> signOut() async {
    // 1. Unregister notifications while we still have a token
    try {
      await PushNotificationService.instance.unregisterCurrentDevice();
    } catch (_) {}

    // 2. Backend revocation
    final refreshToken = await _authStorageService.getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _authApiService.logout(refreshToken: refreshToken);
      } catch (_) {}
    }

    // 3. Local session wipe
    await _authStorageService.clearSession();
  }

  // ============================================================
  // WIPE DATA (FULL RESET)
  // ============================================================
  //
  // PERFORMS A FULL WIPE:
  //
  // 1. Revokes backend session
  // 2. Deletes local session (JWTs)
  // 3. Deletes local wallet (Mnemonic/Keys)
  // 4. Deletes security settings (PIN, Biometrics, App Lock)
  //
  // ============================================================

  Future<void> wipeData() async {
    // 1. Sign out first
    await signOut();

    // 2. Clear wallet
    await _walletService.clearWallet();

    // 3. Clear security
    await Future.wait([
      _appLockService.reset(),
      _biometricService.disable(),
      _pinStorageService.deletePin(),
    ]);
  }

  // ============================================================
  // CLEAR SESSION ONLY
  // ============================================================

  Future<void> clearSession() async {
    await _authStorageService.clearSession();
  }

  Future<String?> getAccessToken() {
    return _authStorageService.getAccessToken();
  }
}
