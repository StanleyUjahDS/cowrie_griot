import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';

class SwapApiService {
  static const String directRpcTransactionId = '__direct_swap_rpc__';

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
    required String modeOfSlippage,
    double? slippage,
    String? order,
  }) async {
    final body = <String, dynamic>{
      'fromChain': fromChain,
      'toChain': toChain,
      'fromToken': fromToken,
      'toToken': toToken,
      'fromAmount': fromAmount,
      'fromAddress': fromAddress,
      'slippageMode': modeOfSlippage,
    };

    if (slippage != null) {
      body['slippage'] = slippage;
    }

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

    final transactionRequest =
        data['transactionRequest'] ?? data['transaction_request'];
    if (transactionRequest is Map) {
      data['transaction'] = Map<String, dynamic>.from(transactionRequest);
    }

    final transactionId = data['transactionId']?.toString();
    if (transactionId == null || transactionId.isEmpty) {
      data['transactionId'] = directRpcTransactionId;
    }

    _normalizeFeeBreakdown(data, fromAmount: fromAmount, fromToken: fromToken);
    return data;
  }

  Future<int> getNonce({
    required String network,
    required String address,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.blockchainNonce(network, address),
    );

    final data = _asMap(_unwrap(response));
    final nonce = data['nonce'];
    if (nonce == null) {
      throw Exception('Backend did not return a transaction nonce');
    }
    return int.parse(nonce.toString());
  }

  Future<String> call({
    required String network,
    required String to,
    required String data,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.blockchainCall(network),
      body: {
        'to': to,
        'data': data,
      },
    );

    final result = _unwrap(response);
    return result?.toString() ?? '0x';
  }

  Future<Map<String, dynamic>> broadcastSwap({
    required String network,
    required String signedTransaction,
    String? transactionType,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.swapBroadcast,
      body: {
        'network': network,
        'signedTransaction': signedTransaction,
        'transactionType': transactionType,
      },
    );

    return _asMap(_unwrap(response));
  }

  void _normalizeFeeBreakdown(
    Map<String, dynamic> data, {
    required String fromAmount,
    required String fromToken,
  }) {
    final backendFee = _asMap(data['fee']);

    final bps = _toInt(backendFee['bps']) ?? 0;
    final percent = _toDouble(backendFee['percent']) ?? (bps / 100.0);
    final amount = backendFee['amount']?.toString();
    final calculatedAmount = backendFee['calculatedAmount']?.toString();
    final token = backendFee['token']?.toString() ?? fromToken;

    final griotFee = <String, dynamic>{
      'bps': bps,
      'percent': percent,
      'rate': _toDouble(backendFee['rate']),
      'amount': amount ?? calculatedAmount,
      'calculatedAmount': calculatedAmount,
      'token': token,
      'source': 'griot',
      'chargedFrom': backendFee['chargedFrom'] ?? 'sellAmount',
      'sellAmount': backendFee['sellAmount']?.toString() ?? fromAmount,
    };

    final providerFee = <String, dynamic>{
      'provider': data['provider']?.toString().toLowerCase(),
      'amount': null,
      'token': null,
      'reportedByProvider': false,
      'included': true,
    };

    data['griotFee'] = griotFee;
    data['providerFee'] = providerFee;
    data['feeBreakdown'] = <String, dynamic>{
      'griot': griotFee,
      'provider': providerFee,
    };

    data['fee'] = griotFee;
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
    String? swapType,
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
    return <String, dynamic>{};
  }
}
