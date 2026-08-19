import 'package:flutter/material.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/ui/widgets/native_ad.dart';
import '../widgets/p2p_loading.dart';

class P2PScreen extends StatefulWidget {
  const P2PScreen({
    super.key,
  });

  @override
  State<P2PScreen> createState() => _P2PScreenState();
}

class _P2PScreenState extends State<P2PScreen> {
  bool _buyMode = true;
  String _selectedAsset = 'USDT';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  final List<Map<String, dynamic>> _offers = [
    {
      'name': 'Alex Morgan',
      'username': '@alexm',
      'rating': 4.9,
      'trades': 128,
      'price': '1.00',
      'currency': 'USD',
      'available': '2,450 USDT',
      'limits': '\$100 - \$2,500',
      'payment': 'Bank Transfer',
      'avatar': 'A',
      'online': true,
    },
    {
      'name': 'David Smith',
      'username': '@davids',
      'rating': 4.8,
      'trades': 94,
      'price': '0.99',
      'currency': 'USD',
      'available': '1,850 USDT',
      'limits': '\$50 - \$1,500',
      'payment': 'Bank Transfer',
      'avatar': 'D',
      'online': true,
    },
    {
      'name': 'Sarah Williams',
      'username': '@sarahw',
      'rating': 5.0,
      'trades': 241,
      'price': '1.01',
      'currency': 'USD',
      'available': '6,200 USDT',
      'limits': '\$100 - \$5,000',
      'payment': 'Wise',
      'avatar': 'S',
      'online': false,
    },
    {
      'name': 'Michael Brown',
      'username': '@michaelb',
      'rating': 4.7,
      'trades': 76,
      'price': '1.00',
      'currency': 'USD',
      'available': '980 USDT',
      'limits': '\$25 - \$750',
      'payment': 'Revolut',
      'avatar': 'M',
      'online': true,
    },
    {
      'name': 'James Wilson',
      'username': '@jamesw',
      'rating': 4.9,
      'trades': 315,
      'price': '1.02',
      'currency': 'USD',
      'available': '12,500 USDT',
      'limits': '\$200 - \$10,000',
      'payment': 'Bank Transfer',
      'avatar': 'J',
      'online': true,
    },
    {
      'name': 'Daniel Johnson',
      'username': '@danielj',
      'rating': 4.8,
      'trades': 187,
      'price': '1.00',
      'currency': 'USD',
      'available': '4,300 USDT',
      'limits': '\$75 - \$3,000',
      'payment': 'PayPal',
      'avatar': 'D',
      'online': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'P2P',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () {},
            icon: const Icon(
              Icons.search_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Orders',
            onPressed: () {},
            icon: const Icon(
              Icons.receipt_long_outlined,
            ),
          ),
        ],
      ),

