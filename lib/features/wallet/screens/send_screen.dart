import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
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
    final price = _token?.priceUsd.toDouble() ?? 0;
    return price > 0 ? value / price : 0;
  }

  void _useMax() {
    final token = _token;
    if (token == null) return;
    if (_usdMode) {
      _amount.text = (token.balance.toDouble() * token.priceUsd.toDouble()).toStringAsFixed(2);
    } else {
      _amount.text = token.balance.toString();
    }
    setState(() {});
  }

  Future<void> _send() async {
    final token = _token;
    final recipient = _address.text.trim();
    final amount = _entered;

    if (token == null) {
      if (mounted) NotificationService.showError(context, 'Select an asset.');
      return;
    }
    if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(recipient)) {
      if (mounted) NotificationService.showError(context, 'Invalid recipient address.');
      return;
    }
    if (amount <= 0) {
      if (mounted) NotificationService.showError(context, 'Enter a valid amount.');
      return;
    }
    if (amount > token.balance) {
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
          ? await api.prepareNativeSend(network: token.chain, toAddress: recipient, amount: amount.toString())
          : await api.prepareTokenSend(network: token.chain, tokenAddress: token.contractAddress, toAddress: recipient, amount: amount.toString());

      final id = prepared['transactionId']?.toString();
      final unsigned = prepared['unsignedTransaction'];
      if (id == null || id.isEmpty || unsigned is! Map) {
        throw Exception('Incomplete transaction.');
      }

      if (!mounted) return;
      final confirmed = await _review(context, token, recipient, amount, prepared, walletProvider);
      if (!confirmed || !mounted) return;

      setState(() => _message = 'Signing...');
      final tx = Map<String, dynamic>.from(unsigned);
      final signed = await walletService.signNativeTransaction(
        to: tx['to']?.toString() ?? '',
        valueRaw: tx['value']?.toString() ?? '0',
        nonce: int.tryParse(tx['nonce']?.toString() ?? '') ?? 0,
        gasLimit: tx['gasLimit']?.toString() ?? '21000',
        gasPrice: tx['gasPrice']?.toString(),
        maxFeePerGas: tx['maxFeePerGas']?.toString(),
        maxPriorityFeePerGas: tx['maxPriorityFeePerGas']?.toString(),
        chainId: int.tryParse(tx['chainId']?.toString() ?? '') ?? int.tryParse(prepared['chainId']?.toString() ?? '') ?? 1,
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

  Future<bool> _review(BuildContext context, TokenModel token, String recipient, double amount, Map<String, dynamic> prepared, WalletProvider provider) async {
    final colors = Theme.of(context).colorScheme;
    final feeRaw = BigInt.tryParse(prepared['estimatedNetworkFeeRaw']?.toString() ?? '');
    final native = provider.tokens.where((t) => t.isNative && t.chain == token.chain).cast<TokenModel?>().firstWhere((t) => t != null, orElse: () => null);
    final feeNative = feeRaw == null ? null : feeRaw.toDouble() / 1e18;
    final feeUsd = native == null || feeNative == null ? null : feeNative * native.priceUsd.toDouble();

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
          Text('${WalletFormatters.formatBalance(amount)} ${token.symbol}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
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

  void _pickToken() {
    final tokens = context.read<WalletProvider>().tokens.where((t) => t.balance >= 0).toList();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView.builder(
        itemCount: tokens.length,
        padding: const EdgeInsets.only(bottom: 20),
        itemBuilder: (_, i) {
          final token = tokens[i];
          return ListTile(
            leading: TokenIcon(imageUrl: token.imageUrl, symbol: token.symbol, name: token.name, chainName: token.chain, isNative: token.isNative, radius: 18),
            title: Text(token.symbol, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            subtitle: Text(token.chain.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
            trailing: Text(WalletFormatters.formatBalance(token.balance), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            onTap: () { setState(() { _token = token; _amount.clear(); }); Navigator.pop(context); },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final token = _token;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GradientScaffold(
        appBar: AppBar(
          title: Text('SEND', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        bottomNavigationBar: const SafeArea(child: GriotBannerAd()),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              physics: const BouncingScrollPhysics(),
              children: [
                const SizedBox(height: 12),
                _buildSectionCard(
                  context,
                  label: 'Asset',
                  child: InkWell(
                    onTap: _pickToken,
                    borderRadius: BorderRadius.circular(20),
                    child: Row(
                      children: [
                        if (token != null)
                          TokenIcon(imageUrl: token.imageUrl, symbol: token.symbol, name: token.name, chainName: token.chain, isNative: token.isNative, radius: 20),
                        if (token != null) const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(token?.symbol ?? 'Select asset', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                              if (token != null)
                                Text('${WalletFormatters.formatBalance(token.balance)} available',
                                  style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.4), fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down_rounded, color: colors.onSurfaceVariant.withValues(alpha: 0.3), size: 24),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0),
                
                const SizedBox(height: 12),
                
                _buildSectionCard(
                  context,
                  label: 'Recipient',
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _address,
                          textInputAction: TextInputAction.next,
                          cursorHeight: 20,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                          decoration: InputDecoration(
                            hintText: '0x… or ENS',
                            hintStyle: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.2)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () async {
                          final result = await GoRouter.of(context).push<String>('/wallet/scan');
                          if (result != null && mounted) _address.text = result;
                        },
                        icon: Icon(Icons.qr_code_scanner_rounded, size: 22, color: colors.primary.withValues(alpha: 0.8)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        onPressed: () {
                          if (_address.text.isNotEmpty) {
                            SharePlus.instance.share(
                              ShareParams(text: 'Wallet Address: ${_address.text}'),
                            );
                          } else {
                            NotificationService.showInfo(context, 'Recipient address is empty');
                          }
                        },
                        icon: Icon(Icons.share_rounded, size: 20, color: colors.onSurfaceVariant.withValues(alpha: 0.6)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideX(begin: 0.1, end: 0),
                
                const SizedBox(height: 12),
                
                _buildSectionCard(
                  context,
                  label: 'Amount',
                  trailing: token != null
                      ? InkWell(onTap: _useMax, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Text('MAX', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5))))
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _amount,
                              onChanged: (_) => setState(() {}),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textInputAction: TextInputAction.done,
                              cursorHeight: 28,
                              cursorWidth: 2,
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1.0),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: '0',
                                hintStyle: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.1)),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: token == null ? null : () { setState(() => _usdMode = !_usdMode); },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Text(_usdMode ? 'USD' : (token?.symbol ?? ''), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                                  const SizedBox(width: 6),
                                  Icon(Icons.swap_horiz_rounded, size: 16, color: colors.onSurfaceVariant.withValues(alpha: 0.5)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (token != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _usdMode ? '≈ ${_entered.toStringAsFixed(8)} ${token.symbol}' : '≈ ${WalletFormatters.formatCurrency(_entered * token.priceUsd.toDouble())}',
                            style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.3), fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideX(begin: 0.1, end: 0),
                
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, {required String label, required Widget child, Widget? trailing}) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(32), // Large corner radius like Receive
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.15), width: 1.5),
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
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
