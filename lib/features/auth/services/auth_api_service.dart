import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';

import '../models/authentication_response.dart';
import '../models/nonce_response.dart';
import 'auth_storage_service.dart';

// ============================================================
// AUTH API SERVICE
// ============================================================

class AuthApiService {
  final ApiClient _apiClient;
  final AuthStorageService _authStorageService;

  AuthApiService({
    required ApiClient apiClient,
    required AuthStorageService authStorageService,
  })  : _apiClient = apiClient,
        _authStorageService = authStorageService;

  // ============================================================
  // REQUEST NONCE
  // ============================================================

  Future<NonceResponse> requestNonce({
    required String walletAddress,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.authNonce,
      body: {
        'walletAddress': walletAddress,
      },
    );

    final data = (response.containsKey('data') ? response['data'] : response);

    return NonceResponse.fromJson(
      data as Map<String, dynamic>,
    );
  }

  // ============================================================
  // VERIFY WALLET
  // ============================================================

  Future<AuthenticationResponse> verifyWallet({
    required String walletAddress,
    required String nonce,
    required String signature,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.authVerify,
      body: {
        'walletAddress': walletAddress,
        'nonce': nonce,
        'signature': signature,
      },
    );

    final data = (response.containsKey('data') ? response['data'] : response);

    final authenticationResponse =
    AuthenticationResponse.fromJson(
      data as Map<String, dynamic>,
    );

    // ----------------------------------------------------------
    // SAVE BOTH TOKENS
    // ----------------------------------------------------------

    await _authStorageService.saveSession(
      accessToken:
      authenticationResponse.accessToken,
      refreshToken:
      authenticationResponse.refreshToken,
    );

    return authenticationResponse;
  }

  // ============================================================
  // REFRESH SESSION
  // ============================================================

  Future<AuthenticationResponse> refreshSession({
    required String refreshToken,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.authRefresh,
      body: {
        'refreshToken': refreshToken,
      },
    );

    final data = (response.containsKey('data') ? response['data'] : response);

    final authenticationResponse =
    AuthenticationResponse.fromJson(
      data as Map<String, dynamic>,
    );

    // ----------------------------------------------------------
    // SAVE ROTATED TOKENS
    // ----------------------------------------------------------

    await _authStorageService.saveSession(
      accessToken:
      authenticationResponse.accessToken,
      refreshToken:
      authenticationResponse.refreshToken,
    );

    return authenticationResponse;
  }

  // ============================================================
  // GET STORED ACCESS TOKEN
  // ============================================================

  Future<String?> getStoredAccessToken() {
    return _authStorageService.getAccessToken();
  }

  // ============================================================
  // GET STORED REFRESH TOKEN
  // ============================================================

  Future<String?> getStoredRefreshToken() {
    return _authStorageService.getRefreshToken();
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout({
    required String refreshToken,
  }) async {
    try {
      await _apiClient.post(
        ApiConfig.authLogout,
        body: {
          'refreshToken': refreshToken,
        },
      );
    } finally {
      // Always remove local session credentials,
      // even if the backend logout request fails.
      await _authStorageService.clearSession();
    }
  }

  // ============================================================
  // CLEAR LOCAL SESSION
  // ============================================================

  Future<void> clearSession() {
    return _authStorageService.clearSession();
  }
}