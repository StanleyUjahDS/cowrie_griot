import 'package:flutter/foundation.dart';

class TransactionLogger {
  TransactionLogger._();

  static void log({
    required String endpoint,
    required String network,
    dynamic chainId,
    String? transactionHash,
    String? backendError,
    String? providerError,
  }) {
    debugPrint('--- TRANSACTION LOG ---');
    debugPrint('Endpoint: $endpoint');
    debugPrint('Network: $network');
    if (chainId != null) debugPrint('Chain ID: $chainId');
    if (transactionHash != null) debugPrint('Tx Hash: $transactionHash');
    if (backendError != null) debugPrint('Backend Error: $backendError');
    if (providerError != null) debugPrint('Provider Error: $providerError');
    debugPrint('-----------------------');
  }
}