      body: RefreshIndicator(
        color: colors.primary,
        backgroundColor: colors.surface,
        onRefresh: () async {
          setState(() => _isLoading = true);
          await Future<void>.delayed(
            const Duration(
              milliseconds: 1200,
            ),
          );
          if (mounted) {
            setState(() => _isLoading = false);
          }
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: _buildModeSelector(
                context,
              ),
            ),

            SliverToBoxAdapter(
              child: _buildAssetSelector(
                context,
              ),
            ),

            SliverToBoxAdapter(
              child: _buildSearchCard(
                context,
              ),
            ),

            SliverToBoxAdapter(
              child: _buildSectionHeader(
                context,
              ),
            ),

            if (_isLoading)
              const P2PLoading()
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                      (
                      context,
                      index,
                      ) {
                  // Show an ad after every 3 items
                  if (index > 0 && index % 3 == 0) {
                    return const Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: GriotNativeAd(),
                        ),
                      ],
                    );
                  }

                  // Adjust index for offer data if ads are inserted
                  // But here we'll just show ads interspersed with the SAME list for now
                  // or we can just show one ad at index 3.
                  
                  final offer = _offers[index % _offers.length];

                  return _buildOfferCard(
                    context,
                    offer,
                  );
                },
                childCount: _offers.length + (_offers.length ~/ 3),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(
                height: 120,
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showCreateOfferSheet(
            context,
          );
        },
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'Create Offer',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector(
      BuildContext context,
      ) {
    final colors =
        Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        8,
        14,
        8,
      ),
      child: Container(
        padding: const EdgeInsets.all(
          4,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(
            14,
          ),
          border: Border.all(
            color: colors.outlineVariant.withValues(
              alpha: 0.35,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildModeButton(
                context,
                title: 'Buy',
                selected: _buyMode,
                onTap: () {
                  setState(() {
                    _buyMode = true;
                  });
                },
              ),
            ),
            Expanded(
              child: _buildModeButton(
                context,
                title: 'Sell',
                selected: !_buyMode,
                onTap: () {
                  setState(() {
                    _buyMode = false;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(
      BuildContext context, {
        required String title,
        required bool selected,
        required VoidCallback onTap,
      }) {
    final colors =
        Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 180,
        ),
        padding: const EdgeInsets.symmetric(
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(
            11,
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected
                ? colors.onPrimary
                : colors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildAssetSelector(
      BuildContext context,
      ) {
    final colors =
        Theme.of(context).colorScheme;
    final text =
        Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        10,
        14,
        8,
      ),
      child: Row(
        children: [
          Text(
            'Asset',
            style: text.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          PopupMenuButton<String>(
            initialValue: _selectedAsset,
            onSelected: (value) {
              setState(() {
                _selectedAsset = value;
              });
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem(
                  value: 'USDT',
                  child: Text('USDT'),
                ),
                PopupMenuItem(
                  value: 'USDC',
                  child: Text('USDC'),
                ),
                PopupMenuItem(
                  value: 'ETH',
                  child: Text('ETH'),
                ),
                PopupMenuItem(
                  value: 'BTC',
                  child: Text('BTC'),
                ),
              ];
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(
                  12,
                ),
                border: Border.all(
                  color: colors.outlineVariant
                      .withValues(
                    alpha: 0.4,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedAsset,
                    style: text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(
                    width: 5,
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Filters',
            onPressed: () {
              _showFilters(
                context,
              );
            },
            icon: const Icon(
              Icons.tune_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard(
      BuildContext context,
      ) {
    final colors =
        Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        4,
        14,
        16,
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText:
          'Enter amount or search merchant',
          prefixIcon: const Icon(
            Icons.search_rounded,
          ),
          suffixIcon: IconButton(
            onPressed: () {
              _showFilters(
                context,
              );
            },
            icon: const Icon(
              Icons.tune_rounded,
            ),
          ),
          filled: true,
          fillColor:
          colors.surfaceContainerLow,
          border: OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(
              16,
            ),
            borderSide: BorderSide(
              color: colors.outlineVariant
                  .withValues(
                alpha: 0.35,
              ),
            ),
          ),
          enabledBorder:
          OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(
              16,
            ),
            borderSide: BorderSide(
              color: colors.outlineVariant
                  .withValues(
                alpha: 0.35,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context,
      ) {
    final text =
        Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        0,
        16,
        8,
      ),
      child: Row(
        children: [
          Text(
            _buyMode
                ? 'Buy $_selectedAsset'
                : 'Sell $_selectedAsset',
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            '${_offers.length} offers',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(
      BuildContext context,
      Map<String, dynamic> offer,
      ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        6,
        14,
        6,
      ),
      child: Container(
        padding: const EdgeInsets.all(
          16,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(
            18,
          ),
          border: Border.all(
            color: colors.outlineVariant.withValues(
              alpha: 0.35,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.04,
              ),
              blurRadius: 12,
              offset: const Offset(
                0,
                4,
              ),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundColor:
                      colors.primary.withValues(
                        alpha: 0.10,
                      ),
                      child: Text(
                        offer['avatar'],
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (offer['online'] == true)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.surface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(
                  width: 11,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer['name'],
                        style: text.titleSmall?.copyWith(
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        '${offer['username']} • ${offer['trades']} trades',
                        style: text.bodySmall?.copyWith(
                          color:
                          colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: Colors.amber,
                    ),
                    const SizedBox(
                      width: 3,
                    ),
                    Text(
                      '${offer['rating']}',
                      style: text.labelMedium?.copyWith(
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            Row(
              crossAxisAlignment:
              CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Price',
                        style: text.bodySmall?.copyWith(
                          color:
                          colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        '\$${offer['price']}',
                        style: text.titleLarge?.copyWith(
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Available',
                      style: text.bodySmall?.copyWith(
                        color:
                        colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      offer['available'],
                      style: text.labelLarge?.copyWith(
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(
              height: 12,
            ),

            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _buildTag(
                  context,
                  offer['payment'],
                  Icons.account_balance_outlined,
                ),
                _buildTag(
                  context,
                  offer['limits'],
                  Icons.swap_horiz_rounded,
                ),
              ],
            ),

            const SizedBox(
              height: 15,
            ),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  _showOfferSheet(
                    context,
                    offer,
                  );
                },
                child: Text(
                  _buyMode
                      ? 'Buy $_selectedAsset'
                      : 'Sell $_selectedAsset',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(
      BuildContext context,
      String label,
      IconData icon,
      ) {
    final colors =
        Theme.of(context).colorScheme;
    final text =
        Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(
          9,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(
            width: 5,
          ),
          Text(
            label,
            style: text.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showOfferSheet(
      BuildContext context,
      Map<String, dynamic> offer,
      ) {
    final colors =
        Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: colors.surface,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.of(context)
                .viewInsets
                .bottom +
                20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                _buyMode
                    ? 'Buy $_selectedAsset'
                    : 'Sell $_selectedAsset',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              Text(
                'Trading with ${offer['name']}',
              ),
              const SizedBox(
                height: 20,
              ),
              TextField(
                keyboardType:
                const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration:
                InputDecoration(
                  labelText:
                  'Amount in USD',
                  prefixText: '\$ ',
                  border:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                  ),
                ),
              ),
              const SizedBox(
                height: 12,
              ),
              Text(
                'Rate: \$${offer['price']} $_selectedAsset',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium,
              ),
              const SizedBox(
                height: 20,
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );

                    NotificationService.showSuccess(
                      _buyMode
                          ? 'Buy order started'
                          : 'Sell order started',
                    );
                  },
                  child: Text(
                    _buyMode
                        ? 'Continue Buy'
                        : 'Continue Sell',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFilters(
      BuildContext context,
      ) {
    final colors =
        Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: colors.surface,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              10,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'P2P Filters',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                const ListTile(
                  leading: Icon(
                    Icons.payments_outlined,
                  ),
                  title: Text(
                    'Payment method',
                  ),
                  subtitle: Text(
                    'All payment methods',
                  ),
                ),
                const ListTile(
                  leading: Icon(
                    Icons.public_rounded,
                  ),
                  title: Text(
                    'Region',
                  ),
                  subtitle: Text(
                    'Use your preferred region',
                  ),
                ),
                const ListTile(
                  leading: Icon(
                    Icons.sort_rounded,
                  ),
                  title: Text(
                    'Sort by',
                  ),
                  subtitle: Text(
                    'Best price',
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );
                    },
                    child: const Text(
                      'Apply Filters',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreateOfferSheet(
      BuildContext context,
      ) {
    final colors =
        Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: colors.surface,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.of(context)
                .viewInsets
                .bottom +
                20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                'Create P2P Offer',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
              const SizedBox(
                height: 18,
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Sell'),
                    icon: Icon(
                      Icons.arrow_upward_rounded,
                    ),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Buy'),
                    icon: Icon(
                      Icons.arrow_downward_rounded,
                    ),
                  ),
                ],
                selected: const {
                  true,
                },
                onSelectionChanged: (_) {},
              ),
              const SizedBox(
                height: 14,
              ),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Asset',
                  hintText: 'USDT',
                  border: OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                  ),
                ),
              ),
              const SizedBox(
                height: 12,
              ),
              TextField(
                keyboardType:
                const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Price',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                  ),
                ),
              ),
              const SizedBox(
                height: 12,
              ),
              TextField(
                keyboardType:
                const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Available amount',
                  border: OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                  ),
                ),
              ),
              const SizedBox(
                height: 18,
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );
                    NotificationService.showSuccess('P2P offer created');
                  },
                  child: const Text(
                    'Publish Offer',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}