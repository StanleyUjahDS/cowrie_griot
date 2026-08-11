class ApiConfig {
  ApiConfig._();

  // ============================================================
  // BASE API
  // ============================================================

  static const String baseUrl = 'http://192.168.1.95:5001/api';
  // ============================================================
  // AUTHENTICATION
  // ============================================================

  static const String authNonce =
      '$baseUrl/auth/nonce';

  static const String authVerify =
      '$baseUrl/auth/verify';

  static const String authRefresh =
      '$baseUrl/auth/refresh';

  static const String authLogout =
      '$baseUrl/auth/logout';

  // ============================================================
  // PROFILE
  // ============================================================

  static const String profile =
      '$baseUrl/profile';

  static const String updateProfile =
      '$baseUrl/profile';
}