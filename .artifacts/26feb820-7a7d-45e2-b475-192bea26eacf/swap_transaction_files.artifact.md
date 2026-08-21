# Swap Transaction Architecture: Full Source Registry

This document contains the complete source code for all files participating in the "Local-Sign, Backend-Broadcast" swap and approval flow.

---

## 1. UI Layer (Screens & Widgets)

### [swap_screen.dart](file:///Users/newuser/cowrie_griot/lib/features/wallet/screens/swap_screen.dart)
```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/token_model.dart';
import '../providers/wallet_provider.dart';
import '../services/swap_api_service.dart';
import '../services/wallet_service.dart';
import '../services/transaction_api_service.dart';
import '../services/wallet_rpc_service.dart';
import '../widgets/token_icon.dart';
import '../utils/wallet_formatters.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/banner_ad.dart';
import '../../../core/services/notification_service.dart';

class SwapScreen extends StatefulWidget {
  final TokenModel? initialFromToken;

  const SwapScreen({super.key, this.initialFromToken});

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  static const String _nativeTokenAddress =
      '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';

  TokenModel? _fromToken;
  TokenModel? _toToken;
  final _amountController = TextEditingController();
  final _usdController = TextEditingController();
  bool _isLoading = false;
  bool _isApproving = false;
  bool _isApprovalRequired = false;
  bool _isUsdMode = false;
  String _loadingMessage = '';
  Map<String, dynamic>? _quote;
  Timer? _debounce;
  int _quoteRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    _fromToken = widget.initialFromToken;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _usdController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onAmountChanged(String value) {
    if (_fromToken == null) return;

    _syncControllers(value, sourceIsUsd: _isUsdMode);

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _getQuote);
  }

  void _syncControllers(String value, {required bool sourceIsUsd}) {
    if (_fromToken == null) return;
    final amount = double.tryParse(value) ?? 0.0;
    final price = _fromToken!.priceUsd.toDouble();

    if (sourceIsUsd) {
      if (price > 0) {
        final tokenAmount = amount / price;
        _amountController.text = tokenAmount.toStringAsFixed(_fromToken!.decimals > 6 ? 6 : _fromToken!.decimals);
      } else {
        _amountController.text = '0';
      }
    } else {
      if (price > 0) {
        final usdAmount = amount * price;
        _usdController.text = usdAmount.toStringAsFixed(2);
      } else {
        _usdController.text = '0.00';
      }
    }
  }

  void _onMaxPressed() {
    if (_fromToken == null) return;
    final maxBalance = _fromToken!.balance.toDouble();

    if (_isUsdMode) {
      final price = _fromToken!.priceUsd.toDouble();
      final maxUsd = maxBalance * price;
      _usdController.text = maxUsd.toStringAsFixed(2);
      _syncControllers(_usdController.text, sourceIsUsd: true);
    } else {
      _amountController.text = maxBalance.toString();
      _syncControllers(_amountController.text, sourceIsUsd: false);
    }

    _getQuote();
  }

  void _toggleCurrencyMode() {
    setState(() {
      _isUsdMode = !_isUsdMode;
    });
  }

  Future<void> _getQuote() async {
    final fromToken = _fromToken;
    final toToken = _toToken;
    if (fromToken == null || toToken == null) return;

    final amount = _amountController.text.trim();
    if (amount.isEmpty || amount == '0') {
      if (mounted) setState(() => _quote = null);
      return;
    }

    final enteredAmount = double.tryParse(amount) ?? 0.0;
    final maxBalance = fromToken.balance.toDouble();
    if (enteredAmount > maxBalance) {
      if (mounted) {
        setState(() {
          _quote = null;
          _isLoading = false;
        });
        NotificationService.showError(
          context,
          'Amount exceeds your maximum balance of $maxBalance ${fromToken.symbol}',
        );
      }
      return;
    }

    final fromAddress = context.read<WalletProvider>().wallet?.address;
    if (fromAddress == null || fromAddress.isEmpty) return;

    final fromTokenAddress = fromToken.isNative
        ? _nativeTokenAddress
        : fromToken.contractAddress;
    final toTokenAddress = toToken.isNative
        ? _nativeTokenAddress
        : toToken.contractAddress;

    if (fromTokenAddress.isEmpty || toTokenAddress.isEmpty) return;

    final fromAmount = _toBaseUnits(amount, fromToken.decimals);
    if (fromAmount == null || fromAmount == '0') return;

    final requestVersion = ++_quoteRequestVersion;
    setState(() => _isLoading = true);

    try {
      final isCrossChain = fromToken.chain.toLowerCase() !=
          toToken.chain.toLowerCase();

      final quote = await context.read<SwapApiService>().getQuote(
            fromChain: fromToken.chain,
            toChain: toToken.chain,
            fromToken: fromTokenAddress,
            toToken: toTokenAddress,
            fromAmount: fromAmount,
            fromAddress: fromAddress,
            toAddress: isCrossChain ? fromAddress : null,
          );

      if (!mounted || requestVersion != _quoteRequestVersion) return;

      bool approvalNeeded = false;
      final approvalAddress = quote['approvalAddress']?.toString();
      if (approvalAddress != null &&
          approvalAddress.isNotEmpty &&
          !fromToken.isNative) {
        try {
          final rpcService = context.read<WalletRpcService>();
          final cryptoService = context.read<WalletService>().crypto;
          final allowanceHex = await rpcService.call(
            network: fromToken.chain,
            to: fromToken.contractAddress,
            data: cryptoService.encodeErc20Allowance(
              owner: fromAddress,
              spender: approvalAddress,
            ),
          );
          final allowance = BigInt.tryParse(allowanceHex.replaceFirst('0x', ''), radix: 16) ?? BigInt.zero;
          final requiredAmount = BigInt.tryParse(fromAmount) ?? BigInt.zero;

          debugPrint('ALLOWANCE CHECK: token=${fromToken.symbol}, spender=$approvalAddress');
          debugPrint('ALLOWANCE: $allowance, REQUIRED: $requiredAmount');

          if (allowance < requiredAmount) {
            approvalNeeded = true;
          }
        } catch (e) {
          debugPrint('Allowance check failed: $e');
        }
      }

      setState(() {
        _quote = quote;
        _isApprovalRequired = approvalNeeded;
      });
    } catch (e) {
      if (mounted && requestVersion == _quoteRequestVersion) {
        debugPrint('Quote failed: $e');
        setState(() => _quote = null);
      }
    } finally {
      if (mounted && requestVersion == _quoteRequestVersion) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSwap() async {
    final quote = _quote;
    final fromToken = _fromToken;
    if (quote == null || fromToken == null) return;

    final fromAddress = context.read<WalletProvider>().wallet?.address;
    if (fromAddress == null || fromAddress.isEmpty) {
      NotificationService.showError(context, 'Wallet address not found.');
      return;
    }

    final transactionApi = context.read<TransactionApiService>();
    final walletService = context.read<WalletService>();

    final amount = _amountController.text.trim();
    final enteredAmount = double.tryParse(amount) ?? 0.0;
    if (enteredAmount > fromToken.balance.toDouble()) {
      NotificationService.showError(
        context,
        'Amount exceeds your maximum balance of ${fromToken.balance} ${fromToken.symbol}',
      );
      return;
    }

    final rawTransaction = quote['transactionRequest'] ?? quote['transaction'];
    if (rawTransaction is! Map) {
      NotificationService.showError(context, 'No transaction data in quote.');
      return;
    }

    final transaction = Map<String, dynamic>.from(rawTransaction);

    debugPrint('SWAP TX: $transaction');

    final to = transaction['to']?.toString();
    final data = transaction['data']?.toString();
    final value = transaction['value']?.toString() ?? '0';
    final chainId = int.tryParse(transaction['chainId']?.toString() ?? '');
    final nonce = int.tryParse(transaction['nonce']?.toString() ?? '');
    final gasLimit = transaction['gasLimit']?.toString() ?? transaction['gas']?.toString();
    final gasPrice = transaction['gasPrice']?.toString();
    final maxFeePerGas = transaction['maxFeePerGas']?.toString();
    final maxPriorityFeePerGas = transaction['maxPriorityFeePerGas']?.toString();

    if (to == null || to.isEmpty ||
        data == null || data.isEmpty || data == '0x' ||
        chainId == null ||
        nonce == null ||
        gasLimit == null ||
        (gasPrice == null && maxFeePerGas == null)) {
      NotificationService.showError(
        context,
        'Swap transaction data is incomplete. Please request a new quote.',
      );
      return;
    }

    final confirmed = await _showConfirmBottomSheet(
      context,
      fromToken: fromToken,
      toToken: _toToken!,
      fromAmount: _amountController.text,
      toAmount: _fromBaseUnits(
        quote['toAmount']?.toString(),
        _toToken?.decimals ?? 18,
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Signing...';
    });
    try {
      final signedTx = await walletService.signNativeTransaction(
        to: to,
        valueRaw: value,
        nonce: nonce,
        gasLimit: gasLimit,
        gasPrice: gasPrice,
        maxFeePerGas: maxFeePerGas,
        maxPriorityFeePerGas: maxPriorityFeePerGas,
        chainId: chainId,
        dataHex: data,
      );

      if (signedTx == null || signedTx.isEmpty) {
        throw Exception('Failed to sign swap transaction locally');
      }

      setState(() => _loadingMessage = 'Broadcasting...');

      final swapApi = context.read<SwapApiService>();
      final broadcastResult = await swapApi.broadcastSwap(
        network: fromToken.chain,
        signedTransaction: signedTx,
        transactionType: 'swap',
      );

      final hash = broadcastResult['hash']?.toString();

      if (hash == null || hash.isEmpty) {
        throw Exception('Backend did not return a transaction hash');
      }

      setState(() => _loadingMessage = 'Confirming...');

      if (mounted) {
        _pollSwapStatus(hash);
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Swap failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = '';
        });
      }
    }
  }

  Future<void> _handleApprove() async {
    final quote = _quote;
    final fromToken = _fromToken;
    if (quote == null || fromToken == null) return;

    final approvalAddress = quote['approvalAddress']?.toString();
    if (approvalAddress == null || approvalAddress.isEmpty) return;

    final fromAddress = context.read<WalletProvider>().wallet?.address;
    if (fromAddress == null || fromAddress.isEmpty) return;

    final walletService = context.read<WalletService>();
    final rpcService = context.read<WalletRpcService>();
    final transactionApi = context.read<TransactionApiService>();

    final network = fromToken.chain;

    setState(() {
      _isApproving = true;
      _loadingMessage = 'Preparing...';
    });
    try {
      final fromAmount = _toBaseUnits(_amountController.text, fromToken.decimals);
      final data = walletService.crypto.encodeErc20Approve(
        spender: approvalAddress,
        amount: fromAmount!,
      );

      final nonce = await rpcService.getPendingNonce(
        network: network,
        address: fromAddress,
      );

      final estimate = await transactionApi.estimateTransaction(
        network: network,
        transaction: {
          'from': fromAddress,
          'to': fromToken.contractAddress,
          'value': '0',
          'data': data,
        },
      );

      final transactionRequest = quote['transactionRequest'] ?? quote['transaction'] ?? {};
      final chainId = int.tryParse(transactionRequest['chainId']?.toString() ?? '') ?? 1;

      setState(() => _loadingMessage = 'Signing...');
      final signedTx = await walletService.signNativeTransaction(
        to: fromToken.contractAddress,
        valueRaw: '0',
        nonce: nonce,
        gasLimit: estimate['gasLimit']?.toString() ?? '100000',
        gasPrice: estimate['gasPrice']?.toString(),
        maxFeePerGas: estimate['maxFeePerGas']?.toString(),
        maxPriorityFeePerGas: estimate['maxPriorityFeePerGas']?.toString(),
        chainId: chainId,
        dataHex: data,
      );

      setState(() => _loadingMessage = 'Approving...');

      final swapApi = context.read<SwapApiService>();
      if (mounted) {
        final broadcastResult = await swapApi.broadcastSwap(
          network: network,
          signedTransaction: signedTx!,
          transactionType: 'approval',
        );

        final hash = broadcastResult['hash']?.toString();
        if (hash == null || hash.isEmpty) {
          throw Exception('Backend did not return an approval hash');
        }
        debugPrint('APPROVAL HASH: $hash');

        // Wait for confirmation
        bool isConfirmed = false;
        for (int i = 0; i < 20; i++) {
          await Future.delayed(const Duration(seconds: 5));
          if (!mounted) return;

          final receipt = await rpcService.getTransactionReceipt(
            network: network,
            hash: hash,
          );
          debugPrint('APPROVAL RECEIPT: $receipt');

          if (receipt != null) {
            final status = receipt['status']?.toString();
            if (status == '0x1' || status == '1') {
              isConfirmed = true;
            }
            break;
          }
        }

        if (isConfirmed) {
          if (mounted) {
            NotificationService.showSuccess(context, 'Token approved!');
            await _getQuote(); // Refresh quote and allowance check
          }
        } else {
          throw Exception('Approval transaction timed out or failed.');
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Approval failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isApproving = false;
          _loadingMessage = '';
        });
      }
    }
  }

  Future<bool?> _showConfirmBottomSheet(
    BuildContext context, {
    required TokenModel fromToken,
    required TokenModel toToken,
    required String fromAmount,
    required String toAmount,
  }) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Review Swap',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      TokenIcon(
                        imageUrl: fromToken.imageUrl,
                        symbol: fromToken.symbol,
                        name: fromToken.name,
                        chainName: fromToken.chain,
                        isNative: fromToken.isNative,
                        radius: 20,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        fromAmount,
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        fromToken.symbol,
                        style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: colors.primary.withValues(alpha: 0.5)),
                Expanded(
                  child: Column(
                    children: [
                      TokenIcon(
                        imageUrl: toToken.imageUrl,
                        symbol: toToken.symbol,
                        name: toToken.name,
                        chainName: toToken.chain,
                        isNative: toToken.isNative,
                        radius: 20,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        toAmount,
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colors.primary),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        toToken.symbol,
                        style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Confirm Swap', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pollSwapStatus(String transactionHash) async {
    final quote = _quote;
    final fromToken = _fromToken;
    final toToken = _toToken;
    final fromAddress = context.read<WalletProvider>().wallet?.address;

    if (quote == null || fromToken == null || fromAddress == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final swapApi = context.read<SwapApiService>();
    final provider = quote['provider']?.toString().toLowerCase() ?? '';
    final swapType = quote['type']?.toString();
    final quoteId = quote['quoteId']?.toString();

    // Poll for up to 5 minutes (30 * 10 seconds)
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(seconds: 10));
      if (!mounted) return;

      try {
        final statusData = await swapApi.getStatus(
          transactionId: transactionHash,
          provider: provider,
          fromChain: fromToken.chain,
          toChain: toToken?.chain,
          fromAddress: fromAddress,
          swapType: swapType,
          quoteId: quoteId,
        );

        final status = statusData['status']?.toString().toUpperCase();

        if (status == 'CONFIRMED' || status == 'SUCCESS' || status == 'COMPLETED') {
          if (mounted) {
            NotificationService.showSuccess(context, 'Swap successful!');
            setState(() {
              _isLoading = false;
              _loadingMessage = '';
            });
            Navigator.of(context).pop();
          }
          return;
        } else if (status == 'FAILED' || status == 'ERROR') {
          if (mounted) {
            final msg = statusData['message']?.toString() ?? 'Swap failed on-chain';
            NotificationService.showError(context, 'Swap failed: $msg');
            setState(() {
              _isLoading = false;
              _loadingMessage = '';
            });
          }
          return;
        }
        // If PENDING, continue polling
      } catch (e) {
        debugPrint('Status poll failed: $e');
      }
    }

    if (mounted) {
      NotificationService.showInfo(
        context,
        'Swap is taking longer than expected. You can check your history later.',
      );
      setState(() {
        _isLoading = false;
        _loadingMessage = '';
      });
      Navigator.of(context).pop();
    }
  }

  String? _toBaseUnits(String value, int decimals) {
    final normalized = value.trim();
    if (normalized.isEmpty || decimals < 0) return null;

    final parts = normalized.split('.');
    if (parts.length > 2) return null;

    final whole = parts[0].isEmpty ? '0' : parts[0];
    final fraction = parts.length == 2 ? parts[1] : '';
    if (!RegExp(r'^\d+$').hasMatch(whole) ||
        (fraction.isNotEmpty && !RegExp(r'^\d+$').hasMatch(fraction))) {
      return null;
    }
    if (fraction.length > decimals) return null;

    final paddedFraction = fraction.padRight(decimals, '0');
    final raw = '$whole$paddedFraction'
        .replaceFirst(RegExp(r'^0+(?=\d)'), '');
    return RegExp(r'^\d+$').hasMatch(raw) ? raw : null;
  }

  String _fromBaseUnits(String? baseAmount, int decimals) {
    if (baseAmount == null || baseAmount.isEmpty || decimals < 0) {
      return '0.00';
    }

    final cleanBase = baseAmount
        .split('.')
        .first
        .replaceAll(RegExp(r'\D'), '');
    if (cleanBase.isEmpty) return '0.00';
    if (decimals == 0) return cleanBase;

    String whole;
    String fraction;
    if (cleanBase.length <= decimals) {
      final padded = cleanBase.padLeft(decimals + 1, '0');
      final splitIndex = padded.length - decimals;
      whole = padded.substring(0, splitIndex);
      fraction = padded.substring(splitIndex);
    } else {
      final splitIndex = cleanBase.length - decimals;
      whole = cleanBase.substring(0, splitIndex);
      fraction = cleanBase.substring(splitIndex);
    }

    fraction = fraction.replaceAll(RegExp(r'0+$'), '');
    if (fraction.isEmpty) return whole;
    if (fraction.length > 8) fraction = fraction.substring(0, 8);
    return '$whole.$fraction';
  }

  TokenModel? _tokenForAddress(String? address) {
    if (address == null || address.isEmpty) return null;
    final normalized = address.toLowerCase();
    if (normalized == _nativeTokenAddress.toLowerCase()) {
      try {
        return context.read<WalletProvider>().tokens.firstWhere(
              (token) =>
                  token.isNative &&
                  token.chain.toLowerCase() == _fromToken?.chain.toLowerCase(),
            );
      } catch (_) {
        return null;
      }
    }

    final tokens = context.read<WalletProvider>().tokens;
    try {
      return tokens.firstWhere(
        (token) =>
            token.contractAddress.toLowerCase() == normalized &&
            token.chain.toLowerCase() == _fromToken?.chain.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  String _formatFeeAmount(String? amount, TokenModel? token) {
    if (amount == null || amount.isEmpty || amount == '0') return '-';
    if (token == null) return amount;
    final value = double.tryParse(_fromBaseUnits(amount, token.decimals));
    if (value == null) return amount;
    return WalletFormatters.formatBalance(value, symbol: token.symbol);
  }

  void _swapTokens() {
    setState(() {
      final temp = _fromToken;
      _fromToken = _toToken;
      _toToken = temp;
      _quote = null;
      _amountController.clear();
      _usdController.clear();
    });
    _debounce?.cancel();
  }

  void _showTokenPicker(BuildContext context, {required bool isFrom}) {
    final tokens = context.read<WalletProvider>().tokens;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView.builder(
        itemCount: tokens.length,
        itemBuilder: (context, index) {
          final token = tokens[index];
          return ListTile(
            leading: TokenIcon(
              imageUrl: token.imageUrl,
              symbol: token.symbol,
              name: token.name,
              chainName: token.chain,
              isNative: token.isNative,
              radius: 16,
            ),
            title: Text(token.name),
            subtitle: Text('${token.symbol} on ${token.chain.toUpperCase()}'),
            trailing: Text(WalletFormatters.formatBalance(token.balance)),
            onTap: () {
              setState(() {
                if (isFrom) {
                  _fromToken = token;
                } else {
                  _toToken = token;
                }
                _quote = null;
                _amountController.clear();
                _usdController.clear();
              });
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return GradientScaffold(
      appBar: AppBar(
        title: Text(
          'Swap',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 80),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      children: [
                        _buildSwapCard(
                          context,
                          label: 'Pay',
                          token: _fromToken,
                          controller: _isUsdMode ? _usdController : _amountController,
                          onChanged: _onAmountChanged,
                          showCurrencyToggle: true,
                          onMaxTap: _onMaxPressed,
                          subValue: _isUsdMode
                            ? '${_amountController.text} ${_fromToken?.symbol ?? ""}'
                            : (_usdController.text.isNotEmpty ? '\$${_usdController.text}' : null),
                          onTokenTap: () => _showTokenPicker(context, isFrom: true),
                        ),
                        const SizedBox(height: 4),
                        _buildSwapCard(
                          context,
                          label: 'Receive',
                          token: _toToken,
                          isReadOnly: true,
                          value: _fromBaseUnits(
                            _quote?['toAmount']?.toString(),
                            _toToken?.decimals ?? 18,
                          ),
                          subValue: _quote != null && _toToken != null && _toToken!.priceUsd > 0
                              ? WalletFormatters.formatCurrency(
                                  (double.tryParse(_fromBaseUnits(_quote!['toAmount']?.toString(), _toToken!.decimals)) ?? 0) *
                                  _toToken!.priceUsd.toDouble()
                                )
                              : null,
                          onTokenTap: () => _showTokenPicker(context, isFrom: false),
                        ),
                      ],
                    ),
                    Positioned(
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: colors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.2), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _swapTokens,
                            customBorder: const CircleBorder(),
                            child: Icon(Icons.arrow_downward_rounded, color: colors.primary, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_quote != null) ...[
                  const SizedBox(height: 16),
                  _buildQuoteDetails(context),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: FilledButton(
                    onPressed: (_quote != null && !_isLoading && !_isApproving)
                        ? (_isApprovalRequired ? _handleApprove : _handleSwap)
                        : null,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: (_isLoading || _isApproving)
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: colors.onPrimary.withValues(alpha: 0.5),
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _loadingMessage,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          )
                        : Text(
                            _isApprovalRequired
                                ? 'Approve ${_fromToken?.symbol ?? "Token"}'
                                : 'Swap Assets',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 40),
                const GriotBannerAd(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwapCard(
    BuildContext context, {
    required String label,
    required TokenModel? token,
    required VoidCallback onTokenTap,
    TextEditingController? controller,
    String? value,
    bool isReadOnly = false,
    ValueChanged<String>? onChanged,
    bool showCurrencyToggle = false,
    String? subValue,
    VoidCallback? onMaxTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: text.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (token != null)
                Row(
                  children: [
                    Text(
                      'Balance: ${WalletFormatters.formatBalance(token.balance)}',
                      style: text.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    if (onMaxTap != null) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onMaxTap,
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            'MAX',
                            style: text.labelSmall?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isReadOnly)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value ?? '0.00',
                          style: text.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1,
                            color: (value == null || value == '0.00')
                                ? colors.onSurface.withValues(alpha: 0.2)
                                : colors.onSurface,
                          ),
                        ),
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (showCurrencyToggle && _isUsdMode)
                            Text(
                              '\$',
                              style: text.headlineLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.onSurface,
                              ),
                            ),
                          Expanded(
                            child: TextField(
                              controller: controller,
                              onChanged: onChanged,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: text.displaySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -1,
                                color: colors.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: '0.00',
                                hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.1)),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 4),
                    if (subValue != null && subValue.isNotEmpty)
                      Text(
                        subValue,
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: onTokenTap,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: token == null ? colors.primary : colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (token != null) ...[
                        TokenIcon(
                          imageUrl: token.imageUrl,
                          symbol: token.symbol,
                          name: token.name,
                          chainName: token.chain,
                          isNative: token.isNative,
                          radius: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          token.symbol,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                        ),
                      ] else
                        Text(
                          'Select Token',
                          style: text.titleSmall?.copyWith(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: token == null ? colors.onPrimary : colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (showCurrencyToggle) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: _toggleCurrencyMode,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.secondaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isUsdMode ? Icons.toll_rounded : Icons.attach_money_rounded,
                      size: 14,
                      color: colors.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isUsdMode ? 'Switch to ${_fromToken?.symbol ?? "Token"}' : 'Switch to USD',
                      style: text.labelSmall?.copyWith(
                        color: colors.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuoteDetails(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final griotFee = _asMap(_quote?['griotFee'] ?? _quote?['fee']);
    final providerFee = _asMap(_quote?['providerFee']);
    final transaction = _quote?['transaction'] ?? _quote?['transactionRequest'];

    final feePercent = griotFee['percent'];
    final feePercentDisplay = feePercent == null ? null : '$feePercent%';

    double? gasNative;
    double? gasUsd;
    String? gasSymbol;
    TokenModel? nativeToken;

    if (transaction is Map) {
      final gas = transaction['gas']?.toString() ?? transaction['gasLimit']?.toString();
      final gasPrice = transaction['maxFeePerGas']?.toString() ??
          transaction['gasPrice']?.toString();

      if (gas != null && gasPrice != null) {
        final gasLimit = double.tryParse(gas);
        final pricePerGas = double.tryParse(gasPrice);
        if (gasLimit != null && pricePerGas != null) {
          gasNative = (gasLimit * pricePerGas) / 1000000000000000000.0;
        }
      }

      try {
        nativeToken = context.read<WalletProvider>().tokens.firstWhere(
              (token) =>
                  token.isNative &&
                  token.chain.toLowerCase() == _fromToken?.chain.toLowerCase(),
            );
        gasSymbol = nativeToken.symbol;
        if (gasNative != null && nativeToken.priceUsd.toDouble() > 0) {
          gasUsd = gasNative * nativeToken.priceUsd.toDouble();
        }
      } catch (_) {
        // Do not invent a price. The UI will show the native gas amount only.
      }
    }

    final providerIncluded = providerFee['included'] == true ||
        providerFee['reportedByProvider'] != true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: colors.onSurfaceVariant.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              Text(
                'Quote Details',
                style: text.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _quoteRow(context, 'Provider', _quote?['provider']?.toString() ?? '-'),
          const SizedBox(height: 10),
          _quoteRow(
            context,
            'Service rate',
            feePercentDisplay ?? '0.8%',
            valueColor: colors.primary,
            isBold: true,
          ),
          const SizedBox(height: 10),
          _quoteRow(
            context,
            'Aggregator fee',
            providerIncluded ? 'Included' :
                _formatFeeAmount(
                  providerFee['amount']?.toString(),
                  _tokenForAddress(providerFee['token']?.toString()),
                ),
          ),
          const SizedBox(height: 10),
          _quoteRow(
            context,
            'Network fee',
            gasNative == null
                ? '-'
                : WalletFormatters.formatBalance(gasNative, symbol: gasSymbol),
            subtitle: gasUsd == null
                ? null
                : (gasUsd < 0.01 ? '< \$0.01' : WalletFormatters.formatCurrency(gasUsd)),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    return value is Map<String, dynamic>
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  Widget _quoteRow(
    BuildContext context,
    String label,
    String value, {
    String? subtitle,
    bool isBold = false,
    Color? valueColor,
  }) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: subtitle != null
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: text.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant.withValues(alpha: 0.7),
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: text.bodyMedium?.copyWith(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? colors.onSurface,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: text.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
```

