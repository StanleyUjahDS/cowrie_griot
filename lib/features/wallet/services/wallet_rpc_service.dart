import 'dart:convert';

import 'package:http/http.dart' as http;

/// Direct EVM RPC used only for operations that are intentionally broadcast
/// by the non-custodial wallet itself (for example a swap provider's
/// transactionRequest).
///
/// The backend remains responsible for quotes, validation and status lookup;
/// this service never sends a user's private key to the backend.
class WalletRpcService {
  final http.Client _client;

  WalletRpcService({http.Client? client}) : _client = client ?? http.Client();

  static const Map<String, String> _rpcUrls = {
    'ethereum': 'https://ethereum-rpc.publicnode.com',
    'base': 'https://base-rpc.publicnode.com',
    'polygon': 'https://polygon-bor-rpc.publicnode.com',
    'arbitrum': 'https://arbitrum-one-rpc.publicnode.com',
    'optimism': 'https://optimism-rpc.publicnode.com',
    'bsc': 'https://bsc-rpc.publicnode.com',
  };

  String _rpcUrl(String network) {
    final url = _rpcUrls[network.trim().toLowerCase()];
    if (url == null) {
      throw Exception('No EVM RPC configured for network: $network');
    }
    return url;
  }

  Future<dynamic> _request(
    String network,
    String method,
    List<dynamic> params,
  ) async {
    final response = await _client.post(
      Uri.parse(_rpcUrl(network)),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': DateTime.now().microsecondsSinceEpoch,
        'method': method,
        'params': params,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('RPC request failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Invalid RPC response');
    }

    final error = decoded['error'];
    if (error != null) {
      final message = error is Map
          ? error['message']?.toString() ?? 'RPC request failed'
          : error.toString();
      throw Exception(message);
    }

    return decoded['result'];
  }

  Future<int> getPendingNonce({
    required String network,
    required String address,
  }) async {
    final result = await _request(
      network,
      'eth_getTransactionCount',
      [address, 'pending'],
    );

    if (result == null) {
      throw Exception('RPC did not return a transaction nonce');
    }

    return int.parse(result.toString().replaceFirst('0x', ''), radix: 16);
  }

  Future<String> sendRawTransaction({
    required String network,
    required String signedTransaction,
  }) async {
    final result = await _request(
      network,
      'eth_sendRawTransaction',
      [signedTransaction],
    );

    final hash = result?.toString() ?? '';
    if (!RegExp(r'^0x[a-fA-F0-9]{64}$').hasMatch(hash)) {
      throw Exception('RPC returned an invalid transaction hash');
    }

    return hash;
  }

  void dispose() {
    _client.close();
  }
}
