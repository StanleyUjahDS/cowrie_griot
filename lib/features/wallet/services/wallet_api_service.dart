import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';

class WalletApiService {
  final ApiClient _apiClient;

  WalletApiService({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  // ============================================================
  // SUPPORTED NETWORKS
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getSupportedNetworks() async {
    final response = await _apiClient.get(
      ApiConfig.walletNetworks,
    );

    return _asMapList(
      _unwrap(response),
    );
  }

  // ============================================================
  // WALLET ASSETS
  // ============================================================

  Future<List<Map<String, dynamic>>> getAssets({
    List<String>? networks,
  }) async {
    final url = _buildQueryUrl(
      ApiConfig.walletAssets,
      networks: networks,
    );

    final response = await _apiClient.get(url);

    final data = _unwrap(response);

    if (data is Map<String, dynamic>) {
      final assets = data['assets'];

      if (assets is List) {
        return _asMapList(assets);
      }
    }

    return _asMapList(data);
  }

  // ============================================================
  // ASSETS BY NETWORK
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getAssetsByNetwork(
    String network,
  ) async {
    final response = await _apiClient.get(
      ApiConfig.walletAssetsByNetwork(
        network,
      ),
    );

    final data = _unwrap(response);

    if (data is Map<String, dynamic>) {
      final assets = data['assets'];

      if (assets is List) {
        return _asMapList(assets);
      }
    }

    return _asMapList(data);
  }

  // ============================================================
  // CUSTOM TOKEN
  // ============================================================

  Future<Map<String, dynamic>>
      getCustomToken({
    required String network,
    required String tokenAddress,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.walletCustomToken(
        network,
        tokenAddress,
      ),
    );

    final data = _unwrap(response);

    if (data is Map<String, dynamic>) {
      return data;
    }

    return {};
  }

  // ============================================================
  // NATIVE BALANCE
  // ============================================================

  Future<Map<String, dynamic>>
      getNativeBalance({
    required String address,
    required String network,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.walletNativeBalance(
        address,
        network,
      ),
    );

    final data = _unwrap(response);

    if (data is Map<String, dynamic>) {
      return data;
    }

    return {};
  }

  // ============================================================
  // NATIVE BALANCES
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getNativeBalances({
    required String address,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.walletNativeBalances(
        address,
      ),
    );

    final data = _unwrap(response);

    // Backend may return:
    //
    // {
    //   balances: [...]
    // }
    //
    // or:
    //
    // [...]

    if (data is Map<String, dynamic>) {
      final balances =
          data['balances'];

      if (balances is List) {
        return _asMapList(balances);
      }
    }

    return _asMapList(data);
  }

  // ============================================================
  // TOKEN BALANCES
  // ============================================================

  Future<List<Map<String, dynamic>>>
      getTokens({
    required String address,
    List<String>? networks,
  }) async {
    final url = _buildQueryUrl(
      ApiConfig.walletTokens(address),
      networks: networks,
    );

    final response = await _apiClient.get(url);

    final data = _unwrap(response);

    // Backend may return:
    //
    // {
    //   tokens: [...]
    // }
    //
    // or:
    //
    // [...]

    if (data is Map<String, dynamic>) {
      final tokens =
          data['tokens'];

      if (tokens is List) {
        return _asMapList(tokens);
      }
    }

    return _asMapList(data);
  }

  // ============================================================
  // RESPONSE UNWRAPPER
  // ============================================================

  dynamic _unwrap(dynamic response) {
    dynamic data = response;

    if (data is Map<String, dynamic> &&
        data.containsKey('data')) {
      data = data['data'];
    }

    return data;
  }

  // ============================================================
  // MAP LIST
  // ============================================================

  List<Map<String, dynamic>> _asMapList(
    dynamic data,
  ) {
    if (data is! List) {
      return [];
    }

    return data
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(
            item,
          ),
        )
        .toList();
  }

  // ============================================================
  // QUERY BUILDER
  // ============================================================

  String _buildQueryUrl(
    String baseUrl, {
    List<String>? networks,
  }) {
    if (networks == null ||
        networks.isEmpty) {
      return baseUrl;
    }

    final uri = Uri.parse(baseUrl);

    final queryParameters =
        Map<String, String>.from(
      uri.queryParameters,
    );

    queryParameters['networks'] =
        networks.join(',');

    return uri
        .replace(
          queryParameters: queryParameters,
        )
        .toString();
  }
}
