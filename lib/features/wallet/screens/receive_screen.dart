import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import '../models/token_model.dart';
import '../providers/wallet_provider.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';

class ReceiveScreen extends StatelessWidget {
  final TokenModel? token;

  const ReceiveScreen({
    super.key,
    this.token,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    
    return Consumer<WalletProvider>(
      builder: (context, provider, child) {
        final address = provider.wallet?.address ?? 'No address found';
        
        return GradientScaffold(
          appBar: AppBar(
            title: Text('Receive ${token?.symbol ?? ''}'),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: QrImageView(
                    data: address,
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Your Wallet Address',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  address,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
