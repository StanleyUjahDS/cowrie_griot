import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/referral_provider.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_loader.dart';
import '../../../core/services/notification_service.dart';
import '../../users/providers/user_provider.dart';
import '../models/referral_model.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final _referralController = TextEditingController();
  final GlobalKey _qrKey = GlobalKey();

  String _getPreferredCode(ReferralData referral, String? username) {
    if (username != null && username.isNotEmpty) {
      return username.replaceFirst('@', '');
    }
    return referral.referralCode;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReferralProvider>().loadReferralStatus();
    });
  }

  @override
  void dispose() {
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _handleClaim() async {
    final code = _referralController.text.trim();
    if (code.isEmpty) {
      NotificationService.showError(context, 'Please enter a referral code');
      return;
    }

    try {
      await context.read<ReferralProvider>().claimReferral(code);
      if (mounted) {
        NotificationService.showSuccess(context, 'Referral claimed successfully!');
        _referralController.clear();
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _shareReferral(String code) async {
    final link = 'https://griot.network/join?ref=$code';
    final text = 'Join me on Griot! My code: $code\n\n$link';
    
    await Share.share(text, subject: 'Join Griot');
  }

  Future<void> _showQRSheet(BuildContext context, String code) async {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final link = 'https://griot.network/join?ref=$code';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),
            Text('Referral QR Code', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Scan to join the Griot community', style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
            const SizedBox(height: 32),
            
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: QrImageView(
                  data: link,
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
                  embeddedImage: const AssetImage('assets/cowrie_images/wolrd_cowrie.png'),
                  embeddedImageStyle: const QrEmbeddedImageStyle(
                    size: Size(44, 44),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            Text(
              code.startsWith('0x') ? _shortenAddress(code) : '@$code',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: () => _shareQRImage(code),
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share QR Image', style: TextStyle(fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: text.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: colors.onSurfaceVariant)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortenAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  Future<void> _shareQRImage(String code) async {
    try {
      final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/griot_referral_qr.png').create();
      await file.writeAsBytes(buffer);

      final link = 'https://griot.network/join?ref=$code';
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Join me on Griot! My code: $code\n\n$link',
      );
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to share QR code');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final username = userProvider.user?.username;

    return Consumer<ReferralProvider>(
      builder: (context, provider, child) {
        final data = provider.data;
        final displayCode = data != null ? _getPreferredCode(data, username) : '';

        return GradientScaffold(
          appBar: AppBar(
            title: const Text('Refer & Earn'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          child: RefreshIndicator(
            onRefresh: provider.loadReferralStatus,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                if (provider.isLoading && data == null)
                  const SizedBox(height: 400, child: Center(child: GriotLoader()))
                else if (data != null) ...[
                  // Hero Section
                  _buildHero(context, data, displayCode),
                  const SizedBox(height: 32),

                  // Claim Section
                  if (data.referredBy == null)
                    _buildClaimSection(context, provider)
                  else
                    _buildReferredByCard(context, data.referredBy!),

                  const SizedBox(height: 32),

                  // Prominent Total Count
                  _buildTotalCounter(context, data),
                  
                  const SizedBox(height: 32),

                  // How it works
                  _buildGrowthGuide(context),
                ] else if (provider.error != null)
                  _buildError(context, provider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHero(BuildContext context, ReferralData data, String displayCode) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isUsername = !displayCode.startsWith('0x');

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary,
            colors.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Decorative Ring
          Positioned(
            right: -50,
            top: -50,
            child: Opacity(
              opacity: 0.12,
              child: Image.asset(
                'assets/cowrie_images/cowrie_ring.png',
                width: 220,
                fit: BoxFit.contain,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Text(
                  isUsername ? 'Personal Referral Code' : 'Wallet Referral ID',
                  style: text.labelMedium?.copyWith(
                    color: colors.onPrimary.withValues(alpha: 0.8),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          isUsername ? '@$displayCode' : _shortenAddress(displayCode),
                          style: text.titleMedium?.copyWith(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: displayCode));
                          NotificationService.showSuccess(context, 'Code copied!');
                        },
                        icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        tooltip: 'Copy Code',
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: () => _showQRSheet(context, displayCode),
                        icon: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 20),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        tooltip: 'Show QR Code',
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _shareReferral(displayCode),
                        icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        tooltip: 'Share Link',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isUsername 
                    ? 'Your friends can join using your handle. It’s personalized just for you.'
                    : 'Share your wallet ID or set a username in settings to get a personal code.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(
                    color: colors.onPrimary.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale(duration: 400.ms, curve: Curves.easeOutBack);
  }

  Widget _buildClaimSection(BuildContext context, ReferralProvider provider) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HAVE A REFERRAL CODE?',
          style: text.labelSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: colors.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              TextField(
                controller: _referralController,
                decoration: InputDecoration(
                  hintText: 'Enter username or wallet',
                  filled: true,
                  fillColor: colors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: provider.isClaiming ? null : _handleClaim,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: provider.isClaiming
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Claim Referral', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildReferredByCard(BuildContext context, String referrer) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Referred by', style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant)),
                Text(
                  referrer,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildTotalCounter(BuildContext context, ReferralData data) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.15)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -20,
            bottom: -20,
            child: Opacity(
              opacity: 0.05,
              child: Image.asset(
                'assets/cowrie_images/cowrie_ring.png',
                width: 120,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.groups_rounded, color: colors.primary, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  '${data.totalReferrals}',
                  style: text.displayMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  'TOTAL REFERRALS',
                  style: text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildGrowthGuide(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.primary.withValues(alpha: 0.08)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            bottom: -30,
            child: Opacity(
              opacity: 0.03,
              child: Image.asset(
                'assets/cowrie_images/cowrie_ring.png',
                width: 140,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: colors.primary, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'GROW THE NETWORK',
                    style: text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Every person you invite strengthens the Griot community. There are no limits—the more people join through your code, the larger your network legacy becomes.',
                style: text.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _buildError(BuildContext context, ReferralProvider provider) {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Unable to load referrals', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: provider.loadReferralStatus,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
