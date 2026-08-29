import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../../core/ui/widgets/griot_loader.dart';
import '../../../../features/wallet/services/wallet_service.dart';

class BackupWalletScreen extends StatefulWidget {
  const BackupWalletScreen({super.key});

  @override
  State<BackupWalletScreen> createState() => _BackupWalletScreenState();
}

class _BackupWalletScreenState extends State<BackupWalletScreen> {
  String? _mnemonic;
  String? _privateKey;
  bool _isLoading = true;
  bool _showPrivateKey = false;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    final walletService = context.read<WalletService>();
    try {
      final m = await walletService.getMnemonic();
      final p = await walletService.getPrivateKey();
      if (mounted) {
        setState(() {
          _mnemonic = m;
          _privateKey = p;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to load wallet data');
        Navigator.pop(context);
      }
    }
  }

  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      NotificationService.showSuccess(context, '$label copied to clipboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text(
          'Backup Wallet',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeOutQuart,
        child: _buildBody(colors, text),
      ),
    );
  }

  Widget _buildBody(ColorScheme colors, TextTheme text) {
    if (_isLoading) {
      return const Center(
        key: ValueKey('loading'),
        child: GriotLoader(),
      );
    }

    return SingleChildScrollView(
      key: const ValueKey('content'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSecurityWarning(colors, text),
          const SizedBox(height: 32),
          
          if (_mnemonic != null) ...[
            Text(
              'RECOVERY PHRASE',
              style: text.labelSmall?.copyWith(
                color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _MnemonicDisplay(mnemonic: _mnemonic!),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () => _copyToClipboard(_mnemonic!, 'Recovery phrase'),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy Phrase', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PRIVATE KEY',
                style: text.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              Switch.adaptive(
                value: _showPrivateKey,
                onChanged: (v) => setState(() => _showPrivateKey = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_showPrivateKey && _privateKey != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.outline.withValues(alpha: 0.1)),
              ),
              child: Text(
                _privateKey!,
                style: const TextStyle(
                  fontFamily: 'Monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: () => _copyToClipboard(_privateKey!, 'Private key'),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy Private Key', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.outline.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  Icon(Icons.visibility_off_rounded, color: colors.onSurfaceVariant.withValues(alpha: 0.3)),
                  const SizedBox(height: 8),
                  Text(
                    'Hidden for security',
                    style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
            
          const SizedBox(height: 48),
        ].animate(interval: 50.ms).fade(duration: 400.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad),
      ),
    );
  }

  Widget _buildSecurityWarning(ColorScheme colors, TextTheme text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.error.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
          const SizedBox(height: 12),
          const Text(
            'NEVER SHARE THIS INFORMATION',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.red, fontSize: 13, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Anyone with your recovery phrase or private key can take full control of your wallet and funds. Griot will never ask for this.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _MnemonicDisplay extends StatelessWidget {
  final String mnemonic;
  const _MnemonicDisplay({required this.mnemonic});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final words = mnemonic.split(' ');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outline.withValues(alpha: 0.05)),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: words.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
        ),
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.outline.withValues(alpha: 0.1)),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${index + 1}',
                style: TextStyle(fontSize: 10, color: colors.primary.withValues(alpha: 0.5), fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              Text(
                words[index],
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
