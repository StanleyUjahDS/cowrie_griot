import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../utils/chain_assets.dart';

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
    final formattedTo = toAddress.startsWith('0x') ? toAddress : '0x$toAddress';
    if (!ChainAssets.isValidEvmAddress(formattedTo)) {
      throw Exception('Invalid recipient address: $formattedTo');
    }

    final body = <String, dynamic>{
      'network': network,
      'toAddress': formattedTo,
      'to_address': formattedTo,
      'amount': amount,
    };

    if (walletAccountId != null && walletAccountId.isNotEmpty) {
      body['walletAccountId'] = walletAccountId;
      body['wallet_account_id'] = walletAccountId;
    }

    final response = await _apiClient.post(
      ApiConfig.prepareNativeTransaction,
      body: body,
    );

    return _asMap(_unwrap(response));
  }

  Future<Map<String, dynamic>> prepareTokenSend({
    String? walletAccountId,
    required String network,
    required String tokenAddress,
    required String toAddress,
    required String amount,
  }) async {
    final formattedTo = toAddress.startsWith('0x') ? toAddress : '0x$toAddress';
    final formattedToken = tokenAddress.startsWith('0x') ? tokenAddress : '0x$tokenAddress';

    if (!ChainAssets.isValidEvmAddress(formattedTo)) {
      throw Exception('Invalid recipient address: $formattedTo');
    }
    if (!ChainAssets.isValidEvmAddress(formattedToken)) {
      throw Exception('Invalid token address: $formattedToken');
    }

    final body = <String, dynamic>{
      'network': network,
      'tokenAddress': formattedToken,
      'token_address': formattedToken,
      'toAddress': formattedTo,
      'to_address': formattedTo,
      'amount': amount,
    };

    if (walletAccountId != null && walletAccountId.isNotEmpty) {
      body['walletAccountId'] = walletAccountId;
      body['wallet_account_id'] = walletAccountId;
    }

    final response = await _apiClient.post(
      ApiConfig.prepareTokenTransaction,
      body: body,
    );

    return _asMap(_unwrap(response));
  }

  Future<Map<String, dynamic>> estimateTransaction({
    required String network,
    required Map<String, dynamic> transaction,
  }) async {
    final tx = Map<String, dynamic>.from(transaction);

    // Normalize and validate addresses
    if (tx['from'] != null) {
      final from = tx['from'].toString();
      tx['from'] = from.startsWith('0x') ? from : '0x$from';
      if (!ChainAssets.isValidEvmAddress(tx['from'])) {
        throw Exception('Invalid sender address: ${tx['from']}');
      }
    }

    if (tx['to'] != null) {
      final to = tx['to'].toString();
      tx['to'] = to.startsWith('0x') ? to : '0x$to';
      if (!ChainAssets.isValidEvmAddress(tx['to'])) {
        throw Exception('Invalid recipient address: ${tx['to']}');
      }
    }

    final response = await _apiClient.post(
      ApiConfig.estimateTransaction,
      body: {
        'network': network,
        'transaction': tx,
      },
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
        'transaction_id': transactionId,
        'signedTransaction': signedTransaction,
        'signed_transaction': signedTransaction,
      },
    );

    return _asMap(_unwrap(response));
  }

  Future<Map<String, dynamic>> broadcastRawTransaction({
    required String network,
    required String signedTransaction,
    String transactionType = 'send',
  }) async {
    final response = await _apiClient.post(
      ApiConfig.swapBroadcast,
      body: {
        'network': network,
        'signedTransaction': signedTransaction,
        'signed_transaction': signedTransaction,
        'transactionType': transactionType,
        'transaction_type': transactionType,
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

  Future<dynamic> getHistory({
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

    return _unwrap(response);
  }

  dynamic _unwrap(dynamic response) {
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      return response['data'];
    }

    return response;
  }

  Map<String, dynamic> _asMap(dynamic data) {
    return data is Map<String, dynamic> ? Map<String, dynamic>.from(data) : {};
  }
}
