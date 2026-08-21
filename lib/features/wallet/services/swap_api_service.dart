import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';

class SwapApiService {
  final ApiClient _apiClient;

  SwapApiService({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  Future<Map<String, dynamic>> getQuote({
    required String fromChain,
    required String toChain,
    required String fromToken,
    required String toToken,
    required String fromAmount,
    required String fromAddress,
    String? toAddress,
    double slippage = 0.005,
    String? order,
  }) async {
    final body = <String, dynamic>{
      'fromChain': fromChain,
      'toChain': toChain,
      'fromToken': fromToken,
      'toToken': toToken,
      'fromAmount': fromAmount,
      'fromAddress': fromAddress,
      'slippageMode': 'custom',
      'slippage': slippage,
    };

    if (toAddress != null && toAddress.isNotEmpty) {
      body['toAddress'] = toAddress;
    }

    if (order != null && order.isNotEmpty) {
      body['order'] = order;
    }

    final response = await _apiClient.post(
      ApiConfig.swapQuote,
      body: body,
    );

    final data = _asMap(_unwrap(response));

    // The backend exposes the provider transaction as `transactionRequest`.
    // Keep the existing screen contract (`transaction`) while preserving the
    // complete transaction request, including calldata.
    final transactionRequest = data['transactionRequest'];
    if (transactionRequest is Map) {
      data['transaction'] = Map<String, dynamic>.from(transactionRequest);
    }

    return data;
  }

  Future<Map<String, dynamic>> getStatus({
    required String transactionId,
    String? provider,
    String? fromChain,
    String? toChain,
    String? bridge,
    String? quoteId,
    String? fromAddress,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.swapStatus(
        transactionId: transactionId,
        provider: provider,
        fromChain: fromChain,
        toChain: toChain,
        bridge: bridge,
        quoteId: quoteId,
        fromAddress: fromAddress,
      ),
    );

    return _asMap(_unwrap(response));
  }

  Future<Map<String, dynamic>> getHealth() async {
    final response = await _apiClient.get(ApiConfig.swapHealth);
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
