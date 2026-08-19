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

  Future<List<dynamic>> getSupportedNetworks() async {
    final response = await _apiClient.get(
      ApiConfig.walletNetworks,
    );

    return _extractList(response);
  }

  // ============================================================
  // WALLET ASSETS
  // ============================================================

  Future<List<dynamic>> getAssets({
    List<String>? networks,
  }) async {
    final url = _buildQueryUrl(
      ApiConfig.walletAssets,
      networks: networks,
    );

    final response = await _apiClient.get(url);

    return _extractList(response);
  }

  // ============================================================
  // ASSETS BY NETWORK
  // ============================================================

  Future<List<dynamic>> getAssetsByNetwork(
      String network,
      ) async {
    final response = await _apiClient.get(
      ApiConfig.walletAssetsByNetwork(network),
    );

    return _extractList(response);
  }

  // ============================================================
  // CUSTOM TOKEN
  // ============================================================

  Future<dynamic> getCustomToken({
    required String network,
    required String tokenAddress,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.walletCustomToken(
        network,
        tokenAddress,
      ),
    );

    return _extractData(response);
  }

  // ============================================================
  // NATIVE BALANCE
  // ============================================================

  Future<dynamic> getNativeBalance({
    required String address,
    required String network,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.walletNativeBalance(
        address,
        network,
      ),
    );

    return _extractData(response);
  }

  // ============================================================
  // NATIVE BALANCES
  // ============================================================

  Future<List<dynamic>> getNativeBalances({
    required String address,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.walletNativeBalances(address),
    );

    return _extractList(response);
  }

  // ============================================================
  // TOKEN BALANCES
  // ============================================================

  Future<List<dynamic>> getTokens({
    required String address,
    List<String>? networks,
  }) async {
    final url = _buildQueryUrl(
      ApiConfig.walletTokens(address),
      networks: networks,
    );

    final response = await _apiClient.get(url);

    return _extractList(response);
  }

  // ============================================================
  // EXTRACT DATA
  // ============================================================

  dynamic _extractData(dynamic response) {
    if (response is Map<String, dynamic> &&
        response.containsKey('data')) {
      return response['data'];
    }

    return response;
  }

  // ============================================================
  // EXTRACT LIST
  // ============================================================

  List<dynamic> _extractList(dynamic response) {
    final data = _extractData(response);

    if (data == null) {
      return [];
    }

    if (data is List) {
      return data;
    }

    return [data];
  }

  // ============================================================
  // BUILD QUERY URL
  // ============================================================

  String _buildQueryUrl(
      String baseUrl, {
        List<String>? networks,
      }) {
    if (networks == null || networks.isEmpty) {
      return baseUrl;
    }

    final encodedNetworks = Uri.encodeQueryComponent(
      networks.join(','),
    );

    return '$baseUrl?networks=$encodedNetworks';
  }
}