### [token_icon.dart](file:///Users/newuser/cowrie_griot/lib/features/wallet/widgets/token_icon.dart)
```dart
import 'package:flutter/material.dart';

import '../utils/chain_assets.dart';

class TokenIcon extends StatelessWidget {
  final String imageUrl;
  final String symbol;
  final String? name;
  final String? chainName;
  final bool isNative;
  final double radius;

  const TokenIcon({
    super.key,
    this.imageUrl = '',
    this.symbol = '',
    this.name,
    this.chainName,
    this.isNative = false,
    this.radius = 24,
  });

  String _initials() {
    final cleanedName = (name ?? '').trim();
    final cleanedSymbol = symbol.trim();
    final source = cleanedName.isNotEmpty ? cleanedName : cleanedSymbol;

    if (source.isEmpty) return '?';

    final words = source
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.length >= 2) {
      return '${words.first[0]}${words.last[0]}'.toUpperCase();
    }

    final value = words.first.toUpperCase();
    return value.length >= 2 ? value.substring(0, 2) : value;
  }

  Widget _initialFallback(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initials = _initials();

    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.surfaceContainerHighest,
      child: Text(
        initials,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          fontSize: radius * (initials.length > 1 ? 0.48 : 0.65),
        ),
      ),
    );
  }

  Widget _remoteTokenImage(BuildContext context) {
    final url = imageUrl.trim();

    if (url.isEmpty) {
      return _initialFallback(context);
    }

    return ClipOval(
      child: Image.network(
        url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _initialFallback(context),
      ),
    );
  }

  Widget _tokenImage(BuildContext context) {
    return _remoteTokenImage(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _tokenImage(context),
          if (chainName != null && chainName!.trim().isNotEmpty)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: radius * 0.78,
                height: radius * 0.78,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.outlineVariant,
                    width: 0.7,
                  ),
                ),
                child: ChainAssets.getIcon(
                  chainName!,
                  size: radius * 0.55,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

---

## 2. Service Layer (Logic & APIs)

### [swap_api_service.dart](file:///Users/newuser/cowrie_griot/lib/features/wallet/services/swap_api_service.dart)
```dart
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

  Future<Map<String, dynamic>> broadcastSwap({
    required String network,
    required String signedTransaction,
    String? transactionType,
  }) async {
    final response = await _apiClient.post(
      '${ApiConfig.swapBase}/broadcast',
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
```

### [wallet_crypto_service.dart](file:///Users/newuser/cowrie_griot/lib/features/wallet/services/wallet_crypto_service.dart)
```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:wallet/wallet.dart' as wallet;
import 'package:web3dart/web3dart.dart' as web3;

class WalletCryptoService {
  static const String derivationPath = "m/44'/60'/0'/0/0";

  Future<WalletData> createWallet() async {
    return compute(_createWalletIsolate, null);
  }

  Future<WalletData> restoreWallet(String mnemonic) async {
    final normalizedMnemonic = mnemonic
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();

    if (normalizedMnemonic.isEmpty) {
      throw Exception('Mnemonic phrase cannot be empty.');
    }

    return compute(_restoreWalletIsolate, normalizedMnemonic);
  }

  static WalletData _createWalletIsolate(dynamic _) {
    final mnemonicWords = wallet.generateMnemonic(strength: 128);
    final mnemonic = mnemonicWords.join(' ');
    return _fromMnemonic(mnemonic);
  }

  static WalletData _restoreWalletIsolate(String mnemonic) {
    final words = mnemonic.split(' ');

    if (!wallet.validateMnemonic(words)) {
      throw Exception('Invalid mnemonic phrase.');
    }

    return _fromMnemonic(mnemonic);
  }

  static WalletData _fromMnemonic(String mnemonic) {
    final words = mnemonic.split(' ');
    final seed = wallet.mnemonicToSeed(words);

    final master = wallet.ExtendedPrivateKey.master(
      seed,
      wallet.xprv,
    );

    final derived = master.forPath(derivationPath);

    if (derived is! wallet.ExtendedPrivateKey) {
      throw Exception('Failed to derive Ethereum private key.');
    }

    final privateKey = wallet.PrivateKey(derived.key);
    final publicKey = wallet.ethereum.createPublicKey(privateKey);
    final address = wallet.ethereum.createAddress(publicKey);

    return WalletData(
      mnemonic: mnemonic,
      privateKey: _bigIntToHex(privateKey.value),
      publicKey: _bytesToHex(publicKey.value),
      address: address,
    );
  }

  String signMessage({
    required String privateKey,
    required String message,
  }) {
    final normalizedPrivateKey = privateKey
        .trim()
        .replaceFirst(RegExp(r'^0x'), '');

    _validatePrivateKey(normalizedPrivateKey);

    final credentials = web3.EthPrivateKey.fromHex(
      normalizedPrivateKey,
    );

    final messageBytes = Uint8List.fromList(
      utf8.encode(message),
    );

    final signature = credentials.signPersonalMessageToUint8List(
      messageBytes,
    );

    if (signature.length != 65) {
      throw Exception(
        'Invalid Ethereum signature length: ${signature.length}. Expected 65 bytes.',
      );
    }

    return '0x${_bytesToHex(signature)}';
  }

  Future<String> signNativeTransaction({
    required String privateKey,
    required String to,
    required String valueRaw,
    required int nonce,
    required String gasLimit,
    String? gasPrice,
    String? maxFeePerGas,
    String? maxPriorityFeePerGas,
    required int chainId,
    String? dataHex,
  }) async {
    final normalizedPrivateKey = privateKey
        .trim()
        .replaceFirst(RegExp(r'^0x'), '');

    _validatePrivateKey(normalizedPrivateKey);

    if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(to.trim())) {
      throw Exception('Invalid transaction recipient address.');
    }

    final credentials = web3.EthPrivateKey.fromHex(
      normalizedPrivateKey,
    );

    final transactionData = _hexToBytes(dataHex);

    final transaction = web3.Transaction(
      to: web3.EthereumAddress.fromHex(to),
      value: web3.EtherAmount.inWei(
        BigInt.parse(valueRaw),
      ),
      nonce: nonce,
      gasPrice: gasPrice != null
          ? web3.EtherAmount.inWei(BigInt.parse(gasPrice))
          : null,
      maxFeePerGas: maxFeePerGas != null
          ? web3.EtherAmount.inWei(BigInt.parse(maxFeePerGas))
          : null,
      maxPriorityFeePerGas: maxPriorityFeePerGas != null
          ? web3.EtherAmount.inWei(BigInt.parse(maxPriorityFeePerGas))
          : null,
      maxGas: int.parse(gasLimit),
      data: transactionData,
    );

    final signed = web3.signTransactionRaw(
      transaction,
      credentials,
      chainId: chainId,
    );

    return '0x${_bytesToHex(signed)}';
  }

  String encodeErc20Allowance({
    required String owner,
    required String spender,
  }) {
    final ownerClean = owner.toLowerCase().replaceFirst('0x', '').padLeft(64, '0');
    final spenderClean = spender.toLowerCase().replaceFirst('0x', '').padLeft(64, '0');
    return '0xdd62ed3e$ownerClean$spenderClean';
  }

  String encodeErc20Approve({
    required String spender,
    required String amount,
  }) {
    final spenderClean = spender.toLowerCase().replaceFirst('0x', '').padLeft(64, '0');
    final amountClean = BigInt.parse(amount).toRadixString(16).padLeft(64, '0');
    return '0x095ea7b3$spenderClean$amountClean';
  }

  bool isValidAddress(String address) {
    return RegExp(
      r'^0x[a-fA-F0-9]{40}$',
    ).hasMatch(address.trim());
  }

  static Uint8List _hexToBytes(String? value) {
    if (value == null || value.trim().isEmpty || value.trim() == '0x') {
      return Uint8List(0);
    }

    var hex = value.trim();
    if (hex.startsWith('0x')) {
      hex = hex.substring(2);
    }

    if (hex.isEmpty) return Uint8List(0);
    if (!RegExp(r'^[a-fA-F0-9]+$').hasMatch(hex)) {
      throw Exception('Invalid transaction data.');
    }
    if (hex.length.isOdd) {
      throw Exception('Invalid transaction data length.');
    }

    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(
        hex.substring(i * 2, i * 2 + 2),
        radix: 16,
      );
    }

    return bytes;
  }

  static void _validatePrivateKey(String privateKey) {
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(privateKey)) {
      throw Exception('Invalid Ethereum private key.');
    }
  }

  static String _bigIntToHex(BigInt value) {
    return value.toRadixString(16).padLeft(64, '0');
  }

  static String _bytesToHex(Uint8List bytes) {
    final buffer = StringBuffer();

    for (final byte in bytes) {
      buffer.write(
        byte.toRadixString(16).padLeft(2, '0'),
      );
    }

    return buffer.toString();
  }
}

