class ApiConfig {
  ApiConfig._();

  // ============================================================
  // BASE API
  // ============================================================

  static const String baseUrl =
      'http://192.168.1.95:5001/api';

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
  // USERS
  // ============================================================

  static const String usersMe =
      '$baseUrl/users/me';

  static const String usersUpdate =
      '$baseUrl/users/me';

  static const String usersSearch =
      '$baseUrl/users/search';

  static const String usernameAvailability =
      '$baseUrl/users/username/availability';

  // ============================================================
  // WALLET
  // ============================================================

  static const String walletNetworks =
      '$baseUrl/crypto/wallets/networks';

  static const String walletAssets =
      '$baseUrl/crypto/wallets/assets';

  static String walletAssetsByNetwork(
    String network,
  ) => '$baseUrl/crypto/wallets/assets/$network';

  static String walletCustomToken(
    String network,
    String tokenAddress,
  ) => '$baseUrl/crypto/wallets/custom-token/$network/$tokenAddress';

  static const String walletNativeBalances =
      '$baseUrl/crypto/wallets/balances';

  static String walletNativeBalance(
    String network,
  ) => '$baseUrl/crypto/wallets/balance/$network';

  static const String walletTokens =
      '$baseUrl/crypto/wallets/tokens';
}
