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
  // WALLET ADDRESS
  // ============================================================

  String? _walletAddress;
  bool _loadingAddress = true;

  // ============================================================
  // PROFILE
  // ============================================================

  final String _displayName = 'Your Griot Account';
  String? _avatarUrl;

  // ============================================================
  // REFRESH
  // ============================================================

  bool _refreshing = false;

  // ============================================================
  // TABS
  // ============================================================

  final List<dynamic> tabs = [
    'Tokens',
    'NFTs',
    'Activity',
    Icons.tune_rounded,
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
  // LOAD WALLET
  // ============================================================

  Future<void> _loadWalletAddress() async {
    try {
      final String? address = await _walletService.getAddress();

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
  // REFRESH
  // ============================================================

  Future<void> _refreshWallet() async {
    if (_refreshing) {
      return;
    }

    setState(() {
      _refreshing = true;
    });

    try {
      await _loadWalletAddress();

      await Future<void>.delayed(
        const Duration(
          milliseconds: 500,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
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
    final String? address = _walletAddress;

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
        duration: Duration(
          seconds: 2,
        ),
      ),
    );
  }

  // ============================================================
  // AVATAR
  // ============================================================

  Widget _buildAvatar(
      BuildContext context,
      ) {
    final colors = Theme.of(context).colorScheme;

    if (_avatarUrl != null &&
        _avatarUrl!.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 23,
        backgroundColor:
        colors.surfaceContainerHighest,
        backgroundImage: NetworkImage(
          _avatarUrl!,
        ),
      );
    }

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.primary.withValues(
          alpha: 0.10,
        ),
        border: Border.all(
          color: colors.primary.withValues(
            alpha: 0.16,
          ),
        ),
      ),
      child: Icon(
        Icons.person_outline_rounded,
        color: colors.primary,
        size: 23,
      ),
    );
  }

  // ============================================================
  // WALLET HEADER
  // ============================================================

  Widget _buildWalletHeader(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        4,
        10,
        0,
      ),
      child: Row(
        children: [
          _buildAvatar(context),

          const SizedBox(
            width: 11,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style:
                  text.titleSmall?.copyWith(
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                if (_loadingAddress)
                  Text(
                    'Loading wallet...',
                    style:
                    text.bodySmall?.copyWith(
                      color:
                      colors.onSurfaceVariant,
                    ),
                  )
                else if (_walletAddress ==
                    null ||
                    _walletAddress!.isEmpty)
                  Text(
                    'Wallet unavailable',
                    style:
                    text.bodySmall?.copyWith(
                      color: colors.error,
                    ),
                  )
                else
                  InkWell(
                    onTap: _copyAddress,
                    borderRadius:
                    BorderRadius.circular(
                      8,
                    ),
                    child: Padding(
                      padding:
                      const EdgeInsets
                          .symmetric(
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize:
                        MainAxisSize.min,
                        children: [
                          Text(
                            _shortenAddress(
                              _walletAddress!,
                            ),
                            style: text
                                .bodySmall
                                ?.copyWith(
                              color: colors
                                  .onSurfaceVariant,
                              fontWeight:
                              FontWeight.w500,
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
                            width: 5,
                          ),

                          Icon(
                            Icons
                                .content_copy_rounded,
                            size: 13,
                            color: colors
                                .onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          IconButton(
            tooltip: 'Notifications',
            visualDensity:
            VisualDensity.compact,
            onPressed: () {},
            icon: Icon(
              Icons
                  .notifications_none_rounded,
              color:
              colors.onSurfaceVariant,
            ),
          ),

          IconButton(
            tooltip: 'Scan QR code',
            visualDensity:
            VisualDensity.compact,
            onPressed: () {},
            icon: Icon(
              Icons
                  .qr_code_scanner_rounded,
              color:
              colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BALANCE
  // ============================================================

  Widget _buildBalance(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        18,
        14,
        0,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          20,
          22,
          20,
          20,
        ),
        decoration: BoxDecoration(
          color: colors.primary.withValues(
            alpha: 0.07,
          ),
          borderRadius:
          BorderRadius.circular(24),
          border: Border.all(
            color:
            colors.primary.withValues(
              alpha: 0.12,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total Balance',
                    style:
                    text.bodyMedium?.copyWith(
                      color:
                      colors.onSurfaceVariant,
                      fontWeight:
                      FontWeight.w500,
                    ),
                  ),
                ),

                Container(
                  padding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors
                        .tertiary
                        .withValues(
                      alpha: 0.10,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Row(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      Icon(
                        Icons
                            .trending_up_rounded,
                        size: 14,
                        color:
                        colors.tertiary,
                      ),

                      const SizedBox(
                        width: 4,
                      ),

                      Text(
                        '+3.5%',
                        style: text
                            .labelMedium
                            ?.copyWith(
                          color:
                          colors.tertiary,
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              '\$12,450.00',
              style:
              text.displaySmall?.copyWith(
                fontWeight:
                FontWeight.w800,
                letterSpacing: -1.3,
              ),
            ),

            const SizedBox(
              height: 5,
            ),

            Text(
              'Across all assets',
              style:
              text.bodySmall?.copyWith(
                color:
                colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Widget _buildActions(
      BuildContext context,
      ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        14,
        14,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: WalletActionBox(
              icon:
              Icons.arrow_upward_rounded,
              label: 'Send',
            ),
          ),

          const SizedBox(
            width: 8,
          ),

          Expanded(
            child: WalletActionBox(
              icon:
              Icons.arrow_downward_rounded,
              label: 'Receive',
            ),
          ),

          const SizedBox(
            width: 8,
          ),

          Expanded(
            child: WalletActionBox(
              icon:
              Icons.swap_horiz_rounded,
              label: 'Swap',
            ),
          ),

          const SizedBox(
            width: 8,
          ),

          // ==================================================
          // BUY
          //
          // This currently opens your Easy Buy sheet.
          // Later this can be connected to a fiat on-ramp
          // provider such as MoonPay, Transak, Ramp, etc.
          // ==================================================

          Expanded(
            child: WalletActionBox(
              icon:
              Icons.shopping_cart_outlined,
              label: 'Buy',
              onTap: () {
                openEasyBuySheet(
                  context,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TABS
  // ============================================================

  Widget _buildTabs(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        18,
        14,
        8,
      ),
      child: Row(
        children: List.generate(
          tabs.length,
              (index) {
            final bool isFilterTab =
            tabs[index] is IconData;

            final bool isSelected =
                !isFilterTab &&
                    controller
                        .state
                        .selectedTab ==
                        index;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right:
                  index ==
                      tabs.length - 1
                      ? 0
                      : 6,
                ),
                child: Material(
                  color:
                  Colors.transparent,
                  child: InkWell(
                    borderRadius:
                    BorderRadius.circular(
                      11,
                    ),
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
                            .setTab(index);
                      });
                    },
                    child:
                    AnimatedContainer(
                      duration:
                      const Duration(
                        milliseconds: 180,
                      ),
                      padding:
                      const EdgeInsets
                          .symmetric(
                        vertical: 10,
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
                            .surfaceContainerLow,
                        borderRadius:
                        BorderRadius
                            .circular(
                          11,
                        ),
                        border:
                        Border.all(
                          color: isSelected
                              ? colors
                              .primary
                              .withValues(
                            alpha:
                            0.45,
                          )
                              : colors
                              .outlineVariant
                              .withValues(
                            alpha:
                            0.40,
                          ),
                        ),
                      ),
                      child: isFilterTab
                          ? Icon(
                        tabs[index]
                        as IconData,
                        size: 18,
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
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // ASSET HEADER
  // ============================================================

  Widget _buildAssetHeader(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    final int tokenCount =
        controller.filteredTokens.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        6,
      ),
      child: Row(
        children: [
          Text(
            'Your Assets',
            style:
            text.titleMedium?.copyWith(
              fontWeight:
              FontWeight.w700,
            ),
          ),

          const Spacer(),

          Text(
            '$tokenCount assets',
            style:
            text.bodySmall?.copyWith(
              color:
              colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY TOKEN STATE
  // ============================================================

  Widget _buildEmptyTokenState(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration:
                BoxDecoration(
                  color: colors
                      .surfaceContainerHighest,
                  shape:
                  BoxShape.circle,
                ),
                child: Icon(
                  Icons
                      .account_balance_wallet_outlined,
                  size: 27,
                  color: colors
                      .onSurfaceVariant,
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              Text(
                'No tokens found',
                style: text
                    .titleSmall
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w600,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                'Your assets will appear here.',
                style: text
                    .bodySmall
                    ?.copyWith(
                  color: colors
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TOKEN LIST
  // ============================================================

  Widget _buildTokenList(
      BuildContext context,
      ) {
    final tokens =
        controller.filteredTokens;

    if (tokens.isEmpty) {
      return _buildEmptyTokenState(
        context,
      );
    }

    return SliverList(
      delegate:
      SliverChildBuilderDelegate(
            (context, index) {
          return TokenListItem(
            token: tokens[index],
          );
        },
        childCount:
        tokens.length,
      ),
    );
  }

  // ============================================================
  // AD SPACE
  // ============================================================

  Widget _buildAdSpace(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          14,
          20,
          14,
          10,
        ),
        child: Container(
          height: 90,
          width: double.infinity,
          decoration: BoxDecoration(
            color:
            colors.surfaceContainerLow,
            borderRadius:
            BorderRadius.circular(18),
            border: Border.all(
              color: colors
                  .outlineVariant
                  .withValues(
                alpha: 0.35,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Icon(
                Icons.campaign_outlined,
                size: 22,
                color:
                colors.onSurfaceVariant,
              ),

              const SizedBox(
                height: 5,
              ),

              Text(
                'Advertisement',
                style:
                text.labelSmall?.copyWith(
                  color: colors
                      .onSurfaceVariant,
                  fontWeight:
                  FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MAIN SCROLL VIEW
  // ============================================================

  Widget _buildScrollableContent(
      BuildContext context,
      ) {
    final colors =
        Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _refreshWallet,
      displacement: 30,
      edgeOffset: 0,
      color: colors.primary,
      backgroundColor:
      colors.surface,
      child: CustomScrollView(
        physics:
        const AlwaysScrollableScrollPhysics(
          parent:
          BouncingScrollPhysics(),
        ),
        slivers: [
          // ==================================================
          // HEADER
          // ==================================================

          SliverToBoxAdapter(
            child:
            _buildWalletHeader(
              context,
            ),
          ),

          // ==================================================
          // BALANCE
          // ==================================================

          SliverToBoxAdapter(
            child:
            _buildBalance(
              context,
            ),
          ),

          // ==================================================
          // ACTIONS
          // ==================================================

          SliverToBoxAdapter(
            child:
            _buildActions(
              context,
            ),
          ),

          // ==================================================
          // TABS
          // ==================================================

          SliverToBoxAdapter(
            child:
            _buildTabs(
              context,
            ),
          ),

          // ==================================================
          // ASSET HEADER
          // ==================================================

          SliverToBoxAdapter(
            child:
            _buildAssetHeader(
              context,
            ),
          ),

          // ==================================================
          // TOKEN LIST
          // ==================================================

          _buildTokenList(
            context,
          ),

          // ==================================================
          // ADVERTISEMENT
          // ==================================================

          _buildAdSpace(
            context,
          ),

          // ==================================================
          // BOTTOM SPACE
          //
          // Gives enough room for:
          // - floating Buy button
          // - bottom navigation
          // - comfortable scrolling
          // ==================================================

          const SliverToBoxAdapter(
            child: SizedBox(
              height: 170,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme =
    Theme.of(context);
    final colors =
        theme.colorScheme;
    final text =
        theme.textTheme;

    return Scaffold(
      backgroundColor:
      theme.scaffoldBackgroundColor,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: Text(
          'Wallet',
          style:
          text.titleLarge?.copyWith(
            fontWeight:
            FontWeight.w700,
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

      body:
      _buildScrollableContent(
        context,
      ),

      // ========================================================
      // BUY BUTTON
      //
      // Right side and raised above the bottom navigation.
      // ========================================================

      floatingActionButton:
      SafeArea(
        minimum:
        const EdgeInsets.only(
          right: 4,
          bottom: 18,
        ),
        child:
        FloatingActionButton.extended(
          heroTag:
          'easy_buy_fab',
          backgroundColor:
          colors.primary,
          foregroundColor:
          colors.onPrimary,
          elevation: 6,
          tooltip:
          'Buy crypto',
          onPressed: () {
            openEasyBuySheet(
              context,
            );
          },
          icon: const Icon(
            Icons
                .shopping_cart_outlined,
          ),
          label: const Text(
            'Buy',
            style: TextStyle(
              fontWeight:
              FontWeight.w700,
            ),
          ),
        ),
      ),

      // ========================================================
      // FAB LOCATION
      // ========================================================

      floatingActionButtonLocation:
      const _RaisedEndFloatLocation(
        bottomDistance: 82,
        rightDistance: 16,
      ),
    );
  }
}

// ================================================================
// RAISED RIGHT-SIDE FAB LOCATION
// ================================================================

class _RaisedEndFloatLocation
    extends FloatingActionButtonLocation {
  final double bottomDistance;
  final double rightDistance;

  const _RaisedEndFloatLocation({
    this.bottomDistance = 82,
    this.rightDistance = 16,
  });

  @override
  Offset getOffset(
      ScaffoldPrelayoutGeometry
      scaffoldGeometry,
      ) {
    final double x =
        scaffoldGeometry.scaffoldSize.width -
            scaffoldGeometry
                .floatingActionButtonSize
                .width -
            rightDistance;

    final double y =
        scaffoldGeometry.scaffoldSize.height -
            scaffoldGeometry
                .floatingActionButtonSize
                .height -
            bottomDistance;

    return Offset(
      x,
      y,
    );
  }
}