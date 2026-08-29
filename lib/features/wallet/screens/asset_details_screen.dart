import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

  String _getTokenType(String chain) {
    final c = chain.toLowerCase();
    if (c == 'solana' || c == 'sol') return 'SPL';
    if (c == 'bsc' || c == 'binance') return 'BEP-20';
    if (c == 'polygon' || c == 'matic') return 'ERC-20';
    if (c == 'arbitrum' || c == 'optimism' || c == 'base' || c == 'eth' || c == 'ethereum') return 'ERC-20';
    return 'Token';
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

    final bool isEcosystem = token.isEcosystem;
    final bool isNative = token.isNative;
    final bool isPositive = (token.changePercent ?? 0) >= 0;

    return GradientScaffold(
      useSafeArea: false,
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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        token.valueUsd != null 
                            ? WalletFormatters.formatCurrency(token.valueUsd!) 
                            : '--',
                        style: text.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${WalletFormatters.formatBalance(token.balance)} ${token.symbol}',
                          style: text.bodyLarge?.copyWith(
                            color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (isPositive ? colors.tertiary : colors.error)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${isPositive ? '+' : ''}${(token.changePercent ?? 0).toStringAsFixed(2)}%',
                            style: text.labelSmall?.copyWith(
                              color: isPositive ? colors.tertiary : colors.error,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '1 ${token.symbol} = ${WalletFormatters.formatCurrency(token.priceUsd, isUnitPrice: true)}',
                      style: text.bodyMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isEcosystem) ...[
                          _Tag(
                            label: 'Ecosystem',
                            color: colors.primary,
                            icon: Icons.workspace_premium_rounded,
                          ),
                        ] else if (isNative) ...[
                          _Tag(label: 'Native', color: colors.secondary),
                        ] else ...[
                          _Tag(label: 'Token', color: colors.onSurfaceVariant),
                        ],
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

                    _buildSectionHeader(context, 'About Asset'),
                    const SizedBox(height: 16),
                    _buildInfoCard(context),

                    const SizedBox(height: 32),

                    // Security & Explorers
                    _buildSectionHeader(context, 'Security & Explorers'),
                    const SizedBox(height: 16),
                    Consumer<WalletProvider>(
                      builder: (context, provider, _) {
                        final explorerUrl = _getExplorerUrl(provider.wallet?.address);
                        final backendExplorer = token.externalLinks['explorer'] ?? '';
                        final dexUrl = token.externalLinks['dexScreener'] ?? '';
                        final securityUrl = token.externalLinks['goPlus'] ?? token.externalLinks['defiScanner'] ?? '';
                        final honeypotUrl = token.externalLinks['honeypot'] ?? '';
                        return _buildLinkCard(
                          context,
                          links: [
                            if (backendExplorer.isNotEmpty || explorerUrl.isNotEmpty)
                              _LinkItem(
                                title: 'Block Explorer',
                                subtitle: 'View transactions on-chain',
                                icon: Icons.explore_outlined,
                                onTap: () => _launchUrl(context, backendExplorer.isNotEmpty ? backendExplorer : explorerUrl),
                              ),
                            if (securityUrl.isNotEmpty) _LinkItem(
                              title: 'Web3 Security (Rewards)',
                              subtitle: 'Scan token security with GoPlus',
                              icon: Icons.verified_user_rounded,
                              onTap: () => _launchUrl(context, securityUrl),
                            ),
                            if (dexUrl.isNotEmpty) _LinkItem(
                              title: 'Market Analysis',
                              subtitle: 'Check price & liquidity on DEX Screener',
                              icon: Icons.bar_chart_rounded,
                              onTap: () => _launchUrl(context, dexUrl),
                            ),
                            if (honeypotUrl.isNotEmpty)
                              _LinkItem(
                                title: 'Contract Security',
                                subtitle: 'Scan for honeypots & risks',
                                icon: Icons.security_rounded,
                                onTap: () => _launchUrl(context, honeypotUrl),
                              ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 48),

                    // Ad Space
                    const GriotBannerAd(isCompact: true),

                    const SizedBox(height: 80),
                  ],
                ).animate().fade(duration: 400.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad),
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
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 1.5,
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
          _infoRow(context, 'Type', token.isNative ? 'Native' : _getTokenType(token.chain)),
          const Divider(height: 32),
          _infoRow(context, 'Decimals', (token.decimals ?? 18).toString()),
          if (!token.isNative) ...[
            const Divider(height: 32),
            _infoRow(
              context, 
              'Contract', 
              WalletFormatters.shortenAddress(token.contractAddress),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: token.contractAddress));
                if (context.mounted) NotificationService.showSuccess(context, 'Contract address copied');
              },
              trailing: Icon(Icons.copy_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value, {VoidCallback? onTap, Widget? trailing}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            Text(
                              item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Tag({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color.withValues(alpha: 0.8)),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color.withValues(alpha: 0.8),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
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
