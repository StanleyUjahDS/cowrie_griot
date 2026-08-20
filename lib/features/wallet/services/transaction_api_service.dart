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

    final data = _unwrap(response);
    return data is Map<String, dynamic>
        ? Map<String, dynamic>.from(data)
        : {};
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

    final data = _unwrap(response);
    return data is Map<String, dynamic>
        ? Map<String, dynamic>.from(data)
        : {};
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

    final data = _unwrap(response);
    return data is Map<String, dynamic>
        ? Map<String, dynamic>.from(data)
        : {};
  }

  Future<Map<String, dynamic>> getTransaction({
    required String transactionId,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.transactionById(transactionId),
    );

    final data = _unwrap(response);
    return data is Map<String, dynamic>
        ? Map<String, dynamic>.from(data)
        : {};
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

    final data = _unwrap(response);
    return data is Map<String, dynamic>
        ? Map<String, dynamic>.from(data)
        : {};
  }

  // ============================================================
  // SWAP
  // ============================================================

  Future<Map<String, dynamic>> getSwapQuote({
    required String fromNetwork,
    required String toNetwork,
    required String fromTokenAddress,
    required String toTokenAddress,
    required String amount,
  }) async {
    final response = await _apiClient.get(
      Uri.parse(ApiConfig.swapQuote).replace(queryParameters: {
        'fromNetwork': fromNetwork,
        'toNetwork': toNetwork,
        'fromTokenAddress': fromTokenAddress,
        'toTokenAddress': toTokenAddress,
        'amount': amount,
      }).toString(),
    );

    final data = _unwrap(response);
    return data is Map<String, dynamic> ? Map<String, dynamic>.from(data) : {};
  }

  Future<Map<String, dynamic>> prepareSwap({
    required String fromNetwork,
    required String toNetwork,
    required String fromTokenAddress,
    required String toTokenAddress,
    required String amount,
    required String slippage,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.swapPrepare,
      body: {
        'fromNetwork': fromNetwork,
        'toNetwork': toNetwork,
        'fromTokenAddress': fromTokenAddress,
        'toTokenAddress': toTokenAddress,
        'amount': amount,
        'slippage': slippage,
      },
    );

    final data = _unwrap(response);
    return data is Map<String, dynamic> ? Map<String, dynamic>.from(data) : {};
  }

  dynamic _unwrap(dynamic response) {
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      return response['data'];
    }

    return response;
  }
}
