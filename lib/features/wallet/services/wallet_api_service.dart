import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../models/token_model.dart';
import 'package:flutter/foundation.dart';

class WalletApiService {
  final ApiClient _apiClient;

  WalletApiService({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  Future<List<Map<String, dynamic>>> getSupportedNetworks() async {
    final response = await _apiClient.get(
      ApiConfig.walletNetworks,
    );

    final data = _unwrap(response);

    if (data is Map<String, dynamic>) {
      final networks = data['networks'];

      if (networks is List) {
        return _asMapList(networks);
      }
    }

    return _asMapList(data);
  }

  Future<Map<String, dynamic>> getAssets({
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
      debugPrint('Wallet assets received: ${assets is List ? assets.length : 0}');
      debugPrint('Wallet assets truncated: ${data['truncated'] == true}');
    }

    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> getNfts({
    List<String>? networks,
  }) async {
    final url = _buildQueryUrl(
      ApiConfig.walletNfts,
      networks: networks,
    );

    final response = await _apiClient.get(url);
    final data = _unwrap(response);

    return data is Map<String, dynamic> ? data : {};
  }

  Future<List<Map<String, dynamic>>> getAssetsByNetwork(
    String network,
  ) async {
    final response = await _apiClient.get(
      ApiConfig.walletAssetsByNetwork(network),
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

  Future<Map<String, dynamic>> getCustomToken({
    required String network,
    required String tokenAddress,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.walletCustomToken(network, tokenAddress),
    );

    final data = _unwrap(response);

    return data is Map<String, dynamic>
        ? Map<String, dynamic>.from(data)
        : {};
  }

  Future<Map<String, dynamic>> getNativeBalance({
    required String network,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.walletNativeBalance(network),
    );

    final data = _unwrap(response);

    return data is Map<String, dynamic>
        ? Map<String, dynamic>.from(data)
        : {};
  }

  Future<List<Map<String, dynamic>>> getNativeBalances() async {
    final response = await _apiClient.get(
      ApiConfig.walletNativeBalances,
    );

    final data = _unwrap(response);

    if (data is Map<String, dynamic>) {
      final balances = data['balances'];

      if (balances is List) {
        return _asMapList(balances);
      }
    }

    return _asMapList(data);
  }

  Future<List<Map<String, dynamic>>> getTokens({
    List<String>? networks,
  }) async {
    final url = _buildQueryUrl(
      ApiConfig.walletTokens,
      networks: networks,
    );

    final response = await _apiClient.get(url);
    final data = _unwrap(response);

    if (data is Map<String, dynamic>) {
      final tokens = data['tokens'];

      if (tokens is List) {
        return _asMapList(tokens);
      }
    }

    return _asMapList(data);
  }

  Future<List<TokenModel>> searchAssets({
    required String query,
    String? network,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.walletAssetsSearch(query, network: network),
    );

    final data = _unwrap(response);

    if (data is Map<String, dynamic>) {
      final tokens = data['tokens'];

      if (tokens is List) {
        return tokens
            .map((json) => TokenModel.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      }
    }

    return [];
  }

  Future<List<TokenModel>> getPopularAssets({String? network}) async {
    final response = await _apiClient.get(
      ApiConfig.walletAssetsPopular(network: network),
    );
    final data = _unwrap(response);
    final tokens = data is Map<String, dynamic> ? data['tokens'] : data;
    if (tokens is List) {
      return tokens
          .whereType<Map>()
          .map((json) => TokenModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    }
    return [];
  }

  dynamic _unwrap(dynamic response) {
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      return response['data'];
    }

    return response;
  }

  List<Map<String, dynamic>> _asMapList(dynamic data) {
    if (data is! List) {
      return [];
    }

    return data
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  String _buildQueryUrl(
    String baseUrl, {
    List<String>? networks,
  }) {
    if (networks == null || networks.isEmpty) {
      return baseUrl;
    }

    final uri = Uri.parse(baseUrl);

    final queryParameters = Map<String, String>.from(
      uri.queryParameters,
    );

    // FIX: Backend expects 'network' (singular) for the comma-separated list
    queryParameters['network'] = networks.join(',');

    return uri
        .replace(
          queryParameters: queryParameters,
        )
        .toString();
  }
}
