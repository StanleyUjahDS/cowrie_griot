import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/token_model.dart';
import '../providers/wallet_provider.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/banner_ad.dart';
import '../../../core/services/notification_service.dart';

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
    final text = theme.textTheme;

    return Consumer<WalletProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.wallet == null) {
          return const GradientScaffold(
            useSafeArea: false,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final address = provider.wallet?.address;
        if (address == null || address.isEmpty) {
          return GradientScaffold(
            useSafeArea: true,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              title: const Text('Receive', style: TextStyle(fontWeight: FontWeight.w800)),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, size: 48, color: colors.error),
                  const SizedBox(height: 16),
                  const Text('No wallet address found'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => provider.loadWallet(force: true),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final symbol = token?.symbol ?? 'Assets';
        final isEvm = _isEvm(token?.chain ?? 'ethereum');

        return GradientScaffold(
          useSafeArea: true,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Text('Receive $symbol', style: const TextStyle(fontWeight: FontWeight.w800)),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      
                      // QR Card
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'YOUR $symbol ADDRESS',
                              style: text.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // QR Code
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
                                eyeStyle: QrEyeStyle(
                                  eyeShape: QrEyeShape.circle,
                                  color: colors.primary,
                                ),
                                dataModuleStyle: QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.circle,
                                  color: colors.primary.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Address display
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: address));
                                NotificationService.showSuccess(context, 'Address copied');
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _formatAddress(address),
                                  textAlign: TextAlign.center,
                                  style: text.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.9, 0.9)),
                      
                      const SizedBox(height: 32),
                      
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.copy_rounded,
                              label: 'Copy',
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: address));
                                NotificationService.showSuccess(context, 'Address copied');
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _ActionButton(
                              icon: Icons.share_rounded,
                              label: 'Share',
                              onTap: () {
                                SharePlus.instance.share(
                                  ShareParams(
                                    text: 'My Cowrie Griot Wallet Address ($symbol):\n\n$address',
                                    subject: 'My Wallet Address',
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Info Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colors.primary.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: colors.primary, size: 20),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'NETWORK: ${token?.chain.toUpperCase() ?? 'MULTICHAIN'}',
                                    style: text.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: colors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isEvm
                                        ? 'This address only supports EVM compatible assets. Sending other assets will result in permanent loss.'
                                        : 'Ensure you are sending assets on the correct network (${token?.chain.toUpperCase() ?? 'MULTICHAIN'}). Incorrect network usage may result in loss.',
                                    style: text.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              const GriotBannerAd(isCompact: true),
            ],
          ),
        );
      },
    );
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

  String _formatAddress(String addr) {
    if (addr.length < 24) return addr;
    return '${addr.substring(0, 12)}...${addr.substring(addr.length - 10)}';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
