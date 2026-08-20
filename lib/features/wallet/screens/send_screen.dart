import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../models/token_model.dart';
import '../services/transaction_api_service.dart';
import '../services/wallet_crypto_service.dart';
import '../services/wallet_storage_service.dart';

class SendScreen extends StatefulWidget {
  final TokenModel? initialToken;

  const SendScreen({
    super.key,
    this.initialToken,
  });

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();

  final _apiClient = ApiClient();
  late final TransactionApiService _transactionApi;
  final _cryptoService = WalletCryptoService();
  final _storageService = WalletStorageService();

  bool _loading = false;
  String? _error;
  String? _transactionHash;

  String get _network {
    final chain = (widget.initialToken?.chain ?? 'bsc')
        .trim()
        .toLowerCase();

    if (chain == 'bnb' || chain == 'bnb smart chain') {
      return 'bsc';
    }

    return chain.isEmpty ? 'bsc' : chain;
  }

  String get _symbol =>
      widget.initialToken?.symbol.isNotEmpty == true
          ? widget.initialToken!.symbol
          : 'BNB';

  bool get _isNative =>
      widget.initialToken == null || widget.initialToken!.isNative;

  @override
  void initState() {
    super.initState();
    _transactionApi = TransactionApiService(
      apiClient: _apiClient,
    );
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    _apiClient.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();

    if (!_isNative) {
      setState(() {
        _error = 'Token sending will be added after native coin sending.';
      });
      return;
    }

    final recipient = _recipientController.text.trim();
    final amount = _amountController.text.trim();

    if (!_cryptoService.isValidAddress(recipient)) {
      setState(() {
        _error = 'Enter a valid recipient address.';
      });
      return;
    }

    if (amount.isEmpty || num.tryParse(amount) == null || num.parse(amount) <= 0) {
      setState(() {
        _error = 'Enter a valid amount.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _transactionHash = null;
    });

    try {
      final prepared = await _transactionApi.prepareNativeSend(
        network: _network,
        toAddress: recipient,
        amount: amount,
      );

      final privateKey = await _storageService.getPrivateKey();

      if (privateKey == null || privateKey.isEmpty) {
        throw Exception('Wallet private key is unavailable.');
      }

      final unsigned = Map<String, dynamic>.from(
        prepared['unsignedTransaction'] as Map,
      );

      final signed = await _cryptoService.signNativeTransaction(
        privateKey: privateKey,
        to: unsigned['to'].toString(),
        valueRaw: unsigned['value'].toString(),
        nonce: int.parse(unsigned['nonce'].toString()),
        gasLimit: unsigned['gasLimit'].toString(),
        gasPrice: unsigned['gasPrice'].toString(),
        chainId: int.parse(unsigned['chainId'].toString()),
      );

      final broadcast = await _transactionApi.broadcastTransaction(
        network: _network,
        transactionId: prepared['transactionId'].toString(),
        signedTransaction: signed,
      );

      final broadcastData = broadcast['broadcast'];
      final hash = broadcastData is Map
          ? broadcastData['hash']?.toString()
          : null;

      if (hash == null || hash.isEmpty) {
        throw Exception('Transaction was broadcast without a transaction hash.');
      }

      if (!mounted) return;

      setState(() {
        _transactionHash = hash;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_symbol transaction sent.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Send'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Send $_symbol',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _recipientController,
            keyboardType: TextInputType.text,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Recipient address',
              hintText: '0x...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              suffixText: _symbol,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          if (_transactionHash != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SelectableText(
                'Transaction: $_transactionHash',
              ),
            ),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _loading ? null : _send,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send'),
            ),
          ),
        ],
      ),
    );
  }
}
