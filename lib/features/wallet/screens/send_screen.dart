import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/token_model.dart';
import '../providers/wallet_provider.dart';
import '../services/transaction_api_service.dart';
import '../services/wallet_service.dart';
import '../widgets/token_icon.dart';
import '../utils/wallet_formatters.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/banner_ad.dart';
import '../../../core/services/notification_service.dart';

class SendScreen extends StatefulWidget {
  final TokenModel? initialToken;
  final String? initialAddress;

  const SendScreen({
    super.key,
    this.initialToken,
    this.initialAddress,
  });

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  TokenModel? _selectedToken;
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isLoading = false;
  String _loadingMessage = '';
  bool _isInputInUsd = false;
  String _equivalentDisplay = '≈ \$0.00';

  @override
  void initState() {
    super.initState();
    _selectedToken = widget.initialToken;
    if (widget.initialAddress != null) {
      _addressController.text = widget.initialAddress!;
    }
    _amountController.addListener(_onAmountChanged);
    _onAmountChanged();
  }

  void _onAmountChanged() {
    final token = _selectedToken;
    if (token == null) {
      setState(() {
        _equivalentDisplay = '';
      });
      return;
    }

    final input = _amountController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _equivalentDisplay = _isInputInUsd ? '≈ 0.00 ${token.symbol}' : '≈ \$0.00';
      });
      return;
    }

    final value = double.tryParse(input) ?? 0.0;
    final price = token.priceUsd.toDouble();

    setState(() {
      if (_isInputInUsd) {
        if (price > 0) {
          final tokenAmount = value / price;
          _equivalentDisplay = '≈ ${tokenAmount.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')} ${token.symbol}';
        } else {
          _equivalentDisplay = '≈ -- ${token.symbol}';
        }
      } else {
        final usdAmount = value * price;
        _equivalentDisplay = '≈ \$${usdAmount.toStringAsFixed(2)}';
      }
    });
  }

  void _toggleInputCurrency() {
    final token = _selectedToken;
    if (token == null) return;

    final input = _amountController.text.trim();
    final value = double.tryParse(input) ?? 0.0;
    final price = token.priceUsd.toDouble();

    setState(() {
      _isInputInUsd = !_isInputInUsd;
      if (input.isNotEmpty && value > 0) {
        if (_isInputInUsd) {
          // Token to USD
          final usdAmount = value * price;
          _amountController.text = usdAmount.toStringAsFixed(2);
        } else {
          // USD to Token
          if (price > 0) {
            final tokenAmount = value / price;
            _amountController.text = tokenAmount.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
          } else {
            _amountController.text = '0';
          }
        }
      }
      _onAmountChanged();
    });
  }

  void _useMaxAmount() {
    final token = _selectedToken;
    if (token == null) return;

    final maxBalance = token.balance.toDouble();

    setState(() {
      if (_isInputInUsd) {
        final maxUsd = maxBalance * token.priceUsd.toDouble();
        _amountController.text = maxUsd.toStringAsFixed(2);
      } else {
        _amountController.text = maxBalance.toString().replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
      }
      _onAmountChanged();
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final token = _selectedToken;

    if (token == null) {
      NotificationService.showError(context, 'Please select a token');
      return;
    }

    final address = _addressController.text.trim();
    if (address.isEmpty) {
      NotificationService.showError(context, 'Please enter a recipient address');
      return;
    }

    var amount = _amountController.text.trim();
    if (amount.isEmpty) {
      NotificationService.showError(context, 'Please enter an amount');
      return;
    }

    if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address)) {
      NotificationService.showError(context, 'Please enter a valid EVM address');
      return;
    }

    // Dynamic resolution of input currency
    var finalAmount = amount;
    if (_isInputInUsd) {
      final usdValue = double.tryParse(finalAmount) ?? 0.0;
      final price = token.priceUsd.toDouble();
      if (price <= 0) {
        NotificationService.showError(context, 'Cannot calculate amount: Token price is zero.');
        return;
      }
      final tokenValue = usdValue / price;
      // Truncate to a maximum of 6 decimals (or token decimals if smaller) to prevent float precision overflows
      final decimals = token.decimals > 6 ? 6 : token.decimals;
      finalAmount = tokenValue.toStringAsFixed(decimals);
    }

    final enteredAmount = double.tryParse(finalAmount) ?? 0.0;
    final maxBalance = token.balance.toDouble();

    if (enteredAmount <= 0) {
      NotificationService.showError(context, 'Please enter an amount greater than zero.');
      return;
    }

    if (enteredAmount > maxBalance) {
      NotificationService.showError(
        context,
        'Insufficient balance: Your maximum balance is $maxBalance ${token.symbol}.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = context.read<TransactionApiService>();

      final Map<String, dynamic> prepared;

      if (token.isNative) {
        prepared = await api.prepareNativeSend(
          network: token.chain,
          toAddress: address,
          amount: finalAmount,
        );
      } else {
        prepared = await api.prepareTokenSend(
          network: token.chain,
          tokenAddress: token.contractAddress,
          toAddress: address,
          amount: finalAmount,
        );
      }

      if (!prepared.containsKey('transactionId') ||
          !prepared.containsKey('unsignedTransaction')) {
        throw Exception('Server returned incomplete transaction data');
      }

      if (!mounted) return;

      final unsignedTransaction = prepared['unsignedTransaction'];
      if (unsignedTransaction is! Map) {
        throw Exception('Server returned invalid transaction data');
      }

      final feeRaw = prepared['estimatedNetworkFeeRaw'];

      if (!mounted) return;

      final confirmed = await _showConfirmBottomSheet(
        context,
        token: token,
        address: address,
        amount: finalAmount,
        feeRaw: feeRaw,
        servicePercent: prepared['percent'],
      );

      if (confirmed == true) {
        _executeBroadcast(prepared, token);
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Transaction failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool?> _showConfirmBottomSheet(
    BuildContext context, {
    required TokenModel token,
    required String address,
    required String amount,
    dynamic feeRaw,
    dynamic servicePercent,
  }) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fee = _getFeeDisplay(feeRaw, token);

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
              'Review Transaction',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Column(
              children: [
                TokenIcon(
                  imageUrl: token.imageUrl,
                  symbol: token.symbol,
                  name: token.name,
                  chainName: token.chain,
                  isNative: token.isNative,
                  radius: 24,
                ),
                const SizedBox(height: 12),
                Text(
                  '$amount ${token.symbol}',
                  style: text.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'to ${address.substring(0, 8)}...${address.substring(36)}',
                  style: text.labelMedium?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    'Network Fee',
                    fee.usdAmount,
                    context,
                    subtitle: fee.nativeAmount,
                  ),
                  if (servicePercent != null) ...[
                    const SizedBox(height: 12),
                    _buildSummaryRow('Service Fee', '$servicePercent%', context),
                  ],
                ],
              ),
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
                child: const Text('Confirm & Send', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildSummaryRow(
    String label,
    String value,
    BuildContext context, {
    String? subtitle,
    Color? valueColor,
    bool isBold = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: subtitle != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: text.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: text.bodyMedium?.copyWith(
                color: valueColor ?? colors.onSurface,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: text.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  double _getNativeTokenPrice(String chain) {
    try {
      final provider = context.read<WalletProvider>();
      final nativeToken = provider.tokens.firstWhere(
        (t) => t.chain == chain && t.isNative,
      );
      return nativeToken.priceUsd.toDouble();
    } catch (_) {
      // Standard fallbacks if native token is not currently held in portfolio
      if (chain == 'ethereum' || chain == 'base') return 3400.0;
      if (chain == 'bsc' || chain == 'binance') return 580.0;
      if (chain == 'polygon') return 0.55;
      return 1.0;
    }
  }

  FeeDisplay _getFeeDisplay(dynamic feeRaw, TokenModel token) {
    if (feeRaw == null) return FeeDisplay(nativeAmount: '--', usdAmount: '0.00');
    final feeNum = double.tryParse(feeRaw.toString()) ?? 0.0;
    if (feeNum <= 0) return FeeDisplay(nativeAmount: '0.00', usdAmount: '0.00');
    
    // Convert Wei to Native units (18 decimals)
    final nativeAmount = feeNum / 1000000000000000000.0;
    final nativeSymbol = token.chain == 'bsc' ? 'BNB' : (token.chain == 'polygon' ? 'POL' : 'ETH');
    
    // Calculate USD value of the gas fee
    final nativePrice = _getNativeTokenPrice(token.chain);
    final usdAmount = nativeAmount * nativePrice;
    
    final formattedNative = nativeAmount.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    final formattedUsd = usdAmount.toStringAsFixed(2);
    
    return FeeDisplay(
      nativeAmount: '$formattedNative $nativeSymbol',
      usdAmount: '≈ \$$formattedUsd',
    );
  }

  Future<void> _executeBroadcast(
    Map<String, dynamic> prepared,
    TokenModel token,
  ) async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Signing...';
    });

    try {
      final walletService = context.read<WalletService>();
      final apiService = context.read<TransactionApiService>();

      final unsigned = prepared['unsignedTransaction'];
      if (unsigned is! Map) {
        throw Exception('Unsigned transaction data missing');
      }

      final signedTx = await walletService.signNativeTransaction(
        to: unsigned['to']?.toString() ?? '',
        valueRaw: unsigned['value']?.toString() ?? '0',
        nonce: int.tryParse(unsigned['nonce']?.toString() ?? '') ?? 0,
        gasLimit: unsigned['gasLimit']?.toString() ?? '21000',
        gasPrice: unsigned['gasPrice']?.toString(),
        maxFeePerGas: unsigned['maxFeePerGas']?.toString(),
        maxPriorityFeePerGas: unsigned['maxPriorityFeePerGas']?.toString(),
        chainId: int.tryParse(unsigned['chainId']?.toString() ?? '') ?? 1,
        dataHex: unsigned['data']?.toString(),
      );

      if (signedTx == null || signedTx.isEmpty) {
        throw Exception('Failed to sign transaction locally');
      }

      setState(() => _loadingMessage = 'Broadcasting...');

      final broadcastResult = await apiService.broadcastTransaction(
        network: token.chain,
        transactionId: prepared['transactionId']?.toString() ?? '',
        signedTransaction: signedTx,
      );

      if (!mounted) return;

      final broadcast = broadcastResult['broadcast'];
      final transactionResult = broadcastResult['transaction'];
      
      final hash = broadcastResult['hash'] ?? 
                 broadcastResult['transactionHash'] ??
                 (broadcast is Map ? broadcast['hash'] : null) ??
                 (transactionResult is Map ? (transactionResult['txHash'] ?? transactionResult['tx_hash']) : null);

      if (hash != null && hash.toString().isNotEmpty) {
        NotificationService.showSuccess(
          context,
          'Sent successfully!',
        );
        // Automatically refresh the wallet screen balances!
        if (context.mounted) {
          context.read<WalletProvider>().loadWallet();
        }
        Navigator.of(context).pop();
      } else {
        throw Exception('Broadcast failed: No transaction hash returned');
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Transaction failed: $e');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Send'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        'Select Asset',
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildAssetSelector(context),
                      const SizedBox(height: 32),
                      Text(
                        'Recipient Address',
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          hintText: 'Enter 0x address',
                          prefixIcon: const Icon(
                            Icons.account_balance_wallet_outlined,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.qr_code_scanner_rounded,
                            ),
                            onPressed: () async {
                              final result = await GoRouter.of(context).push<String>('/wallet/scan');
                              if (result != null && mounted) {
                                _addressController.text = result;
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Amount',
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_selectedToken != null)
                            TextButton(
                              onPressed: _useMaxAmount,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'USE MAX',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixText: _isInputInUsd ? '\$ ' : null,
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isInputInUsd ? 'USD' : (_selectedToken?.symbol ?? ''),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                                onPressed: _toggleInputCurrency,
                                tooltip: 'Switch Input Currency',
                              ),
                            ],
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                        ),
                      ),
                      if (_selectedToken != null) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            _equivalentDisplay,
                            style: text.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 48),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _handleSend,
                          child: _isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _loadingMessage.isEmpty ? 'Loading...' : _loadingMessage,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                )
                              : const Text(
                                  'Review Transaction',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const SizedBox(height: 32),
                      const GriotBannerAd(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAssetSelector(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => _showTokenPicker(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            if (_selectedToken != null) ...[
              TokenIcon(
                imageUrl: _selectedToken!.imageUrl,
                symbol: _selectedToken!.symbol,
                name: _selectedToken!.name,
                chainName: _selectedToken!.chain,
                isNative: _selectedToken!.isNative,
                radius: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedToken!.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Balance: ${WalletFormatters.formatBalance(_selectedToken!.balance)} ${_selectedToken!.symbol}',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              const Expanded(
                child: Text('Choose a token to send'),
              ),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }

  void _showTokenPicker(BuildContext context) {
    final provider = context.read<WalletProvider>();
    final tokens = provider.tokens;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListView.builder(
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
                setState(() => _selectedToken = token);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }
}

class FeeDisplay {
  final String nativeAmount;
  final String usdAmount;

  FeeDisplay({required this.nativeAmount, required this.usdAmount});
}
