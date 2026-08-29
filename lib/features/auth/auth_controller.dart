import 'package:flutter/foundation.dart';
import 'services/auth_api_service.dart';
import 'services/auth_session_service.dart';
import 'services/auth_storage_service.dart';
import 'services/wallet_auth_service.dart';
import '../wallet/services/wallet_service.dart';
import '../chat/providers/messaging_provider.dart';

class AuthController extends ChangeNotifier {
  final AuthApiService _authService;
  final WalletService _walletService;
  MessagingProvider? _messagingProvider;

  AuthController({
    required AuthApiService authService,
    required WalletService walletService,
  }) : _authService = authService,
       _walletService = walletService;

  void setMessagingProvider(MessagingProvider provider) {
    _messagingProvider = provider;
  }

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isAuthenticating = false;
  bool get isAuthenticating => _isAuthenticating;

  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;

  bool _isNewUser = false;

  bool get isNewUser => _isNewUser;

  String? _errorMessage;

  String? get errorMessage => _errorMessage;

  String? _accessToken;

  String? get accessToken => _accessToken;

  String? _refreshToken;

  String? get refreshToken => _refreshToken;

  String? _walletAddress;

  String? get walletAddress => _walletAddress;

  // ============================================================
  // LOADING STATE
  // ============================================================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // ============================================================
  // CLEAR ERROR
  // ============================================================

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ============================================================
  // WALLET AUTHENTICATION
  // ============================================================
  //
  // Handles both:
  //
  // 1. New wallet registration
  // 2. Existing wallet login
  //
  // Flow:
  //
  // Flutter
  //    ↓
  // Request nonce
  //    ↓
  // Backend creates authentication message
  //    ↓
  // Flutter signs message
  //    ↓
  // Send signature to backend
  //    ↓
  // Backend verifies signature
  //    ↓
  // JWT tokens returned
  //
  // ============================================================

  Future<bool> authenticateWallet() async {
    if (_isAuthenticating) {
      debugPrint('AuthController: Authentication already in progress.');
      return false;
    }

    try {
      _isAuthenticating = true;
      _setLoading(true);

      _errorMessage = null;

      // ----------------------------------------------------------
      // Get wallet address
      // ----------------------------------------------------------

      final address = await _walletService.getAddress();

      if (address == null || address.isEmpty) {
        throw Exception('No wallet found on this device.');
      }

      _walletAddress = address;

      // ----------------------------------------------------------
      // Request authentication nonce
      // ----------------------------------------------------------

      final nonceResponse = await _authService.requestNonce(
        walletAddress: address,
      );

      // ----------------------------------------------------------
      // Get authentication message
      // ----------------------------------------------------------

      final nonce = nonceResponse.nonce;

      final message = nonceResponse.message;

      // ----------------------------------------------------------
      // Sign authentication message
      // ----------------------------------------------------------
      //
      // This is a message signature.
      //
      // It does NOT authorize a blockchain transaction.
      //
      // ----------------------------------------------------------

      final signature = await _walletService.signMessage(message);

      if (signature == null || signature.isEmpty) {
        throw Exception('Wallet signature was not created.');
      }

      // ----------------------------------------------------------
      // Verify wallet signature
      // ----------------------------------------------------------

      final authenticationResponse = await _authService.verifyWallet(
        walletAddress: address,
        nonce: nonce,
        signature: signature,
      );

      // ----------------------------------------------------------
      // Store authentication state
      // ----------------------------------------------------------

      _accessToken = authenticationResponse.accessToken;

      _refreshToken = authenticationResponse.refreshToken;

      _walletAddress = authenticationResponse.user.walletAddress;

      _isNewUser = authenticationResponse.isNewUser;

      _isAuthenticated = true;
      notifyListeners();

      if (_accessToken != null) {
        _messagingProvider?.initSocket(_accessToken!);
      }

      return true;
    } catch (error) {
      debugPrint('AuthController: Authentication error: $error');
      _isAuthenticated = false;

      _errorMessage = error.toString().replaceFirst('Exception: ', '');

      notifyListeners();

      return false;
    } finally {
      _isAuthenticating = false;
      _setLoading(false);
    }
  }

