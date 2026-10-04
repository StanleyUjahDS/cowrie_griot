// Version: Fixed build errors
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/token_model.dart';
import '../providers/wallet_provider.dart';
import '../providers/display_currency_provider.dart';
import '../services/transaction_api_service.dart';
import '../services/wallet_service.dart';
import '../utils/wallet_formatters.dart';
import '../widgets/token_icon.dart';
import '../../../core/ui/widgets/banner_ad.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/utils/transaction_logger.dart';

class SendScreen extends StatefulWidget {
  final TokenModel? initialToken;
  final String? initialAddress;

  const SendScreen({super.key, this.initialToken, this.initialAddress});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  TokenModel? _token;
  final _address = TextEditingController();
  final _amount = TextEditingController();
  bool _loading = false;
  bool _usdMode = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _token = widget.initialToken;
    if (widget.initialAddress != null) _address.text = widget.initialAddress!;
  }

  @override
  void dispose() {
    _address.dispose();
    _amount.dispose();
    super.dispose();
  }

  double get _entered {
    final value = double.tryParse(_amount.text.trim()) ?? 0;
    if (!_usdMode) return value;
    final usdValue = context.read<DisplayCurrencyProvider>().displayToUsd(
      value,
    );
    final price = _token?.priceUsd?.toDouble() ?? 0;
    return price > 0 && usdValue != null ? usdValue / price : 0;
  }

  void _useMax() {
    final token = _token;
    if (token == null) return;
    final balance = num.tryParse(token.balance)?.toDouble() ?? 0.0;
    if (_usdMode) {
      final usdValue = balance * (token.priceUsd?.toDouble() ?? 0.0);
      final rate = context.read<DisplayCurrencyProvider>();
      _amount.text = rate.usdToDisplay(usdValue).toStringAsFixed(2);
    } else {
      _amount.text = balance.toString();
    }
    setState(() {});
  }

  Future<void> _send() async {
    final token = _token;
    final recipient = _address.text.trim();

    if (token == null) {
      if (mounted) NotificationService.showError(context, 'Select an asset.');
      return;
    }
    if (!_isValidAddress(recipient, token.chain)) {
      if (mounted) {
        NotificationService.showError(
          context,
          'Invalid recipient address for ${token.chain.toUpperCase()}.',
        );
      }
      return;
    }
    // The API expects a human-readable decimal amount and performs the
    // token-decimal conversion itself. Keep the raw amount only for the local
    // balance check.
    final amountText = _usdMode ? _entered.toString() : _amount.text.trim();
    final amountRaw = _toBaseUnits(amountText, token.decimals ?? 18);
    if (amountRaw == null || amountRaw == '0') {
      if (mounted) {
        NotificationService.showError(context, 'Enter a valid amount.');
      }
      return;
    }

    final balanceRaw = BigInt.tryParse(token.rawBalance) ?? BigInt.zero;
    final enteredRaw = BigInt.tryParse(amountRaw) ?? BigInt.zero;

    if (enteredRaw > balanceRaw) {
      if (mounted) {
        NotificationService.showError(context, 'Insufficient balance.');
      }
      return;
    }

    final api = context.read<TransactionApiService>();
    final walletService = context.read<WalletService>();
    final walletProvider = context.read<WalletProvider>();
    final navigator = Navigator.of(context);

    if (mounted) {
      setState(() {
        _loading = true;
        _message = 'Preparing...';
      });
    }
    try {
      final prepared = token.isNative
          ? await api.prepareNativeSend(
              network: token.chain,
              toAddress: recipient,
              amount: amountText,
            )
          : await api.prepareTokenSend(
              network: token.chain,
              tokenAddress: token.contractAddress,
              toAddress: recipient,
              amount: amountText,
            );

      final id =
          prepared['transactionId']?.toString() ??
          prepared['transaction_id']?.toString();
      final unsigned =
          prepared['unsignedTransaction'] ?? prepared['unsigned_transaction'];
      if (id == null || id.isEmpty || unsigned is! Map) {
        throw Exception('Incomplete transaction.');
      }

      if (!mounted) return;
      final confirmed = await _review(
        context,
        token,
        recipient,
        amountRaw,
        prepared,
        walletProvider,
      );
      if (!confirmed || !mounted) return;

      setState(() => _message = 'Signing...');
      final tx = Map<String, dynamic>.from(unsigned);
      final chainId =
          _parseIntQuantity(tx['chainId']) ??
          _parseIntQuantity(tx['chain_id']) ??
          _parseIntQuantity(prepared['chainId']) ??
          _parseIntQuantity(prepared['chain_id']);

      if (chainId == null) {
        throw Exception('Transaction chain ID is missing');
      }

      final expectedChainId = _getExpectedChainId(token.chain);
      if (expectedChainId == null || chainId != expectedChainId) {
        throw Exception('Network and chain ID do not match for ${token.chain}');
      }

      final signed = await walletService.signNativeTransaction(
        to: tx['to']?.toString() ?? '',
        valueRaw: (tx['value'] ?? tx['amount'] ?? '0').toString(),
        nonce: _parseIntQuantity(tx['nonce']) ?? 0,
        gasLimit: (tx['gasLimit'] ?? tx['gas'] ?? '21000').toString(),
        gasPrice: (tx['gasPrice'] ?? tx['gas_price'])?.toString(),
        maxFeePerGas: (tx['maxFeePerGas'] ?? tx['max_fee_per_gas'])?.toString(),
        maxPriorityFeePerGas:
            (tx['maxPriorityFeePerGas'] ?? tx['max_priority_fee_per_gas'])
                ?.toString(),
        chainId: chainId,
        dataHex: tx['data']?.toString(),
      );
      if (signed == null || signed.isEmpty) throw Exception('Signing failed.');

      if (mounted) setState(() => _message = 'Broadcasting...');
      final result = await api.broadcastTransaction(
        network: token.chain,
        transactionId: id,
        signedTransaction: signed,
      );

      final broadcast = result['broadcast'];
      final hash = broadcast is Map ? broadcast['hash']?.toString() : null;

      TransactionLogger.log(
        endpoint: '/crypto/transactions/broadcast',
        network: token.chain,
        chainId: prepared['chainId'],
        transactionHash: hash,
        backendError: result['message'],
      );

      if (hash == null || hash.isEmpty) throw Exception('Broadcast failed.');

      if (mounted) setState(() => _message = 'Confirming...');
      var status = 'PENDING';
      for (var i = 0; i < 24; i++) {
        await Future.delayed(const Duration(seconds: 5));
        if (!mounted) return;
        final statusResult = await api.getTransactionStatus(
          transactionId: id,
          network: token.chain,
        );
        status = statusResult['status']?.toString().toUpperCase() ?? 'PENDING';
        if (status == 'CONFIRMED' || status == 'FAILED') break;
      }

      if (!mounted) return;
      // Do not hold the success/pending UI open while all wallet networks and
      // market data refresh. Refresh in the background after the transaction
      // status has been recorded.
      unawaited(walletProvider.loadWallet());

      if (mounted) {
        if (status == 'CONFIRMED') {
          NotificationService.showSuccess(context, 'Sent successfully!');
          navigator.pop();
        } else if (status == 'FAILED') {
          NotificationService.showError(
            context,
            'The transaction failed on-chain.',
          );
        } else {
          NotificationService.showInfo(context, 'Transaction pending.');
          navigator.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Transaction failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _message = '';
        });
      }
    }
  }

  Future<bool> _review(
    BuildContext context,
    TokenModel token,
    String recipient,
    String amountRaw,
    Map<String, dynamic> prepared,
    WalletProvider provider,
  ) async {
    final colors = Theme.of(context).colorScheme;
    final feeRawStr =
        (prepared['estimatedNetworkFeeRaw'] ??
                prepared['estimated_network_fee_raw'] ??
                '')
            .toString();
    final feeRaw = BigInt.tryParse(feeRawStr);
    final native = provider.tokens
        .where((t) => t.isNative && t.chain == token.chain)
        .cast<TokenModel?>()
        .firstWhere((t) => t != null, orElse: () => null);

    double? feeNative;
    if (feeRaw != null) {
      final decimals = native?.decimals ?? 18;
      feeNative =
          feeRaw.toDouble() / (BigInt.from(10).pow(decimals).toDouble());
    }

    final feeUsd = native == null || feeNative == null
        ? null
        : feeNative * (native.priceUsd?.toDouble() ?? 0);

    final displayAmount = _fromBaseUnits(amountRaw, token.decimals ?? 18);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Review Transaction',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 32),
              TokenIcon(
                imageUrl: token.imageUrl,
                symbol: token.symbol,
                name: token.name,
                chainName: token.chain,
                isNative: token.isNative,
                radius: 28,
              ),
              const SizedBox(height: 16),
              Text(
                '$displayAmount ${token.symbol}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _shortAddress(recipient),
                  style: TextStyle(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _row(context, 'Network', token.chain.toUpperCase()),
              _row(
                context,
                'Est. Fee',
                feeNative == null
                    ? '—'
                    : '${feeNative.toStringAsFixed(6)} ${native?.symbol ?? ''}',
              ),
              if (feeUsd != null)
                _row(
                  context,
                  'Value',
                  context.read<DisplayCurrencyProvider>().formatUsd(feeUsd),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'Confirm & Send',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return result == true;
  }

  Widget _row(BuildContext context, String label, String value) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ],
      ),
    );
  }

  int? _getExpectedChainId(String network) {
    const expectedChainIds = {
      'ethereum': 1,
      'base': 8453,
      'polygon': 137,
      'arbitrum': 42161,
      'optimism': 10,
      'bsc': 56,
      'avalanche': 43114,
    };
    return expectedChainIds[network.toLowerCase()];
  }

  int? _parseIntQuantity(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return null;
    try {
      final quantity = normalized.startsWith('0x')
          ? BigInt.parse(normalized.substring(2), radix: 16)
          : BigInt.parse(normalized);
      return quantity <= BigInt.from(0x7fffffff) ? quantity.toInt() : null;
    } catch (_) {
      return null;
    }
  }

  String _shortAddress(String address) {
    if (address.length <= 14) return address;
    return '${address.substring(0, 8)}…${address.substring(address.length - 6)}';
  }

  bool _isValidAddress(String address, String network) {
    final n = network.toLowerCase();
    if (_isEvm(n)) {
      return RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address);
    }
    // Fallback for non-EVM: generic check if not empty
    return address.isNotEmpty;
  }

  bool _isEvm(String network) {
    final n = network.toLowerCase();
    return n == 'ethereum' ||
        n == 'eth' ||
        n == 'base' ||
        n == 'polygon' ||
        n == 'matic' ||
        n == 'arbitrum' ||
        n == 'optimism' ||
        n == 'bsc' ||
        n == 'avalanche' ||
        n == 'avax' ||
        n == 'binance';
  }

  void _pickToken() {
    final tokens = context
        .read<WalletProvider>()
        .filteredTokens
        // Sending is limited to assets the wallet can actually spend.
        // Do not offer zero-balance or merely discoverable assets here.
        .where((t) => (num.tryParse(t.balance) ?? 0) > 0)
        .toList();
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (_) => ListView.builder(
        itemCount: tokens.isEmpty ? 1 : tokens.length,
        padding: const EdgeInsets.only(bottom: 20),
        itemBuilder: (_, i) {
          if (tokens.isEmpty) {
            return ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('No funded assets available'),
              subtitle: const Text('Receive crypto before sending.'),
            );
          }

          final token = tokens[i];
          return ListTile(
            leading: TokenIcon(
              imageUrl: token.imageUrl,
              symbol: token.symbol,
              name: token.name,
              chainName: token.chain,
              isNative: token.isNative,
              radius: 18,
            ),
            title: Row(
              children: [
                Text(
                  token.symbol,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                if (token.isOfficial) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.verified_rounded,
                    size: 14,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ],
              ],
            ),
            subtitle: Text(
              token.chain.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Text(
              WalletFormatters.formatBalance(token.balance),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            onTap: () {
              setState(() {
                _token = token;
                _amount.clear();
              });
              Navigator.pop(context);
            },
          );
        },
      ),
    );
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
    final raw = '$whole$paddedFraction'.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    return RegExp(r'^\d+$').hasMatch(raw) ? raw : null;
  }

  String _fromBaseUnits(String? baseAmount, int decimals) {
    if (baseAmount == null || baseAmount.isEmpty || decimals < 0) {
      return '0.00';
    }

    final cleanBase = baseAmount.split('.').first.replaceAll(RegExp(r'\D'), '');
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

  @override
  Widget build(BuildContext context) {
    // Send form with premium pill action
    final colors = Theme.of(context).colorScheme;
    final displayCurrency = context.watch<DisplayCurrencyProvider>();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GradientScaffold(
        useSafeArea: true,
        resizeToAvoidBottomInset: true,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Send'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  // Content
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),

                        // Asset Selection
                        _buildInputLabel(context, 'Select Asset'),
                        const SizedBox(height: 8),
                        _buildAssetSelector(context),

                        const SizedBox(height: 24),

                        // Recipient
                        _buildInputLabel(context, 'Recipient Address'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _address,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            hintText: 'Enter 0x… address',
                            prefixIcon: Icon(
                              Icons.account_balance_wallet_rounded,
                              color: colors.primary.withValues(alpha: 0.5),
                            ),
                            suffixIcon: IconButton(
                              onPressed: () async {
                                final result = await GoRouter.of(
                                  context,
                                ).push<String>('/wallet/scan');
                                if (result != null && mounted) {
                                  _address.text = result;
                                }
                              },
                              icon: Icon(
                                Icons.qr_code_scanner_rounded,
                                color: colors.primary,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: colors.primary.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: colors.primary.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: colors.primary,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: colors.surfaceContainerLow.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Amount
                        _buildInputLabel(context, 'Amount'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _amount,
                          onChanged: (_) => setState(() {}),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_token != null)
                                    TextButton(
                                      onPressed: _useMax,
                                      style: TextButton.styleFrom(
                                        backgroundColor: colors.primary
                                            .withValues(alpha: 0.1),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                      ),
                                      child: const Text(
                                        'MAX',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  _buildCurrencyToggle(context),
                                ],
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: colors.primary.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: colors.primary.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: colors.primary,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: colors.surfaceContainerLow.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        if (_token != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 4),
                            child: Text(
                              _usdMode
                                  ? '≈ ${_entered.toStringAsFixed(8)} ${_token!.symbol}'
                                  : '≈ ${displayCurrency.formatUsd(_entered * (_token!.priceUsd?.toDouble() ?? 0))}',
                              style: TextStyle(
                                color: colors.onSurfaceVariant.withValues(
                                  alpha: 0.4,
                                ),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                        const SizedBox(height: 48),

                        // Premium Action Pill
                        Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _loading ? null : _send,
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primary,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: _loading
                                      ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 3,
                                                color: colors.onPrimary
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Text(
                                              _message,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                                color: colors.onPrimary,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Center(
                                          child: Text(
                                            'CONTINUE',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 18,
                                              letterSpacing: 1.5,
                                              color: colors.onPrimary,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 600.ms, delay: 400.ms)
                            .scale(
                              begin: const Offset(0.9, 0.9),
                              end: const Offset(1, 1),
                            ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const GriotBannerAd(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildAssetSelector(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final token = _token;

    return InkWell(
      onTap: _pickToken,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border(
            top: BorderSide(
              color: colors.primary.withValues(alpha: 0.6),
              width: 1.2,
            ),
            bottom: BorderSide(
              color: colors.primary.withValues(alpha: 0.6),
              width: 1.2,
            ),
          ),
        ),
        child: Row(
          children: [
            if (token != null) ...[
              TokenIcon(
                imageUrl: token.imageUrl,
                symbol: token.symbol,
                name: token.name,
                chainName: token.chain,
                isNative: token.isNative,
                radius: 20,
              ),
              const SizedBox(width: 14),
            ] else ...[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_circle_outline_rounded,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    token?.symbol ?? 'Select asset',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (token != null)
                    Text(
                      '${WalletFormatters.formatBalance(token.balance)} available',
                      style: TextStyle(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: colors.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyToggle(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: _token == null ? null : () => setState(() => _usdMode = !_usdMode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              _usdMode
                  ? context.read<DisplayCurrencyProvider>().currency
                  : (_token?.symbol ?? ''),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.swap_horiz_rounded,
              size: 14,
              color: colors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
