import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/token_model.dart';
import '../providers/wallet_provider.dart';
import '../services/transaction_api_service.dart';
import '../services/wallet_service.dart';
import '../utils/wallet_formatters.dart';
import '../widgets/token_icon.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';

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
      NotificationService.showError(context, 'Select an asset');
      return;
    }
    if (!RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(recipient)) {
      NotificationService.showError(context, 'Enter a valid EVM recipient address');
      return;
    }
    if (amount <= 0) {
      NotificationService.showError(context, 'Enter an amount greater than zero');
      return;
    }
    if (amount > token.balance) {
      NotificationService.showError(context, 'Insufficient ${token.symbol} balance');
      return;
    }

    setState(() { _loading = true; _message = 'Preparing transaction…'; });
    try {
      final api = context.read<TransactionApiService>();
      final prepared = token.isNative
          ? await api.prepareNativeSend(network: token.chain, toAddress: recipient, amount: amount.toString())
          : await api.prepareTokenSend(network: token.chain, tokenAddress: token.contractAddress, toAddress: recipient, amount: amount.toString());

      final id = prepared['transactionId']?.toString();
      final unsigned = prepared['unsignedTransaction'];
      if (id == null || id.isEmpty || unsigned is! Map) {
        throw Exception('Backend returned an incomplete transaction');
      }

      final confirmed = await _review(token, recipient, amount, prepared);
      if (!confirmed || !mounted) return;

      setState(() => _message = 'Signing transaction…');
      final tx = Map<String, dynamic>.from(unsigned);
      final signed = await context.read<WalletService>().signNativeTransaction(
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
      if (signed == null || signed.isEmpty) throw Exception('Unable to sign transaction');

      setState(() => _message = 'Broadcasting transaction…');
      final result = await api.broadcastTransaction(
        network: token.chain,
        transactionId: id,
        signedTransaction: signed,
      );

      final broadcast = result['broadcast'];
      final hash = broadcast is Map ? broadcast['hash']?.toString() : null;
      if (hash == null || hash.isEmpty) throw Exception('Backend did not return a transaction hash');

      setState(() => _message = 'Confirming transaction…');
      var status = 'PENDING';
      for (var i = 0; i < 24; i++) {
        await Future.delayed(const Duration(seconds: 5));
        if (!mounted) return;
        final statusResult = await api.getTransactionStatus(transactionId: id, network: token.chain);
        status = statusResult['status']?.toString().toUpperCase() ?? 'PENDING';
        if (status == 'CONFIRMED' || status == 'FAILED') break;
      }

      if (!mounted) return;
      await context.read<WalletProvider>().loadWallet();
      if (status == 'CONFIRMED') {
        NotificationService.showSuccess(context, 'Sent successfully');
        Navigator.of(context).pop();
      } else {
        NotificationService.showInfo(context, 'Transaction submitted. It is still pending.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Transaction failed: $e');
    } finally {
      if (mounted) setState(() { _loading = false; _message = ''; });
    }
  }

  Future<bool> _review(TokenModel token, String recipient, double amount, Map<String, dynamic> prepared) async {
    final colors = Theme.of(context).colorScheme;
    final feeRaw = BigInt.tryParse(prepared['estimatedNetworkFeeRaw']?.toString() ?? '');
    final native = context.read<WalletProvider>().tokens.where((t) => t.isNative && t.chain == token.chain).cast<TokenModel?>().firstWhere((t) => t != null, orElse: () => null);
    final feeNative = feeRaw == null ? null : feeRaw.toDouble() / 1e18;
    final feeUsd = native == null || feeNative == null ? null : feeNative * native.priceUsd.toDouble();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(color: colors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 42, height: 4, decoration: BoxDecoration(color: colors.outlineVariant, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 22),
          const Text('Review Transaction', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 22),
          TokenIcon(imageUrl: token.imageUrl, symbol: token.symbol, name: token.name, chainName: token.chain, isNative: token.isNative, radius: 24),
          const SizedBox(height: 10),
          Text('${WalletFormatters.formatBalance(amount)} ${token.symbol}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text('${recipient.substring(0, 8)}…${recipient.substring(36)}', style: TextStyle(color: colors.onSurfaceVariant)),
          const SizedBox(height: 22),
          _row('Network', token.chain.toUpperCase()),
          _row('Network fee', feeNative == null ? '—' : '${feeNative.toStringAsFixed(6)} ${native?.symbol ?? ''}'),
          if (feeUsd != null) _row('Fee value', WalletFormatters.formatCurrency(feeUsd)),
          _row('Status', 'Ready to sign'),
          const SizedBox(height: 22),
          SizedBox(width: double.infinity, height: 56, child: FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm & Send'))),
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ])),
      ),
    );
    return result == true;
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.w600))]),
  );

  void _pickToken() {
    final tokens = context.read<WalletProvider>().tokens.where((t) => t.balance >= 0).toList();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView.builder(
        itemCount: tokens.length,
        itemBuilder: (_, i) {
          final token = tokens[i];
          return ListTile(
            leading: TokenIcon(imageUrl: token.imageUrl, symbol: token.symbol, name: token.name, chainName: token.chain, isNative: token.isNative, radius: 18),
            title: Text(token.symbol, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(token.chain.toUpperCase()),
            trailing: Text(WalletFormatters.formatBalance(token.balance)),
            onTap: () { setState(() { _token = token; _amount.clear(); }); Navigator.pop(context); },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final token = _token;
    return GradientScaffold(
      appBar: AppBar(title: const Text('Send'), centerTitle: true, backgroundColor: Colors.transparent, elevation: 0),
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 28), children: [
        _sectionLabel('Asset'),
        const SizedBox(height: 10),
        InkWell(onTap: _pickToken, borderRadius: BorderRadius.circular(22), child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: colors.surfaceContainerLowest, borderRadius: BorderRadius.circular(22), border: Border.all(color: colors.outlineVariant.withValues(alpha: .2))),
          child: Row(children: [
            if (token != null) TokenIcon(imageUrl: token.imageUrl, symbol: token.symbol, name: token.name, chainName: token.chain, isNative: token.isNative, radius: 20),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(token?.symbol ?? 'Select asset', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), if (token != null) Text('${WalletFormatters.formatBalance(token.balance)} available', style: TextStyle(color: colors.onSurfaceVariant))])),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ]),
        )),
        const SizedBox(height: 26),
        _sectionLabel('Recipient'),
        const SizedBox(height: 10),
        TextField(controller: _address, decoration: InputDecoration(hintText: '0x…', prefixIcon: const Icon(Icons.account_balance_wallet_outlined), suffixIcon: IconButton(icon: const Icon(Icons.qr_code_scanner_rounded), onPressed: () async { final result = await GoRouter.of(context).push<String>('/wallet/scan'); if (result != null && mounted) _address.text = result; }))),
        const SizedBox(height: 26),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_sectionLabel('Amount'), if (token != null) TextButton(onPressed: _useMax, child: const Text('MAX'))]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
          decoration: BoxDecoration(color: colors.surfaceContainerLowest, borderRadius: BorderRadius.circular(22), border: Border.all(color: colors.outlineVariant.withValues(alpha: .2))),
          child: Row(children: [
            Expanded(child: TextField(controller: _amount, onChanged: (_) => setState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(border: InputBorder.none, hintText: '0.00'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700))),
            Text(_usdMode ? 'USD' : (token?.symbol ?? ''), style: const TextStyle(fontWeight: FontWeight.w700)),
            IconButton(onPressed: token == null ? null : () { setState(() => _usdMode = !_usdMode); }, icon: const Icon(Icons.swap_horiz_rounded)),
          ]),
        ),
        if (token != null) ...[
          const SizedBox(height: 8),
          Text(_usdMode ? '≈ ${_entered.toStringAsFixed(8)} ${token.symbol}' : '≈ ${WalletFormatters.formatCurrency(_entered * token.priceUsd.toDouble())}', style: TextStyle(color: colors.onSurfaceVariant)),
        ],
        const SizedBox(height: 34),
        SizedBox(height: 58, child: FilledButton(onPressed: _loading ? null : _send, child: _loading ? Text(_message) : const Text('Review & Send'))),
      ]),
    );
  }

  Widget _sectionLabel(String text) => Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700));
}
