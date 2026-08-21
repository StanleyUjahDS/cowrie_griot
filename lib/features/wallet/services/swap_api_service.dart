import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';

class SwapApiService {
  final ApiClient _apiClient;

  SwapApiService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<Map<String, dynamic>> getQuote({
    required String fromChain,
    required String toChain,
    required String fromToken,
    required String toToken,
    required String fromAmount,
    required String fromAddress,
    String? toAddress,
    String slippageMode = 'auto',
    double? slippage,
  }) async {
    final body = <String, dynamic>{
      'fromChain': fromChain,
      'toChain': toChain,
      'fromToken': fromToken,
      'toToken': toToken,
      'fromAmount': fromAmount,
      'fromAddress': fromAddress,
      'slippageMode': slippageMode,
    };

    // The backend requires `slippage` only for custom mode.
    if (slippageMode == 'custom') {
      body['slippage'] = slippage ?? 0.005;
    }

    // Backend validation requires toAddress for cross-chain swaps.
    if (toAddress != null && toAddress.isNotEmpty) {
      body['toAddress'] = toAddress;
    }

    final response = await _apiClient.post(
      ApiConfig.swapQuote,
      body: body,
    );

    return _asMap(_unwrap(response));
  }

  Future<Map<String, dynamic>> broadcastSwap({
    required String network,
    required String signedTransaction,
    required String transactionType,
  }) async {
    final response = await _apiClient.post(
      '${ApiConfig.swapBase}/broadcast',
      body: {
        'network': network,
        'signedTransaction': signedTransaction,
        'transactionType': transactionType,
      },
    );

    return _asMap(_unwrap(response));
  }

  Future<Map<String, dynamic>> getStatus({
    required String transactionId,
    required String provider,
    required String fromChain,
    required String toChain,
    String? bridge,
    String? quoteId,
    String? fromAddress,
    required String swapType,
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
        swapType: swapType,
      ),
    );

    return _asMap(_unwrap(response));
  }

  Future<Map<String, dynamic>> getReceipt({
    required String network,
    required String hash,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.swapReceipt(
        network: network,
        hash: hash,
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
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw const FormatException('Invalid swap API response');
  }
}
