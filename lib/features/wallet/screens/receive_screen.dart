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
                const SizedBox(height: 12),
                
                // Animated Premium QR Section
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer Decorative Glow
                      Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              colors.primary.withValues(alpha: 0.15),
                              colors.primary.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                       .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2), duration: 3.seconds, curve: Curves.easeInOut),

                      // Main Card
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: colors.surface.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(48),
                          border: Border.all(
                            color: colors.outlineVariant.withValues(alpha: 0.15),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'YOUR $symbol ADDRESS',
                                  style: text.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    SharePlus.instance.share(
                                      ShareParams(
                                        text: 'My Cowrie Griot Wallet Address ($symbol):\n\n$address',
                                        subject: 'My Wallet Address',
                                      ),
                                    );
                                  },
                                  icon: Icon(Icons.share_rounded, size: 20, color: colors.primary.withValues(alpha: 0.6)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // QR Code with Logo and Gradient
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.primary.withValues(alpha: 0.1),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: QrImageView(
                                data: address,
                                version: QrVersions.auto,
                                size: 220.0,
                                // Eye Style with Brand Gradient
                                eyeStyle: QrEyeStyle(
                                  eyeShape: QrEyeShape.circle,
                                  color: colors.primary,
                                ),
                                // Data Module with softer circular shape and brand blending
                                dataModuleStyle: QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.circle,
                                  color: colors.primary.withValues(alpha: 0.9),
                                ),
                                embeddedImage: const AssetImage('assets/cowrie_images/wolrd_cowrie.png'),
                                embeddedImageStyle: const QrEmbeddedImageStyle(
                                  size: Size(54, 54),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: address));
                                NotificationService.showSuccess(context, 'Copied');
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.1)),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _formatAddress(address),
                                    textAlign: TextAlign.center,
                                    style: text.bodyLarge?.copyWith(
                                      color: colors.onSurface,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                      fontFamily: 'Monospace',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // COPY Action Button (Sharing is now integrated above)
                SizedBox(
                  width: double.infinity,
                  child: _ActionPill(
                    icon: Icons.copy_all_rounded,
                    label: 'COPY ADDRESS',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: address));
                      NotificationService.showSuccess(context, 'Address copied');
                    },
                  ),
                ).animate().fadeIn(delay: 300.ms),
                
                const SizedBox(height: 40),
                
                // Network Badge & Note
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.info_outline_rounded, color: colors.primary, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NETWORK: ${token?.chain.toUpperCase() ?? 'EVM (MULTIPLE CHAINS)'}',
                              style: text.labelSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: colors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'This address supports all major EVM networks including Ethereum, BNB Chain, Polygon, Base, Arbitrum, and Optimism. Only send supported assets or they will be lost.',
                              style: text.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 500.ms),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatAddress(String addr) {
    if (addr.length < 20) return addr;
    return '${addr.substring(0, 10)}...${addr.substring(addr.length - 8)}';
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: colors.onPrimary, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: text.labelLarge?.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
