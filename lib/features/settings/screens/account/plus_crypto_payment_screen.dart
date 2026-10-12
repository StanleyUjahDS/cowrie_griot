import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../wallet/models/token_model.dart';
import '../../../wallet/providers/wallet_provider.dart';
import '../../../wallet/screens/send_screen.dart';

class PlusCryptoPaymentScreen extends StatefulWidget {
  const PlusCryptoPaymentScreen({super.key});

  @override
  State<PlusCryptoPaymentScreen> createState() =>
      _PlusCryptoPaymentScreenState();
}

class _PlusCryptoPaymentScreenState extends State<PlusCryptoPaymentScreen> {
  List<Map<String, dynamic>> _catalog = [];
  String _productId = 'griot_plus_monthly';
  String? _network;
  String? _token;
  Map<String, dynamic>? _invoice;
  bool _loading = true;
  bool _creating = false;
  String? _error;
  final _hashController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _hashController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final response = await context.read<ApiClient>().get(
        ApiConfig.plusCryptoCatalog,
      );
      final raw = response is Map ? response['data'] : response;
      final rows = raw is List
          ? raw
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _catalog = rows;
        _loading = false;
        _network ??= rows.isNotEmpty ? rows.first['network']?.toString() : null;
        _token ??= rows.isNotEmpty ? rows.first['token']?.toString() : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<Map<String, dynamic>> get _options => _catalog
      .where((row) => row['productId']?.toString() == _productId)
      .toList();

  Map<String, dynamic>? get _selected {
    for (final row in _options) {
      if (row['network']?.toString() == _network &&
          row['token']?.toString() == _token) {
        return row;
      }
    }
    return _options.isEmpty ? null : _options.first;
  }

