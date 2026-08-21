import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';

class SwapApiService {
  static const String directRpcTransactionId = '__direct_swap_rpc__';

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

    final transactionRequest = data['transactionRequest'] ??
        data['transaction_request'];
    if (transactionRequest is Map) {
      data['transaction'] = Map<String, dynamic>.from(transactionRequest);
    }

    final transactionId = data['transactionId']?.toString();
    if (transactionId == null || transactionId.isEmpty) {
      data['transactionId'] = directRpcTransactionId;
    }

    _normalizeFeeBreakdown(
      data,
      fromAmount: fromAmount,
      fromToken: fromToken,
    );

    return data;
  }

  /// The backend's legacy `fee` object combines Griot's configured percentage
  /// with the aggregator's reported fee amount. Those are different concepts.
  /// Normalize them so Flutter can display them independently.
  void _normalizeFeeBreakdown(
    Map<String, dynamic> data, {
    required String fromAmount,
    required String fromToken,
  }) {
    final backendFee = _asMap(data['fee']);
    final provider = data['provider']?.toString().toLowerCase();

    final bps = _toInt(backendFee['bps']) ?? 0;
    final percent = _toDouble(backendFee['percent']) ?? (bps / 100.0);
    final providerAmount = backendFee['amount']?.toString();
    final providerToken = backendFee['token']?.toString();

    final sellAmount = _toBigInt(fromAmount);
    final griotFeeAmount = sellAmount == null || bps <= 0
        ? null
        : (sellAmount * BigInt.from(bps)) ~/ BigInt.from(10000);

    final griotFee = <String, dynamic>{
      'bps': bps,
      'percent': percent,
      'amount': griotFeeAmount?.toString(),
      'token': fromToken,
      'source': 'griot',
      'chargedFrom': 'sellAmount',
    };

    final providerFee = <String, dynamic>{
      'provider': provider,
      'amount': providerAmount,
      'token': providerToken,
      'reportedByProvider': providerAmount != null && providerAmount.isNotEmpty,
    };

    data['griotFee'] = griotFee;
    data['providerFee'] = providerFee;
    data['feeBreakdown'] = <String, dynamic>{
      'griot': griotFee,
      'provider': providerFee,
    };

    // Backwards compatibility: existing quote UI reads `fee`. It now means
    // Griot's fee consistently instead of mixing Griot percent with provider
    // amount.
    data['fee'] = griotFee;
  }

  BigInt? _toBigInt(String value) {
    try {
      final normalized = value.trim();
      if (!RegExp(r'^\d+$').hasMatch(normalized)) return null;
      return BigInt.parse(normalized);
    } catch (_) {
      return null;
    }
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
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
