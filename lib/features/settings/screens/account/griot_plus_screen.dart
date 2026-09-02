import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../miner/providers/mining_provider.dart';
import '../../../../core/ui/widgets/griot_loader.dart';
import '../../../iap/providers/iap_provider.dart';
import '../../../iap/models/plus_status_model.dart';


class GriotPlusScreen extends StatefulWidget {
  const GriotPlusScreen({super.key});

  @override
  State<GriotPlusScreen> createState() => _GriotPlusScreenState();
}

class _GriotPlusScreenState extends State<GriotPlusScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IapProvider>().refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<IapProvider>().refresh();
    }
  }

  Future<void> _manageSubscription() async {
    final url = Uri.parse(
      Theme.of(context).platform == TargetPlatform.iOS
          ? 'https://apps.apple.com/account/subscriptions'
          : 'https://play.google.com/store/account/subscriptions',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final iapProvider = context.watch<IapProvider>();
    final miningProvider = context.watch<MiningProvider>();

    return GradientScaffold(
      appBar: AppBar(
        title: const Text(
          'Griot Plus',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => iapProvider.refresh(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _buildContent(context, iapProvider, miningProvider, colors),
      ),
    );
  }

  Widget _buildContent(BuildContext context, IapProvider iapProvider, MiningProvider miningProvider, ColorScheme colors) {
    if (iapProvider.isLoading && iapProvider.status.status == PlusSubscriptionStatus.none) {
      return const Center(child: GriotLoader());
    }

    if (iapProvider.error != null && iapProvider.products.isEmpty && !iapProvider.status.isPlus) {
      return _buildErrorState(iapProvider.error!);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildHeroCard(context, iapProvider.status),
          const SizedBox(height: 32),
          
          if (iapProvider.status.isPlus) ...[
            _buildActiveStatusDetails(iapProvider.status),
            const SizedBox(height: 32),
          ],

          _buildSectionLabel(context, 'PLUS BENEFITS'),
          const SizedBox(height: 16),
          _buildBenefitTile(
            context,
            icon: Icons.bolt_rounded,
            title: 'Mining Multiplier',
            description: 'Gain a premium boost to your daily decentralized rewards.',
            extra: miningProvider.status != null 
                ? '${miningProvider.status!.multiplier.total}x Active'
                : 'Boost Active',
            color: Colors.amber,
          ),
          _buildBenefitTile(
            context,
            icon: Icons.verified_user_rounded,
            title: 'Premium Badge',
            description: 'Stand out in the community with a unique Griot Plus identity.',
            color: colors.primary,
          ),
          _buildBenefitTile(
            context,
            icon: Icons.auto_awesome_rounded,
            title: 'Early Access',
            description: 'Be the first to test new decentralized features and tools.',
            color: Colors.purple,
          ),
          
          const SizedBox(height: 40),
          
          if (iapProvider.isVerifying)
             _buildProcessingState('Verifying purchase...')
          else if (iapProvider.status.isPlus)
            _buildManageSection(iapProvider)
          else
            _buildSubscriptionOptions(iapProvider),

          const SizedBox(height: 60),
        ].animate(interval: 50.ms).fade(duration: 400.ms).slideY(begin: 0.05, end: 0),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, PlusStatus status) {
    final colors = Theme.of(context).colorScheme;
    final isPlus = status.isPlus;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPlus 
            ? [colors.primary, colors.secondary]
            : [colors.surfaceContainerHighest, colors.surfaceContainer],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: (isPlus ? colors.primary : Colors.black).withValues(alpha: 0.1),
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
              opacity: 0.1,
              child: SvgPicture.asset(
                'assets/coins_logo/hbadger_logo.svg',
                width: 140,
                colorFilter: ColorFilter.mode(isPlus ? Colors.white : colors.onSurface, BlendMode.srcIn),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (isPlus ? Colors.white : colors.primary).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'GRIOT PLUS',
                  style: TextStyle(
                    color: isPlus ? Colors.white : colors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isPlus ? 'Certified Pioneer' : 'Elevate your Identity',
                style: TextStyle(
                  color: isPlus ? Colors.white : colors.onSurface,
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
                  color: (isPlus ? Colors.white : colors.onSurface).withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveStatusDetails(PlusStatus status) {
    final colors = Theme.of(context).colorScheme;
    final df = DateFormat('MMM dd, yyyy');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          _buildDetailRow('Plan', status.productId?.contains('yearly') == true ? 'Yearly' : 'Monthly'),
          const Divider(height: 24),
          _buildDetailRow('Status', status.status.name.toUpperCase(), color: Colors.green),
          const Divider(height: 24),
          if (status.expiresAt != null)
            _buildDetailRow('Renewal Date', df.format(status.expiresAt!)),
          _buildDetailRow('Provider', status.provider?.toUpperCase() ?? 'STORE'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.6), fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }

  Widget _buildBenefitTile(BuildContext context, {required IconData icon, required String title, required String description, String? extra, required Color color}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    if (extra != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(extra, style: const TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ],
                ),
                Text(description, style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionOptions(IapProvider iap) {
    if (!iap.isStoreAvailable) {
      return _buildInfoCard('STORE UNAVAILABLE', 'We could not connect to the app store. Please check your connection or try again later.');
    }

    if (iap.products.isEmpty) {
      return _buildInfoCard('LOADING PLANS', 'Fetching latest subscription plans from the store...');
    }

    return Column(
      children: [
        ...iap.products.map((product) => _buildProductTile(iap, product)),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => iap.restorePurchases(),
          child: const Text('Restore Purchases', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _buildProductTile(IapProvider iap, ProductDetails product) {
    final colors = Theme.of(context).colorScheme;
    final isYearly = product.id.contains('yearly');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: iap.isLoading ? null : () => iap.buyProduct(product),
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.primary.withValues(alpha: 0.1), width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isYearly ? 'Annual Plan' : 'Monthly Plan', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      Text(isYearly ? 'Best value • Save 20%' : 'Flexible month-to-', style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(product.price, style: TextStyle(color: colors.primary, fontWeight: FontWeight.w900, fontSize: 18)),
                    Text(isYearly ? '/ year' : '/ month', style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManageSection(IapProvider iap) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: _manageSubscription,
            icon: const Icon(Icons.subscriptions_rounded),
            label: const Text('MANAGE SUBSCRIPTION', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
            style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => iap.restorePurchases(),
          child: const Text('Restore Purchases', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, String message) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Something went wrong', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.read<IapProvider>().refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingState(String message) {
    return Column(
      children: [
        const GriotLoader(size: 32),
        const SizedBox(height: 16),
        Text(message, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.grey)),
      ],
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
