import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ============================================================
// AUTH STORAGE SERVICE
// ============================================================
//
// Stores authentication session credentials securely.
//
// Wallet credentials remain managed by WalletStorageService.
// This service is ONLY responsible for backend authentication.
//
// ============================================================

class AuthStorageService {
  static const FlutterSecureStorage _storage =
  FlutterSecureStorage();

  static const String _accessTokenKey =
      'auth_access_token';

  static const String _refreshTokenKey =
      'auth_refresh_token';

  // ============================================================
  // SAVE SESSION
  // ============================================================

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(
      key: _accessTokenKey,
      value: accessToken,
    );

    await _storage.write(
      key: _refreshTokenKey,
      value: refreshToken,
    );
  }

  // ============================================================
  // GET ACCESS TOKEN
  // ============================================================

  Future<String?> getAccessToken() async {
    return _storage.read(
      key: _accessTokenKey,
    );
  }

  // ============================================================
  // GET REFRESH TOKEN
  // ============================================================

  Future<String?> getRefreshToken() async {
    return _storage.read(
      key: _refreshTokenKey,
    );
  }

  // ============================================================
  // CLEAR SESSION
  // ============================================================

  Future<void> clearSession() async {
    await _storage.delete(
      key: _accessTokenKey,
    );

    await _storage.delete(
      key: _refreshTokenKey,
    );
  }

  // ============================================================
  // HAS SESSION
  // ============================================================

  Future<bool> hasSession() async {
    final refreshToken =
    await getRefreshToken();

    return refreshToken != null &&
        refreshToken.isNotEmpty;
  }
}