import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/token_model.dart';
import '../providers/wallet_provider.dart';
import '../services/swap_api_service.dart';
import '../services/wallet_service.dart';
import '../services/transaction_api_service.dart';
import '../widgets/token_icon.dart';
import '../utils/wallet_formatters.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/banner_ad.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/transaction_logger.dart';

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
  
  String _slippageMode = 'auto';
  double? _customSlippageValue;

  double get _effectiveSlippage => _customSlippageValue ?? 0.01;

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
    
    final swapApi = context.read<SwapApiService>();
    final walletProvider = context.read<WalletProvider>();
    final walletService = context.read<WalletService>();
    final fromAddress = walletProvider.wallet?.address;

    if (fromAddress == null || fromAddress.isEmpty) return;

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
          'Amount exceeds your balance of $maxBalance ${fromToken.symbol}',
        );
      }
      return;
    }

    final fromTokenAddress = fromToken.isNative
        ? _nativeTokenAddress
        : fromToken.contractAddress;
    final toTokenAddress = toToken.isNative
        ? _nativeTokenAddress
        : toToken.contractAddress;

    if (fromTokenAddress.isEmpty || toTokenAddress.isEmpty) return;

    final fromAmountRaw = _toBaseUnits(amount, fromToken.decimals);
    if (fromAmountRaw == null || fromAmountRaw == '0') return;

    final requestVersion = ++_quoteRequestVersion;
    setState(() => _isLoading = true);

    try {
      final isCrossChain = fromToken.chain.toLowerCase() !=
          toToken.chain.toLowerCase();

      final quoteResponse = await swapApi.getQuote(
            fromChain: fromToken.chain,
            toChain: toToken.chain,
            fromToken: fromTokenAddress,
            toToken: toTokenAddress,
            fromAmount: fromAmountRaw,
            fromAddress: fromAddress,
            toAddress: isCrossChain ? fromAddress : null,
            modeOfSlippage: _slippageMode,
            slippage: _slippageMode == 'custom' ? _effectiveSlippage : null,
          );

      if (!mounted || requestVersion != _quoteRequestVersion) return;

      final quote = quoteResponse;
      
      final tx = quote['transactionRequest'] ?? quote['transaction'];
      if (tx is! Map) {
        throw Exception('Incomplete quote: missing transaction data.');
      }
      
      final requiredFields = ['to', 'data', 'value', 'chainId'];
      for (final field in requiredFields) {
        if (tx[field] == null) {
          throw Exception('Incomplete quote: missing field $field.');
        }
      }

      bool approvalNeeded = false;
      final approvalAddress = quote['approvalAddress']?.toString();
      if (approvalAddress != null &&
          approvalAddress.isNotEmpty &&
          !fromToken.isNative) {
        try {
          final allowanceHex = await swapApi.call(
            network: fromToken.chain,
            to: fromToken.contractAddress,
            data: walletService.crypto.encodeErc20Allowance(
              owner: fromAddress,
              spender: approvalAddress,
            ),
          );
          final allowance = BigInt.tryParse(allowanceHex.replaceFirst('0x', ''), radix: 16) ?? BigInt.zero;
          final requiredAmount = BigInt.tryParse(fromAmountRaw) ?? BigInt.zero;

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
        NotificationService.showError(context, 'Unable to get swap quote: $e');
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
    final walletProvider = context.read<WalletProvider>();
    final fromAddress = walletProvider.wallet?.address;

    if (quote == null || fromToken == null || fromAddress == null) {
      if (mounted) NotificationService.showError(context, 'Wallet session missing.');
      return;
    }

    final walletService = context.read<WalletService>();
    final swapApi = context.read<SwapApiService>();
    final transactionApi = context.read<TransactionApiService>();

    final amount = _amountController.text.trim();
    final enteredAmount = double.tryParse(amount) ?? 0.0;
    if (enteredAmount > fromToken.balance.toDouble()) {
      NotificationService.showError(context, 'Insufficient balance.');
      return;
    }

    final rawTransaction = quote['transactionRequest'] ?? quote['transaction'];
    if (rawTransaction is! Map) {
      NotificationService.showError(context, 'Invalid transaction data.');
      return;
    }

    final transaction = Map<String, dynamic>.from(rawTransaction);

    final to = transaction['to']?.toString();
    final data = transaction['data']?.toString();
    final value = transaction['value']?.toString() ?? '0';
    final chainIdStr = transaction['chainId']?.toString() ?? '';
    final chainId = int.tryParse(chainIdStr);
    int? nonce = int.tryParse(transaction['nonce']?.toString() ?? '');
    String? gasLimit = transaction['gasLimit']?.toString() ?? transaction['gas']?.toString();
    final gasPrice = transaction['gasPrice']?.toString();
    final maxFeePerGas = transaction['maxFeePerGas']?.toString();
    final maxPriorityFeePerGas = transaction['maxPriorityFeePerGas']?.toString();

    if (to == null || to.isEmpty || data == null || data.isEmpty || chainId == null) {
      NotificationService.showError(context, 'Incomplete transaction data.');
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

    // Dismiss keyboard and focus before proceeding with transaction
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Preparing...';
    });
    try {
      nonce ??= await swapApi.getNonce(
          network: fromToken.chain,
          address: fromAddress,
        );
      
      final networkChainId = _getExpectedChainId(fromToken.chain);
      if (networkChainId == null || chainId != networkChainId) {
        throw Exception('Transaction chain ID mismatch for ${fromToken.chain}');
      }

      if (gasLimit == null) {
        final estimate = await transactionApi.estimateTransaction(
          network: fromToken.chain,
          transaction: {
            'from': fromAddress,
            'to': to,
            'value': value,
            'data': data,
          },
        );
        gasLimit = estimate['gasLimit']?.toString() ?? '300000';
      }

      if (mounted) setState(() => _loadingMessage = 'Signing...');
      
      // Ensure focus is dismissed
      if (mounted) FocusScope.of(context).unfocus();

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
        throw Exception('Failed to sign transaction.');
      }

      if (mounted) setState(() => _loadingMessage = 'Broadcasting...');

      final broadcastResult = await swapApi.broadcastSwap(
        network: fromToken.chain,
        signedTransaction: signedTx,
        transactionType: 'swap',
      );

      final hash = broadcastResult['hash']?.toString();

      TransactionLogger.log(
        endpoint: '/crypto/swap/broadcast',
        network: fromToken.chain,
        chainId: chainId,
        transactionHash: hash,
        backendError: broadcastResult['message'],
      );

      if (hash == null || hash.isEmpty) {
        throw Exception('Broadcast failed.');
      }

      if (mounted) setState(() => _loadingMessage = 'Confirming...');

      if (mounted) {
        await _pollSwapStatus(hash);
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
    final walletProvider = context.read<WalletProvider>();
    final fromAddress = walletProvider.wallet?.address;

    if (quote == null || fromToken == null || fromAddress == null) return;

    final approvalAddress = quote['approvalAddress']?.toString();
    if (approvalAddress == null || approvalAddress.isEmpty) return;

    final walletService = context.read<WalletService>();
    final transactionApi = context.read<TransactionApiService>();
    final swapApi = context.read<SwapApiService>();

    final network = fromToken.chain;

    setState(() {
      _isApproving = true;
      _loadingMessage = 'Preparing...';
    });
    try {
      final fromAmountRaw = _toBaseUnits(_amountController.text, fromToken.decimals);
      final data = walletService.crypto.encodeErc20Approve(
        spender: approvalAddress,
        amount: fromAmountRaw!,
      );

      final nonce = await swapApi.getNonce(
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
      final chainId = int.tryParse(transactionRequest['chainId']?.toString() ?? '');
      
      if (chainId == null) {
        throw Exception('Approval chain ID is missing');
      }

      final networkChainId = _getExpectedChainId(network);
      if (networkChainId == null || chainId != networkChainId) {
        throw Exception('Approval network and chain ID do not match');
      }

      if (mounted) setState(() => _loadingMessage = 'Signing...');
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

      if (mounted) setState(() => _loadingMessage = 'Approving...');

      if (mounted) {
        final broadcastResult = await swapApi.broadcastSwap(
          network: network,
          signedTransaction: signedTx!,
          transactionType: 'approval',
        );

        final hash = broadcastResult['hash']?.toString();
        
        TransactionLogger.log(
          endpoint: '/crypto/swap/broadcast',
          network: network,
          chainId: chainId,
          transactionHash: hash,
          backendError: broadcastResult['message'],
        );

        if (hash == null || hash.isEmpty) {
          throw Exception('Approval failed.');
        }

        bool isConfirmed = false;
        for (int i = 0; i < 30; i++) {
          if (mounted) setState(() => _loadingMessage = 'Waiting for confirmation...');
          await Future.delayed(const Duration(seconds: 5));
          if (!mounted) return;

          final receipt = await swapApi.getReceipt(
            network: network,
            hash: hash,
          );

          if (receipt['status'] != null) {
            final status = receipt['status']?.toString();
            if (status == '0x1' || status == '1') {
              isConfirmed = true;
            } else if (status == '0x0' || status == '0') {
              throw Exception('Approval transaction failed on-chain.');
            }
            break;
          }
        }

        if (isConfirmed) {
          if (mounted) {
            NotificationService.showSuccess(context, 'Token approved!');
            await _getQuote();
          }
        } else {
          throw Exception('Timed out.');
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Review Swap',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 32),
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
                        radius: 24,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        fromAmount,
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        fromToken.symbol,
                        style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: colors.primary.withValues(alpha: 0.4), size: 28),
                Expanded(
                  child: Column(
                    children: [
                      TokenIcon(
                        imageUrl: toToken.imageUrl,
                        symbol: toToken.symbol,
                        name: toToken.name,
                        chainName: toToken.chain,
                        isNative: toToken.isNative,
                        radius: 24,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        toAmount,
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: colors.primary),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        toToken.symbol,
                        style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: const Text('CONFIRM SWAP', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: colors.onSurfaceVariant)),
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
    final walletProvider = context.read<WalletProvider>();
    // Backend expects the canonical provider identifiers `lifi` or `0x`.
    final provider = (quote['provider']?.toString().toLowerCase() ?? '')
        .replaceAll('.', '')
        .replaceAll('-', '');
    final swapType = quote['type']?.toString();
    final quoteId = quote['quoteId']?.toString();

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
            await walletProvider.loadWallet();
            if (mounted) Navigator.of(context).pop();
          }
          return;
        } else if (status == 'FAILED' || status == 'ERROR') {
          if (mounted) {
            final msg = statusData['message']?.toString() ?? 'Failed.';
            NotificationService.showError(context, 'Swap failed: $msg');
          }
          return;
        }
      } catch (e) {
        debugPrint('Status poll failed: $e');
      }
    }

    if (mounted) {
      NotificationService.showInfo(
        context,
        'Swap is still pending. Check your history later.',
      );
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

  int? _getExpectedChainId(String network) {
    const expectedChainIds = {
      'ethereum': 1,
      'base': 8453,
      'polygon': 137,
      'arbitrum': 42161,
      'optimism': 10,
      'bsc': 56,
    };
    return expectedChainIds[network.toLowerCase()];
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

  Future<void> _showTokenPicker(BuildContext context, {required bool isFrom}) async {
    final selected = await context.push<TokenModel>('/wallet/search?mode=select');
    
    if (selected != null && mounted) {
      setState(() {
        if (isFrom) {
          _fromToken = selected;
        } else {
          _toToken = selected;
        }
        _quote = null;
        _amountController.clear();
        _usdController.clear();
      });
      _getQuote();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GradientScaffold(
        appBar: AppBar(
          title: Text(
            'SWAP',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        bottomNavigationBar: const SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GriotBannerAd(),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Decorative Glow
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colors.primary.withValues(alpha: 0.1),
                      colors.primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
               .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 5.seconds),
            ),

            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        children: [
                          _buildSwapCard(
                            context,
                            label: 'You Pay',
                            token: _fromToken,
                            controller: _isUsdMode ? _usdController : _amountController,
                            onChanged: _onAmountChanged,
                            showCurrencyToggle: true,
                            onMaxTap: _onMaxPressed,
                            subValue: _isUsdMode
                              ? '${_amountController.text} ${_fromToken?.symbol ?? ""}'
                              : (_usdController.text.isNotEmpty ? '\$${_usdController.text}' : null),
                            onTokenTap: () => _showTokenPicker(context, isFrom: true),
                          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                          const SizedBox(height: 8),
                          _buildSwapCard(
                            context,
                            label: 'You Receive',
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
                          ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1, end: 0),
                        ],
                      ),
                      Positioned(
                        child: Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: colors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.2), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _swapTokens,
                              customBorder: const CircleBorder(),
                              child: Icon(Icons.swap_vert_rounded, color: colors.primary, size: 26),
                            ),
                          ),
                        ),
                      ).animate().scale(delay: 300.ms),
                    ],
                  ),
                  if (_quote != null) ...[
                    const SizedBox(height: 24),
                    _buildQuoteDetails(context).animate().fadeIn(),
                  ],
                  const SizedBox(height: 16),
                  _buildSlippageSettings(context).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 48),
                  
                  // Premium Action Pill
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: (_quote != null && !_isLoading && !_isApproving)
                          ? (_isApprovalRequired ? _handleApprove : _handleSwap)
                          : null,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: (_isLoading || _isApproving)
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white60,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    _loadingMessage,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white),
                                  ),
                                ],
                              )
                            : Center(
                                child: Text(
                                  _isApprovalRequired
                                      ? 'APPROVE ${_fromToken?.symbol ?? "TOKEN"}'
                                      : 'SWAP ASSETS',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5, color: Colors.white),
                                ),
                              ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 600.ms, delay: 400.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
                ],
              ),
            ),
          ],
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(32),
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
                label.toUpperCase(),
                style: text.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              if (token != null)
                Text(
                  'Bal: ${WalletFormatters.formatBalance(token.balance)}',
                  style: text.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w700,
                  ),
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
                          style: text.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: (value == null || value == '0.00')
                                ? colors.onSurface.withValues(alpha: 0.1)
                                : colors.onSurface,
                          ),
                        ),
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          if (showCurrencyToggle && _isUsdMode)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                r'$',
                                style: text.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                          Expanded(
                            child: TextField(
                              controller: controller,
                              onChanged: onChanged,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textInputAction: TextInputAction.done,
                              cursorHeight: 28,
                              cursorWidth: 2,
                              style: text.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: colors.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: '0',
                                hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.1)),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 4),
                    if (subValue != null && subValue.isNotEmpty)
                      Text(
                        subValue,
                        style: text.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTokenTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                    decoration: BoxDecoration(
                      color: token == null ? colors.primary : colors.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        if (token == null)
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                      ],
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
                          const SizedBox(width: 10),
                          Text(
                            token.symbol,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ] else
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              'Select',
                              style: text.titleSmall?.copyWith(
                                color: colors.onPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: token == null ? colors.onPrimary : colors.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (showCurrencyToggle) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                InkWell(
                  onTap: _toggleCurrencyMode,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isUsdMode ? Icons.toll_rounded : Icons.attach_money_rounded,
                          size: 14,
                          color: colors.secondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isUsdMode ? 'Use ${token?.symbol ?? "Token"}' : 'Use USD',
                          style: text.labelSmall?.copyWith(
                            color: colors.secondary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (onMaxTap != null)
                  InkWell(
                    onTap: onMaxTap,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'MAX',
                        style: text.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuoteDetails(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
      } catch (_) { }
    }

    final providerIncluded = providerFee['included'] == true ||
        providerFee['reportedByProvider'] != true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _quoteRow(context, 'Rate', feePercentDisplay ?? '0.8%', valueColor: colors.primary, isBold: true),
          const SizedBox(height: 10),
          _quoteRow(context, 'Fee', providerIncluded ? 'Included' :
                _formatFeeAmount(
                  providerFee['amount']?.toString(),
                  _tokenForAddress(providerFee['token']?.toString()),
                )),
          const SizedBox(height: 10),
          _quoteRow(
            context,
            'Network Cost',
            gasNative == null
                ? '-'
                : WalletFormatters.formatBalance(gasNative, symbol: gasSymbol),
            subtitle: gasUsd == null
                ? null
                : (gasUsd < 0.01 ? r'< $0.01' : WalletFormatters.formatCurrency(gasUsd)),
          ),
        ],
      ),
    );
  }

  Widget _buildSlippageSettings(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    String displayValue;
    if (_slippageMode == 'auto') {
      displayValue = 'Auto';
    } else {
      displayValue = '${(_effectiveSlippage * 100).toStringAsFixed(1)}%';
    }

    return InkWell(
      onTap: () => _showSlippagePicker(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.tune_rounded, size: 20, color: colors.onSurfaceVariant.withValues(alpha: 0.6)),
            const SizedBox(width: 14),
            Text(
              'Slippage Tolerance',
              style: text.bodySmall?.copyWith(
                color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const Spacer(),
            Text(
              displayValue,
              style: text.bodyMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 20, color: colors.primary.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  void _showSlippagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _SlippagePickerSheet(
        initialMode: _slippageMode,
        initialValue: _customSlippageValue ?? 0.01,
        onChanged: (mode, value) {
          setState(() {
            _slippageMode = mode;
            _customSlippageValue = value;
          });
          _getQuote();
        },
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
      children: [
        Text(
          label,
          style: text.bodySmall?.copyWith(
            color: colors.onSurfaceVariant.withValues(alpha: 0.6),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  value,
                  style: text.bodySmall?.copyWith(
                    fontWeight: isBold ? FontWeight.w900 : FontWeight.w800,
                    color: valueColor ?? colors.onSurface,
                  ),
                ),
              ),
              if (subtitle != null)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    subtitle,
                    style: text.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SlippagePickerSheet extends StatefulWidget {
  final String initialMode;
  final double initialValue;
  final Function(String mode, double? value) onChanged;

  const _SlippagePickerSheet({
    required this.initialMode,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_SlippagePickerSheet> createState() => _SlippagePickerSheetState();
}

class _SlippagePickerSheetState extends State<_SlippagePickerSheet> {
  late String _mode;
  late TextEditingController _controller;
  final List<double> _presets = [0.005, 0.01, 0.02, 0.03, 0.05, 0.10];

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _controller = TextEditingController(
      text: (widget.initialValue * 100).toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_mode == 'auto') {
      widget.onChanged('auto', null);
    } else {
      final val = double.tryParse(_controller.text) ?? 1.0;
      widget.onChanged('custom', val / 100);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final double? currentVal = double.tryParse(_controller.text);

    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text('Swap Settings', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          
          // Auto / Custom Toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _mode = 'auto'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _mode == 'auto' ? colors.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _mode == 'auto' ? [BoxShadow(color: Colors.black12, blurRadius: 4)] : null,
                      ),
                      alignment: Alignment.center,
                      child: Text('Auto', style: TextStyle(fontWeight: _mode == 'auto' ? FontWeight.bold : FontWeight.normal)),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _mode = 'custom'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _mode == 'custom' ? colors.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _mode == 'custom' ? [BoxShadow(color: Colors.black12, blurRadius: 4)] : null,
                      ),
                      alignment: Alignment.center,
                      child: Text('Custom', style: TextStyle(fontWeight: _mode == 'custom' ? FontWeight.bold : FontWeight.normal)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (_mode == 'custom') ...[
            const SizedBox(height: 24),
            Text('Custom Slippage', style: text.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      suffixText: '%',
                      hintText: '1.0',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((val) {
                final pct = (val * 100);
                final isSelected = currentVal == pct;
                return InkWell(
                  onTap: () => setState(() => _controller.text = pct.toStringAsFixed(pct == pct.toInt() ? 0 : 1)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? colors.primary : colors.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${pct.toStringAsFixed(pct == pct.toInt() ? 0 : 1)}%', 
                      style: TextStyle(color: isSelected ? colors.onPrimary : colors.onSurface, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                );
              }).toList(),
            ),
            if (currentVal != null && currentVal > 5) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (currentVal > 15 ? colors.error : Colors.orange).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: currentVal > 15 ? colors.error : Colors.orange, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        currentVal > 15 
                          ? 'Extremely high slippage. You may lose a significant portion of your tokens.'
                          : 'High slippage. Your transaction might be front-run or result in a poor rate.',
                        style: TextStyle(
                          color: currentVal > 15 ? colors.error : Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            const SizedBox(height: 24),
            Text(
              'Griot will automatically adjust your slippage to ensure the best possible success rate for your trade.',
              style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant.withValues(alpha: 0.6), height: 1.4),
            ),
          ],
          
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
