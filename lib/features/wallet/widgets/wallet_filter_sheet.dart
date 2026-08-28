import 'package:flutter/material.dart';
import '../providers/wallet_provider.dart';
import '../utils/chain_assets.dart';

void openWalletFilterSheet({
  required BuildContext context,
  required WalletProvider provider,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return StatefulBuilder(
        builder: (context, setModal) {
          final theme = Theme.of(context);
          final colors = theme.colorScheme;
          final text = theme.textTheme;

          void refresh() {
            setModal(() {});
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.68,
            maxChildSize: 0.94,
            minChildSize: 0.50,
            expand: false,
            builder: (_, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    // Handle
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: colors.onSurface.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.tune_rounded, color: colors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Filters",
                                  style: text.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Customize your wallet view",
                                  style: text.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _activeFilterCount(context, provider),
                        ],
                      ),
                    ),

                    Divider(
                      height: 1,
                      color: colors.outline.withValues(alpha: 0.10),
                    ),

                    // Content
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.fromLTRB(
                          20,
                          18,
                          20,
                          24 + MediaQuery.of(context).padding.bottom,
                        ),
                        children: [
                          _sectionTitle(context, "Wallet", Icons.account_balance_wallet_rounded),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: colors.outline.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Column(
                              children: [
                                _filterSwitchTile(
                                  context: context,
                                  icon: Icons.money_off_rounded,
                                  title: "Hide Small Balances",
                                  subtitle: "Hide tiny balances below the wallet threshold",
                                  value: provider.hideLowBalance,
                                  onChanged: (value) {
                                    provider.setHideLowBalance(value);
                                    refresh();
                                  },
                                ),
                                _itemDivider(context),
                                _filterSwitchTile(
                                  context: context,
                                  icon: Icons.trending_up_rounded,
                                  title: "Only Profit",
                                  subtitle: "Show tokens currently in profit",
                                  value: provider.onlyProfit,
                                  onChanged: (value) {
                                    provider.setOnlyProfit(value);
                                    refresh();
                                  },
                                ),
                                _itemDivider(context),
                                _filterSwitchTile(
                                  context: context,
                                  icon: Icons.trending_down_rounded,
                                  title: "Only Loss",
                                  subtitle: "Show tokens currently in loss",
                                  value: provider.onlyLoss,
                                  onChanged: (value) {
                                    provider.setOnlyLoss(value);
                                    refresh();
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 26),

                          _sectionTitle(context, "Networks", Icons.hub_rounded),
                          const SizedBox(height: 6),
                          Text(
                            "Select the networks you want to see.",
                            style: text.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _chainChip("Ethereum", "ethereum", provider, refresh),
                              _chainChip("BNB Chain", "bsc", provider, refresh),
                              _chainChip("Polygon", "polygon", provider, refresh),
                              _chainChip("Arbitrum", "arbitrum", provider, refresh),
                              _chainChip("Optimism", "optimism", provider, refresh),
                              _chainChip("Base", "base", provider, refresh),
                              _chainChip("Avalanche", "avalanche", provider, refresh),
                            ],
                          ),

                          const SizedBox(height: 28),

                          SizedBox(
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                provider.clearFilters();
                                refresh();
                              },
                              icon: const Icon(Icons.restart_alt_rounded),
                              label: const Text(
                                "Clear All Filters",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}

Widget _sectionTitle(BuildContext context, String title, IconData icon) {
  final colors = Theme.of(context).colorScheme;
  final text = Theme.of(context).textTheme;

  return Row(
    children: [
      Icon(icon, size: 18, color: colors.primary),
      const SizedBox(width: 8),
      Text(
        title,
        style: text.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

Widget _filterSwitchTile({
  required BuildContext context,
  required IconData icon,
  required String title,
  required String subtitle,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  final colors = Theme.of(context).colorScheme;
  final text = Theme.of(context).textTheme;

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: value ? colors.primary.withValues(alpha: 0.12) : colors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: value ? colors.primary : colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: text.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

Widget _chainChip(String label, String chainId, WalletProvider provider, VoidCallback refresh) {
  return Builder(
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      final selected = provider.selectedChains.contains(chainId);

      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          provider.toggleChain(chainId);
          refresh();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? colors.primary.withValues(alpha: 0.11)
                : colors.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? colors.primary.withValues(alpha: 0.45)
                  : colors.outline.withValues(alpha: 0.10),
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _chainIcon(context, chainId, selected),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? colors.primary : colors.onSurface,
                    ),
              ),
              if (selected) ...[
                const SizedBox(width: 7),
                Icon(Icons.check_circle_rounded, size: 17, color: colors.primary),
              ],
            ],
          ),
        ),
      );
    },
  );
}

Widget _chainIcon(BuildContext context, String chain, bool selected) {
  final colors = Theme.of(context).colorScheme;

  return Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: selected ? colors.primary.withValues(alpha: 0.14) : colors.surface,
    ),
    child: Center(
      child: ChainAssets.getIcon(
        chain,
        size: 18,
      ),
    ),
  );
}

Widget _itemDivider(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return Divider(
    height: 1,
    indent: 66,
    endIndent: 14,
    color: colors.outline.withValues(alpha: 0.08),
  );
}

Widget _activeFilterCount(BuildContext context, WalletProvider provider) {
  final colors = Theme.of(context).colorScheme;
  int count = 0;
  if (provider.hideLowBalance) count++;
  if (provider.onlyProfit) count++;
  if (provider.onlyLoss) count++;
  count += provider.selectedChains.length;

  if (count == 0) return const SizedBox.shrink();

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: colors.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      "$count active",
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w800,
          ),
    ),
  );
}
