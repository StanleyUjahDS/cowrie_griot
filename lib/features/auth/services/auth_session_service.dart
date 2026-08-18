import '/features/auth/services/auth_api_service.dart';
import '/features/auth/services/auth_storage_service.dart';
import '/features/auth/services/wallet_auth_service.dart';
import '/features/wallet/services/wallet_service.dart';

// ============================================================
// AUTH SESSION SERVICE
// ============================================================
//
// Responsible for restoring the application session when the
// application starts.
//
// IMPORTANT:
//
// This service NEVER creates, replaces, or deletes a wallet.
//
// Wallet and backend authentication sessions are independent.
//
// WALLET
//   ↓
// Permanent local wallet identity
//
// SESSION
//   ↓
// Temporary backend authentication
//
// STARTUP FLOW:
//
// No wallet
//     ↓
// /welcome_one
//
// Wallet exists
//     ↓
// Try refresh token
//     ↓
// Refresh succeeds
//     ↓
// /chat
//
// Refresh missing / expired / invalid
//     ↓
// Silently authenticate existing wallet
//     ↓
// New access + refresh tokens
//     ↓
// /chat
//
// IMPORTANT:
//
// An expired access token or refresh token MUST NOT force the
// user to manually log in or enter their recovery phrase.
//
// As long as the wallet still exists locally, the application
// can authenticate the wallet again by signing a backend nonce.
//
// The recovery phrase is ONLY required when the wallet itself
// has been lost and must be restored.
//
// ============================================================

class AuthSessionService {
  final WalletService _walletService;
  final AuthApiService _authApiService;
  final AuthStorageService _authStorageService;
  final WalletAuthService _walletAuthService;

  AuthSessionService({
    required WalletService walletService,
    required AuthApiService authApiService,
    required AuthStorageService authStorageService,
    required WalletAuthService walletAuthService,
  })  : _walletService = walletService,
        _authApiService = authApiService,
        _authStorageService = authStorageService,
        _walletAuthService = walletAuthService;

  // ============================================================
  // GET STARTUP DESTINATION
  // ============================================================
  //
  // This is the main method used by SplashScreen.
  //
  // The wallet is checked FIRST.
  //
  // The backend session is secondary.
  //
  // ============================================================

