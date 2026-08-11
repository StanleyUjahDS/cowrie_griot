import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/features/wallet/services/wallet_service.dart';
import '/features/wallet/services/wallet_crypto_service.dart';
import '/features/wallet/services/wallet_storage_service.dart';

import '../controllers/wallet_controller.dart';
import '../sheets/easy_buy_sheet.dart';
import '../sheets/wallet_filter_sheet.dart';
import '../widgets/token_list_item.dart';
import '../widgets/wallet_action_box.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({
    super.key,
  });

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  // ============================================================
  // CONTROLLER
  // ============================================================

  late final WalletController controller;

  // ============================================================
  // WALLET SERVICE
  // ============================================================

  late final WalletService _walletService;

  // ============================================================
  // STORED WALLET ADDRESS
  // ============================================================

  String? _walletAddress;

  bool _loadingAddress = true;

  // ============================================================
  // TABS
  // ============================================================

  final List<dynamic> tabs = [
    "Tokens",
    "NFTs",
    "Activity",
    Icons.filter_list_rounded,
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    controller = WalletController();

    _walletService = WalletService(
      cryptoService: WalletCryptoService(),
      storageService: WalletStorageService(),
    );

    _loadWalletAddress();
  }

  // ============================================================
  // LOAD STORED WALLET ADDRESS
  // ============================================================

  Future<void> _loadWalletAddress() async {
    try {
      debugPrint('Loading wallet address...');

      final String? address =
      await _walletService.getAddress();

      debugPrint(
        'Stored wallet address: $address',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _walletAddress = address;
        _loadingAddress = false;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to load wallet address: $error',
      );

      debugPrint(
        '$stackTrace',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _walletAddress = null;
        _loadingAddress = false;
      });
    }
  }

  // ============================================================
  // SHORTEN ADDRESS
  // ============================================================

  String _shortenAddress(String address) {
    final String cleanAddress = address.trim();

    if (cleanAddress.length <= 12) {
      return cleanAddress;
    }

    return '${cleanAddress.substring(0, 6)}...'
        '${cleanAddress.substring(cleanAddress.length - 4)}';
  }

  // ============================================================
  // COPY ADDRESS
  // ============================================================

  Future<void> _copyAddress() async {
    final address = _walletAddress;

    if (address == null || address.isEmpty) {
      return;
    }

    await Clipboard.setData(
      ClipboardData(
        text: address,
      ),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Wallet address copied',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    final bool isDark =
        theme.brightness == Brightness.dark;

    final Color borderColor =
    colors.outline.withValues(
      alpha: isDark ? 0.20 : 0.12,
    );

    final tokens =
        controller.filteredTokens;

    return Scaffold(
      backgroundColor:
      theme.scaffoldBackgroundColor,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: Text(
          "Wallet",
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor:
        theme.scaffoldBackgroundColor,
        foregroundColor:
        colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor:
        Colors.transparent,
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: Column(
        children: [
          // ======================================================
          // USER HEADER
          // ======================================================

          ListTile(
            contentPadding:
            const EdgeInsets.symmetric(
              horizontal: 12,
            ),

            // ====================================================
            // AVATAR
            // ====================================================

            leading: CircleAvatar(
              radius: 22,
              backgroundColor:
              colors.surfaceContainerHighest,
              backgroundImage:
              const AssetImage(
                "assets/cowrie_images/wolrd_cowrie.png",
              ),
            ),

            // ====================================================
            // NAME + ADDRESS
            // ====================================================

            title: Text(
              "John Doe",
              style: text.bodyLarge?.copyWith(
                fontWeight:
                FontWeight.w600,
              ),
            ),

            subtitle:
            _loadingAddress
                ? Text(
              "Loading wallet...",
              style: text.bodySmall
                  ?.copyWith(
                color: colors
                    .onSurfaceVariant,
              ),
            )
                : _walletAddress == null ||
                _walletAddress!
                    .isEmpty
                ? Text(
              "Wallet address unavailable",
              style: text.bodySmall
                  ?.copyWith(
                color: colors
                    .error,
              ),
            )
                : Row(
              children: [
                Flexible(
                  child: Text(
                    _shortenAddress(
                      _walletAddress!,
                    ),
                    maxLines: 1,
                    overflow:
                    TextOverflow
                        .ellipsis,
                    style: text
                        .bodySmall
                        ?.copyWith(
                      color: colors
                          .onSurfaceVariant,
                      fontWeight:
                      FontWeight
                          .w500,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 5,
                ),

                Icon(
                  Icons
                      .verified_rounded,
                  size: 14,
                  color:
                  colors.primary,
                ),

                const SizedBox(
                  width: 2,
                ),

                IconButton(
                  onPressed:
                  _copyAddress,
                  tooltip:
                  "Copy address",
                  padding:
                  EdgeInsets.zero,
                  constraints:
                  const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  icon: Icon(
                    Icons
                        .content_copy_rounded,
                    size: 15,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),
              ],
            ),

            // ====================================================
            // HEADER ACTIONS
            // ====================================================

            trailing: Row(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                IconButton(
                  tooltip:
                  "Notifications",
                  onPressed: () {},
                  icon: Icon(
                    Icons
                        .notifications_none_rounded,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),

                IconButton(
                  tooltip:
                  "Scan QR code",
                  onPressed: () {},
                  icon: Icon(
                    Icons
                        .qr_code_scanner_rounded,
                    color: colors
                        .onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ======================================================
          // BALANCE
          // ======================================================

          Column(
            children: [
              Text(
                "Total Balance",
                style: text.bodyMedium?.copyWith(
                  color:
                  colors.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                "\$12,450.00",
                style:
                text.headlineLarge?.copyWith(
                  fontWeight:
                  FontWeight.w800,
                ),
              ),

              const SizedBox(height: 6),

              Row(
                mainAxisSize:
                MainAxisSize.min,
                children: [
                  Icon(
                    Icons
                        .trending_up_rounded,
                    size: 16,
                    color:
                    colors.tertiary,
                  ),

                  const SizedBox(
                    width: 4,
                  ),

                  Text(
                    "+3.5%",
                    style: text.bodySmall
                        ?.copyWith(
                      color:
                      colors.tertiary,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ======================================================
          // ACTIONS
          // ======================================================

          Padding(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: WalletActionBox(
                    icon: Icons
                        .arrow_upward_rounded,
                    label: "Send",
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                Expanded(
                  child: WalletActionBox(
                    icon: Icons
                        .arrow_downward_rounded,
                    label: "Receive",
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                Expanded(
                  child: WalletActionBox(
                    icon: Icons
                        .swap_horiz_rounded,
                    label: "Swap",
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                Expanded(
                  child: WalletActionBox(
                    icon: Icons
                        .qr_code_scanner_rounded,
                    label: "Scan",
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ======================================================
          // TABS
          // ======================================================

          Padding(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            child: Row(
              children:
              List.generate(
                tabs.length,
                    (index) {
                  final bool isFilterTab =
                  tabs[index]
                  is IconData;

                  final bool isSelected =
                      !isFilterTab &&
                          controller
                              .state
                              .selectedTab ==
                              index;

                  return Expanded(
                    child:
                    GestureDetector(
                      onTap: () {
                        if (isFilterTab) {
                          openWalletFilterSheet(
                            context:
                            context,
                            controller:
                            controller,
                            onChanged: () {
                              setState(
                                    () {},
                              );
                            },
                          );

                          return;
                        }

                        setState(() {
                          controller
                              .setTab(
                            index,
                          );
                        });
                      },
                      child:
                      AnimatedContainer(
                        duration:
                        const Duration(
                          milliseconds:
                          180,
                        ),
                        margin:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 4,
                        ),
                        padding:
                        const EdgeInsets
                            .symmetric(
                          vertical: 12,
                        ),
                        decoration:
                        BoxDecoration(
                          color: isSelected
                              ? colors
                              .primary
                              .withValues(
                            alpha:
                            0.10,
                          )
                              : colors
                              .surface,
                          borderRadius:
                          BorderRadius
                              .circular(
                            12,
                          ),
                          border:
                          Border.all(
                            color: isSelected
                                ? colors
                                .primary
                                : borderColor,
                          ),
                        ),
                        child: isFilterTab
                            ? Icon(
                          tabs[index]
                          as IconData,
                          size: 20,
                          color: colors
                              .onSurfaceVariant,
                        )
                            : Text(
                          tabs[index]
                          as String,
                          textAlign:
                          TextAlign
                              .center,
                          style: text
                              .labelLarge
                              ?.copyWith(
                            color: isSelected
                                ? colors
                                .primary
                                : colors
                                .onSurface,
                            fontWeight:
                            FontWeight
                                .w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ======================================================
          // TOKEN LIST
          // ======================================================

          Expanded(
            child: tokens.isEmpty
                ? Center(
              child: Text(
                "No tokens found",
                style: text
                    .bodyLarge
                    ?.copyWith(
                  color: colors
                      .onSurfaceVariant,
                ),
              ),
            )
                : ListView.builder(
              padding:
              const EdgeInsets.only(
                bottom: 24,
              ),
              itemCount:
              tokens.length,
              itemBuilder:
                  (
                  context,
                  index,
                  ) {
                return TokenListItem(
                  token:
                  tokens[index],
                );
              },
            ),
          ),
        ],
      ),

      // ==========================================================
      // EASY BUY
      // ==========================================================

      floatingActionButton:
      FloatingActionButton(
        heroTag: "easy_buy_fab",
        backgroundColor:
        colors.primary,
        foregroundColor:
        colors.onPrimary,
        elevation: 3,
        tooltip: "Easy Buy",
        onPressed: () {
          openEasyBuySheet(
            context,
          );
        },
        child: const Icon(
          Icons.flash_on_rounded,
        ),
      ),
    );
  }
}