class WalletData {
  final String mnemonic;
  final String privateKey;
  final String publicKey;
  final String address;

  const WalletData({
    required this.mnemonic,
    required this.privateKey,
    required this.publicKey,
    required this.address,
  });
}
```

### [wallet_rpc_service.dart](file:///Users/newuser/cowrie_griot/lib/features/wallet/services/wallet_rpc_service.dart)
```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

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

  Future<String> call({
    required String network,
    required String to,
    required String data,
  }) async {
    final result = await _request(
      network,
      'eth_call',
      [
        {'to': to, 'data': data},
        'latest',
      ],
    );
    return result?.toString() ?? '0x';
  }

  Future<Map<String, dynamic>?> getTransactionReceipt({
    required String network,
    required String hash,
  }) async {
    final result = await _request(
      network,
      'eth_getTransactionReceipt',
      [hash],
    );
    return result is Map ? Map<String, dynamic>.from(result) : null;
  }

  void dispose() {
    _client.close();
  }
}
```

### [transaction_api_service.dart](file:///Users/newuser/cowrie_griot/lib/features/wallet/services/transaction_api_service.dart)
```dart
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
```

---

## 3. Data & Configuration Layer

### [swap_models.dart](file:///Users/newuser/cowrie_griot/lib/features/wallet/models/swap_models.dart)
```dart
class SwapTokenMetadata {
  final String? address;
  final String network;
  final int decimals;
  final bool isNative;

