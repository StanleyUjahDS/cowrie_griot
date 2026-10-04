import 'dart:convert';
import 'package:flutter/material.dart';
import 'wallet_service.dart';
import 'transaction_api_service.dart';
import 'wallet_rpc_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../utils/chain_assets.dart';
import '../utils/dapp_network_registry.dart';

class DAppBrowserService {
  final WalletService _walletService;
  final TransactionApiService _transactionApiService;
  final WalletRpcService _walletRpcService;
  final ApiClient _apiClient;
  final String Function() getChainId;
  final Future<bool> Function(String chainId)? onChainSwitch;
  bool _isProcessingSwitch = false;

  static final Set<String> _connectedOrigins = {};

  static bool isConnected(String origin) => _connectedOrigins.contains(origin);
  static void disconnect(String origin) => _connectedOrigins.remove(origin);

  DAppBrowserService({
    required WalletService walletService,
    required TransactionApiService transactionApiService,
    required WalletRpcService walletRpcService,
    required ApiClient apiClient,
    required this.getChainId,
    this.onChainSwitch,
  }) : _walletService = walletService,
       _transactionApiService = transactionApiService,
       _walletRpcService = walletRpcService,
       _apiClient = apiClient;

  Future<Map<String, dynamic>> handleRequest(
    Map<String, dynamic> request,
    BuildContext activeContext, {
    required String origin,
  }) async {
    final method = request['method']?.toString();
    if (method == null || method.isEmpty) {
      return {
        'error': {'code': -32600, 'message': 'Invalid wallet request'},
      };
    }
    final params = request['params'];
    final trustedOrigin = origin.toLowerCase();

    try {
      switch (method) {
        case 'eth_requestAccounts':
          final address = await _walletService.getAddress();
          if (address == null) {
            return {
              'error': {'code': -32000, 'message': 'Wallet not initialized'},
            };
          }

          final normalizedAddress = _formatAddress(address);

          if (_connectedOrigins.contains(trustedOrigin)) {
            return {
              'result': [normalizedAddress],
            };
          }

          if (!activeContext.mounted) {
            return {
              'error': {'code': 4001, 'message': 'User rejected the request'},
            };
          }

          final approved = await _showApprovalDialog(
            activeContext,
            title: 'Connect to DApp',
            content: '$trustedOrigin wants to connect to your wallet.',
          );

          if (approved) {
            _connectedOrigins.add(trustedOrigin);
            return {
              'result': [normalizedAddress],
            };
          } else {
            return {
              'error': {'code': 4001, 'message': 'User rejected the request'},
            };
          }

        case 'eth_accounts':
          final address = await _walletService.getAddress();
          if (address != null && _connectedOrigins.contains(trustedOrigin)) {
            return {
              'result': [_formatAddress(address)],
            };
          }
          return {'result': []};

        case 'wallet_requestPermissions':
          final address = await _walletService.getAddress();
          if (address == null) {
            return {
              'error': {'code': -32000, 'message': 'Wallet not initialized'},
            };
          }

          if (!activeContext.mounted) {
            return {
              'error': {'code': 4001, 'message': 'User rejected the request'},
            };
          }

          final approved = await _showApprovalDialog(
            activeContext,
            title: 'Permission Request',
            content:
                '$trustedOrigin is requesting permission to access your account.',
          );

          if (approved) {
            _connectedOrigins.add(trustedOrigin);
            return {
              'result': [
                {
                  'parentCapability': 'eth_accounts',
                  'caveats': [
                    {
                      'type': 'restrictAccounts',
                      'value': [_formatAddress(address)],
                    },
                  ],
                },
              ],
            };
          } else {
            return {
              'error': {'code': 4001, 'message': 'User rejected the request'},
            };
          }

        case 'wallet_getPermissions':
          final address = await _walletService.getAddress();
          if (address != null && _connectedOrigins.contains(trustedOrigin)) {
            return {
              'result': [
                {'parentCapability': 'eth_accounts'},
              ],
            };
          }
          return {'result': []};

        case 'eth_chainId':
          return {'result': getChainId()};
        case 'net_version':
          return {
            'result': int.parse(
              getChainId().replaceFirst('0x', ''),
              radix: 16,
            ).toString(),
          };
        case 'eth_protocolVersion':
          return {'result': '0x41'};
        case 'eth_mining':
          return {'result': false};
        case 'eth_syncing':
          return {'result': false};

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
        case 'eth_getBlockByNumber':
        case 'eth_getBlockByHash':
        case 'eth_feeHistory':
        case 'eth_maxPriorityFeePerGas':
        case 'eth_getStorageAt':
        case 'eth_getProof':
        case 'eth_getTransactionByBlockHashAndIndex':
        case 'eth_getTransactionByBlockNumberAndIndex':
        case 'eth_getBlockTransactionCountByHash':
        case 'eth_getBlockTransactionCountByNumber':
        case 'web3_clientVersion':
          return await _rpcRead(method, params ?? []);

        case 'eth_sendTransaction':
          return await _handleSendTransaction(
            activeContext,
            params,
            origin: trustedOrigin,
          );

        case 'personal_sign':
          return await _handlePersonalSign(
            activeContext,
            params,
            origin: trustedOrigin,
          );

        case 'eth_signTypedData_v4':
          return await _handleSignTypedData(
            activeContext,
            params,
            origin: trustedOrigin,
          );

        case 'wallet_switchEthereumChain':
        case 'wallet_addEthereumChain':
          return await _handleSwitchChain(
            activeContext,
            params,
            origin: trustedOrigin,
          );

        default:
          return {
            'error': {'code': -32601, 'message': 'Method not supported'},
          };
      }
    } catch (e) {
      return {
        'error': {'code': -32000, 'message': e.toString()},
      };
    }
  }

