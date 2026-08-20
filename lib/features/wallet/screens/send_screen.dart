import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/token_model.dart';
import '../providers/wallet_provider.dart';
import '../services/transaction_api_service.dart';
import '../widgets/token_icon.dart';
import '../utils/wallet_formatters.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/banner_ad.dart';
import '../../../core/services/notification_service.dart';

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
  TokenModel? _selectedToken;
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedToken = widget.initialToken;
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (_selectedToken == null) {
      NotificationService.showError(context, 'Please select a token');
      return;
    }

    final address = _addressController.text.trim();
    if (address.isEmpty) {
      NotificationService.showError(context, 'Please enter a recipient address');
      return;
    }

    final amount = _amountController.text.trim();
    if (amount.isEmpty) {
      NotificationService.showError(context, 'Please enter an amount');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final api = context.read<TransactionApiService>();
      
      // Step 1: Prepare
      final prepared = await api.prepareNativeSend(
        network: _selectedToken!.chain,
        toAddress: address,
        amount: amount,
      );

      if (prepared.containsKey('transactionId')) {
        // In a real flow, we would sign here and then broadcast
        if (!mounted) return;
        NotificationService.showSuccess(context, 'Transaction prepared successfully');
      } else {
        throw Exception('Failed to prepare transaction');
      }
    } catch (e) {
      if (!mounted) return;
      NotificationService.showError(context, 'Send failed: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
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
                      // Select Asset
                      Text('Select Asset', style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildAssetSelector(context),

                      const SizedBox(height: 32),

                      // Recipient
                      Text('Recipient Address', style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          hintText: 'Enter 0x address',
                          prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            onPressed: () {}, // TODO: Scan QR
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Amount
                      Text('Amount', style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: text.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          suffixText: _selectedToken?.symbol ?? '',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        ),
                      ),
                      
                      const SizedBox(height: 48),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _handleSend,
                          child: _isLoading 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Review Transaction', style: TextStyle(fontWeight: FontWeight.bold)),
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
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
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
                    Text(_selectedToken!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      'Balance: ${WalletFormatters.formatBalance(_selectedToken!.balance)} ${_selectedToken!.symbol}',
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ] else
              const Expanded(child: Text('Choose a token to send')),
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
              subtitle: Text('${token.symbol} on ${token.chain.toUpperCase()}'),
              trailing: Text(WalletFormatters.formatBalance(token.balance)),
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