  const SwapTokenMetadata({
    this.address,
    required this.network,
    required this.decimals,
    required this.isNative,
  });

  factory SwapTokenMetadata.fromJson(Map<String, dynamic> json) {
    return SwapTokenMetadata(
      address: json['address']?.toString(),
      network: json['network']?.toString() ?? '',
      decimals: int.tryParse(json['decimals']?.toString() ?? '') ?? 18,
      isNative: json['isNative'] == true || json['is_native'] == true,
    );
  }
}

class SwapSlippage {
  final String mode;
  final double? requested;
  final double? recommended;
  final double? maximumRecommended;
  final bool auto;
  final String? reason;

  const SwapSlippage({
    required this.mode,
    this.requested,
    this.recommended,
    this.maximumRecommended,
    this.auto = false,
    this.reason,
  });

  factory SwapSlippage.fromJson(Map<String, dynamic> json) {
    return SwapSlippage(
      mode: json['mode']?.toString() ?? 'auto',
      requested: double.tryParse(json['requested']?.toString() ?? ''),
      recommended: double.tryParse(json['recommended']?.toString() ?? ''),
      maximumRecommended: double.tryParse(
        json['maximumRecommended']?.toString() ??
            json['maximum_recommended']?.toString() ??
            '',
      ),
      auto: json['auto'] == true,
      reason: json['reason']?.toString(),
    );
  }
}

