import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'wallet_service.dart';
import 'transaction_api_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';

class DAppBrowserService {
  final BuildContext context;
  final String Function() getChainId;
  final Function(String chainId)? onChainSwitch;
  bool _isProcessingSwitch = false;

  DAppBrowserService(this.context, {required this.getChainId, this.onChainSwitch});

  WalletService get _walletService => context.read<WalletService>();
  TransactionApiService get _transactionApiService => context.read<TransactionApiService>();
  ApiClient get _apiClient => context.read<ApiClient>();

  Future<Map<String, dynamic>> handleRequest(Map<String, dynamic> request) async {
    final method = request['method'] as String;
    final params = request['params'];

    try {
      switch (method) {
        case 'eth_requestAccounts':
        case 'eth_accounts':
          final address = await _walletService.getAddress();
          return {
            'result': address != null ? [address] : [],
          };

        case 'eth_chainId':
          return {'result': getChainId()};

        case 'net_version':
          final chainId = getChainId();
          return {'result': int.parse(chainId.replaceFirst('0x', ''), radix: 16).toString()};

        case 'eth_call':
        case 'eth_getBalance':
        case 'eth_blockNumber':
        case 'eth_gasPrice':
        case 'eth_estimateGas':
        case 'eth_getTransactionCount':
        case 'eth_getCode':
        case 'eth_getLogs':
        case 'eth_getTransactionByHash':
        case 'eth_getTransactionReceipt':
          return await _rpcRead(method, params ?? []);

        case 'eth_sendTransaction':
          return await _handleSendTransaction(params);

        case 'personal_sign':
          return await _handlePersonalSign(params);

        case 'wallet_switchEthereumChain':
          return await _handleSwitchChain(params);

        default:
          debugPrint('DAppBrowserService: Unsupported method $method');
          return {
            'error': {'code': -32601, 'message': 'Method not supported'}
          };
      }
    } catch (e) {
      debugPrint('DAppBrowserService Error: $e');
      return {
        'error': {'code': -32000, 'message': e.toString()}
      };
    }
  }

  Future<Map<String, dynamic>> _handleSendTransaction(dynamic params) async {
    final tx = params[0] as Map<String, dynamic>;
    
    final to = tx['to'] as String;
    final valueHex = tx['value'] as String? ?? '0x0';
    final data = tx['data'] as String? ?? '0x';
    final gasLimitHex = tx['gas'] as String? ?? tx['gasLimit'] as String? ?? '0x5208';
    
    final approved = await _showApprovalDialog(
      title: 'Approve Transaction',
      content: 'DApp wants to send a transaction to $to.',
      txData: tx,
    );

    if (!approved) {
      return {
        'error': {'code': 4001, 'message': 'User rejected the transaction'}
      };
    }

    final valueRaw = _hexToBigInt(valueHex).toString();
    final gasLimit = _hexToBigInt(gasLimitHex).toInt();
    final nonceHex = tx['nonce'] as String? ?? '0x0';
    final nonce = _hexToBigInt(nonceHex).toInt();

    final selectedChainId = getChainId();
    final chainIdInt = int.parse(selectedChainId.replaceFirst('0x', ''), radix: 16);
    final network = _networkForChainId(selectedChainId);

    final signedTx = await _walletService.signNativeTransaction(
      to: to,
      valueRaw: valueRaw,
      nonce: nonce,
      gasLimit: gasLimit.toString(),
      chainId: chainIdInt,
      dataHex: data,
    );

    if (signedTx == null) {
      throw Exception('Failed to sign transaction');
    }

    final result = await _transactionApiService.broadcastTransaction(
      network: network,
      transactionId: 'dapp_${DateTime.now().millisecondsSinceEpoch}',
      signedTransaction: signedTx,
    );

    final hash = result['broadcast']?['hash'] ?? result['hash'];
    if (hash == null) throw Exception('Broadcast failed: ${result['message']}');

    return {'result': hash};
  }

  Future<Map<String, dynamic>> _rpcRead(String method, dynamic params) async {
    final response = await _apiClient.post(
      '${ApiConfig.blockchainBase}/rpc/$_networkForChainIdValue',
      body: {'method': method, 'params': params is List ? params : []},
    );
    
    final data = response is Map && response['data'] != null ? response['data'] : response;
    if (data is Map && data.containsKey('result')) {
      return {'result': data['result']};
    }
    throw Exception('Invalid RPC response');
  }

  String get _networkForChainIdValue => _networkForChainId(getChainId());

  String _networkForChainId(String chainId) {
    const networks = {
      '0x1': 'ethereum',
      '0x38': 'bsc',
      '0x89': 'polygon',
      '0xa4b1': 'arbitrum',
      '0xa': 'optimism',
      '0x2105': 'base'
    };
    final normalized = chainId.toLowerCase();
    final network = networks[normalized];
    if (network == null) throw Exception('Unsupported DApp network: $chainId');
    return network;
  }

  Future<Map<String, dynamic>> _handlePersonalSign(dynamic params) async {
    String message = params[0] as String;
    String displayMessage = message;
    if (message.startsWith('0x')) {
      try {
        final decoded = utf8.decode(_hexToBytes(message));
        displayMessage = decoded;
      } catch (_) {}
    }

    final approved = await _showApprovalDialog(
      title: 'Sign Message',
      content: 'DApp wants you to sign this message:\n\n$displayMessage',
    );

    if (!approved) {
      return {
        'error': {'code': 4001, 'message': 'User rejected the signature'}
      };
    }

    final signature = await _walletService.signMessage(displayMessage);
    return {'result': signature};
  }

  Future<Map<String, dynamic>> _handleSwitchChain(dynamic params) async {
    if (_isProcessingSwitch) return {'result': null};

    final switchParams = params[0] as Map<String, dynamic>;
    final targetChainId = switchParams['chainId'] as String;

    try {
      final currentInt = int.parse(getChainId().replaceFirst('0x', ''), radix: 16);
      final targetInt = int.parse(targetChainId.replaceFirst('0x', ''), radix: 16);

      if (currentInt == targetInt) {
        return {'result': null};
      }
    } catch (_) {
      if (getChainId().toLowerCase() == targetChainId.toLowerCase()) {
        return {'result': null};
      }
    }

    _isProcessingSwitch = true;
    try {
      final approved = await _showApprovalDialog(
        title: 'Switch Network',
        content: 'DApp wants to switch your network to $targetChainId.',
      );

      if (approved) {
        if (onChainSwitch != null) {
          onChainSwitch!(targetChainId);
        }
        return {'result': null};
      } else {
        return {
          'error': {'code': 4001, 'message': 'User rejected the network switch'}
        };
      }
    } finally {
      _isProcessingSwitch = false;
    }
  }

  BigInt _hexToBigInt(String hex) {
    if (!hex.startsWith('0x')) return BigInt.parse(hex);
    if (hex == '0x') return BigInt.zero;
    return BigInt.parse(hex.substring(2), radix: 16);
  }

  List<int> _hexToBytes(String hex) {
    hex = hex.replaceFirst('0x', '');
    if (hex.length.isOdd) hex = '0$hex';
    final List<int> bytes = [];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  Future<bool> _showApprovalDialog({
    required String title,
    required String content,
    Map<String, dynamic>? txData,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text(content),
            if (txData != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text("Value: ${txData['value'] ?? '0'} ETH"),
              ),
            ],
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }
}
