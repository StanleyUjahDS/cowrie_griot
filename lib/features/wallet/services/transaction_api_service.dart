import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import 'wallet_rpc_service.dart';
import 'wallet_storage_service.dart';

class TransactionApiService {
  static const String _directSwapTransactionId = '__direct_swap_rpc__';

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
    // SwapScreen historically used prepareNativeSend(amount: '0') only to
    // obtain a nonce. The backend correctly rejects zero-value sends, so do
    // not create a fake pending transaction just to obtain a nonce.
    if (amount.trim() == '0') {
      final storage = WalletStorageService();
      final address = await storage.getAddress();
      if (address == null || address.isEmpty) {
        throw Exception('Wallet address not found');
      }

      final rpc = WalletRpcService();
      try {
        final nonce = await rpc.getPendingNonce(
          network: network,
          address: address,
        );
        return {
          'nonce': nonce,
          'network': network,
        };
      } finally {
        rpc.dispose();
      }
    }

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

  Future<Map<String, dynamic>> prepareTokenSend({
    String? walletAccountId,
    required String network,
    required String tokenAddress,
    required String toAddress,
    required String amount,
  }) async {
    final body = <String, dynamic>{
      'network': network,
      'tokenAddress': tokenAddress,
      'toAddress': toAddress,
      'amount': amount,
    };

    if (walletAccountId != null && walletAccountId.isNotEmpty) {
      body['walletAccountId'] = walletAccountId;
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
    final response = await _apiClient.post(
      ApiConfig.estimateTransaction,
      body: {
        'network': network,
        'transaction': transaction,
      },
    );

    return _asMap(_unwrap(response));
  }

  Future<Map<String, dynamic>> broadcastTransaction({
    required String network,
    required String transactionId,
    required String signedTransaction,
  }) async {
    // Swap provider transactions are not backend-created transaction drafts.
    // They must be broadcast directly by the non-custodial wallet. The swap
    // quote service uses this internal sentinel when no backend transactionId
    // exists, while normal sends continue through the backend broadcast API.
    if (transactionId == _directSwapTransactionId) {
      final rpc = WalletRpcService();
      try {
        final hash = await rpc.sendRawTransaction(
          network: network,
          signedTransaction: signedTransaction,
        );
        return {
          'broadcast': {
            'hash': hash,
          },
          'transaction': null,
        };
      } finally {
        rpc.dispose();
      }
    }

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
    return data is Map<String, dynamic>
        ? Map<String, dynamic>.from(data)
        : {};
  }
}