class SwapTokenTax {
  final bool detected;
  final int? buyTaxBps;
  final int? sellTaxBps;
  final double? buyTaxPercent;
  final double? sellTaxPercent;
  final String? source;

  const SwapTokenTax({
    required this.detected,
    this.buyTaxBps,
    this.sellTaxBps,
    this.buyTaxPercent,
    this.sellTaxPercent,
    this.source,
  });

  factory SwapTokenTax.fromJson(Map<String, dynamic> json) {
    return SwapTokenTax(
      detected: json['detected'] == true,
      buyTaxBps: _nullableInt(json['buyTaxBps'] ?? json['buy_tax_bps']),
      sellTaxBps: _nullableInt(json['sellTaxBps'] ?? json['sell_tax_bps']),
      buyTaxPercent: _nullableDouble(
        json['buyTaxPercent'] ?? json['buy_tax_percent'],
      ),
      sellTaxPercent: _nullableDouble(
        json['sellTaxPercent'] ?? json['sell_tax_percent'],
      ),
      source: json['source']?.toString(),
    );
  }
}

class SwapRisk {
  final double? priceImpact;
  final String? priceImpactSource;
  final SwapTokenTax? tokenTaxes;
  final SwapSlippage? slippage;
  final List<String> warnings;

  const SwapRisk({
    this.priceImpact,
    this.priceImpactSource,
    this.tokenTaxes,
    this.slippage,
    required this.warnings,
  });

