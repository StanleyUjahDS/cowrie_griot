import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'wallet_service.dart';
import 'transaction_api_service.dart';
import 'wallet_rpc_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';

class DAppBrowserService {
  final BuildContext context;
  final String Function() getChainId;
  final Function(String chainId)? onChainSwitch;
  bool _isProcessingSwitch = false;
  
  static final Set<String> _connectedOrigins = {};

  static bool isConnected(String origin) => _connectedOrigins.contains(origin);
  static void disconnect(String origin) => _connectedOrigins.remove(origin);

  DAppBrowserService(this.context, {required this.getChainId, this.onChainSwitch});

  WalletService get _walletService => context.read<WalletService>();
  TransactionApiService get _transactionApiService => context.read<TransactionApiService>();
  WalletRpcService get _walletRpcService => context.read<WalletRpcService>();
  ApiClient get _apiClient => context.read<ApiClient>();

  Future<Map<String, dynamic>> handleRequest(Map<String, dynamic> request, BuildContext activeContext) async {
    final method = request['method'] as String;
    final params = request['params'];
    final origin = (request['origin'] as String?)?.toLowerCase();

    debugPrint('GriotWeb3 Request: $method from $origin');

    try {
      switch (method) {
        case 'eth_requestAccounts':
          final address = await _walletService.getAddress();
          if (address == null) return {'error': {'code': -32000, 'message': 'Wallet not initialized'}};

          final normalizedAddress = _formatAddress(address);

          if (origin != null && _connectedOrigins.contains(origin)) {
            return {'result': [normalizedAddress]};
          }

          if (!activeContext.mounted) return {'error': {'code': 4001, 'message': 'User rejected the request'}};

          final approved = await _showApprovalDialog(
            activeContext,
            title: 'Connect to DApp',
            content: '${origin ?? "This DApp"} wants to connect to your wallet.',
          );

          if (approved) {
            if (origin != null) _connectedOrigins.add(origin);
            return {'result': [normalizedAddress]};
          } else {
            return {'error': {'code': 4001, 'message': 'User rejected the request'}};
          }

        case 'eth_accounts':
          final address = await _walletService.getAddress();
          if (address != null && origin != null && _connectedOrigins.contains(origin)) {
            return {'result': [_formatAddress(address)]};
          }
          return {'result': []};

        case 'wallet_requestPermissions':
          final address = await _walletService.getAddress();
          if (address == null) return {'error': {'code': -32000, 'message': 'Wallet not initialized'}};
          
          if (!activeContext.mounted) return {'error': {'code': 4001, 'message': 'User rejected the request'}};

          final approved = await _showApprovalDialog(
            activeContext,
            title: 'Permission Request',
            content: '${origin ?? "This DApp"} is requesting permission to access your account.',
          );

          if (approved) {
            if (origin != null) _connectedOrigins.add(origin);
            return {'result': [
              {
                'parentCapability': 'eth_accounts',
                'caveats': [
                  {'type': 'restrictAccounts', 'value': [_formatAddress(address)]}
                ]
              }
            ]};
          } else {
            return {'error': {'code': 4001, 'message': 'User rejected the request'}};
          }

        case 'wallet_getPermissions':
          final address = await _walletService.getAddress();
          if (address != null && origin != null && _connectedOrigins.contains(origin)) {
            return {'result': [
              {'parentCapability': 'eth_accounts'}
            ]};
          }
          return {'result': []};

        case 'eth_chainId': return {'result': getChainId()};
        case 'net_version': return {'result': int.parse(getChainId().replaceFirst('0x', ''), radix: 16).toString()};
        case 'eth_protocolVersion': return {'result': '0x41'};
        case 'eth_mining': return {'result': false};
        case 'eth_syncing': return {'result': false};

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
          return await _handleSendTransaction(activeContext, params, origin: origin);

        case 'personal_sign':
          return await _handlePersonalSign(activeContext, params, origin: origin);

        case 'eth_signTypedData_v4':
          return await _handleSignTypedData(activeContext, params, origin: origin);

        case 'wallet_switchEthereumChain':
          return await _handleSwitchChain(activeContext, params, origin: origin);

        default:
          return {'error': {'code': -32601, 'message': 'Method not supported'}};
      }
    } catch (e) {
      return {'error': {'code': -32000, 'message': e.toString()}};
    }
  }

