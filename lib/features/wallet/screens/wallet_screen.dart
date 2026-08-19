import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/wallet_provider.dart';
import '../widgets/easy_buy_sheet.dart';
import '../widgets/wallet_filter_sheet.dart';
import '../widgets/wallet_header.dart';
import '../widgets/wallet_balance_card.dart';
import '../widgets/wallet_address_card.dart';
import '../widgets/wallet_actions.dart';
import '../widgets/token_list.dart';
import '../widgets/wallet_loading.dart';
import '../utils/wallet_formatters.dart';
import '../utils/wallet_layout_utils.dart';
import '../../../core/ui/widgets/ad_banner.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    return Consumer<WalletProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.wallet == null) {
          return const Scaffold(body: WalletLoading());
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              'Wallet',
              style: text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            backgroundColor: theme.scaffoldBackgroundColor,
            foregroundColor: colors.onSurface,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
          body: RefreshIndicator(
            onRefresh: provider.loadWallet,
            displacement: 30,
            edgeOffset: 0,
            color: colors.primary,
            backgroundColor: colors.surface,
            child: CustomScrollView(
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
                    onScanTap: () => context.push('/wallet/scan'),
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
                    change: '${(provider.wallet?.changePercent ?? 0) >= 0 ? '+' : ''}${provider.wallet?.changePercent ?? 0}%',
                    isProfit: (provider.wallet?.changePercent ?? 0) >= 0,
                  ),
                ),

                // Actions
                SliverToBoxAdapter(
                  child: WalletActions(
                    onSendTap: () {},
                    onReceiveTap: () {},
                    onSwapTap: () {},
                    onBuyTap: () => openEasyBuySheet(context),
                  ),
                ),

                // Tabs
                SliverToBoxAdapter(
                  child: _buildTabs(context, provider),
                ),

                // Asset Header
                SliverToBoxAdapter(
                  child: _buildAssetHeader(context, provider),
                ),

                // Token List
                TokenList(
                  tokens: provider.filteredTokens,
                  onTokenTap: (token) {},
                  emptyState: _buildEmptyTokenState(context),
                ),

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
        );
      },
    );
  }

  Future<void> _copyAddress(BuildContext context, String? address) async {
    if (address == null || address.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: address));
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Wallet address copied'),
        duration: Duration(seconds: 2),
      ),
    );
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

  Widget _buildAssetHeader(BuildContext context, WalletProvider provider) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          Text(
            'Your Assets',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Text(
            '${provider.filteredTokens.length} assets',
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
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
}

class _AdSpace extends StatelessWidget {
  const _AdSpace();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(14, 20, 14, 10),
      child: GriotAdBanner(),
    );
  }
}
