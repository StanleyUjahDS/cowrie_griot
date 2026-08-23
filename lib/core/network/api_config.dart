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

  static String usersSearch(String query) => Uri.parse('$baseUrl/users/search')
      .replace(queryParameters: {'q': query}).toString();

  static String usernameAvailability(String username) =>
      Uri.parse('$baseUrl/users/username/availability')
          .replace(queryParameters: {'username': username}).toString();

  static const String walletBase = '$baseUrl/crypto/wallets';
  static const String walletNetworks = '$walletBase/networks';
  static const String walletAssets = '$walletBase/assets';

  static const String cryptoAssetsBase = '$baseUrl/crypto/assets';

  static String walletAssetsSearch(String query, {String? network}) {
    final params = {'q': query};
    if (network != null && network.isNotEmpty) {
      params['network'] = network;
    }
    return Uri.parse('$cryptoAssetsBase/search')
        .replace(queryParameters: params)
        .toString();
  }

  static String walletAssetsPopular({String? network}) {
    final params = <String, String>{};
    if (network != null && network.isNotEmpty) params['network'] = network;
    return Uri.parse('$cryptoAssetsBase/popular')
        .replace(queryParameters: params)
        .toString();
  }

  static String walletAssetsByNetwork(String network) =>
      '$walletBase/assets/$network';

  static String walletCustomToken(
    String network,
    String tokenAddress,
  ) =>
      '$walletBase/custom-token/$network/$tokenAddress';

  static String walletNativeBalance(String network) =>
      '$walletBase/balance/$network';

  static const String walletNativeBalances = '$walletBase/balances';

  static const String walletTokens = '$walletBase/tokens';

  static const String transactionBase =
      '$baseUrl/crypto/transactions';

  static const String prepareNativeTransaction =
      '$transactionBase/prepare-native';

  static const String prepareTokenTransaction =
      '$transactionBase/prepare-token';

  static const String estimateTransaction =
      '$transactionBase/estimate';

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

  static const String swapBase =
      '$baseUrl/crypto/swap';

  static const String swapQuote =
      '$swapBase/quote';

  static const String swapBroadcast =
      '$swapBase/broadcast';

  static String swapStatus({
    required String transactionId,
    String? provider,
    String? fromChain,
    String? toChain,
    String? bridge,
    String? quoteId,
    String? fromAddress,
    String? swapType,
  }) {
    final query = <String, String>{
      'transactionId': transactionId,
    };

    if (provider != null && provider.isNotEmpty) {
      query['provider'] = provider;
    }

    if (fromChain != null && fromChain.isNotEmpty) {
      query['fromChain'] = fromChain;
    }

    if (toChain != null && toChain.isNotEmpty) {
      query['toChain'] = toChain;
    }

    if (bridge != null && bridge.isNotEmpty) {
      query['bridge'] = bridge;
    }

    if (quoteId != null && quoteId.isNotEmpty) {
      query['quoteId'] = quoteId;
    }

    if (fromAddress != null && fromAddress.isNotEmpty) {
      query['fromAddress'] = fromAddress;
    }

    if (swapType != null && swapType.isNotEmpty) {
      query['swapType'] = swapType;
    }

    return Uri.parse(
      '$swapBase/status',
    ).replace(
      queryParameters: query,
    ).toString();
  }

  static String swapReceipt({
    required String network,
    required String hash,
  }) =>
      Uri.parse(
        '$swapBase/receipt',
      ).replace(
        queryParameters: {
          'network': network,
          'hash': hash,
        },
      ).toString();

  static const String swapHealth =
      '$swapBase/health';

  static const String miningBase =
      '$baseUrl/crypto/mining';

  static const String miningStatus =
      '$miningBase/status';

  static const String miningStart =
      '$miningBase/start';

  static String miningHistory({
    int limit = 20,
    int offset = 0,
  }) =>
      Uri.parse(
        '$miningBase/history',
      ).replace(
        queryParameters: {
          'limit': '$limit',
          'offset': '$offset',
        },
      ).toString();

  static const String blockchainBase = '$baseUrl/crypto/blockchain';

  static String blockchainNonce(String network, String address) =>
      '$blockchainBase/nonce/$network/$address';

  static String blockchainCall(String network) =>
      '$blockchainBase/call/$network';

  static String blockchainReceipt(String network, String hash) =>
      '$blockchainBase/receipt/$network/$hash';

  static const String referralBase =
      '$baseUrl/crypto/referrals';

  static const String referralStats =
      '$referralBase/stats';

  static String referralList({
    int limit = 20,
    int offset = 0,
  }) =>
      Uri.parse(
        '$referralBase/list',
      ).replace(
        queryParameters: {
          'limit': '$limit',
          'offset': '$offset',
        },
      ).toString();
}
