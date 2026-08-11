import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';

import '../models/authentication_response.dart';
import '../models/nonce_response.dart';

class AuthApiService {
  final ApiClient _apiClient;

  static const FlutterSecureStorage _storage =
  FlutterSecureStorage();

  static const String _refreshTokenKey =
      'auth_refresh_token';

  AuthApiService({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  // ============================================================
  // REQUEST NONCE
  // ============================================================

  Future<NonceResponse> requestNonce({
    required String walletAddress,
  }) async {
    final data = await _apiClient.post(
      ApiConfig.authNonce,
      body: {
        'walletAddress': walletAddress,
      },
    );

    return NonceResponse.fromJson(
      data['data'] as Map<String, dynamic>,
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
    final data = await _apiClient.post(
      ApiConfig.authVerify,
      body: {
        'walletAddress': walletAddress,
        'nonce': nonce,
        'signature': signature,
      },
    );

    final authenticationResponse =
    AuthenticationResponse.fromJson(
      data['data'] as Map<String, dynamic>,
    );

    await saveRefreshToken(
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
    final data = await _apiClient.post(
      ApiConfig.authRefresh,
      body: {
        'refreshToken': refreshToken,
      },
    );

    final authenticationResponse =
    AuthenticationResponse.fromJson(
      data['data'] as Map<String, dynamic>,
    );

    await saveRefreshToken(
      authenticationResponse.refreshToken,
    );

    return authenticationResponse;
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout({
    required String refreshToken,
  }) async {
    await _apiClient.post(
      ApiConfig.authLogout,
      body: {
        'refreshToken': refreshToken,
      },
    );

    await deleteRefreshToken();
  }

  // ============================================================
  // SAVE REFRESH TOKEN
  // ============================================================

  Future<void> saveRefreshToken(
      String refreshToken,
      ) async {
    await _storage.write(
      key: _refreshTokenKey,
      value: refreshToken,
    );
  }

  // ============================================================
  // GET STORED REFRESH TOKEN
  // ============================================================

  Future<String?> getStoredRefreshToken() async {
    return _storage.read(
      key: _refreshTokenKey,
    );
  }

  // ============================================================
  // DELETE REFRESH TOKEN
  // ============================================================

  Future<void> deleteRefreshToken() async {
    await _storage.delete(
      key: _refreshTokenKey,
    );
  }
}