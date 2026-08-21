import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';

/// Direct EVM RPC operations proxied through the backend.
///
/// This service no longer communicates with public RPC nodes directly.
/// All requests are routed through the Griot backend to ensure consistency
/// with Alchemy/Ethers configurations and to maintain secure nonce tracking.
class WalletRpcService {
  final ApiClient _apiClient;

  WalletRpcService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<int> getPendingNonce({
    required String network,
    required String address,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.blockchainNonce(network, address),
    );

    final data = _unwrap(response);
    final nonce = data['nonce'];

    if (nonce == null) {
      throw Exception('Backend did not return a transaction nonce');
    }

    return nonce is int ? nonce : int.parse(nonce.toString());
  }

  Future<String> sendRawTransaction({
    required String network,
    required String signedTransaction,
  }) async {
    // We use the standard broadcast endpoint for all transactions
    // to ensure they are recorded in the user's history.
    final response = await _apiClient.post(
      ApiConfig.broadcastTransaction,
      body: {
        'network': network,
        'signedTransaction': signedTransaction,
        'transactionId': 'direct_${DateTime.now().millisecondsSinceEpoch}',
      },
    );

    final data = _unwrap(response);
    final broadcast = data['broadcast'];
    final hash = broadcast is Map ? broadcast['hash']?.toString() : null;

    if (hash == null || !RegExp(r'^0x[a-fA-F0-9]{64}$').hasMatch(hash)) {
      throw Exception('Backend returned an invalid transaction hash');
    }

    return hash;
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
        'blockTag': 'latest',
      },
    );

    final result = _unwrap(response);
    return result?.toString() ?? '0x';
  }

  Future<Map<String, dynamic>?> getTransactionReceipt({
    required String network,
    required String hash,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.blockchainReceipt(network, hash),
    );

    final result = _unwrap(response);
    return result is Map ? Map<String, dynamic>.from(result) : null;
  }

  dynamic _unwrap(dynamic response) {
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      return response['data'];
    }
    return response;
  }

  void dispose() {
    // ApiClient is typically managed by a provider and disposed elsewhere.
  }
}
