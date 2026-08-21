import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
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
        final address = provider.wallet?.address ?? 'No address found';
        final symbol = token?.symbol ?? 'Assets';

        return GradientScaffold(
          appBar: AppBar(
            title: Text('Receive $symbol', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          bottomNavigationBar: const SafeArea(child: GriotBannerAd()),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Premium Glass Card for QR
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // QR Code with Logo
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: QrImageView(
                          data: address,
                          version: QrVersions.auto,
                          size: 240.0,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.circle,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.circle,
                            color: Colors.black,
                          ),
                          embeddedImage: const AssetImage('assets/cowrie_images/wolrd_cowrie.png'),
                          embeddedImageStyle: const QrEmbeddedImageStyle(
                            size: Size(60, 60),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Your $symbol Address',
                        style: text.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: address));
                          NotificationService.showSuccess(context, 'Address copied to clipboard');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            address,
                            textAlign: TextAlign.center,
                            style: text.bodyMedium?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Monospace',
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
                          Share.share(
                            'My Cowrie Griot Wallet Address ($symbol):\n\n$address',
                            subject: 'My Wallet Address',
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Warning Note
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.errorContainer.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.error.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: colors.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Only send ${token?.name ?? symbol} to this address via the ${token?.chain.toUpperCase() ?? 'correct'} network.',
                          style: text.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.primary.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: colors.primary, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: text.labelLarge?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