  Future<String> getStartupDestination() async {
    // ----------------------------------------------------------
    // STEP 1
    // CHECK WHETHER A WALLET EXISTS
    // ----------------------------------------------------------

    final wallet = await _walletService.loadWallet();

    if (wallet == null) {
      // --------------------------------------------------------
      // NO WALLET
      // --------------------------------------------------------
      //
      // This is the only situation where the user needs to
      // enter the onboarding/recovery flow.
      //
      // We do NOT create a wallet automatically here.
      //
      // --------------------------------------------------------

      return '/welcome_one';
    }

    // ----------------------------------------------------------
    // STEP 2
    // CHECK STORED REFRESH TOKEN
    // ----------------------------------------------------------

    final refreshToken =
    await _authStorageService.getRefreshToken();

    // ----------------------------------------------------------
    // STEP 3
    // REFRESH TOKEN EXISTS
    // ----------------------------------------------------------

    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _authApiService.refreshSession(
          refreshToken: refreshToken,
        );

        // ------------------------------------------------------
        // REFRESH SUCCESSFUL
        // ------------------------------------------------------
        //
        // AuthApiService.refreshSession()
        // already saves the rotated access token and
        // refresh token.
        //
        // ------------------------------------------------------

        return '/chat';
      } catch (_) {
        // ------------------------------------------------------
        // REFRESH FAILED
        // ------------------------------------------------------
        //
        // DO NOT send the user to /login.
        //
        // DO NOT delete the wallet.
        //
        // Instead, silently authenticate the wallet again.
        //
      }
    }

    // ----------------------------------------------------------
    // STEP 4
    // SILENT WALLET AUTHENTICATION
    // ----------------------------------------------------------
    //
    // This happens when:
    //
    // - refresh token is missing
    // - refresh token expired
    // - refresh token was revoked
    // - refresh token became invalid
    // - refresh request failed
    //
    // The wallet still exists locally, so we can authenticate
    // it directly.
    //
    // WalletAuthService performs:
    //
    // wallet address
    //      ↓
    // request nonce
    //      ↓
    // sign nonce with private key
    //      ↓
    // verify signature
    //      ↓
    // new access token
    //      +
    // new refresh token
    //
    // ----------------------------------------------------------

    try {
      await _walletAuthService.authenticateWallet();

      // --------------------------------------------------------
      // WALLET AUTHENTICATION SUCCESSFUL
      // --------------------------------------------------------
      //
      // WalletAuthService → AuthApiService.verifyWallet()
      // saves both new tokens.
      //
      // The user never needs to see the login screen.
      //
      // --------------------------------------------------------

      return '/chat';
    } catch (_) {
      // --------------------------------------------------------
      // WALLET AUTHENTICATION FAILED
      // --------------------------------------------------------
      //
      // IMPORTANT:
      //
      // Even if backend authentication fails, DO NOT delete
      // the wallet.
      //
      // The wallet is still locally stored and can be tried
      // again later.
      //
      // At this point we need a user-facing authentication
      // recovery screen rather than silently pretending the
      // session exists.
      //
      // --------------------------------------------------------

      return '/login';
    }
  }

  // ============================================================
  // HAS WALLET
  // ============================================================
  //
  // Checks whether a wallet exists locally.
  //
  // This does NOT check backend authentication.
  //
  // ============================================================

  Future<bool> hasWallet() async {
    final wallet = await _walletService.loadWallet();

    return wallet != null;
  }

  // ============================================================
  // HAS REFRESH SESSION
  // ============================================================
  //
  // Checks whether a refresh token is stored.
  //
  // IMPORTANT:
  //
  // This only tells us that a token exists.
  // It does NOT prove that the token is valid.
  //
  // ============================================================

  Future<bool> hasRefreshSession() async {
    final refreshToken =
    await _authStorageService.getRefreshToken();

    return refreshToken != null && refreshToken.isNotEmpty;
  }

  // ============================================================
  // RESTORE SESSION
  // ============================================================
  //
  // Attempts to restore the backend session.
  //
  // If refresh fails, this method automatically falls back to
  // wallet authentication.
  //
  // Therefore the user does NOT need to manually log in simply
  // because a refresh token expired.
  //
  // ============================================================

  Future<bool> restoreSession() async {
    // ----------------------------------------------------------
    // STEP 1
    // CHECK WALLET
    // ----------------------------------------------------------

    final wallet = await _walletService.loadWallet();

    if (wallet == null) {
      return false;
    }

    // ----------------------------------------------------------
    // STEP 2
    // TRY REFRESH TOKEN
    // ----------------------------------------------------------

    final refreshToken =
    await _authStorageService.getRefreshToken();

    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _authApiService.refreshSession(
          refreshToken: refreshToken,
        );

        return true;
      } catch (_) {
        // ------------------------------------------------------
        // Refresh failed.
        //
        // Continue to wallet authentication.
        // ------------------------------------------------------
      }
    }

    // ----------------------------------------------------------
    // STEP 3
    // FALL BACK TO WALLET AUTHENTICATION
    // ----------------------------------------------------------

    try {
      await _walletAuthService.authenticateWallet();

      return true;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // NEEDS WALLET AUTHENTICATION
  // ============================================================
  //
  // Determines whether the wallet exists but the current
  // backend session cannot be restored automatically.
  //
  // IMPORTANT:
  //
  // This method does NOT delete anything.
  //
  // ============================================================

  Future<bool> needsWalletAuthentication() async {
    final walletExists = await hasWallet();

    if (!walletExists) {
      return false;
    }

    final restored = await restoreSession();

    return !restored;
  }

  // ============================================================
  // REAUTHENTICATE WALLET
  // ============================================================
  //
  // Explicitly authenticates the existing local wallet.
  //
  // Useful for login screens, retry buttons, or manual
  // authentication.
  //
  // ============================================================

  Future<bool> reauthenticateWallet() async {
    try {
      await _walletAuthService.authenticateWallet();

      return true;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================
  //
  // IMPORTANT:
  //
  // Logout ONLY removes the backend authentication session.
  //
  // It NEVER removes:
  //
  // - mnemonic
  // - private key
  // - public key
  // - wallet address
  //
  // Therefore:
  //
  // logout()
  //     ↓
  // backend session removed
  //     ↓
  // wallet remains
  //     ↓
  // wallet can authenticate again
  //
  // ============================================================

  Future<void> logout() async {
    final refreshToken =
    await _authStorageService.getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      await _authStorageService.clearSession();
      return;
    }

    try {
      await _authApiService.logout(
        refreshToken: refreshToken,
      );
    } catch (_) {
      // --------------------------------------------------------
      // Even if the backend is unavailable, clear the local
      // authentication session.
      //
      // The wallet remains untouched.
      // --------------------------------------------------------

      await _authStorageService.clearSession();
    }
  }

  // ============================================================
  // CLEAR SESSION ONLY
  // ============================================================
  //
  // Clears backend authentication credentials only.
  //
  // NEVER touches wallet storage.
  //
  // ============================================================

  Future<void> clearSession() async {
    await _authStorageService.clearSession();
  }
}