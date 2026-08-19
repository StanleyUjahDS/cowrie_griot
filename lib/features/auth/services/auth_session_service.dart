// auth_session_service.dart

import 'auth_api_service.dart';
import 'auth_storage_service.dart';
import 'wallet_auth_service.dart';
import '../../wallet/services/wallet_service.dart';
import '../../local_auth/services/app_lock_service.dart';
import '../../local_auth/services/biometric_service.dart';
import '../../local_auth/services/pin_storage_service.dart';

// ============================================================
// AUTH SESSION SERVICE
// ============================================================
//
// RESPONSIBILITY:
//
// This service is responsible ONLY for restoring the backend
// authentication session and coordinating a full account logout.
//
// ============================================================

class AuthSessionService {
  final WalletService _walletService;
  final AuthApiService _authApiService;
  final AuthStorageService _authStorageService;
  final WalletAuthService _walletAuthService;

  // Security services for full wipe
  final AppLockService _appLockService;
  final BiometricService _biometricService;
  final PinStorageService _pinStorageService;

  AuthSessionService({
    required WalletService walletService,
    required AuthApiService authApiService,
    required AuthStorageService authStorageService,
    required WalletAuthService walletAuthService,
    AppLockService? appLockService,
    BiometricService? biometricService,
    PinStorageService? pinStorageService,
  })  : _walletService = walletService,
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
    final wallet =
    await _walletService.loadWallet();

    return wallet != null;
  }

  // ============================================================
  // HAS REFRESH SESSION
  // ============================================================

  Future<bool> hasRefreshSession() async {
    final refreshToken =
    await _authStorageService.getRefreshToken();

    return refreshToken != null &&
        refreshToken.isNotEmpty;
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
  // If the refresh token fails, we DO NOT stop there.
  //
  // The local wallet is still available, therefore we
  // authenticate the wallet again.
  //
  // ============================================================

  Future<bool> restoreSession() async {
    // ----------------------------------------------------------
    // STEP 1
    // VERIFY LOCAL WALLET EXISTS
    // ----------------------------------------------------------

    final wallet =
    await _walletService.loadWallet();

    if (wallet == null) {
      return false;
    }

    // ----------------------------------------------------------
    // STEP 2
    // TRY REFRESH TOKEN
    // ----------------------------------------------------------

    final refreshToken =
    await _authStorageService.getRefreshToken();

    if (refreshToken != null &&
        refreshToken.isNotEmpty) {
      try {
        await _authApiService.refreshSession(
          refreshToken: refreshToken,
        );

        // ------------------------------------------------------
        // REFRESH SUCCESSFUL
        //
        // AuthApiService.refreshSession() is responsible for
        // storing the new access/refresh tokens.
        // ------------------------------------------------------

        return true;
      } catch (_) {
        // ------------------------------------------------------
        // REFRESH FAILED
        //
        // DO NOT:
        //
        // - delete wallet
        // - delete user
        // - send user to recovery
        //
        // Continue with wallet authentication.
        // ------------------------------------------------------
      }
    }

    // ----------------------------------------------------------
    // STEP 3
    // AUTHENTICATE EXISTING WALLET
    // ----------------------------------------------------------
    //
    // WalletAuthService:
    //
    // wallet address
    //      ↓
    // backend nonce
    //      ↓
    // wallet signs nonce
    //      ↓
    // backend verifies signature
    //      ↓
    // new access + refresh tokens
    //
    // ----------------------------------------------------------

    try {
      await _walletAuthService
          .authenticateWallet();

      return true;
    } catch (_) {
      // --------------------------------------------------------
      // Wallet authentication failed.
      //
      // IMPORTANT:
      //
      // The wallet remains untouched.
      //
      // The caller decides what UI should be shown.
      // --------------------------------------------------------

      return false;
    }
  }

  // ============================================================
  // REAUTHENTICATE WALLET
  // ============================================================
  //
  // Explicit wallet authentication.
  //
  // This is NOT automatically called separately by startup.
  //
  // ============================================================

  Future<bool> reauthenticateWallet() async {
    try {
      await _walletAuthService
          .authenticateWallet();

      return true;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // LOGOUT
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

  Future<void> logout() async {
    // ----------------------------------------------------------
    // 1. BACKEND REVOCATION
    // ----------------------------------------------------------

    final refreshToken =
    await _authStorageService.getRefreshToken();

    if (refreshToken != null &&
        refreshToken.isNotEmpty) {
      try {
        await _authApiService.logout(
          refreshToken: refreshToken,
        );
      } catch (_) {
        // Backend may be offline.
      }
    }

    // ----------------------------------------------------------
    // 2. CLEAR SESSION (JWTs)
    // ----------------------------------------------------------

    await _authStorageService.clearSession();

    // ----------------------------------------------------------
    // 3. CLEAR WALLET (MNEMONIC/KEYS)
    // ----------------------------------------------------------

    await _walletService.clearWallet();

    // ----------------------------------------------------------
    // 4. CLEAR SECURITY SETTINGS
    // ----------------------------------------------------------

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
}