  factory SwapRisk.fromJson(Map<String, dynamic> json) {
    final taxJson = json['tokenTaxes'] ?? json['token_taxes'];
    final slippageJson = json['slippage'];

    return SwapRisk(
      priceImpact: _nullableDouble(
        json['priceImpact'] ?? json['price_impact'],
      ),
      priceImpactSource: json['priceImpactSource']?.toString() ??
          json['price_impact_source']?.toString(),
      tokenTaxes: taxJson is Map
          ? SwapTokenTax.fromJson(Map<String, dynamic>.from(taxJson))
          : null,
      slippage: slippageJson is Map
          ? SwapSlippage.fromJson(Map<String, dynamic>.from(slippageJson))
          : null,
      warnings: (json['warnings'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class SwapTransactionRequest {
  final String? from;
  final String? to;
  final String? data;
  final String value;
  final String? gas;
  final String? gasLimit;
  final String? gasPrice;
  final int? chainId;

  const SwapTransactionRequest({
    this.from,
    this.to,
    this.data,
    required this.value,
    this.gas,
    this.gasLimit,
    this.gasPrice,
    this.chainId,
  });

  factory SwapTransactionRequest.fromJson(Map<String, dynamic> json) {
    return SwapTransactionRequest(
      from: json['from']?.toString(),
      to: json['to']?.toString(),
      data: json['data']?.toString(),
      value: json['value']?.toString() ?? '0',
      gas: json['gas']?.toString(),
      gasLimit: json['gasLimit']?.toString() ?? json['gas_limit']?.toString(),
      gasPrice: json['gasPrice']?.toString() ?? json['gas_price']?.toString(),
      chainId: int.tryParse(json['chainId']?.toString() ?? ''),
    );
  }
}

class SwapStatusLookup {
  final String provider;
  final String type;
  final String transactionIdField;
  final String? quoteIdField;

  const SwapStatusLookup({
    required this.provider,
    required this.type,
    required this.transactionIdField,
    this.quoteIdField,
  });

  factory SwapStatusLookup.fromJson(Map<String, dynamic> json) {
    return SwapStatusLookup(
      provider: json['provider']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      transactionIdField: json['transactionIdField']?.toString() ??
          json['transaction_id_field']?.toString() ??
          'transactionId',
      quoteIdField: json['quoteIdField']?.toString() ??
          json['quote_id_field']?.toString(),
    );
  }
}

class SwapQuote {
  final String provider;
  final String type;
  final String fromChain;
  final String toChain;
  final String fromToken;
  final String toToken;
  final String fromAmount;
  final String? toAmount;
  final String? toAmountMin;
  final String? approvalAddress;
  final String? transactionId;
  final String? quoteId;
  final String? bridge;
  final SwapTransactionRequest? transactionRequest;
  final SwapStatusLookup? statusLookup;
  final SwapRisk? risk;
  final Map<String, dynamic>? fee;
  final List<dynamic>? gasCosts;
  final List<dynamic>? feeCosts;
  final List<dynamic>? route;
  final dynamic gas;
  final dynamic gasPrice;
  final dynamic fees;

  const SwapQuote({
    required this.provider,
    required this.type,
    required this.fromChain,
    required this.toChain,
    required this.fromToken,
    required this.toToken,
    required this.fromAmount,
    this.toAmount,
    this.toAmountMin,
    this.approvalAddress,
    this.transactionId,
    this.quoteId,
    this.bridge,
    this.transactionRequest,
    this.statusLookup,
    this.risk,
    this.fee,
    this.gasCosts,
    this.feeCosts,
    this.route,
    this.gas,
    this.gasPrice,
    this.fees,
  });

  factory SwapQuote.fromJson(Map<String, dynamic> json) {
    final txJson = json['transactionRequest'] ?? json['transaction_request'];
    final statusJson = json['statusLookup'] ?? json['status_lookup'];

    return SwapQuote(
      provider: json['provider']?.toString() ?? '',
      type: json['type']?.toString() ?? 'same-chain',
      fromChain: (json['fromChain'] ?? json['from_chain'])?.toString() ?? '',
      toChain: (json['toChain'] ?? json['to_chain'])?.toString() ?? '',
      fromToken: (json['fromToken'] ?? json['from_token'])?.toString() ?? '',
      toToken: (json['toToken'] ?? json['to_token'])?.toString() ?? '',
      fromAmount: (json['fromAmount'] ?? json['from_amount'])?.toString() ?? '0',
      toAmount: (json['toAmount'] ?? json['to_amount'])?.toString(),
      toAmountMin:
          (json['toAmountMin'] ?? json['to_amount_min'])?.toString(),
      approvalAddress:
          (json['approvalAddress'] ?? json['approval_address'])?.toString(),
      transactionId: json['transactionId']?.toString(),
      quoteId: json['quoteId']?.toString(),
      bridge: json['bridge']?.toString(),
      transactionRequest: txJson is Map
          ? SwapTransactionRequest.fromJson(Map<String, dynamic>.from(txJson))
          : null,
      statusLookup: statusJson is Map
          ? SwapStatusLookup.fromJson(Map<String, dynamic>.from(statusJson))
          : null,
      risk: json['risk'] is Map
          ? SwapRisk.fromJson(Map<String, dynamic>.from(json['risk']))
          : null,
      fee: json['fee'] is Map
          ? Map<String, dynamic>.from(json['fee'])
          : null,
      gasCosts: json['gasCosts'] is List ? List<dynamic>.from(json['gasCosts']) : null,
      feeCosts: json['feeCosts'] is List ? List<dynamic>.from(json['feeCosts']) : null,
      route: json['route'] is List ? List<dynamic>.from(json['route']) : null,
      gas: json['gas'],
      gasPrice: json['gasPrice'],
      fees: json['fees'],
    );
  }
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  return int.tryParse(value.toString());
}

double? _nullableDouble(dynamic value) {
  if (value == null) return null;
  return double.tryParse(value.toString());
}
```

### [api_config.dart](file:///Users/newuser/cowrie_griot/lib/core/network/api_config.dart)
```dart
class ApiConfig {
  ApiConfig._();

  static const String baseUrl =
      'http://192.168.1.95:5001/api';

  static const String authNonce = '$baseUrl/auth/nonce';
  static const String authVerify = '$baseUrl/auth/verify';
  static const String authRefresh = '$baseUrl/auth/refresh';
  static const String authLogout = '$baseUrl/auth/logout';

  static const String usersMe = '$baseUrl/users/me';
  static const String usersUpdate = '$baseUrl/users/me';
  static const String usersSearch = '$baseUrl/users/search';
  static const String usernameAvailability =
      '$baseUrl/users/username/availability';

  static const String walletBase = '$baseUrl/crypto/wallets';
  static const String walletNetworks = '$walletBase/networks';
  static const String walletAssets = '$walletBase/assets';

  static String walletAssetsByNetwork(String network) =>
      '$walletBase/assets/$network';

  static String walletCustomToken(
    String network,
    String tokenAddress,
  ) =>
      '$walletBase/custom-token/$network/$tokenAddress';

  static String walletNativeBalance(String network) =>
      '$walletBase/balance/$network';

  static const String walletNativeBalances = '$walletBase/balances';

  static const String walletTokens = '$walletBase/tokens';

  static const String transactionBase =
      '$baseUrl/crypto/transactions';

  static const String prepareNativeTransaction =
      '$transactionBase/prepare-native';

  static const String prepareTokenTransaction =
      '$transactionBase/prepare-token';

  static const String estimateTransaction =
      '$transactionBase/estimate';

  static const String broadcastTransaction =
      '$transactionBase/broadcast';

  static String transactionStatus(
    String transactionId,
    String network,
  ) =>
      Uri.parse(
        '$transactionBase/id/$transactionId/status',
      ).replace(
        queryParameters: {'network': network},
      ).toString();

  static String transactionById(String transactionId) =>
      '$transactionBase/id/$transactionId';

  static String transactionHistory({
    String? walletAccountId,
    String? network,
    int limit = 20,
    int offset = 0,
  }) {
    final query = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
    };

    if (walletAccountId != null && walletAccountId.isNotEmpty) {
      query['walletAccountId'] = walletAccountId;
    }

    if (network != null && network.isNotEmpty) {
      query['network'] = network;
    }

    return Uri.parse(
      '$transactionBase/history',
    ).replace(
      queryParameters: query,
    ).toString();
  }

  static const String swapBase =
      '$baseUrl/crypto/swap';

  static const String swapQuote =
      '$swapBase/quote';

  static String swapStatus({
    required String transactionId,
    String? provider,
    String? fromChain,
    String? toChain,
    String? bridge,
    String? quoteId,
    String? fromAddress,
    String? swapType,
  }) {
    final query = <String, String>{
      'transactionId': transactionId,
    };

    if (provider != null && provider.isNotEmpty) {
      query['provider'] = provider;
    }

    if (fromChain != null && fromChain.isNotEmpty) {
      query['fromChain'] = fromChain;
    }

    if (toChain != null && toChain.isNotEmpty) {
      query['toChain'] = toChain;
    }

    if (bridge != null && bridge.isNotEmpty) {
      query['bridge'] = bridge;
    }

    if (quoteId != null && quoteId.isNotEmpty) {
      query['quoteId'] = quoteId;
    }

    if (fromAddress != null && fromAddress.isNotEmpty) {
      query['fromAddress'] = fromAddress;
    }

    if (swapType != null && swapType.isNotEmpty) {
      query['swapType'] = swapType;
    }

    return Uri.parse(
      '$swapBase/status',
    ).replace(
      queryParameters: query,
    ).toString();
  }

  static const String swapHealth =
      '$swapBase/health';

  static const String miningBase =
      '$baseUrl/crypto/mining';

  static const String miningStatus =
      '$miningBase/status';

  static const String miningStart =
      '$miningBase/start';

  static String miningHistory({
    int limit = 20,
    int offset = 0,
  }) =>
      Uri.parse(
        '$miningBase/history',
      ).replace(
        queryParameters: {
          'limit': '$limit',
          'offset': '$offset',
        },
      ).toString();

  static const String referralBase =
      '$baseUrl/crypto/referrals';

  static const String referralStats =
      '$referralBase/stats';

  static String referralList({
    int limit = 20,
    int offset = 0,
  }) =>
      Uri.parse(
        '$referralBase/list',
      ).replace(
        queryParameters: {
          'limit': '$limit',
          'offset': '$offset',
        },
      ).toString();
}
```

### [api_client.dart](file:///Users/newuser/cowrie_griot/lib/core/network/api_client.dart)
```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../features/auth/services/auth_storage_service.dart';

import 'api_exception.dart';
import 'api_config.dart';

class ApiClient {
  final http.Client _client;
  final AuthStorageService _authStorageService;

  ApiClient({
    http.Client? client,
    AuthStorageService? authStorageService,
  })  : _client = client ?? http.Client(),
        _authStorageService =
            authStorageService ?? AuthStorageService();

  Future<dynamic> get(
      String url, {
        Map<String, String>? headers,
      }) async {
    return _request(
      method: 'GET',
      url: url,
      headers: headers,
    );
  }

  Future<dynamic> post(
      String url, {
        Map<String, dynamic>? body,
        Map<String, String>? headers,
      }) async {
    return _request(
      method: 'POST',
      url: url,
      body: body,
      headers: headers,
    );
  }

  Future<dynamic> _request({
    required String method,
    required String url,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool isRetry = false,
  }) async {
    final uri = Uri.parse(url);

    final accessToken =
    await _authStorageService.getAccessToken();

    final requestHeaders = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?headers,
    };

    if (accessToken != null && accessToken.isNotEmpty) {
      requestHeaders['Authorization'] = 'Bearer $accessToken';
    }

    http.Response response;

    try {
      switch (method) {
        case 'GET':
          response = await _client.get(uri, headers: requestHeaders);
          break;
        case 'POST':
          response = await _client.post(uri, headers: requestHeaders, body: body == null ? null : jsonEncode(body));
          break;
        default:
          throw ApiException(message: 'Unsupported HTTP method: $method');
      }
    } catch (error) {
      throw ApiException(message: 'Unable to connect to the server.', originalError: error);
    }

    dynamic data;
    if (response.body.isNotEmpty) {
      data = jsonDecode(response.body);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    if (response.statusCode == 401 && !isRetry && url != ApiConfig.authRefresh) {
      // Refresh token logic...
    }

    throw ApiException(message: 'Request failed', statusCode: response.statusCode, data: data);
  }

  void dispose() {
    _client.close();
  }
}
```

---

## 4. Integration & Orchestration

### [app.dart](file:///Users/newuser/cowrie_griot/lib/app.dart)
```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/startup/app_startup_service.dart';

import 'features/auth/services/auth_api_service.dart';
import 'features/auth/services/auth_session_service.dart';
import 'features/auth/services/auth_storage_service.dart';
import 'features/auth/services/wallet_auth_service.dart';
import 'features/users/providers/user_provider.dart';
import 'features/users/services/user_api_service.dart';
import 'features/wallet/services/wallet_crypto_service.dart';
import 'features/wallet/services/wallet_service.dart';
import 'features/wallet/services/wallet_storage_service.dart';

import 'features/wallet/services/wallet_api_service.dart';
import 'features/wallet/services/transaction_api_service.dart';
import 'features/wallet/services/swap_api_service.dart';
import 'features/wallet/services/wallet_rpc_service.dart';
import 'features/miner/services/mining_api_service.dart';
import 'features/miner/services/referral_api_service.dart';
import 'features/wallet/providers/wallet_provider.dart';
import 'core/services/navigation_scroll_service.dart';

class GriotCowrieApp extends StatefulWidget {
  const GriotCowrieApp({super.key});

  @override
  State<GriotCowrieApp> createState() => _GriotCowrieAppState();
}

class _GriotCowrieAppState extends State<GriotCowrieApp> {
  final ThemeController _themeController = ThemeController.instance;

  late final ApiClient _apiClient;
  late final UserApiService _userApiService;
  late final WalletService _walletService;
  late final AuthApiService _authApiService;
  late final AuthSessionService _authSessionService;
  late final WalletApiService _walletApiService;
  late final TransactionApiService _transactionApiService;
  late final SwapApiService _swapApiService;
  late final WalletRpcService _walletRpcService;
  late final MiningApiService _miningApiService;
  late final ReferralApiService _referralApiService;

  @override
  void initState() {
    super.initState();

    _apiClient = ApiClient();
    final walletStorage = WalletStorageService();
    final authStorage = AuthStorageService();

    _walletService = WalletService(
      cryptoService: WalletCryptoService(),
      storageService: walletStorage,
    );

    _userApiService = UserApiService(apiClient: _apiClient);
    _walletApiService = WalletApiService(apiClient: _apiClient);
    _transactionApiService = TransactionApiService(apiClient: _apiClient);
    _swapApiService = SwapApiService(apiClient: _apiClient);
    _walletRpcService = WalletRpcService();
    _miningApiService = MiningApiService(apiClient: _apiClient);
    _referralApiService = ReferralApiService(apiClient: _apiClient);
    _authApiService = AuthApiService(apiClient: _apiClient, authStorageService: authStorage);

    final walletAuthService = WalletAuthService(
      walletService: _walletService,
      authApiService: _authApiService,
    );

    _authSessionService = AuthSessionService(
      walletService: _walletService,
      authApiService: _authApiService,
      authStorageService: authStorage,
      walletAuthService: walletAuthService,
    );

    AppRouter.setThemeController(_themeController);
  }

  @override
  void dispose() {
    _apiClient.dispose();
    _walletRpcService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<WalletService>.value(value: _walletService),
        Provider<AuthSessionService>.value(value: _authSessionService),
        Provider<WalletApiService>.value(value: _walletApiService),
        Provider<TransactionApiService>.value(value: _transactionApiService),
        Provider<SwapApiService>.value(value: _swapApiService),
        Provider<WalletRpcService>.value(value: _walletRpcService),
        Provider<MiningApiService>.value(value: _miningApiService),
        Provider<ReferralApiService>.value(value: _referralApiService),
        ChangeNotifierProvider<NavigationScrollService>.value(
          value: NavigationScrollService.instance,
        ),
        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider(userApiService: _userApiService),
        ),
        ChangeNotifierProvider<WalletProvider>(
          create: (_) => WalletProvider(
            walletService: _walletService,
            walletApiService: _walletApiService,
          )..loadWallet(),
        ),
        ProxyProvider2<AuthSessionService, UserProvider, AppStartupService>(
          update: (_, auth, user, previous) => AppStartupService(
            authSessionService: auth,
            userProvider: user,
          ),
        ),
      ],
      child: AnimatedBuilder(
        animation: _themeController,
        builder: (context, _) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.theme(
              style: _themeController.themeStyle,
              brightness: Brightness.light,
            ),
            darkTheme: AppTheme.theme(
              style: _themeController.themeStyle,
              brightness: Brightness.dark,
            ),
            themeMode: _themeController.themeMode,
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
```
