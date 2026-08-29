import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../miner/providers/mining_provider.dart';
import '../../../../core/ui/widgets/griot_loader.dart';
import '../../../iap/providers/iap_provider.dart';

class GriotPlusScreen extends StatefulWidget {
  const GriotPlusScreen({super.key});

  @override
  State<GriotPlusScreen> createState() => _GriotPlusScreenState();
}

class _GriotPlusScreenState extends State<GriotPlusScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final miningProvider = context.watch<MiningProvider>();
    final iapProvider = context.watch<IapProvider>();
    
    final status = miningProvider.status;
    final isPlus = status?.multiplier.membershipStatus.toLowerCase() == 'plus';

    return GradientScaffold(
      appBar: AppBar(
        title: const Text(
          'Griot Plus',
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
        child: _buildBody(context, iapProvider, isPlus, colors),
      ),
    );
  }

  Widget _buildBody(BuildContext context, IapProvider iapProvider, bool isPlus, ColorScheme colors) {
    if (iapProvider.isLoading) {
      return const Center(
        key: ValueKey('loading'),
        child: GriotLoader(),
      );
    }

    return SingleChildScrollView(
      key: const ValueKey('content'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildHeroCard(context, isPlus),
          const SizedBox(height: 32),
          _buildSectionLabel(context, 'PLUS BENEFITS'),
          const SizedBox(height: 16),
          _buildBenefitTile(
            context,
            icon: Icons.bolt_rounded,
            title: 'Mining Multiplier',
            description: 'Gain a +0.4× boost to your daily decentralized rewards.',
            color: Colors.amber,
          ),
          _buildBenefitTile(
            context,
            icon: Icons.verified_user_rounded,
            title: 'Premium Badge',
            description: 'Stand out in the community with a unique Griot Plus identity.',
            color: colors.primary,
          ),
          const SizedBox(height: 40),
          if (!isPlus) ...[
            _buildComingSoonInfo(context, iapProvider),
            const SizedBox(height: 32),
            _buildSubscribeButton(context, iapProvider),
          ] else 
            _buildActiveStatusCard(context),
          const SizedBox(height: 60),
        ].animate(interval: 50.ms).fade(duration: 400.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, bool isPlus) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.secondary],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Opacity(
              opacity: 0.15,
              child: SvgPicture.asset(
                'assets/coins_logo/hbadger_logo.svg',
                width: 140,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'GRIOT PLUS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isPlus ? 'Certified Pioneer' : 'Elevate your Identity',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isPlus 
                  ? 'Your account is verified for premium network benefits.'
                  : 'Join the inner circle of social pioneers and high-tier miners.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack);
  }

  Widget _buildBenefitTile(BuildContext context, {required IconData icon, required String title, required String description, required Color color}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outline.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildComingSoonInfo(BuildContext context, IapProvider iapProvider) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          const Text('NETWORK UPGRADE PENDING', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2.0)),
          const SizedBox(height: 16),
          Text(
            'Multi-platform subscription support is being integrated. Soon you will be able to upgrade via Web, Apple Pay, and Google Play.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.8), fontSize: 14, height: 1.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribeButton(BuildContext context, IapProvider iapProvider) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          side: BorderSide(color: colors.primary.withValues(alpha: 0.3)),
        ),
        child: const Text('STAY TUNED', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.0)),
      ),
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildActiveStatusCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.green.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 40),
          const SizedBox(height: 16),
          const Text('GRIOT PLUS ACTIVE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.0, color: Colors.green)),
          const SizedBox(height: 8),
          const Text('You are a verified member of the legacy.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