  // ============================================================
  // REFRESH SESSION
  // ============================================================
  //
  // Uses the current refresh token to obtain a new:
  //
  // - Access token
  // - Refresh token
  //
  // ============================================================

  Future<bool> refreshSession() async {
    try {
      if (_refreshToken == null || _refreshToken!.isEmpty) {
        return false;
      }

      final response = await _authService.refreshSession(
        refreshToken: _refreshToken!,
      );

      // ----------------------------------------------------------
      // Update tokens
      // ----------------------------------------------------------

      _accessToken = response.accessToken;

      _refreshToken = response.refreshToken;

      _walletAddress = response.user.walletAddress;

      _isAuthenticated = true;
      notifyListeners();

      if (_accessToken != null) {
        _messagingProvider?.initSocket(_accessToken!);
      }

      return true;
    } catch (error) {
      debugPrint('Auth: Refresh session failed: $error');

      _isAuthenticated = false;

      _accessToken = null;

      _refreshToken = null;

      // ----------------------------------------------------------
      // IMPORTANT: Clear stored tokens on refresh failure
      // ----------------------------------------------------------

      await _authService.clearSession();

      _errorMessage = error.toString().replaceFirst('Exception: ', '');

      notifyListeners();

      return false;
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================
  //
  // Revokes the backend session.
  //
  // IMPORTANT:
  //
  // This does NOT delete:
  //
  // - Wallet
  // - Seed phrase
  // - Private key
  // - Public key
  // - Wallet address
  //
  // The wallet remains safely stored on the device.
  //
  // ============================================================

  Future<bool> logout() async {
    try {
      _setLoading(true);

      _errorMessage = null;

      // ----------------------------------------------------------
      // PERFORMS FULL WIPE (Session + Wallet + Security)
      // ----------------------------------------------------------

      final sessionService = AuthSessionService(
        walletService: _walletService,
        authApiService: _authService,
        authStorageService: AuthStorageService(),
        walletAuthService: WalletAuthService(
          walletService: _walletService,
          authApiService: _authService,
        ),
      );

      await sessionService.signOut();

      // ----------------------------------------------------------
      // Clear in-memory state
      // ----------------------------------------------------------

      _messagingProvider?.disconnectSocket();

      _accessToken = null;
      _refreshToken = null;
      _walletAddress = null;
      _isAuthenticated = false;
      _isNewUser = false;

      notifyListeners();

      return true;
    } catch (error) {
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isAuthenticating = false;
      _setLoading(false);
    }
  }

  // ============================================================
  // RESTORE SESSION
  // ============================================================
  //
  // Called when the application starts.
  //
  // This checks whether a refresh token exists and uses it
  // to restore the backend authentication session.
  //
  // ============================================================

  Future<bool> restoreSession() async {
    try {
      _setLoading(true);
      _errorMessage = null;

      final accessToken = await _authService.getStoredAccessToken();
      final refreshToken = await _authService.getStoredRefreshToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        _isAuthenticated = false;
        return false;
      }

      _accessToken = accessToken;
      _refreshToken = refreshToken;
      _isAuthenticated = true; // We have keys, assume authenticated until an API fails
      
      notifyListeners();
      return true;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // AUTHORIZATION TOKEN
  // ============================================================
  //
  // Used by authenticated API requests.
  //
  // Example:
  //
  // headers: {
  //   'Authorization': authController.authorizationToken!,
  // }
  //
  // ============================================================

  String? get authorizationToken {
    if (_accessToken == null || _accessToken!.isEmpty) {
      return null;
    }

    return 'Bearer $_accessToken';
  }

  // ============================================================
  // CHECK SESSION
  // ============================================================

  bool get hasValidSession {
    return _isAuthenticated && _accessToken != null && _accessToken!.isNotEmpty;
  }
}
