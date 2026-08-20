import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';

class TransactionApiService {
  final ApiClient _apiClient;

  TransactionApiService({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  Future<Map<String, dynamic>> prepareNativeSend({
    String? walletAccountId,
    required String network,
    required String toAddress,
    required String amount,
  }) async {
    final body = <String, dynamic>{
      'network': network,
      'toAddress': toAddress,
      'amount': amount,
    };

    if (walletAccountId != null && walletAccountId.isNotEmpty) {
      body['walletAccountId'] = walletAccountId;
    }

    final response = await _apiClient.post(
      ApiConfig.prepareNativeTransaction,
      body: body,
    );

    return _asMap(_unwrap(response));
  }

  Future<Map<String, dynamic>> broadcastTransaction({
    required String network,
    required String transactionId,
    required String signedTransaction,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.broadcastTransaction,
      body: {
        'network': network,
        'transactionId': transactionId,
        'signedTransaction': signedTransaction,
      },
    );

    return _asMap(_unwrap(response));
  }

  Future<Map<String, dynamic>> getTransactionStatus({
    required String transactionId,
    required String network,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.transactionStatus(
        transactionId,
        network,
      ),
    );

    return _asMap(_unwrap(response));
  }

  Future<Map<String, dynamic>> getTransaction({
    required String transactionId,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.transactionById(transactionId),
    );

    return _asMap(_unwrap(response));
  }

  Future<Map<String, dynamic>> getHistory({
    String? walletAccountId,
    String? network,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.transactionHistory(
        walletAccountId: walletAccountId,
        network: network,
        limit: limit,
        offset: offset,
      ),
    );

    return _asMap(_unwrap(response));
  }

  dynamic _unwrap(dynamic response) {
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      return response['data'];
    }

    return response;
  }

  Map<String, dynamic> _asMap(dynamic data) {
    return data is Map<String, dynamic>
        ? Map<String, dynamic>.from(data)
        : {};
  }
}
