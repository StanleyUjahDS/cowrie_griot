import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../models/wallet_models.dart';

class WalletApiService {
  final ApiClient _apiClient;

  WalletApiService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  Future<WalletAssetsResponse> getAssets({
    List<String>? networks,
  }) async {
    final url = networks == null || networks.isEmpty
        ? ApiConfig.walletAssets
        : '${ApiConfig.walletAssets}?networks=${networks.join(',')}';

    final response = await _apiClient.get(url);

    final data = response['data'] as Map<String, dynamic>;

    return WalletAssetsResponse.fromJson(data);
  }

  Future<List<WalletNetwork>> getNetworks() async {
    final response = await _apiClient.get(
      ApiConfig.walletNetworks,
    );

    final data = response['data'] as List<dynamic>;

    return data
        .map(
          (item) => WalletNetwork.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  void dispose() {
    _apiClient.dispose();
  }
}