  Future<Map<String, dynamic>> _handleSendTransaction(BuildContext activeContext, dynamic params, {String? origin}) async {
    final tx = params[0] as Map<String, dynamic>;
    final valueHex = (tx['value'] ?? '0x0').toString();
    final valueEth = valueHex == '0x' ? 0.0 : (BigInt.parse(valueHex.replaceFirst('0x', ''), radix: 16).toDouble() / 1e18);

    final approved = await _showApprovalDialog(activeContext, title: 'Approve Transaction', content: 'Send to: ${tx['to']}', valueDisplay: '${valueEth.toStringAsFixed(6)} ETH');
    if (!approved) return {'error': {'code': 4001, 'message': 'User rejected'}};

    final address = await _walletService.getAddress();
    final network = _networkForChainId(getChainId());
    final nonce = tx['nonce'] is String ? int.parse((tx['nonce'] as String).replaceFirst('0x', ''), radix: 16) : await _walletRpcService.getPendingNonce(network: network, address: address!);

    final signedTx = await _walletService.signNativeTransaction(
      to: tx['to'] as String,
      valueRaw: valueHex == '0x' ? '0' : BigInt.parse(valueHex.replaceFirst('0x', ''), radix: 16).toString(),
      nonce: nonce,
      gasLimit: (tx['gas'] ?? tx['gasLimit'] ?? '0x5208').toString().replaceFirst('0x', ''),
      chainId: int.parse(getChainId().replaceFirst('0x', ''), radix: 16),
      dataHex: tx['data'] as String?,
    );

    final result = await _transactionApiService.broadcastTransaction(network: network, transactionId: 'dapp_${DateTime.now().millisecondsSinceEpoch}', signedTransaction: signedTx!);
    return {'result': result['broadcast']?['hash'] ?? result['hash']};
  }

  Future<Map<String, dynamic>> _handlePersonalSign(BuildContext activeContext, dynamic params, {String? origin}) async {
    String msg = params[0] as String;
    if (msg.startsWith('0x')) try { msg = utf8.decode(_hexToBytes(msg)); } catch (_) {}
    final approved = await _showApprovalDialog(activeContext, title: 'Sign Message', content: msg);
    if (!approved) return {'error': {'code': 4001, 'message': 'User rejected'}};
    return {'result': await _walletService.signMessage(msg)};
  }

  Future<Map<String, dynamic>> _handleSignTypedData(BuildContext activeContext, dynamic params, {String? origin}) async {
    final data = params[1];
    final approved = await _showApprovalDialog(activeContext, title: 'Typed Signature', content: data is String ? data : jsonEncode(data));
    if (!approved) return {'error': {'code': 4001, 'message': 'User rejected'}};
    return {'result': await _walletService.signMessage(data is String ? data : jsonEncode(data))};
  }

  Future<Map<String, dynamic>> _handleSwitchChain(BuildContext activeContext, dynamic params, {String? origin}) async {
    if (_isProcessingSwitch) return {'result': null};
    final target = params[0]['chainId'] as String;
    if (getChainId().toLowerCase() == target.toLowerCase()) return {'result': null};
    _isProcessingSwitch = true;
    try {
      final approved = await _showApprovalDialog(activeContext, title: 'Switch Network', content: 'Switch to $target?');
      if (approved && onChainSwitch != null) {
        onChainSwitch!(target);
        return {'result': null};
      }
      return {'error': {'code': 4001, 'message': 'User rejected'}};
    } finally { _isProcessingSwitch = false; }
  }

  Future<Map<String, dynamic>> _rpcRead(String method, dynamic params) async {
    final response = await _apiClient.post('${ApiConfig.blockchainBase}/rpc/$_networkForChainIdValue', body: {'method': method, 'params': params is List ? params : []});
    final data = response is Map && response['data'] != null ? response['data'] : response;
    if (data is Map && data.containsKey('result')) return {'result': data['result']};
    throw Exception('Invalid RPC response');
  }

  String get _networkForChainIdValue => _networkForChainId(getChainId());
  String _networkForChainId(String chainId) {
    const networks = {'0x1': 'ethereum', '0x38': 'bsc', '0x89': 'polygon', '0xa4b1': 'arbitrum', '0xa': 'optimism', '0x2105': 'base'};
    return networks[chainId.toLowerCase()] ?? 'ethereum';
  }

  String _formatAddress(String address) {
    String addr = address.trim();
    if (!addr.startsWith('0x')) {
      addr = '0x$addr';
    }
    return addr.toLowerCase();
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

  Future<bool> _showApprovalDialog(BuildContext activeContext, {required String title, required String content, String? valueDisplay}) async {
    return await showModalBottomSheet<bool>(
      context: activeContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Text(content, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            if (valueDisplay != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("AMOUNT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
                  Text(valueDisplay, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ]),
              ),
            ],
            const SizedBox(height: 32),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Reject'))),
              const SizedBox(width: 16),
              Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Approve'))),
            ]),
          ],
        ),
      ),
    ) ?? false;
  }
}