  Future<Map<String, dynamic>> _handleSendTransaction(
    BuildContext activeContext,
    dynamic params, {
    String? origin,
  }) async {
    if (params is! List || params.isEmpty || params.first is! Map) {
      return {
        'error': {'code': -32602, 'message': 'Invalid transaction parameters'},
      };
    }
    if (origin == null || !_connectedOrigins.contains(origin)) {
      return {
        'error': {'code': 4100, 'message': 'DApp is not connected'},
      };
    }
    final tx = Map<String, dynamic>.from(params.first as Map);
    final chain = DAppNetworkRegistry.find(getChainId());
    if (chain == null) {
      return {
        'error': {'code': 4902, 'message': 'Unsupported chain'},
      };
    }
    final to = tx['to']?.toString() ?? '';
    if (!ChainAssets.isValidEvmAddress(to)) {
      return {
        'error': {'code': -32602, 'message': 'Invalid transaction recipient'},
      };
    }
    final address = await _walletService.getAddress();
    if (address == null) {
      return {
        'error': {'code': -32000, 'message': 'Wallet not initialized'},
      };
    }
    if (tx['from'] != null &&
        _formatAddress(tx['from'].toString()) != _formatAddress(address)) {
      return {
        'error': {
          'code': 4100,
          'message': 'Transaction sender is not the connected account',
        },
      };
    }
    if (tx['chainId'] != null &&
        DAppNetworkRegistry.normalizeChainId(tx['chainId']) != chain.chainId) {
      return {
        'error': {
          'code': 4901,
          'message': 'Transaction chain does not match the selected network',
        },
      };
    }
    final valueHex = (tx['value'] ?? '0x0').toString();
    final valueRaw = _quantity(valueHex);
    final valueNative = valueRaw.toDouble() / 1e18;

    if (!activeContext.mounted) {
      return {
        'error': {'code': 4001, 'message': 'Request cancelled'},
      };
    }
    final approved = await _showApprovalDialog(
      activeContext,
      title: 'Approve Transaction',
      content: 'Send to: $to',
      valueDisplay: '${valueNative.toStringAsFixed(6)} ${chain.symbol}',
    );
    if (!approved) {
      return {
        'error': {'code': 4001, 'message': 'User rejected'},
      };
    }

    final estimate = await _transactionApiService.estimateTransaction(
      network: chain.network,
      transaction: {...tx, 'from': _formatAddress(address)},
    );
    final nonce = tx['nonce'] != null
        ? _quantity(tx['nonce']).toInt()
        : await _walletRpcService.getPendingNonce(
            network: chain.network,
            address: address,
          );
    final gasLimit = tx['gas'] ?? tx['gasLimit'] ?? estimate['gasLimit'];
    final gasPrice = tx['gasPrice'] ?? estimate['gasPrice'];
    final maxFeePerGas = tx['maxFeePerGas'] ?? estimate['maxFeePerGas'];
    final maxPriorityFeePerGas =
        tx['maxPriorityFeePerGas'] ?? estimate['maxPriorityFeePerGas'];

    final signedTx = await _walletService.signNativeTransaction(
      to: to,
      valueRaw: valueRaw.toString(),
      nonce: nonce,
      gasLimit: gasLimit.toString(),
      gasPrice: gasPrice?.toString(),
      maxFeePerGas: maxFeePerGas?.toString(),
      maxPriorityFeePerGas: maxPriorityFeePerGas?.toString(),
      chainId: int.parse(chain.chainId.substring(2), radix: 16),
      dataHex: tx['data'] as String?,
    );

    if (signedTx == null) throw Exception('Wallet signing failed');
    final result = await _transactionApiService.broadcastRawTransaction(
      network: chain.network,
      signedTransaction: signedTx,
      transactionType: 'send',
    );
    return {'result': result['hash'] ?? result['broadcast']?['hash']};
  }

