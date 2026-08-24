import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/wallet_provider.dart';
import '../models/token_model.dart';
import '../widgets/easy_buy_sheet.dart';
import '../widgets/wallet_filter_sheet.dart';
import '../widgets/wallet_header.dart';
import '../widgets/wallet_balance_card.dart';
import '../widgets/wallet_address_card.dart';
import '../widgets/wallet_actions.dart';
import '../widgets/token_list.dart';
import '../widgets/token_icon.dart';
import '../widgets/wallet_loading.dart';
import '../utils/wallet_formatters.dart';
import '../utils/wallet_layout_utils.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/ad_carousel.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/navigation_scroll_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Future<void> _showAssetActions(BuildContext context, WalletProvider provider, TokenModel token) async {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with Token Info
            Row(
              children: [
                TokenIcon(
                  imageUrl: token.imageUrl,
                  symbol: token.symbol,
                  name: token.name,
                  chainName: token.chain,
                  isNative: token.isNative,
                  radius: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        token.name.isEmpty ? token.symbol : token.name,
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${token.symbol} • ${token.chain.toUpperCase()}',
                        style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Divider(color: colors.outlineVariant.withValues(alpha: 0.1)),
            const SizedBox(height: 12),

            // Actions
            _actionTile(
              context,
              icon: Icons.visibility_off_rounded,
              label: 'Hide from wallet',
              subtitle: 'Removes this token from your view. Balances are safe.',
              onTap: () async {
                Navigator.pop(context);
                await provider.hideToken(token);
                if (context.mounted) {
                  NotificationService.showSuccess(context, '${token.symbol} hidden');
                }
              },
            ),
            _actionTile(
              context,
              icon: Icons.copy_rounded,
              label: 'Copy contract address',
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: token.contractAddress));
                NotificationService.showSuccess(context, 'Address copied');
              },
              show: !token.isNative,
            ),
            _actionTile(
              context,
              icon: Icons.account_balance_wallet_outlined,
              label: 'View profile',
              onTap: () {
                Navigator.pop(context);
                context.push('/wallet/asset', extra: token);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
    bool show = true,
  }) {
    if (!show) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: colors.primary, size: 20),
      ),
      title: Text(label, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
      subtitle: subtitle != null ? Text(subtitle, style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant)) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    NavigationScrollService.instance.addListener(_onNavTap);
  }

  @override
  void dispose() {
    NavigationScrollService.instance.removeListener(_onNavTap);
    _scrollController.dispose();
    super.dispose();
  }

  void _onNavTap() {
    if (NavigationScrollService.instance.tappedIndex == 2) { // Index 2 is Wallet
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    return Consumer<WalletProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.wallet == null) {
          return const WalletLoading();
        }

        return GradientScaffold(
          appBar: AppBar(
            title: Text(
              'Wallet',
              style: text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => context.push('/wallet/search'),
                icon: const Icon(Icons.search),
                tooltip: 'Search tokens',
              ),
              const SizedBox(width: 8),
            ],
            backgroundColor: theme.scaffoldBackgroundColor,
            foregroundColor: colors.onSurface,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
          floatingActionButton: SafeArea(
            minimum: const EdgeInsets.only(right: 4, bottom: 18),
            child: FloatingActionButton.extended(
              heroTag: 'easy_buy_fab',
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              elevation: 6,
              tooltip: 'Buy crypto',
              onPressed: () => openEasyBuySheet(context),
              icon: const Icon(Icons.shopping_cart_outlined),
              label: const Text(
                'Buy',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          floatingActionButtonLocation: const RaisedEndFloatLocation(
            bottomDistance: 82,
            rightDistance: 16,
          ),
          child: RefreshIndicator(
            onRefresh: provider.loadWallet,
            displacement: 30,
            edgeOffset: 0,
            color: colors.primary,
            backgroundColor: colors.surface,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: WalletHeader(
                    displayName: provider.wallet?.displayName ?? 'Your Account',
                    avatarUrl: provider.wallet?.avatarUrl,
                    onNotificationsTap: () {},
                    onScanTap: () async {
                      final result = await context.push<String>('/wallet/scan');
                      if (result != null && context.mounted) {
                        // Navigate to send screen with the scanned address
                        // We might need to adjust the router to accept an initial address
                        context.push('/wallet/send', extra: result); 
                      }
                    },
                    addressCard: WalletAddressCard(
                      address: provider.wallet?.address,
                      isLoading: provider.isLoading,
                      onTap: () => _copyAddress(context, provider.wallet?.address),
                    ),
                  ),
                ),

                // Balance
                SliverToBoxAdapter(
                  child: WalletBalanceCard(
                    balance: WalletFormatters.formatCurrency(provider.wallet?.totalBalance ?? 0),
                    change: '${(provider.wallet?.changePercent ?? 0) >= 0 ? '+' : ''}${provider.wallet?.changePercent.toStringAsFixed(2)}%',
                    isProfit: (provider.wallet?.changePercent ?? 0) >= 0,
                  ),
                ),

                // Actions
                SliverToBoxAdapter(
                  child: WalletActions(
                    onSendTap: () => context.push('/wallet/send'),
                    onReceiveTap: () => context.push('/wallet/receive'),
                    onSwapTap: () => context.push('/wallet/swap'),
                    onBuyTap: () => openEasyBuySheet(context),
                  ),
                ),

                // Tabs
                SliverToBoxAdapter(
                  child: _buildTabs(context, provider),
                ),

                // CONTENT BASED ON SELECTED TAB
                if (provider.selectedTab == 0) ...[
                  // Trusted Assets (Verified/Official/Ecosystem/Native)
                  if (provider.verifiedAssets.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _buildSectionHeader(context, 'Trusted Assets', provider.verifiedAssets.length),
                    ),
                    TokenList(
                      tokens: provider.verifiedAssets,
                      onTokenTap: (token) => context.push('/wallet/asset', extra: token),
                      onTokenLongPress: (token) => _showAssetActions(context, provider, token),
                      emptyState: const SliverToBoxAdapter(child: SizedBox.shrink()),
                    ),
                  ],

                  // Unverified Assets (Security Scan Pending/Unknown)
                  if (provider.unverifiedAssets.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _buildSectionHeader(context, 'Other Assets', provider.unverifiedAssets.length),
                    ),
                    TokenList(
                      tokens: provider.unverifiedAssets,
                      onTokenTap: (token) => context.push('/wallet/asset', extra: token),
                      onTokenLongPress: (token) => _showAssetActions(context, provider, token),
                      emptyState: const SliverToBoxAdapter(child: SizedBox.shrink()),
                    ),
                  ],

                  // Blocked or spam tokens
                  if (provider.blockedAssets.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _buildSectionHeader(context, 'Blocked or Spam Tokens', provider.blockedAssets.length, isBlocked: true),
                    ),
                    TokenList(
                      tokens: provider.blockedAssets,
                      onTokenTap: (token) => context.push('/wallet/asset', extra: token),
                      onTokenLongPress: (token) => _showAssetActions(context, provider, token),
                      emptyState: const SliverToBoxAdapter(child: SizedBox.shrink()),
                    ),
                  ],

                  if (provider.tokens.isEmpty)
                    _buildEmptyTokenState(context),
                ] else if (provider.selectedTab == 1) ...[
                  // NFTs Tab
                  _buildEmptyNFTState(context),
                ] else if (provider.selectedTab == 2) ...[
                  // Activity Tab
                  _buildEmptyActivityState(context),
                ],

                // Ad Placeholder
                const SliverToBoxAdapter(
                  child: _AdSpace(),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 170),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _copyAddress(BuildContext context, String? address) async {
    if (address == null || address.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: address));
    if (!context.mounted) return;

    NotificationService.showSuccess(context, 'Wallet address copied');
  }

  Widget _buildTabs(BuildContext context, WalletProvider provider) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final tabs = ['Tokens', 'NFTs', 'Activity', Icons.tune_rounded];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isFilterTab = tabs[index] is IconData;
          final isSelected = !isFilterTab && provider.selectedTab == index;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == tabs.length - 1 ? 0 : 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: () {
                    if (isFilterTab) {
                      openWalletFilterSheet(context: context, provider: provider);
                    } else {
                      provider.setTab(index);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? colors.primary.withValues(alpha: 0.10) : colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: isSelected
                            ? colors.primary.withValues(alpha: 0.45)
                            : colors.outlineVariant.withValues(alpha: 0.40),
                      ),
                    ),
                    child: isFilterTab
                        ? Icon(tabs[index] as IconData, size: 18, color: colors.onSurfaceVariant)
                        : Text(
                            tabs[index] as String,
                            textAlign: TextAlign.center,
                            style: text.labelLarge?.copyWith(
                              color: isSelected ? colors.primary : colors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, int count, {bool isBlocked = false}) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: text.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isBlocked ? colors.error : colors.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (isBlocked ? colors.error : colors.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              count.toString(),
              style: text.labelSmall?.copyWith(
                color: isBlocked ? colors.error : colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTokenState(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 27,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No tokens found',
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Your assets will appear here.',
                style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyNFTState(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.grid_view_rounded,
                  size: 27,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No NFTs found',
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Collectibles will appear here.',
                style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyActivityState(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.history_rounded,
                  size: 27,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No activity yet',
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Transactions will appear here.',
                style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdSpace extends StatelessWidget {
  const _AdSpace();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        const SizedBox(height: 64),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Text(
                'Griot Discovery',
                style: text.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Divider(
                  color: colors.outline.withValues(alpha: 0.1),
                  thickness: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GriotAdCarousel(
          height: 420, // Increased to 420 for better spacing and compliance
          items: [
            CarouselItem(
              type: CarouselItemType.feature,
              title: 'Start Mining',
              subtitle: 'Earn Griot points daily',
              icon: Icons.bolt_rounded,
              onTap: () => context.go('/miner'),
            ),
            CarouselItem(
              type: CarouselItemType.ad,
            ),
            CarouselItem(
              type: CarouselItemType.feature,
              title: 'Private Chat',
              subtitle: 'Secure end-to-end messaging',
              icon: Icons.chat_bubble_rounded,
              onTap: () => context.go('/chat'),
            ),
            CarouselItem(
              type: CarouselItemType.feature,
              title: 'P2P Trading',
              subtitle: 'Secure local trade offers',
              icon: Icons.swap_horiz_rounded,
              onTap: () => context.go('/p2p'),
            ),
            CarouselItem(
              type: CarouselItemType.ad,
            ),
            CarouselItem(
              type: CarouselItemType.feature,
              title: 'Refer & Earn',
              subtitle: 'Invite friends for rewards',
              icon: Icons.people_rounded,
              onTap: () => context.push('/settings/user-details'),
            ),
          ],
        ),
      ],
    );
  }
}
