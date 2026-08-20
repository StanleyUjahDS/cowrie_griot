class ApiConfig {
  ApiConfig._();

  static const String baseUrl =
      'http://192.168.1.95:5001/api';

  static const String authNonce = '$baseUrl/auth/nonce';
  static const String authVerify = '$baseUrl/auth/verify';
  static const String authRefresh = '$baseUrl/auth/refresh';
  static const String authLogout = '$baseUrl/auth/logout';

  static const String usersMe = '$baseUrl/users/me';
  static const String usersUpdate = '$baseUrl/users/me';
  static const String usersSearch = '$baseUrl/users/search';
  static const String usernameAvailability =
      '$baseUrl/users/username/availability';

  static const String walletBase = '$baseUrl/crypto/wallets';
  static const String walletNetworks = '$walletBase/networks';
  static const String walletAssets = '$walletBase/assets';

  static String walletAssetsByNetwork(String network) =>
      '$walletBase/assets/$network';

  static String walletCustomToken(
    String network,
    String tokenAddress,
  ) =>
      '$walletBase/custom-token/$network/$tokenAddress';

  static String walletNativeBalance(
    String address,
    String network,
  ) =>
      '$walletBase/$address/balance/$network';

  static String walletNativeBalances(String address) =>
      '$walletBase/$address/balances';

  static String walletTokens(String address) =>
      '$walletBase/$address/tokens';

  // ============================================================
  // TRANSACTIONS
  // ============================================================

  static const String transactionBase =
      '$baseUrl/crypto/transactions';

  static const String prepareNativeTransaction =
      '$transactionBase/prepare-native';

  static const String broadcastTransaction =
      '$transactionBase/broadcast';

  static String transactionStatus(
    String transactionId,
    String network,
  ) =>
      Uri.parse(
        '$transactionBase/id/$transactionId/status',
      ).replace(
        queryParameters: {'network': network},
      ).toString();

  static String transactionById(String transactionId) =>
      '$transactionBase/id/$transactionId';

  static String transactionHistory({
    String? walletAccountId,
    String? network,
    int limit = 20,
    int offset = 0,
  }) {
    final query = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
    };

    if (walletAccountId != null && walletAccountId.isNotEmpty) {
      query['walletAccountId'] = walletAccountId;
    }

    if (network != null && network.isNotEmpty) {
      query['network'] = network;
    }

    return Uri.parse(
      '$transactionBase/history',
    ).replace(
      queryParameters: query,
    ).toString();
  }
}
