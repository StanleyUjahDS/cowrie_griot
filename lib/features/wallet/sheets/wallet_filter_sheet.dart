import 'package:flutter/material.dart';

import '../controllers/wallet_controller.dart';
void openWalletFilterSheet({
  required BuildContext context,
  required WalletController controller,
  required VoidCallback onChanged,
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
            onChanged();
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
                    // ======================================================
                    // HANDLE
                    // ======================================================

                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: colors.onSurface.withValues(
                            alpha: 0.18,
                          ),
                          borderRadius:
                          BorderRadius.circular(20),
                        ),
                      ),
                    ),

                    // ======================================================
                    // HEADER
                    // ======================================================

                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        18,
                        20,
                        14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius:
                              BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.tune_rounded,
                              color: colors.primary,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
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
                                    color:
                                    colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          _activeFilterCount(
                            context,
                            controller,
                          ),
                        ],
                      ),
                    ),

                    Divider(
                      height: 1,
                      color: colors.outline.withValues(
                        alpha: 0.10,
                      ),
                    ),

                    // ======================================================
                    // CONTENT
                    // ======================================================

                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          18,
                          20,
                          24,
                        ),
                        children: [
                          // ==================================================
                          // BALANCE / PERFORMANCE
                          // ==================================================

                          _sectionTitle(
                            context,
                            "Wallet",
                            Icons.account_balance_wallet_rounded,
                          ),

                          const SizedBox(height: 10),

                          Container(
                            decoration: BoxDecoration(
                              color: colors
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                              borderRadius:
                              BorderRadius.circular(18),
                              border: Border.all(
                                color: colors.outline
                                    .withValues(alpha: 0.08),
                              ),
                            ),
                            child: Column(
                              children: [
                                _filterSwitchTile(
                                  context: context,
                                  icon: Icons
                                      .visibility_off_rounded,
                                  title: "Hide Zero Balance",
                                  subtitle:
                                  "Hide tokens with no balance",
                                  value: controller
                                      .state.hideZeroBalance,
                                  onChanged: (value) {
                                    controller
                                        .setHideZeroBalance(
                                      value,
                                    );
                                    refresh();
                                  },
                                ),

                                _itemDivider(context),

                                _filterSwitchTile(
                                  context: context,
                                  icon: Icons
                                      .trending_up_rounded,
                                  title: "Only Profit",
                                  subtitle:
                                  "Show tokens currently in profit",
                                  value:
                                  controller.state.onlyProfit,
                                  onChanged: (value) {
                                    controller.setOnlyProfit(
                                      value,
                                    );
                                    refresh();
                                  },
                                ),

                                _itemDivider(context),

                                _filterSwitchTile(
                                  context: context,
                                  icon: Icons
                                      .trending_down_rounded,
                                  title: "Only Loss",
                                  subtitle:
                                  "Show tokens currently in loss",
                                  value:
                                  controller.state.onlyLoss,
                                  onChanged: (value) {
                                    controller.setOnlyLoss(
                                      value,
                                    );
                                    refresh();
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 26),

                          // ==================================================
                          // CHAINS
                          // ==================================================

                          _sectionTitle(
                            context,
                            "Networks",
                            Icons.hub_rounded,
                          ),

                          const SizedBox(height: 6),

                          Text(
                            "Select the networks you want to see.",
                            style: text.bodySmall?.copyWith(
                              color:
                              colors.onSurfaceVariant,
                            ),
                          ),

                          const SizedBox(height: 14),

                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _chainChip(
                                "Ethereum",
                                controller,
                                refresh,
                              ),
                              _chainChip(
                                "Solana",
                                controller,
                                refresh,
                              ),
                              _chainChip(
                                "Polygon",
                                controller,
                                refresh,
                              ),
                              _chainChip(
                                "BNB Chain",
                                controller,
                                refresh,
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // ==================================================
                          // CLEAR
                          // ==================================================

                          SizedBox(
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                controller.clearFilters();
                                refresh();
                              },
                              icon: const Icon(
                                Icons.restart_alt_rounded,
                              ),
                              label: const Text(
                                "Clear All Filters",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),
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

// ============================================================================
// SECTION TITLE
// ============================================================================

Widget _sectionTitle(
    BuildContext context,
    String title,
    IconData icon,
    ) {
  final colors = Theme.of(context).colorScheme;
  final text = Theme.of(context).textTheme;

  return Row(
    children: [
      Icon(
        icon,
        size: 18,
        color: colors.primary,
      ),
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

// ============================================================================
// FILTER SWITCH TILE
// ============================================================================

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
    padding: const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 11,
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: value
                ? colors.primary.withValues(alpha: 0.12)
                : colors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: value
                ? colors.primary
                : colors.onSurfaceVariant,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
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

// ============================================================================
// CHAIN CHIP
// ============================================================================

Widget _chainChip(
    String chain,
    WalletController controller,
    VoidCallback refresh,
    ) {
  return Builder(
    builder: (context) {
      final colors =
          Theme.of(context).colorScheme;

      final selected = controller
          .state
          .selectedChains
          .contains(chain);

      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          controller.toggleChain(chain);
          refresh();
        },
        child: AnimatedContainer(
          duration:
          const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: selected
                ? colors.primary.withValues(
              alpha: 0.11,
            )
                : colors
                .surfaceContainerHighest
                .withValues(alpha: 0.35),
            borderRadius:
            BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? colors.primary.withValues(
                alpha: 0.45,
              )
                  : colors.outline.withValues(
                alpha: 0.10,
              ),
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _chainIcon(
                context,
                chain,
                selected,
              ),

              const SizedBox(width: 8),

              Text(
                chain,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? colors.primary
                      : colors.onSurface,
                ),
              ),

              if (selected) ...[
                const SizedBox(width: 7),
                Icon(
                  Icons.check_circle_rounded,
                  size: 17,
                  color: colors.primary,
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

// ============================================================================
// CHAIN ICON
// ============================================================================

Widget _chainIcon(
    BuildContext context,
    String chain,
    bool selected,
    ) {
  final colors =
      Theme.of(context).colorScheme;

  IconData icon;

  switch (chain) {
    case "Ethereum":
      icon = Icons.diamond_rounded;
      break;

    case "Solana":
      icon = Icons.bolt_rounded;
      break;

    case "Polygon":
      icon = Icons.hexagon_rounded;
      break;

    case "BNB Chain":
      icon = Icons.apps_rounded;
      break;

    default:
      icon = Icons.hub_rounded;
  }

  return Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: selected
          ? colors.primary.withValues(
        alpha: 0.14,
      )
          : colors.surface,
    ),
    child: Icon(
      icon,
      size: 16,
      color: selected
          ? colors.primary
          : colors.onSurfaceVariant,
    ),
  );
}

// ============================================================================
// DIVIDER
// ============================================================================

Widget _itemDivider(BuildContext context) {
  final colors =
      Theme.of(context).colorScheme;

  return Divider(
    height: 1,
    indent: 66,
    endIndent: 14,
    color: colors.outline.withValues(
      alpha: 0.08,
    ),
  );
}

// ============================================================================
// ACTIVE FILTER COUNT
// ============================================================================

Widget _activeFilterCount(
    BuildContext context,
    WalletController controller,
    ) {
  final colors =
      Theme.of(context).colorScheme;

  int count = 0;

  if (controller.state.hideZeroBalance) {
    count++;
  }

  if (controller.state.onlyProfit) {
    count++;
  }

  if (controller.state.onlyLoss) {
    count++;
  }

  count += controller.state.selectedChains.length;

  if (count == 0) {
    return const SizedBox.shrink();
  }

  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 6,
    ),
    decoration: BoxDecoration(
      color: colors.primary.withValues(
        alpha: 0.10,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      "$count active",
      style: Theme.of(context)
          .textTheme
          .labelSmall
          ?.copyWith(
        color: colors.primary,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}