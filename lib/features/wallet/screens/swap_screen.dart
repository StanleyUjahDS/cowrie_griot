import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/token_model.dart';
import '../providers/wallet_provider.dart';
import '../services/swap_api_service.dart';
import '../services/transaction_api_service.dart';
import '../services/wallet_rpc_service.dart';
import '../services/wallet_service.dart';
import '../utils/wallet_formatters.dart';
import '../widgets/token_icon.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';

class SwapScreen extends StatefulWidget {
  final TokenModel? initialFromToken;

  const SwapScreen({super.key, this.initialFromToken});

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  static const _native = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';

  TokenModel? _from;
  TokenModel? _to;
  final _amount = TextEditingController();
  Timer? _debounce;
  Map<String, dynamic>? _quote;
  bool _loadingQuote = false;
  bool _processing = false;
  bool _approvalRequired = false;
  String _processingText = '';
  int _quoteVersion = 0;

  @override
  void initState() {
    super.initState();
    _from = widget.initialFromToken;
    _amount.addListener(_amountChanged);
  }

  @override
  void dispose() {
    _amount.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _amountChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _requestQuote);
  }

  String _chainId(String chain) {
    switch (chain.toLowerCase()) {
      case 'ethereum':
      case 'eth':
        return '1';
      case 'base':
        return '8453';
      case 'polygon':
      case 'matic':
        return '137';
      case 'arbitrum':
      case 'arb':
        return '42161';
      case 'optimism':
      case 'op':
        return '10';
      case 'bsc':
      case 'bnb':
      case 'binance':
        return '56';
      default:
        return chain;
    }
  }

  String? _baseUnits(String value, int decimals) {
    final v = value.trim();
    if (!RegExp(r'^\d+(?:\.\d+)?\$').hasMatch(v)) return null;
    final p = v.split('.');
    final whole = p[0];
    final fraction = p.length == 2 ? p[1] : '';
    if (fraction.length > decimals) return null;
    final raw = '$whole${fraction.padRight(decimals, '0')}'
        .replaceFirst(RegExp(r'^0+(?=\d)'), '');
    return raw.isEmpty ? '0' : raw;
  }

  String _displayUnits(dynamic raw, int decimals) {
    if (raw == null) return '0';
    final s = raw.toString().split('.').first.replaceAll(RegExp(r'\D'), '');
    if (s.isEmpty) return '0';
    if (decimals == 0) return s;
    final padded = s.padLeft(decimals + 1, '0');
    final cut = padded.length - decimals;
    final whole = padded.substring(0, cut);
    var fraction = padded.substring(cut).replaceFirst(RegExp(r'0+\$'), '');
    if (fraction.length > 8) fraction = fraction.substring(0, 8);
    return fraction.isEmpty ? whole : '$whole.$fraction';
  }

  Future<void> _requestQuote() async {
    final from = _from;
    final to = _to;
    final wallet = context.read<WalletProvider>().wallet;
    final input = _amount.text.trim();
    if (from == null || to == null || wallet?.address == null || input.isEmpty) {
      if (mounted) setState(() => _quote = null);
      return;
    }

    final numeric = double.tryParse(input) ?? 0;
    if (numeric <= 0 || numeric > from.balance) {
      if (mounted) setState(() => _quote = null);
      return;
    }

    final rawAmount = _baseUnits(input, from.decimals);
    if (rawAmount == null || rawAmount == '0') return;

    final version = ++_quoteVersion;
    setState(() => _loadingQuote = true);

    try {
      final crossChain = _chainId(from.chain) != _chainId(to.chain);
      final quote = await context.read<SwapApiService>().getQuote(
        fromChain: _chainId(from.chain),
        toChain: _chainId(to.chain),
        fromToken: from.isNative ? _native : from.contractAddress,
        toToken: to.isNative ? _native : to.contractAddress,
        fromAmount: rawAmount,
        fromAddress: wallet!.address,
        toAddress: crossChain ? wallet.address : null,
        slippageMode: 'auto',
      );

      if (!mounted || version != _quoteVersion) return;
      final approval = quote['approvalAddress']?.toString();
      var needsApproval = false;
      if (!from.isNative && approval != null && approval.isNotEmpty) {
        try {
          final rpc = context.read<WalletRpcService>();
          final crypto = context.read<WalletService>().crypto;
          final allowanceHex = await rpc.call(
            network: from.chain,
            to: from.contractAddress,
            data: crypto.encodeErc20Allowance(
              owner: wallet.address,
              spender: approval,
            ),
          );
          final clean = allowanceHex.replaceFirst(RegExp(r'^0x'), '');
          final allowance = BigInt.tryParse(clean, radix: 16) ?? BigInt.zero;
          needsApproval = allowance < BigInt.parse(rawAmount);
        } catch (e) {
          debugPrint('Swap allowance check failed: $e');
        }
      }

      setState(() {
        _quote = quote;
        _approvalRequired = needsApproval;
      });
    } catch (e) {
      if (mounted && version == _quoteVersion) {
        setState(() {
          _quote = null;
          _approvalRequired = false;
        });
        NotificationService.showError(context, 'Unable to get swap quote: $e');
      }
    } finally {
      if (mounted && version == _quoteVersion) setState(() => _loadingQuote = false);
    }
  }

  Future<Map<String, dynamic>> _transactionForSigning(
    Map<String, dynamic> request,
    String network,
    String fromAddress,
  ) async {
    final tx = Map<String, dynamic>.from(request);
    final rpc = context.read<WalletRpcService>();
    final nonce = await rpc.getPendingNonce(network: network, address: fromAddress);
    tx['nonce'] = nonce;

    final gas = tx['gasLimit']?.toString() ?? tx['gas']?.toString();
    final hasFee = tx['gasPrice'] != null || tx['maxFeePerGas'] != null;
    if (gas != null && hasFee) return tx;

    final estimate = await context.read<TransactionApiService>().estimateTransaction(
      network: network,
      transaction: {
        'from': fromAddress,
        'to': tx['to'],
        'value': tx['value']?.toString() ?? '0',
        'data': tx['data']?.toString() ?? '0x',
      },
    );
    tx['gasLimit'] ??= estimate['gasLimit'] ?? estimate['gas'];
    tx['gasPrice'] ??= estimate['gasPrice'];
    tx['maxFeePerGas'] ??= estimate['maxFeePerGas'];
    tx['maxPriorityFeePerGas'] ??= estimate['maxPriorityFeePerGas'];
    return tx;
  }

  Future<void> _approve() async {
    final from = _from;
    final quote = _quote;
    final wallet = context.read<WalletProvider>().wallet;
    if (from == null || quote == null || wallet?.address == null) return;

    final spender = quote['approvalAddress']?.toString();
    final rawAmount = _baseUnits(_amount.text, from.decimals);
    if (spender == null || spender.isEmpty || rawAmount == null) return;

    setState(() {
      _processing = true;
      _processingText = 'Preparing approval…';
    });

    try {
      final walletService = context.read<WalletService>();
      final data = walletService.crypto.encodeErc20Approve(
        spender: spender,
        amount: rawAmount,
      );
      final rpc = context.read<WalletRpcService>();
      final nonce = await rpc.getPendingNonce(network: from.chain, address: wallet.address);
      final estimate = await context.read<TransactionApiService>().estimateTransaction(
        network: from.chain,
        transaction: {
          'from': wallet.address,
          'to': from.contractAddress,
          'value': '0',
          'data': data,
        },
      );

      final signed = await walletService.signNativeTransaction(
        to: from.contractAddress,
        valueRaw: '0',
        nonce: nonce,
        gasLimit: estimate['gasLimit']?.toString() ?? estimate['gas']?.toString() ?? '100000',
        gasPrice: estimate['gasPrice']?.toString(),
        maxFeePerGas: estimate['maxFeePerGas']?.toString(),
        maxPriorityFeePerGas: estimate['maxPriorityFeePerGas']?.toString(),
        chainId: int.parse(_chainId(from.chain)),
        dataHex: data,
      );
      if (signed == null || signed.isEmpty) throw Exception('Could not sign approval');

      setState(() => _processingText = 'Broadcasting approval…');
      final result = await context.read<SwapApiService>().broadcastSwap(
        network: from.chain,
        signedTransaction: signed,
        transactionType: 'approval',
      );
      final hash = result['hash']?.toString();
      if (hash == null || hash.isEmpty) throw Exception('Backend did not return approval hash');

      setState(() => _processingText = 'Waiting for approval…');
      for (var i = 0; i < 24; i++) {
        await Future.delayed(const Duration(seconds: 5));
        final receipt = await context.read<SwapApiService>().getReceipt(network: from.chain, hash: hash);
        final status = receipt['status']?.toString();
        if (status == '0x1' || status == '1') {
          if (mounted) NotificationService.showSuccess(context, 'Token approved');
          await _requestQuote();
          return;
        }
        if (status == '0x0' || status == '0') throw Exception('Approval transaction failed');
      }
      throw Exception('Approval confirmation timed out');
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Approval failed: $e');
    } finally {
      if (mounted) setState(() { _processing = false; _processingText = ''; });
    }
  }

  Future<void> _swap() async {
    final from = _from;
    final to = _to;
    final quote = _quote;
    final wallet = context.read<WalletProvider>().wallet;
    if (from == null || to == null || quote == null || wallet?.address == null) return;

    final raw = quote['transactionRequest'];
    if (raw is! Map) {
      NotificationService.showError(context, 'This quote has no executable transaction.');
      return;
    }

    final confirmed = await _confirm(from, to, quote);
    if (!confirmed || !mounted) return;

    setState(() { _processing = true; _processingText = 'Preparing transaction…'; });
    try {
      final tx = await _transactionForSigning(Map<String, dynamic>.from(raw), from.chain, wallet.address);
      final toAddress = tx['to']?.toString();
      final data = tx['data']?.toString();
      final gasLimit = tx['gasLimit']?.toString() ?? tx['gas']?.toString();
      final chainId = int.tryParse(tx['chainId']?.toString() ?? '') ?? int.parse(_chainId(from.chain));
      if (toAddress == null || toAddress.isEmpty || data == null || data.isEmpty || gasLimit == null) {
        throw Exception('Swap transaction request is incomplete');
      }

      setState(() => _processingText = 'Signing transaction…');
      final signed = await context.read<WalletService>().signNativeTransaction(
        to: toAddress,
        valueRaw: tx['value']?.toString() ?? '0',
        nonce: int.parse(tx['nonce'].toString()),
        gasLimit: gasLimit,
        gasPrice: tx['gasPrice']?.toString(),
        maxFeePerGas: tx['maxFeePerGas']?.toString(),
        maxPriorityFeePerGas: tx['maxPriorityFeePerGas']?.toString(),
        chainId: chainId,
        dataHex: data,
      );
      if (signed == null || signed.isEmpty) throw Exception('Could not sign swap transaction');

      setState(() => _processingText = 'Broadcasting transaction…');
      final result = await context.read<SwapApiService>().broadcastSwap(
        network: from.chain,
        signedTransaction: signed,
        transactionType: 'swap',
      );
      final hash = result['hash']?.toString();
      if (hash == null || hash.isEmpty) throw Exception('Backend did not return transaction hash');

      setState(() => _processingText = 'Confirming swap…');
      await _pollStatus(hash, quote, from, to, wallet.address);
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Swap failed: $e');
    } finally {
      if (mounted) setState(() { _processing = false; _processingText = ''; });
    }
  }

  Future<void> _pollStatus(
    String hash,
    Map<String, dynamic> quote,
    TokenModel from,
    TokenModel to,
    String address,
  ) async {
    final api = context.read<SwapApiService>();
    final provider = quote['provider']?.toString().toLowerCase() ?? '';
    final type = quote['type']?.toString() ?? 'same-chain';
    final quoteId = quote['quoteId']?.toString();
    final bridge = quote['bridge']?.toString();

    for (var i = 0; i < 36; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      try {
        final status = await api.getStatus(
          transactionId: hash,
          provider: provider,
          fromChain: _chainId(from.chain),
          toChain: _chainId(to.chain),
          bridge: bridge,
          quoteId: quoteId,
          fromAddress: address,
          swapType: type,
        );
        final value = status['status']?.toString().toUpperCase();
        if (value == 'CONFIRMED' || value == 'SUCCESS' || value == 'COMPLETED') {
          NotificationService.showSuccess(context, 'Swap successful');
          await context.read<WalletProvider>().loadWallet();
          if (mounted) Navigator.of(context).pop();
          return;
        }
        if (value == 'FAILED' || value == 'ERROR') {
          throw Exception(status['message']?.toString() ?? 'Swap failed on-chain');
        }
      } catch (e) {
        if (i == 35 && mounted) throw Exception(e.toString());
      }
    }
    if (mounted) NotificationService.showInfo(context, 'Swap is still pending. Check your transaction history later.');
  }

  Future<bool> _confirm(TokenModel from, TokenModel to, Map<String, dynamic> quote) async {
    final colors = Theme.of(context).colorScheme;
    final amount = _amount.text.trim();
    final received = _displayUnits(quote['toAmount'], to.decimals);
    final minReceived = _displayUnits(quote['toAmountMin'], to.decimals);
    final fee = quote['fee'];
    final feeMap = fee is Map ? Map<String, dynamic>.from(fee) : <String, dynamic>{};

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 42, height: 4, decoration: BoxDecoration(color: colors.outlineVariant, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 22),
              const Text('Review Swap', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _reviewAsset(from, amount, colors)),
                  Icon(Icons.arrow_forward_rounded, color: colors.primary),
                  Expanded(child: _reviewAsset(to, received, colors, accent: true)),
                ],
              ),
              const SizedBox(height: 22),
              _reviewRow('Provider', quote['provider']?.toString() ?? '-'),
              _reviewRow('Minimum received', '$minReceived ${to.symbol}'),
              _reviewRow('Griot fee', _displayUnits(feeMap['amount'], from.decimals) + ' ' + from.symbol),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm Swap')),
              ),
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ],
          ),
        ),
      ),
    );
    return result == true;
  }

  Widget _reviewAsset(TokenModel token, String amount, ColorScheme colors, {bool accent = false}) {
    return Column(children: [
      TokenIcon(imageUrl: token.imageUrl, symbol: token.symbol, name: token.name, chainName: token.chain, isNative: token.isNative, radius: 22),
      const SizedBox(height: 8),
      Text(amount, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: accent ? colors.primary : null)),
      Text(token.symbol, style: TextStyle(color: colors.onSurfaceVariant)),
    ]);
  }

  Widget _reviewRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.w600))]),
  );

  void _pickToken(bool fromSide) {
    final tokens = context.read<WalletProvider>().tokens.where((t) => t.balance >= 0).toList();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView.builder(
        itemCount: tokens.length,
        itemBuilder: (_, i) {
          final token = tokens[i];
          return ListTile(
            leading: TokenIcon(imageUrl: token.imageUrl, symbol: token.symbol, name: token.name, chainName: token.chain, isNative: token.isNative, radius: 18),
            title: Text(token.symbol, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(token.chain.toUpperCase()),
            trailing: Text(WalletFormatters.formatBalance(token.balance)),
            onTap: () {
              setState(() { if (fromSide) _from = token; else _to = token; _quote = null; _approvalRequired = false; });
              Navigator.pop(context);
              _requestQuote();
            },
          );
        },
      ),
    );
  }

  Widget _assetCard(String label, TokenModel? token, {required bool fromSide}) {
    final colors = Theme.of(context).colorScheme;
    final amount = fromSide ? _amount.text : (_quote == null || token == null ? '0' : _displayUnits(_quote!['toAmount'], token.decimals));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: colors.surfaceContainerLowest, borderRadius: BorderRadius.circular(28), border: Border.all(color: colors.outlineVariant.withValues(alpha: .2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(color: colors.onSurfaceVariant, fontWeight: FontWeight.w600)),
          if (token != null) Text('Balance ${WalletFormatters.formatBalance(token.balance)}', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Text(fromSide ? (amount.isEmpty ? '0' : amount) : amount, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700))),
          InkWell(
            onTap: () => _pickToken(fromSide),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (token != null) TokenIcon(imageUrl: token.imageUrl, symbol: token.symbol, name: token.name, chainName: token.chain, isNative: token.isNative, radius: 15),
                if (token != null) const SizedBox(width: 7),
                Text(token?.symbol ?? 'Select', style: const TextStyle(fontWeight: FontWeight.w700)),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ]),
            ),
          ),
        ]),
        if (fromSide && token != null) ...[
          const SizedBox(height: 10),
          Text(WalletFormatters.formatCurrency((double.tryParse(amount) ?? 0) * token.priceUsd.toDouble()), style: TextStyle(color: colors.onSurfaceVariant)),
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () { _amount.text = token.balance.toString(); }, child: const Text('MAX'))),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final quote = _quote;
    return GradientScaffold(
      appBar: AppBar(title: const Text('Swap'), centerTitle: true, backgroundColor: Colors.transparent, elevation: 0),
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 30), children: [
        _assetCard('Pay', _from, fromSide: true),
        Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 6), decoration: BoxDecoration(color: colors.surface, shape: BoxShape.circle, border: Border.all(color: colors.outlineVariant.withValues(alpha: .25))), child: IconButton(icon: const Icon(Icons.swap_vert_rounded), onPressed: () { setState(() { final x = _from; _from = _to; _to = x; _amount.clear(); _quote = null; }); }))),
        _assetCard('Receive', _to, fromSide: false),
        if (_loadingQuote) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
        if (quote != null) _quoteCard(quote),
        const SizedBox(height: 20),
        SizedBox(height: 58, child: FilledButton(
          onPressed: _processing || _loadingQuote || quote == null ? null : (_approvalRequired ? _approve : _swap),
          child: _processing ? Text(_processingText) : Text(_approvalRequired ? 'Approve ${_from?.symbol ?? ''}' : 'Swap'),
        )),
      ]),
    );
  }

  Widget _quoteCard(Map<String, dynamic> quote) {
    final colors = Theme.of(context).colorScheme;
    final fee = quote['fee'];
    final feeMap = fee is Map ? Map<String, dynamic>.from(fee) : <String, dynamic>{};
    final risk = quote['risk'];
    final riskMap = risk is Map ? Map<String, dynamic>.from(risk) : <String, dynamic>{};
    final priceImpact = riskMap['priceImpact'];
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: colors.surfaceContainerLow.withValues(alpha: .55), borderRadius: BorderRadius.circular(22)),
      child: Column(children: [
        Row(children: [Icon(Icons.receipt_long_rounded, size: 18, color: colors.primary), const SizedBox(width: 8), const Text('Quote details', style: TextStyle(fontWeight: FontWeight.w700))]),
        const SizedBox(height: 14),
        _reviewRow('Provider', quote['provider']?.toString() ?? '-'),
        _reviewRow('Type', quote['type']?.toString() ?? '-'),
        _reviewRow('Minimum received', '${_displayUnits(quote['toAmountMin'], _to?.decimals ?? 18)} ${_to?.symbol ?? ''}'),
        _reviewRow('Griot fee', '${_displayUnits(feeMap['amount'], _from?.decimals ?? 18)} ${_from?.symbol ?? ''}'),
        if (priceImpact != null) _reviewRow('Price impact', '$priceImpact%'),
        if (quote['fallbackUsed'] == true) Padding(padding: const EdgeInsets.only(top: 10), child: Align(alignment: Alignment.centerLeft, child: Text('Fallback provider used', style: TextStyle(color: colors.tertiary, fontWeight: FontWeight.w600)))),
      ]),
    );
  }
}
