// Version: Fixed build errors
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/token_model.dart';
import '../providers/wallet_provider.dart';
import '../services/transaction_api_service.dart';
import '../services/wallet_service.dart';
import '../utils/wallet_formatters.dart';
import '../widgets/token_icon.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/banner_ad.dart';
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
    final price = _token?.priceUsd?.toDouble() ?? 0;
    return price > 0 ? value / price : 0;
  }

  void _useMax() {
    final token = _token;
    if (token == null) return;
    final balance = num.tryParse(token.balance)?.toDouble() ?? 0.0;
    if (_usdMode) {
      final price = token.priceUsd?.toDouble() ?? 0.0;
      _amount.text = (balance * price).toStringAsFixed(2);
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
      if (mounted) NotificationService.showError(context, 'Invalid recipient address for ${token.chain.toUpperCase()}.');
      return;
    }
    final amountRaw = _toBaseUnits(_amount.text.trim(), token.decimals ?? 18);
    if (amountRaw == null || amountRaw == '0') {
      if (mounted) NotificationService.showError(context, 'Enter a valid amount.');
      return;
    }

    final balanceRaw = BigInt.tryParse(token.rawBalance) ?? BigInt.zero;
    final enteredRaw = BigInt.tryParse(amountRaw) ?? BigInt.zero;
    
    if (enteredRaw > balanceRaw) {
      if (mounted) NotificationService.showError(context, 'Insufficient balance.');
      return;
    }

    final api = context.read<TransactionApiService>();
    final walletService = context.read<WalletService>();
    final walletProvider = context.read<WalletProvider>();
    final navigator = Navigator.of(context);

    if (mounted) setState(() { _loading = true; _message = 'Preparing...'; });
    try {
      final prepared = token.isNative
          ? await api.prepareNativeSend(network: token.chain, toAddress: recipient, amount: amountRaw)
          : await api.prepareTokenSend(network: token.chain, tokenAddress: token.contractAddress, toAddress: recipient, amount: amountRaw);

      final id = prepared['transactionId']?.toString();
      final unsigned = prepared['unsignedTransaction'];
      if (id == null || id.isEmpty || unsigned is! Map) {
        throw Exception('Incomplete transaction.');
      }

      if (!mounted) return;
      final confirmed = await _review(context, token, recipient, amountRaw, prepared, walletProvider);
      if (!confirmed || !mounted) return;

      setState(() => _message = 'Signing...');
      final tx = Map<String, dynamic>.from(unsigned);
      final chainId = int.tryParse(tx['chainId']?.toString() ?? '') ?? int.tryParse(prepared['chainId']?.toString() ?? '');
      
      if (chainId == null) {
        throw Exception('Transaction chain ID is missing');
      }

      final expectedChainId = _getExpectedChainId(token.chain);
      if (expectedChainId == null || chainId != expectedChainId) {
        throw Exception('Network and chain ID do not match for ${token.chain}');
      }

      final signed = await walletService.signNativeTransaction(
        to: tx['to']?.toString() ?? '',
        valueRaw: tx['value']?.toString() ?? '0',
        nonce: int.tryParse(tx['nonce']?.toString() ?? '') ?? 0,
        gasLimit: tx['gasLimit']?.toString() ?? '21000',
        gasPrice: tx['gasPrice']?.toString(),
        maxFeePerGas: tx['maxFeePerGas']?.toString(),
        maxPriorityFeePerGas: tx['maxPriorityFeePerGas']?.toString(),
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
        final statusResult = await api.getTransactionStatus(transactionId: id, network: token.chain);
        status = statusResult['status']?.toString().toUpperCase() ?? 'PENDING';
        if (status == 'CONFIRMED' || status == 'FAILED') break;
      }

      if (!mounted) return;
      await walletProvider.loadWallet();
      
      if (mounted) {
        if (status == 'CONFIRMED') {
          NotificationService.showSuccess(context, 'Sent successfully!');
          navigator.pop();
        } else {
          NotificationService.showInfo(context, 'Transaction pending.');
          navigator.pop();
        }
      }
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Transaction failed: $e');
    } finally {
      if (mounted) setState(() { _loading = false; _message = ''; });
    }
  }

  Future<bool> _review(BuildContext context, TokenModel token, String recipient, String amountRaw, Map<String, dynamic> prepared, WalletProvider provider) async {
    final colors = Theme.of(context).colorScheme;
    final feeRaw = BigInt.tryParse(prepared['estimatedNetworkFeeRaw']?.toString() ?? '');
    final native = provider.tokens.where((t) => t.isNative && t.chain == token.chain).cast<TokenModel?>().firstWhere((t) => t != null, orElse: () => null);
    
    double? feeNative;
    if (feeRaw != null) {
      final decimals = native?.decimals ?? 18;
      feeNative = feeRaw.toDouble() / (BigInt.from(10).pow(decimals).toDouble());
    }

    final feeUsd = native == null || feeNative == null ? null : feeNative * (native.priceUsd?.toDouble() ?? 0);

    final displayAmount = _fromBaseUnits(amountRaw, token.decimals ?? 18);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(color: colors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(36))),
        child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 42, height: 4, decoration: BoxDecoration(color: colors.outlineVariant.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 28),
          const Text('Review Transaction', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 32),
          TokenIcon(imageUrl: token.imageUrl, symbol: token.symbol, name: token.name, chainName: token.chain, isNative: token.isNative, radius: 28),
          const SizedBox(height: 16),
          Text('$displayAmount ${token.symbol}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: colors.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
            child: Text('${recipient.substring(0, 8)}…${recipient.substring(32)}', style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ),
          const SizedBox(height: 32),
          _row('Network', token.chain.toUpperCase()),
          _row('Est. Fee', feeNative == null ? '—' : '${feeNative.toStringAsFixed(6)} ${native?.symbol ?? ''}'),
          if (feeUsd != null) _row('Value', WalletFormatters.formatCurrency(feeUsd)),
          const SizedBox(height: 32),
          SizedBox(width: double.infinity, height: 60, child: FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), child: const Text('Confirm & Send', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)))),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700))),
        ])),
      ),
    );
    return result == true;
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)), Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))]),
  );

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
        n == 'binance';
  }

  void _pickToken() {
    final tokens = context.read<WalletProvider>().tokens.where((t) => (num.tryParse(t.balance) ?? 0) >= 0).toList();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView.builder(
        itemCount: tokens.length + 1,
        padding: const EdgeInsets.only(bottom: 20),
        itemBuilder: (_, i) {
          if (i == 0) {
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
              ),
              title: const Text('Search for more tokens', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () async {
                Navigator.pop(context);
                final selected = await context.push<TokenModel>('/wallet/search?mode=select');
                if (selected != null && mounted) {
                  setState(() {
                    _token = selected;
                    _amount.clear();
                  });
                }
              },
            );
          }

          final token = tokens[i - 1];
          return ListTile(
            leading: TokenIcon(imageUrl: token.imageUrl, symbol: token.symbol, name: token.name, chainName: token.chain, isNative: token.isNative, radius: 18),
            title: Row(
              children: [
                Text(token.symbol, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                if (token.isOfficial) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.verified_rounded, size: 14, color: Theme.of(context).colorScheme.tertiary),
                ],
              ],
            ),
            subtitle: Text(token.chain.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
            trailing: Text(WalletFormatters.formatBalance(token.balance), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            onTap: () { setState(() { _token = token; _amount.clear(); }); Navigator.pop(context); },
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

  @override
  Widget build(BuildContext context) {
    // Send form with premium pill action
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GradientScaffold(
        useSafeArea: true,
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
                  // Decorative Glow
                  Positioned(
                    top: -100,
                    left: -100,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            colors.primary.withValues(alpha: 0.12),
                            colors.primary.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                     .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.3, 1.3), duration: 4.seconds),
                  ),

                  ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    physics: const BouncingScrollPhysics(),
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
                          prefixIcon: Icon(Icons.account_balance_wallet_rounded, color: colors.primary.withValues(alpha: 0.5)),
                          suffixIcon: IconButton(
                            onPressed: () async {
                              final result = await GoRouter.of(context).push<String>('/wallet/scan');
                              if (result != null && mounted) _address.text = result;
                            },
                            icon: Icon(Icons.qr_code_scanner_rounded, color: colors.primary),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.2))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.2))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.primary, width: 2)),
                          filled: true,
                          fillColor: colors.surfaceContainerLow.withValues(alpha: 0.5),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Amount
                      _buildInputLabel(context, 'Amount'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _amount,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
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
                                      backgroundColor: colors.primary.withValues(alpha: 0.1),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                    child: const Text('MAX', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                                  ),
                                const SizedBox(width: 8),
                                _buildCurrencyToggle(context),
                              ],
                            ),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.2))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.2))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.primary, width: 2)),
                          filled: true,
                          fillColor: colors.surfaceContainerLow.withValues(alpha: 0.5),
                        ),
                      ),
                      if (_token != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 4),
                          child: Text(
                            _usdMode ? '≈ ${_entered.toStringAsFixed(8)} ${_token!.symbol}' : '≈ ${WalletFormatters.formatCurrency(_entered * (_token!.priceUsd?.toDouble() ?? 0))}',
                            style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.4), fontSize: 13, fontWeight: FontWeight.w600),
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
                            child: _loading
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white60)),
                                      const SizedBox(width: 16),
                                      Text(_message, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
                                    ],
                                  )
                                : const Center(child: Text('CONTINUE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5, color: Colors.white))),
                          ),
                        ),
                      ).animate().fadeIn(duration: 600.ms, delay: 400.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
                      const SizedBox(height: 20),
                    ],
                  ),
                ],
              ),
            ),
            const GriotBannerAd(isCompact: true),
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
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            if (token != null) ...[
              TokenIcon(imageUrl: token.imageUrl, symbol: token.symbol, name: token.name, chainName: token.chain, isNative: token.isNative, radius: 20),
              const SizedBox(width: 14),
            ] else ...[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(Icons.add_circle_outline_rounded, color: colors.primary),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(token?.symbol ?? 'Select asset', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  if (token != null)
                    Text('${WalletFormatters.formatBalance(token.balance)} available',
                      style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.4), fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: colors.onSurfaceVariant.withValues(alpha: 0.3)),
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
            Text(_usdMode ? 'USD' : (_token?.symbol ?? ''), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            const SizedBox(width: 4),
            Icon(Icons.swap_horiz_rounded, size: 14, color: colors.onSurfaceVariant.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
