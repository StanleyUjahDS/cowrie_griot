import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';

class TipApiService {
  final ApiClient _apiClient;

  TipApiService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<Map<String, dynamic>> getTipConfig() async {
    final response = await _apiClient.get(ApiConfig.tipConfig);
    return _asMap(_unwrap(response));
  }

  Future<Map<String, dynamic>> prepareNativeTip({
    required int chainId,
    required String recipient,
    required String amount,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.tipPrepare,
      body: {
        'chainId': chainId,
        'mode': 'native',
        'recipient': recipient,
        'amount': amount,
      },
    );
    return _asMap(_unwrap(response));
  }

  Future<Map<String, dynamic>> prepareTokenTip({
    required int chainId,
    required String token,
    required String recipient,
    required String amount,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.tipPrepare,
      body: {
        'chainId': chainId,
        'mode': 'token',
        'token': token,
        'recipient': recipient,
        'amount': amount,
      },
    );
    return _asMap(_unwrap(response));
  }

  Future<Map<String, dynamic>> prepareBatchNativeTip({
    required int chainId,
    required List<String> recipients,
    required List<String> amounts,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.tipPrepare,
      body: {
        'chainId': chainId,
        'mode': 'native',
        'batch': true,
        'recipients': recipients,
        'amounts': amounts,
      },
    );
    return _asMap(_unwrap(response));
  }

  Future<Map<String, dynamic>> prepareBatchTokenTip({
    required int chainId,
    required String token,
    required List<String> recipients,
    required List<String> amounts,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.tipPrepare,
      body: {
        'chainId': chainId,
        'mode': 'token',
        'token': token,
        'batch': true,
        'recipients': recipients,
        'amounts': amounts,
      },
    );
    return _asMap(_unwrap(response));
  }

  dynamic _unwrap(dynamic response) {
    if (response is Map<String, dynamic> && response['success'] == true) {
      return response['data'];
    }
    throw Exception(response['message'] ?? 'Tip preparation failed');
  }

  Map<String, dynamic> _asMap(dynamic data) {
    return data is Map<String, dynamic> ? Map<String, dynamic>.from(data) : {};
  }
}
