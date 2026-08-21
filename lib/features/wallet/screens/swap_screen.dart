import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

class SwapScreen extends StatefulWidget {
  final TokenModel? initialFromToken;

  const SwapScreen({
    super.key,
    this.initialFromToken,
  });

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  static const String _nativeTokenAddress =
      '0x0000000000000000000000000000000000000000';

  TokenModel? _fromToken;
  TokenModel? _toToken;
  final _amountController = TextEditingController();
  bool _isLoading = false;
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
    _debounce?.cancel();
    super.dispose();
  }

  void _onAmountChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 500),
      _getQuote,
    );
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
      final quote = await context.read<SwapApiService>().getQuote(
            fromChain: fromToken.chain,
            toChain: toToken.chain,
            fromToken: fromTokenAddress,
            toToken: toTokenAddress,
            fromAmount: fromAmount,
            fromAddress: fromAddress,
          );

      if (!mounted || requestVersion != _quoteRequestVersion) return;
      setState(() => _quote = quote);
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
    if (quote == null) return;

    final fromAddress = context.read<WalletProvider>().wallet?.address;
    if (fromAddress == null || fromAddress.isEmpty) {
      NotificationService.showError(
        context,
        'Wallet address not found.',
      );
      return;
    }

    final apiService = context.read<TransactionApiService>();
    final walletService = context.read<WalletService>();

    final rawTransaction = quote['transaction'] ?? quote['transactionRequest'];
    if (rawTransaction is! Map) {
      NotificationService.showError(
        context,
        'No transaction data in quote',
      );
      return;
    }

    final transaction = Map<String, dynamic>.from(rawTransaction);
    final transactionId = quote['transactionId']?.toString();

    if (transactionId == null || transactionId.isEmpty) {
      NotificationService.showError(
        context,
        'This swap quote has no backend transaction ID yet.',
      );
      return;
    }

    final to = transaction['to']?.toString();
    final data = transaction['data']?.toString();
    final value = transaction['value']?.toString() ?? '0';
    final chainId = int.tryParse(transaction['chainId']?.toString() ?? '');

    if (to == null || to.isEmpty) {
      NotificationService.showError(context, 'Recipient/contract address is missing in swap data.');
      return;
    }

    if (data == null || data.isEmpty || data == '0x') {
      NotificationService.showError(
        context,
        'Swap calldata is missing. The transaction cannot be signed safely.',
      );
      return;
    }

    if (chainId == null) {
      NotificationService.showError(context, 'Chain ID is missing in swap data.');
      return;
    }

    // Dynamic resolution of nonce, gasLimit, and gasPrice
    int? resolvedNonce = int.tryParse(transaction['nonce']?.toString() ?? '');
    String? resolvedGasLimit = transaction['gasLimit']?.toString() ?? transaction['gas']?.toString();
    String? resolvedGasPrice = transaction['gasPrice']?.toString();

    setState(() => _isLoading = true);

    try {
      // 1. Resolve nonce if null
      if (resolvedNonce == null) {
        final prep = await apiService.prepareNativeSend(
          network: _fromToken!.chain,
          toAddress: '0x0000000000000000000000000000000000000000',
          amount: '0',
        );
        resolvedNonce = int.tryParse(prep['nonce']?.toString() ?? '');
      }

      // 2. Resolve gasLimit and gasPrice if null
      if (resolvedGasLimit == null || resolvedGasLimit.isEmpty || resolvedGasPrice == null || resolvedGasPrice.isEmpty) {
        final estimate = await apiService.estimateTransaction(
          network: _fromToken!.chain,
          transaction: {
            'from': fromAddress,
            'to': to,
            'value': value,
            'data': data,
          },
        );
        resolvedGasLimit = estimate['gasLimit']?.toString();
        resolvedGasPrice = estimate['gasPrice']?.toString();
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to fetch transaction details: $e');
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }

    if (!mounted) return;

    if (resolvedNonce == null ||
        resolvedGasLimit == null || resolvedGasLimit.isEmpty ||
        resolvedGasPrice == null || resolvedGasPrice.isEmpty) {
      NotificationService.showError(
        context,
        'Swap transaction data is incomplete. Nonce or gas parameters could not be resolved.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Swap'),
        content: Text(
          'Swap ${_amountController.text} ${_fromToken?.symbol} '
          'for approximately ${_fromBaseUnits(
            quote['toAmount']?.toString(),
            _toToken?.decimals ?? 18,
          )} ${_toToken?.symbol}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm Swap'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      if (!mounted) return;
      NotificationService.showInfo(
        context,
        'Signing swap transaction locally...',
      );

      final signedTx = await walletService.signNativeTransaction(
            to: to,
            valueRaw: value,
            nonce: resolvedNonce,
            gasLimit: resolvedGasLimit,
            gasPrice: resolvedGasPrice,
            chainId: chainId,
            dataHex: data,
          );

      if (signedTx == null || signedTx.isEmpty) {
        throw Exception('Failed to sign swap transaction locally');
      }

      if (!mounted) return;
      NotificationService.showInfo(
        context,
        'Broadcasting swap...',
      );

      final result = await apiService.broadcastTransaction(
            network: _fromToken!.chain,
            transactionId: transactionId,
            signedTransaction: signedTx,
          );

      if (!mounted) return;

      final broadcast = result['broadcast'];
      final transactionResult = result['transaction'];
      
      final hash = result['hash'] ?? 
                 result['transactionHash'] ??
                 (broadcast is Map ? broadcast['hash'] : null) ??
                 (transactionResult is Map ? (transactionResult['txHash'] ?? transactionResult['tx_hash']) : null);

      if (hash == null || hash.toString().isEmpty) {
        throw Exception('Broadcast failed: No transaction hash returned');
      }

      NotificationService.showSuccess(
        context,
        'Swap broadcasted successfully!',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        NotificationService.showError(
          context,
          'Swap failed: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  void _swapTokens() {
    setState(() {
      final temp = _fromToken;
      _fromToken = _toToken;
      _toToken = temp;
      _quote = null;
    });
    _debounce?.cancel();
    _getQuote();
  }

  void _showTokenPicker(
    BuildContext context, {
    required bool isFrom,
  }) {
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
            subtitle: Text(
              '${token.symbol} on ${token.chain.toUpperCase()}',
            ),
            trailing: Text(
              WalletFormatters.formatBalance(token.balance),
            ),
            onTap: () {
              setState(() {
                if (isFrom) {
                  _fromToken = token;
                } else {
                  _toToken = token;
                }
                _quote = null;
              });
              Navigator.pop(context);
              _getQuote();
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Swap'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildSwapCard(
                      context,
                      label: 'From',
                      token: _fromToken,
                      controller: _amountController,
                      onChanged: _onAmountChanged,
                      onTokenTap: () =>
                          _showTokenPicker(context, isFrom: true),
                    ),
                    const SizedBox(height: 12),
                    CircleAvatar(
                      backgroundColor: colors.primary,
                      child: IconButton(
                        icon: const Icon(
                          Icons.swap_vert_rounded,
                          color: Colors.white,
                        ),
                        onPressed: _swapTokens,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSwapCard(
                      context,
                      label: 'To',
                      token: _toToken,
                      isReadOnly: true,
                      value: _fromBaseUnits(
                        _quote?['toAmount']?.toString(),
                        _toToken?.decimals ?? 18,
                      ),
                      onTokenTap: () =>
                          _showTokenPicker(context, isFrom: false),
                    ),
                    if (_quote != null) ...[
                      const SizedBox(height: 24),
                      _buildQuoteDetails(context),
                    ],
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: (_quote != null && !_isLoading)
                            ? _handleSwap
                            : null,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Swap Assets',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
                const Column(
                  children: [
                    SizedBox(height: 32),
                    GriotBannerAd(),
                    SizedBox(height: 32),
                  ],
                ),
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
  }) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.3),
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
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (token != null)
                Text(
                  'Balance: ${WalletFormatters.formatBalance(token.balance)}',
                  style: text.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: isReadOnly
                    ? Text(
                        value ?? '0.00',
                        style: text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : TextField(
                        controller: controller,
                        onChanged: onChanged,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          hintText: '0.00',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: onTokenTap,
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(100),
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
                          radius: 12,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          token.symbol,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ] else
                        const Text(
                          'Select',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteDetails(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fee = _quote?['fee'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _quoteRow(
            context,
            'Provider',
            _quote?['provider']?.toString() ?? '-',
          ),
          const SizedBox(height: 8),
          _quoteRow(
            context,
            'Type',
            _quote?['type']?.toString() ?? '-',
          ),
          const SizedBox(height: 8),
          _quoteRow(
            context,
            'Swap Fee',
            fee is Map<String, dynamic>
                ? '${fee['percent'] ?? 0}%'
                : '-',
          ),
          if (fee is Map<String, dynamic> && fee['amount'] != null) ...[
            const SizedBox(height: 8),
            _quoteRow(
              context,
              'Fee Amount',
              fee['amount'].toString(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quoteRow(
    BuildContext context,
    String label,
    String value,
  ) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: text.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: text.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