  Future<Map<String, dynamic>> _handlePersonalSign(
    BuildContext activeContext,
    dynamic params, {
    String? origin,
  }) async {
    if (origin == null || !_connectedOrigins.contains(origin)) {
      return {
        'error': {'code': 4100, 'message': 'DApp is not connected'},
      };
    }
    if (params is! List || params.isEmpty || params.first is! String) {
      return {
        'error': {'code': -32602, 'message': 'Invalid signing parameters'},
      };
    }
    final address = await _walletService.getAddress();
    if (address == null) {
      return {
        'error': {'code': -32000, 'message': 'Wallet not initialized'},
      };
    }
    final requestedAddress = params.length > 1 ? params[1]?.toString() : null;
    if (requestedAddress != null &&
        _formatAddress(requestedAddress) != _formatAddress(address)) {
      return {
        'error': {'code': 4100, 'message': 'Signing account is not connected'},
      };
    }
    if (!activeContext.mounted) {
      return {
        'error': {'code': 4001, 'message': 'Request cancelled'},
      };
    }
    String msg = params.first as String;
    if (msg.startsWith('0x')) {
      try {
        msg = utf8.decode(_hexToBytes(msg));
      } catch (_) {}
    }
    final approved = await _showApprovalDialog(
      activeContext,
      title: 'Sign Message',
      content: msg,
    );
    if (!approved) {
      return {
        'error': {'code': 4001, 'message': 'User rejected'},
      };
    }
    return {'result': await _walletService.signMessage(msg)};
  }

  Future<Map<String, dynamic>> _handleSignTypedData(
    BuildContext activeContext,
    dynamic params, {
    String? origin,
  }) async {
    if (origin == null || !_connectedOrigins.contains(origin)) {
      return {
        'error': {'code': 4100, 'message': 'DApp is not connected'},
      };
    }
    // A personal-message signature is not a valid EIP-712 signature. Refuse
    // before showing an approval prompt until structured-data hashing exists.
    return {
      'error': {
        'code': -32601,
        'message': 'EIP-712 typed-data signing is not supported yet',
      },
    };
  }

  Future<Map<String, dynamic>> _handleSwitchChain(
    BuildContext activeContext,
    dynamic params, {
    String? origin,
  }) async {
    if (origin == null || !_connectedOrigins.contains(origin)) {
      return {
        'error': {'code': 4100, 'message': 'DApp is not connected'},
      };
    }
    if (_isProcessingSwitch) return {'result': null};
    if (params is! List || params.isEmpty || params.first is! Map) {
      return {
        'error': {'code': -32602, 'message': 'Invalid chain switch parameters'},
      };
    }
    final target = DAppNetworkRegistry.find((params.first as Map)['chainId']);
    if (target == null) {
      return {
        'error': {'code': 4902, 'message': 'Requested chain is not supported'},
      };
    }
    if (DAppNetworkRegistry.normalizeChainId(getChainId()) == target.chainId) {
      return {'result': null};
    }
    _isProcessingSwitch = true;
    try {
      final approved = await _showApprovalDialog(
        activeContext,
        title: 'Switch Network',
        content: 'Switch to ${target.name}?',
      );
      if (approved && onChainSwitch != null) {
        final switched = await onChainSwitch!(target.chainId);
        if (switched) return {'result': null};
        return {
          'error': {
            'code': 4902,
            'message': 'Requested chain is not supported',
          },
        };
      }
      return {
        'error': {'code': 4001, 'message': 'User rejected'},
      };
    } finally {
      _isProcessingSwitch = false;
    }
  }

  Future<Map<String, dynamic>> _rpcRead(String method, dynamic params) async {
    final response = await _apiClient.post(
      '${ApiConfig.blockchainBase}/rpc/$_networkForChainIdValue',
      body: {'method': method, 'params': params is List ? params : []},
    );
    final data = response is Map && response['data'] != null
        ? response['data']
        : response;
    if (data is Map && data.containsKey('result')) {
      return {'result': data['result']};
    }
    throw Exception('Invalid RPC response');
  }

  String get _networkForChainIdValue => _networkForChainId(getChainId());
  String _networkForChainId(String chainId) {
    final network = DAppNetworkRegistry.find(chainId);
    if (network == null) throw Exception('Unsupported chain: $chainId');
    return network.network;
  }

  BigInt _quantity(Object? value) {
    final raw = value?.toString().trim() ?? '0';
    if (raw.isEmpty || raw == '0x') return BigInt.zero;
    return raw.startsWith('0x')
        ? BigInt.parse(raw.substring(2), radix: 16)
        : BigInt.parse(raw);
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

  Future<bool> _showApprovalDialog(
    BuildContext activeContext, {
    required String title,
    required String content,
    String? valueDisplay,
  }) async {
    return await showModalBottomSheet<bool>(
          context: activeContext,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  content,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (valueDisplay != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "AMOUNT",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Text(
                          valueDisplay,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
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
        ) ??
        false;
  }
}
