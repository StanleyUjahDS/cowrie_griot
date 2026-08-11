import 'package:flutter/foundation.dart';

import 'services/auth_api_service.dart';
import '../wallet/services/wallet_service.dart';


class AuthController extends ChangeNotifier {
  final AuthApiService _authService;
  final WalletService _walletService;

  AuthController({
    required AuthApiService authService,
    required WalletService walletService,
  })  : _authService = authService,
        _walletService = walletService;

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = false;

  bool get isLoading => _isLoading;

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
    try {
      _setLoading(true);

      _errorMessage = null;

      // ----------------------------------------------------------
      // Get wallet address
      // ----------------------------------------------------------

      final address = await _walletService.getAddress();

      if (address == null || address.isEmpty) {
        throw Exception(
          'No wallet found on this device.',
        );
      }

      _walletAddress = address;

      // ----------------------------------------------------------
      // Request authentication nonce
      // ----------------------------------------------------------

      final nonceResponse =
      await _authService.requestNonce(
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

      final signature = await _walletService.signMessage(
        message,
      );

      if (signature == null || signature.isEmpty) {
        throw Exception(
          'Wallet signature was not created.',
        );
      }

      // ----------------------------------------------------------
      // Verify wallet signature
      // ----------------------------------------------------------

      final authenticationResponse =
      await _authService.verifyWallet(
        walletAddress: address,
        nonce: nonce,
        signature: signature,
      );

      // ----------------------------------------------------------
      // Store authentication state
      // ----------------------------------------------------------

      _accessToken =
          authenticationResponse.accessToken;

      _refreshToken =
          authenticationResponse.refreshToken;

      _walletAddress =
          authenticationResponse.user.walletAddress;

      _isNewUser =
          authenticationResponse.isNewUser;

      _isAuthenticated = true;

      notifyListeners();

      return true;
    } catch (error) {
      _isAuthenticated = false;

      _errorMessage = error
          .toString()
          .replaceFirst(
        'Exception: ',
        '',
      );

      notifyListeners();

      return false;
    } finally {
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
      if (_refreshToken == null ||
          _refreshToken!.isEmpty) {
        return false;
      }

      final response =
      await _authService.refreshSession(
        refreshToken: _refreshToken!,
      );

      // ----------------------------------------------------------
      // Update tokens
      // ----------------------------------------------------------

      _accessToken =
          response.accessToken;

      _refreshToken =
          response.refreshToken;

      _walletAddress =
          response.user.walletAddress;

      _isAuthenticated = true;

      notifyListeners();

      return true;
    } catch (error) {
      _isAuthenticated = false;

      _accessToken = null;

      _refreshToken = null;

      _errorMessage = error
          .toString()
          .replaceFirst(
        'Exception: ',
        '',
      );

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
      // Revoke backend session
      // ----------------------------------------------------------

      if (_refreshToken != null &&
          _refreshToken!.isNotEmpty) {
        await _authService.logout(
          refreshToken: _refreshToken!,
        );
      }

      // ----------------------------------------------------------
      // Clear authentication state
      // ----------------------------------------------------------

      _accessToken = null;

      _refreshToken = null;

      _isAuthenticated = false;

      _isNewUser = false;

      notifyListeners();

      return true;
    } catch (error) {
      _errorMessage = error
          .toString()
          .replaceFirst(
        'Exception: ',
        '',
      );

      notifyListeners();

      return false;
    } finally {
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

      // ----------------------------------------------------------
      // Get stored refresh token
      // ----------------------------------------------------------

      final storedRefreshToken =
      await _authService.getStoredRefreshToken();

      if (storedRefreshToken == null ||
          storedRefreshToken.isEmpty) {
        _isAuthenticated = false;

        return false;
      }

      // ----------------------------------------------------------
      // Set refresh token
      // ----------------------------------------------------------

      _refreshToken =
          storedRefreshToken;

      // ----------------------------------------------------------
      // Refresh session
      // ----------------------------------------------------------

      final success =
      await refreshSession();

      return success;
    } catch (error) {
      _isAuthenticated = false;

      _accessToken = null;

      _refreshToken = null;

      _errorMessage = error
          .toString()
          .replaceFirst(
        'Exception: ',
        '',
      );

      notifyListeners();

      return false;
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
    if (_accessToken == null ||
        _accessToken!.isEmpty) {
      return null;
    }

    return 'Bearer $_accessToken';
  }

  // ============================================================
  // CHECK SESSION
  // ============================================================

  bool get hasValidSession {
    return _isAuthenticated &&
        _accessToken != null &&
        _accessToken!.isNotEmpty;
  }
}