  Future<void> _createInvoice() async {
    final selected = _selected;
    if (selected == null) return;
    setState(() => _creating = true);
    try {
      final response = await context.read<ApiClient>().post(
        ApiConfig.plusCryptoInvoices,
        body: {
          'productId': _productId,
          'network': selected['network'],
          'token': selected['token'],
        },
      );
      final data = response is Map && response['data'] is Map
          ? Map<String, dynamic>.from(response['data'])
          : <String, dynamic>{};
      if (data.isEmpty) throw Exception('The payment invoice was not created.');
      if (!mounted) return;
      setState(() => _invoice = data);
    } catch (error) {
      if (mounted)
        NotificationService.showError(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _verifyPayment() async {
    final invoice = _invoice;
    final hash = _hashController.text.trim();
    if (invoice == null || hash.isEmpty) return;
    try {
      final response = await context.read<ApiClient>().post(
        ApiConfig.plusCryptoInvoiceVerify(invoice['id'].toString()),
        body: {'txHash': hash},
      );
      final data = response is Map && response['data'] is Map
          ? response['data']
          : const {};
      if (!mounted) return;
      NotificationService.showSuccess(
        context,
        data['status'] == 'paid'
            ? 'Griot Plus is now active.'
            : 'Payment submitted for verification.',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted)
        NotificationService.showError(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
    }
  }

  Future<void> _openWallet() async {
    final invoice = _invoice;
    if (invoice == null) return;
    final address =
        invoice['treasury_address']?.toString() ??
        invoice['treasuryAddress']?.toString();
    final network = invoice['network']?.toString() ?? '';
    final tokenAddress =
        invoice['token_contract']?.toString() ??
        invoice['tokenContract']?.toString();
    final wallet = context.read<WalletProvider>();
    TokenModel? token;
    for (final candidate in wallet.tokens) {
      if (candidate.chain.toLowerCase() == network.toLowerCase() &&
          candidate.contractAddress.toLowerCase() ==
              (tokenAddress ?? '').toLowerCase()) {
        token = candidate;
        break;
      }
    }
    if (token == null || address == null) {
      if (mounted)
        NotificationService.showInfo(
          context,
          'Open Wallet and add this token on the $network network first.',
        );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SendScreen(
          initialToken: token,
          initialAddress: address,
          initialAmount: (invoice['amountUsdt'] ?? invoice['amountUsd'])
              .toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GradientScaffold(
      appBar: AppBar(
        title: const Text(
          'Pay with crypto',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
              children: [
                _intro(colors),
                const SizedBox(height: 20),
                _productPicker(colors),
                const SizedBox(height: 12),
                _networkPicker(colors),
                const SizedBox(height: 18),
                if (_invoice == null) _createButton() else _invoiceCard(colors),
              ],
            ),
    );
  }

  Widget _intro(ColorScheme colors) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: colors.primary.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: colors.primary.withValues(alpha: .25)),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Griot Network payment',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 8),
        Text(
          'Pay Griot Plus directly with USDT or USDC on a supported network. Payments are verified on-chain before Plus is activated.',
        ),
      ],
    ),
  );

  Widget _productPicker(ColorScheme colors) => SegmentedButton<String>(
    segments: const [
      ButtonSegment(value: 'griot_plus_monthly', label: Text('Monthly')),
      ButtonSegment(value: 'griot_plus_yearly', label: Text('Yearly')),
    ],
    selected: {_productId},
    onSelectionChanged: (value) => setState(() {
      _productId = value.first;
      _invoice = null;
    }),
  );

  Widget _networkPicker(ColorScheme colors) {
    final options = _options;
    final networks = options
        .map((row) => row['network'].toString())
        .toSet()
        .toList();
    final tokens = options
        .where((row) => row['network'].toString() == _network)
        .map((row) => row['token'].toString())
        .toSet()
        .toList();
    if (!networks.contains(_network))
      _network = networks.isEmpty ? null : networks.first;
    if (!tokens.contains(_token)) _token = tokens.isEmpty ? null : tokens.first;
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _network,
            decoration: const InputDecoration(
              labelText: 'Network',
              border: OutlineInputBorder(),
            ),
            items: networks
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value.toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() {
              _network = value;
              _token = null;
              _invoice = null;
            }),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _token,
            decoration: const InputDecoration(
              labelText: 'Token',
              border: OutlineInputBorder(),
            ),
            items: tokens
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value.toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() {
              _token = value;
              _invoice = null;
            }),
          ),
        ),
      ],
    );
  }

  Widget _createButton() => SizedBox(
    height: 56,
    child: FilledButton.icon(
      onPressed: _creating ? null : _createInvoice,
      icon: _creating
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.receipt_long_rounded),
      label: Text(_creating ? 'Creating invoice…' : 'Create payment invoice'),
    ),
  );

  Widget _invoiceCard(ColorScheme colors) {
    final invoice = _invoice!;
    final address =
        invoice['treasury_address']?.toString() ??
        invoice['treasuryAddress']?.toString() ??
        '';
    final amount = invoice['amountUsdt'] ?? invoice['amountUsd'] ?? '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: .6),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$amount ${invoice['currency'] ?? _token?.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${invoice['network']?.toString().toUpperCase()} • Send exactly this amount',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              SelectableText(
                address,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: address));
                  NotificationService.showInfo(
                    context,
                    'Treasury address copied.',
                  );
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy address'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _openWallet,
          icon: const Icon(Icons.account_balance_wallet_rounded),
          label: const Text('Pay from Griot Wallet'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _showVerifyDialog(),
          icon: const Icon(Icons.verified_rounded),
          label: const Text('I have paid — verify transaction'),
        ),
        TextButton(
          onPressed: () => setState(() => _invoice = null),
          child: const Text('Choose a different network or token'),
        ),
      ],
    );
  }

  Future<void> _showVerifyDialog() async {
    _hashController.clear();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verify payment'),
        content: TextField(
          controller: _hashController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Transaction hash',
            hintText: '0x…',
          ),
          minLines: 1,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _verifyPayment();
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Widget _errorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _loadCatalog();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
