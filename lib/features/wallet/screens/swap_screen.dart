import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/token_model.dart';
import '../providers/wallet_provider.dart';
import '../services/swap_api_service.dart';
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

  @override
  void initState() {
    super.initState();
    _fromToken = widget.initialFromToken;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _getQuote() async {
    if (_fromToken == null || _toToken == null) return;

    final amount = _amountController.text.trim();
    if (amount.isEmpty) return;

    final wallet = context.read<WalletProvider>().wallet;
    final fromAddress = wallet?.address;

    if (fromAddress == null || fromAddress.isEmpty) {
      NotificationService.showError(context, 'Wallet address is not available');
      return;
    }

    final fromToken = _fromToken!;
    final toToken = _toToken!;

    final fromTokenAddress = fromToken.isNative
        ? _nativeTokenAddress
        : fromToken.contractAddress;
    final toTokenAddress = toToken.isNative
        ? _nativeTokenAddress
        : toToken.contractAddress;

    if (fromTokenAddress.isEmpty || toTokenAddress.isEmpty) {
      NotificationService.showError(context, 'Swap token address is not available');
      return;
    }

    final fromAmount = _toBaseUnits(amount, fromToken.decimals);

    if (fromAmount == null || fromAmount == '0') {
      NotificationService.showError(context, 'Enter a valid swap amount');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = context.read<SwapApiService>();
      final quote = await api.getQuote(
        fromChain: fromToken.chain,
        toChain: toToken.chain,
        fromToken: fromTokenAddress,
        toToken: toTokenAddress,
        fromAmount: fromAmount,
        fromAddress: fromAddress,
      );

      if (mounted) {
        setState(() => _quote = quote);
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Quote failed: $e');
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
    final raw = '$whole$paddedFraction'.replaceFirst(RegExp(r'^0+(?=\d)'), '');

    if (!RegExp(r'^\d+$').hasMatch(raw)) return null;

    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Swap'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildSwapCard(
                    context,
                    label: 'From',
                    token: _fromToken,
                    onTokenTap: () => _showTokenPicker(context, isFrom: true),
                    controller: _amountController,
                    onChanged: (val) => _getQuote(),
                  ),
                  const SizedBox(height: 12),
                  CircleAvatar(
                    backgroundColor: colors.primary,
                    child: IconButton(
                      icon: const Icon(Icons.swap_vert_rounded, color: Colors.white),
                      onPressed: _swapTokens,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSwapCard(
                    context,
                    label: 'To',
                    token: _toToken,
                    onTokenTap: () => _showTokenPicker(context, isFrom: false),
                    isReadOnly: true,
                    value: _quote?['toAmount']?.toString() ?? '0.00',
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
                      onPressed: (_fromToken != null && _toToken != null && !_isLoading)
                          ? () => NotificationService.showSuccess(context, 'Swap Initiated')
                          : null,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Swap Assets', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const GriotBannerAd(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _swapTokens() {
    setState(() {
      final temp = _fromToken;
      _fromToken = _toToken;
      _toToken = temp;
      _quote = null;
    });
    _getQuote();
  }

  Widget _buildSwapCard(
    BuildContext context, {
    required String label,
    TokenModel? token,
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
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: text.labelLarge?.copyWith(color: colors.onSurfaceVariant)),
              if (token != null)
                Text(
                  'Balance: ${WalletFormatters.formatBalance(token.balance)}',
                  style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: isReadOnly
                    ? Text(value ?? '0.00', style: text.headlineMedium?.copyWith(fontWeight: FontWeight.bold))
                    : TextField(
                        controller: controller,
                        onChanged: onChanged,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: text.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        Text(token.symbol, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ] else
                        const Text('Select', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
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
    final text = Theme.of(context).textTheme;
    final fee = _quote?['fee'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _quoteRow(context, 'Provider', _quote?['provider']?.toString() ?? '-'),
          const SizedBox(height: 8),
          _quoteRow(context, 'Type', _quote?['type']?.toString() ?? '-'),
          const SizedBox(height: 8),
          _quoteRow(
            context,
            'Swap Fee',
            fee is Map<String, dynamic> ? '${fee['percent'] ?? 0}%' : '-',
          ),
          if (fee is Map<String, dynamic> && fee['amount'] != null) ...[
            const SizedBox(height: 8),
            _quoteRow(context, 'Fee Amount', fee['amount'].toString()),
          ],
        ],
      ),
    );
  }

  Widget _quoteRow(BuildContext context, String label, String value, {bool isWarning = false}) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
        Text(
          value,
          style: text.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: isWarning ? Colors.orange : null,
          ),
        ),
      ],
    );
  }

  void _showTokenPicker(BuildContext context, {required bool isFrom}) {
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
              subtitle: Text('${token.symbol} on ${token.chain.toUpperCase()}'),
              trailing: Text(WalletFormatters.formatBalance(token.balance)),
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
        );
      },
    );
  }
}
