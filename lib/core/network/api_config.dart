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

  static const String walletBase =
      '$baseUrl/crypto/wallets';

  // Supported networks
  static const String walletNetworks =
      '$walletBase/networks';

  // All supported assets
  static const String walletAssets =
      '$walletBase/assets';

  // Assets for one network
  static String walletAssetsByNetwork(
      String network,
      ) =>
      '$walletBase/assets/$network';

  // Custom token
  static String walletCustomToken(
      String network,
      String tokenAddress,
      ) =>
      '$walletBase/custom-token/$network/$tokenAddress';

  // Native balance for one network
  static String walletNativeBalance(
      String address,
      String network,
      ) =>
      '$walletBase/$address/balance/$network';

  // Native balances across supported networks
  static String walletNativeBalances(
      String address,
      ) =>
      '$walletBase/$address/balances';

  // Token balances
  static String walletTokens(
      String address,
      ) =>
      '$walletBase/$address/tokens';
}