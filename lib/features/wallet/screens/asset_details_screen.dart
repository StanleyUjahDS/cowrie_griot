import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../models/token_model.dart';
import '../providers/wallet_provider.dart';
import '../widgets/token_icon.dart';
import '../utils/wallet_formatters.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/ui/widgets/banner_ad.dart';

class AssetDetailsScreen extends StatelessWidget {
  final TokenModel token;

  const AssetDetailsScreen({
    super.key,
    required this.token,
  });

  String _getExplorerUrl(String? walletAddress) {
    final chain = token.chain.toLowerCase();
    final address = token.isNative ? walletAddress : token.contractAddress;

    if (address == null || address.isEmpty) return '';

    switch (chain) {
      case 'ethereum':
      case 'eth':
        return 'https://etherscan.io/address/$address';
      case 'bsc':
      case 'binance':
        return 'https://bscscan.com/address/$address';
      case 'polygon':
      case 'matic':
        return 'https://polygonscan.com/address/$address';
      case 'solana':
      case 'sol':
        return 'https://solscan.io/account/$address';
      case 'arbitrum':
        return 'https://arbiscan.io/address/$address';
      case 'optimism':
        return 'https://optimistic.etherscan.io/address/$address';
      case 'base':
        return 'https://basescan.org/address/$address';
      default:
        return '';
    }
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        NotificationService.showError(context, 'Could not launch explorer');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    final bool isPositive = token.changePercent >= 0;

    return GradientScaffold(
      appBar: AppBar(
        title: Text(token.name.isEmpty ? token.symbol : token.name),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () => _copyContractAddress(context),
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy contract address',
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    // Icon & Balance
                    TokenIcon(
                      imageUrl: token.imageUrl,
                      symbol: token.symbol,
                      name: token.name,
                      chainName: token.chain,
                      isNative: token.isNative,
                      radius: 42,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${WalletFormatters.formatBalance(token.balance)} ${token.symbol}',
                      style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          WalletFormatters.formatCurrency(token.valueUsd),
                          style: text.titleMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (isPositive ? colors.tertiary : colors.error)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${isPositive ? '+' : ''}${token.changePercent.toStringAsFixed(2)}%',
                            style: text.labelMedium?.copyWith(
                              color: isPositive ? colors.tertiary : colors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // Quick Actions
                    Row(
                      children: [
                        _ActionButton(
                          label: 'Send',
                          icon: Icons.north_east_rounded,
                          onTap: () => context.push('/wallet/send', extra: token),
                        ),
                        const SizedBox(width: 12),
                        _ActionButton(
                          label: 'Receive',
                          icon: Icons.south_west_rounded,
                          onTap: () => context.push('/wallet/receive', extra: token),
                        ),
                        const SizedBox(width: 12),
                        _ActionButton(
                          label: 'Swap',
                          icon: Icons.swap_horiz_rounded,
                          onTap: () => context.push('/wallet/swap', extra: token),
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),

                    // Market Info or Charts could go here
                    _buildSectionHeader(context, 'About ${token.name}'),
                    const SizedBox(height: 16),
                    _buildInfoCard(context),

                    const SizedBox(height: 32),

                    // Security & Explorers
                    _buildSectionHeader(context, 'Security & Explorers'),
                    const SizedBox(height: 16),
                    Consumer<WalletProvider>(
                      builder: (context, provider, _) {
                        final explorerUrl = _getExplorerUrl(provider.wallet?.address);
                        return _buildLinkCard(
                          context,
                          links: [
                            if (explorerUrl.isNotEmpty)
                              _LinkItem(
                                title: 'Block Explorer',
                                subtitle: 'View transactions on-chain',
                                icon: Icons.explore_outlined,
                                onTap: () => _launchUrl(context, explorerUrl),
                              ),
                            _LinkItem(
                              title: 'Market Analysis',
                              subtitle: 'Check price & liquidity on Dexscreener',
                              icon: Icons.bar_chart_rounded,
                              onTap: () {
                                final address = token.isNative ? '' : token.contractAddress;
                                final url = address.isNotEmpty 
                                  ? 'https://dexscreener.com/${token.chain}/$address'
                                  : 'https://dexscreener.com/${token.chain}';
                                _launchUrl(context, url);
                              },
                            ),
                            _LinkItem(
                              title: 'Web3 Security (Rewards)',
                              subtitle: 'Scan with De.Fi Shield for points',
                              icon: Icons.verified_user_rounded,
                              onTap: () {
                                final address = token.isNative ? provider.wallet?.address : token.contractAddress;
                                // De.Fi and GoPlus often have networking/loyalty programs 
                                // that track usage for potential airdrops/rewards.
                                _launchUrl(context, 'https://de.fi/scanner/ethereum/$address');
                              },
                            ),
                            if (!token.isNative)
                              _LinkItem(
                                title: 'Contract Security',
                                subtitle: 'Scan for honeypots & risks',
                                icon: Icons.security_rounded,
                                onTap: () => _launchUrl(
                                  context, 
                                  'https://honeypot.is/ethereum?address=${token.contractAddress}'
                                ),
                              ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // Recent Activity
                    _buildSectionHeader(context, 'Recent Activity'),
                    const SizedBox(height: 16),
                    _buildEmptyActivity(context),

                    const SizedBox(height: 48),

                    // Ad Space
                    const GriotBannerAd(),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyContractAddress(BuildContext context) async {
    final address = token.isNative ? 'Native Asset' : token.contractAddress;
    if (address == 'Native Asset') {
       NotificationService.showInfo(context, 'Native asset on ${token.chain}');
       return;
    }
    await Clipboard.setData(ClipboardData(text: address));
    if (!context.mounted) return;
    NotificationService.showSuccess(context, 'Contract address copied');
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _infoRow(context, 'Network', token.chain.toUpperCase()),
          const Divider(height: 32),
          _infoRow(context, 'Price', WalletFormatters.formatCurrency(token.priceUsd)),
          const Divider(height: 32),
          _infoRow(context, 'Symbol', token.symbol),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
        Text(value, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildEmptyActivity(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.2),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 32, color: colors.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            'No transactions yet',
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkCard(BuildContext context, {required List<_LinkItem> links}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: List.generate(links.length, (index) {
          final item = links[index];
          return Column(
            children: [
              InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? const Radius.circular(20) : Radius.zero,
                  bottom: index == links.length - 1 ? const Radius.circular(20) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item.icon, size: 20, color: colors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Text(
                              item.subtitle,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
              if (index < links.length - 1)
                Divider(
                  height: 1,
                  indent: 60,
                  endIndent: 16,
                  color: colors.outlineVariant.withValues(alpha: 0.2),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _LinkItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _LinkItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Expanded(
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
                style: text.labelLarge?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
