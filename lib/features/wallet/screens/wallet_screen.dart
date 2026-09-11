import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/wallet_provider.dart';
import '../../users/providers/user_provider.dart';
import '../models/token_model.dart';
import '../widgets/wallet_filter_sheet.dart';
import '../widgets/wallet_header.dart';
import '../widgets/wallet_balance_card.dart';
import '../widgets/wallet_address_card.dart';
import '../widgets/wallet_actions.dart';
import '../widgets/token_list.dart';
import '../widgets/nft_item.dart';
import '../widgets/token_icon.dart';
import '../widgets/wallet_loading.dart';
import '../utils/wallet_formatters.dart';
import '../utils/wallet_layout_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_loader.dart';
import '../../../core/ui/widgets/ad_carousel.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/navigation_scroll_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    NavigationScrollService.instance.addListener(_onNavTap);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<WalletProvider>();
      if (provider.tokens.isEmpty) {
        provider.loadWallet();
      }
    });
  }

  @override
  void dispose() {
    NavigationScrollService.instance.removeListener(_onNavTap);
    _scrollController.dispose();
    super.dispose();
  }

  void _onNavTap() {
    if (NavigationScrollService.instance.tappedIndex == 3) {
      // Index 3 is Wallet
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  Future<void> _showAssetActions(
    BuildContext context,
    WalletProvider provider,
    TokenModel token,
  ) async {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(
              color: colors.primary.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${token.symbol} • ${token.chain.toUpperCase()}',
                        style: text.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Divider(color: colors.outlineVariant.withValues(alpha: 0.1)),
            const SizedBox(height: 12),

            _actionTile(
              context,
              icon: Icons.visibility_off_rounded,
              label: 'Hide from wallet',
              subtitle: 'Removes this token from your view. Balances are safe.',
              onTap: () async {
                Navigator.pop(context);
                await provider.hideToken(token);
                if (context.mounted) {
                  NotificationService.showSuccess(
                    context,
                    '${token.symbol} hidden',
                  );
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
      title: Text(
        label,
        style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
            )
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Consumer2<WalletProvider, UserProvider>(
      builder: (context, walletProvider, userProvider, child) {
        final user = userProvider.user;
        final wallet = walletProvider.wallet;

        String displayName = 'Your Account';
        if (user != null) {
          displayName =
              user.displayName ??
              (user.username != null ? '@${user.username}' : 'Griot User');
        } else if (wallet != null) {
          displayName = wallet.displayName ?? 'Your Account';
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          switchInCurve: Curves.easeOutQuart,
          child: _buildBody(
            context,
            walletProvider,
            userProvider,
            theme,
            colors,
            displayName,
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    WalletProvider provider,
    UserProvider userProvider,
    ThemeData theme,
    ColorScheme colors,
    String displayName,
  ) {
    if (provider.isLoading && provider.wallet == null) {
      return const WalletLoading(key: ValueKey('loading'));
    }

    final user = userProvider.user;
    final avatarUrl = user?.avatarUrl ?? provider.wallet?.avatarUrl;

    return GradientScaffold(
      key: const ValueKey('content'),
      useSafeArea: false,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text('Wallet'),
        centerTitle: true,
        toolbarHeight: 56,
        automaticallyImplyLeading: false,
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () => context.push('/wallet/search'),
            icon: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.95),
                border: Border(
                  top: BorderSide(
                    color: colors.primary.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  bottom: BorderSide(
                    color: colors.primary.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.search_rounded, size: 20),
            ),
            tooltip: 'Search tokens',
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'dapp_browser_fab',
            backgroundColor: colors.secondaryContainer,
            foregroundColor: colors.onSecondaryContainer,
            elevation: 6,
            tooltip: 'DApp Browser',
            onPressed: () => context.push('/wallet/browser'),
            child: const Icon(Icons.public_rounded, size: 24),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'easy_buy_fab',
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            elevation: 6,
            tooltip: 'Flash exchange',
            onPressed: () => context.push('/wallet/flash'),
            child: const Icon(Icons.currency_exchange_rounded, size: 24),
          ),
        ],
      ),
      floatingActionButtonLocation: const RaisedEndFloatLocation(
        bottomDistance: 125,
        rightDistance: 16,
      ),
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait<dynamic>([
            provider.loadWallet(force: true),
            userProvider.refreshUser(),
          ]);
        },
        displacement: 100,
        edgeOffset: 0,
        color: colors.primary,
        backgroundColor: colors.surface,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: const SizedBox(height: 12),
            ),
            SliverToBoxAdapter(
              child: WalletHeader(
                displayName: displayName,
                avatarUrl: avatarUrl,
                onScanTap: () async {
                  final result = await context.push<String>('/wallet/scan');
                  if (result != null && context.mounted) {
                    context.push('/wallet/send', extra: result);
                  }
                },
                onProfileTap: () => context.push('/settings/user-details'),
                addressCard: WalletAddressCard(
                  address: provider.wallet?.address,
                  isLoading: provider.isLoading,
                  onTap: () => _copyAddress(context, provider.wallet?.address),
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
            ),

            SliverToBoxAdapter(
              child:
                  WalletBalanceCard(
                        balance: WalletFormatters.formatCurrency(
                          provider.wallet?.totalBalance ?? 0,
                        ),
                        change:
                            '${(provider.wallet?.changePercent ?? 0) >= 0 ? '+' : ''}${provider.wallet?.changePercent.toStringAsFixed(2)}%',
                        isProfit: (provider.wallet?.changePercent ?? 0) >= 0,
                      )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 50.ms)
                      .slideY(begin: 0.05, end: 0),
            ),

            SliverToBoxAdapter(
              child:
                  WalletActions(
                        onSendTap: () => context.push('/wallet/send'),
                        onReceiveTap: () => context.push('/wallet/receive'),
                        onSwapTap: () => context.push('/wallet/swap'),
                        onBuyTap: () => context.push('/wallet/flash'),
                      )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 100.ms)
                      .slideY(begin: 0.05, end: 0),
            ),

            SliverToBoxAdapter(
              child: _buildTabs(
                context,
                provider,
              ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
            ),

            if (provider.selectedTab == 0) ...[
              if (provider.visibleAssets.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    context,
                    'Assets',
                    provider.visibleAssets.length,
                  ),
                ),
                TokenList(
                  tokens: provider.visibleAssets,
                  onTokenTap: (token) =>
                      context.push('/wallet/asset', extra: token),
                  onTokenLongPress: (token) =>
                      _showAssetActions(context, provider, token),
                  emptyState: const SliverToBoxAdapter(
                    child: SizedBox.shrink(),
                  ),
                ),
              ],

              if (provider.tokens.isEmpty) _buildEmptyTokenState(context),
            ] else if (provider.selectedTab == 1) ...[
              if (provider.isLoadingNfts && provider.nfts.isEmpty)
                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 300,
                    child: Center(child: GriotLoader(size: 44)),
                  ),
                )
              else if (provider.nftError != null && provider.nfts.isEmpty)
                _buildNftErrorState(context, provider.nftError!)
              else if (provider.nfts.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(8),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final nft = provider.nfts[index];
                      return NftItem(
                            nft: nft,
                            onTap: () =>
                                context.push('/wallet/nft', extra: nft),
                          )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: (index * 40).ms)
                          .slideY(begin: 0.05, end: 0);
                    }, childCount: provider.nfts.length),
                  ),
                )
              else
                _buildEmptyNFTState(context),
            ] else if (provider.selectedTab == 2) ...[
              if (provider.isLoadingActivity && provider.activities.isEmpty)
                const SliverToBoxAdapter(
                  child: SizedBox(
                    height: 180,
                    child: Center(child: GriotLoader(size: 40)),
                  ),
                )
              else if (provider.activities.isEmpty)
                _buildEmptyActivityState(context)
              else ...[
                _buildActivityList(context, provider),
                if (provider.activityNextPageKey != null)
                  SliverToBoxAdapter(
                    child: _buildLoadMoreActivityButton(context, provider),
                  ),
              ],
            ],

            const SliverToBoxAdapter(child: _AdSpace()),

            const SliverToBoxAdapter(child: SizedBox(height: 170)),
          ],
        ),
      ),
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isFilterTab = tabs[index] is IconData;
          final isSelected = !isFilterTab && provider.selectedTab == index;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == tabs.length - 1 ? 0 : 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (isFilterTab) {
                      openWalletFilterSheet(
                        context: context,
                        provider: provider,
                      );
                    } else {
                      provider.setTab(index);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.primary
                          : colors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        top: BorderSide(
                          color: colors.primary.withValues(alpha: isSelected ? 0 : 0.6),
                          width: 1.5,
                        ),
                        bottom: BorderSide(
                          color: colors.primary.withValues(alpha: isSelected ? 0 : 0.6),
                          width: 1.5,
                        ),
                      ),
                    ),
                    child: isFilterTab
                        ? Icon(
                            tabs[index] as IconData,
                            size: 16,
                            color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                          )
                        : Text(
                            tabs[index] as String,
                            textAlign: TextAlign.center,
                            style: text.labelMedium?.copyWith(
                              color: isSelected
                                  ? colors.onPrimary
                                  : colors.onSurfaceVariant.withValues(alpha: 0.7),
                              fontWeight: isSelected
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              fontSize: 11,
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

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    int count, {
    bool isBlocked = false,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: isBlocked ? colors.error : colors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (isBlocked ? colors.error : colors.primary).withValues(
                alpha: 0.1,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: isBlocked ? colors.error : colors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTokenState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your assets will appear here.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyNFTState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Collectibles will appear here.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNftErrorState(BuildContext context, String error) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: colors.error.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                error,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () =>
                    context.read<WalletProvider>().loadNfts(force: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyActivityState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Transactions will appear here.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityList(BuildContext context, WalletProvider provider) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final item = provider.activities[index];
        final operation = item['operationType']?.toString() ?? 'transaction';
        final chain = item['chain']?.toString();
        final hash = item['hash']?.toString();
        final title = item['title']?.toString() ?? (operation[0].toUpperCase() + operation.substring(1));
        final subtitle = item['subtitle']?.toString() ?? [
          if (chain != null && chain.isNotEmpty) chain.toUpperCase(),
          if (hash != null && hash.isNotEmpty) _shortenHash(hash),
        ].join(' • ');
        final status = item['status']?.toString() ?? '';
        final timestampStr = item['timestamp']?.toString();
        final timestamp = timestampStr != null ? DateTime.tryParse(timestampStr) : null;

        final groupedItems = item['groupedItems'] is List
            ? (item['groupedItems'] as List).whereType<Map>().toList()
            : const <Map>[];
        final hasDetails = groupedItems.length > 1;

        final tile = ListTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              operation == 'receive' ? Icons.volunteer_activism_outlined : (operation == 'send' ? Icons.north_east_rounded : Icons.swap_horiz_rounded),
              color: colors.primary,
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              if (timestamp != null)
                Text(
                  _formatRelativeTime(timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 12),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (status == 'confirmed' ? AppColors.success : colors.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: status == 'confirmed' ? AppColors.success : colors.primary,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );

        if (!hasDetails) return tile;

        return ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: tile.leading ?? const SizedBox.shrink(),
          title: tile.title ?? const SizedBox.shrink(),
          subtitle: tile.subtitle,
          trailing: tile.trailing,
          children: [
            for (final groupedItem in groupedItems)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _tipParticipantName(groupedItem, operation),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  _tipParticipantAmount(groupedItem),
                  style: TextStyle(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ),
            if (hash != null && hash.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Transaction: ${_shortenHash(hash)}',
                  style: TextStyle(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.65),
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        );
      }, childCount: provider.activities.length),
    );
  }

  String _tipParticipantName(Map item, String operation) {
    final user = operation == 'send' ? item['toUser'] : item['fromUser'];
    if (user is Map) {
      return (user['displayName'] ?? user['username'] ?? 'Griot user').toString();
    }
    return operation == 'send' ? 'Recipient' : 'Sender';
  }

  String _tipParticipantAmount(Map item) {
    final transfers = item['transfers'];
    if (transfers is List && transfers.isNotEmpty && transfers.first is Map) {
      final transfer = Map<String, dynamic>.from(transfers.first as Map);
      return '${transfer['amount'] ?? ''} ${transfer['symbol'] ?? ''}'.trim();
    }
    return item['subtitle']?.toString() ?? 'Blockchain tip';
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return DateFormat('MMM d').format(time);
  }

  String _shortenHash(String hash) {
    if (hash.length < 10) return hash;
    return '${hash.substring(0, 6)}...${hash.substring(hash.length - 4)}';
  }

  Widget _buildLoadMoreActivityButton(BuildContext context, WalletProvider provider) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: provider.isLoadingMoreActivity
            ? const CircularProgressIndicator()
            : TextButton.icon(
                onPressed: () => provider.loadActivity(refresh: false),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'LOAD MORE',
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: colors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colors.primary.withValues(alpha: 0.2)),
                  ),
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
            CarouselItem(type: CarouselItemType.ad),
            CarouselItem(
              type: CarouselItemType.feature,
              title: 'Private Chat',
              subtitle: 'Secure end-to-end messaging',
              icon: Icons.chat_bubble_rounded,
              onTap: () => context.go('/chat'),
            ),
            CarouselItem(type: CarouselItemType.ad),
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
