import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';

import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_branded_container.dart';
import '../services/golds_api_service.dart';
import '../../iap/providers/iap_provider.dart';

class GriotGoldsScreen extends StatefulWidget {
  const GriotGoldsScreen({super.key});

  @override
  State<GriotGoldsScreen> createState() => _GriotGoldsScreenState();
}

class _GriotGoldsScreenState extends State<GriotGoldsScreen> {
  late Future<_GoldsSnapshot> _snapshot;
  int _lastGoldPurchaseGeneration = 0;

  @override
  void initState() {
    super.initState();
    _snapshot = _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final iap = context.read<IapProvider>();
      _lastGoldPurchaseGeneration = iap.goldPurchaseGeneration;
      iap.addListener(_onIapChanged);
    });
  }

  void _onIapChanged() {
    if (!mounted) return;
    final generation = context.read<IapProvider>().goldPurchaseGeneration;
    if (generation != _lastGoldPurchaseGeneration) {
      _lastGoldPurchaseGeneration = generation;
      setState(() => _snapshot = _load());
    }
  }

  Future<_GoldsSnapshot> _load() async {
    final api = context.read<GoldsApiService>();
    var balance = 0;
    var packages = <Map<String, dynamic>>[];
    try {
      balance = await api.getBalance();
    } catch (_) {
      // Keep the page useful while an account has no ledger row yet or the
      // endpoint is being deployed.
    }
    try {
      packages = await api.getCatalog();
    } catch (_) {
      // Fall back to the published catalogue until the API is reachable.
    }
    if (packages.isEmpty) packages = _fallbackPackages;
    return _GoldsSnapshot(balance: balance, packages: packages);
  }

  void _retry() => setState(() => _snapshot = _load());

  @override
  void dispose() {
    context.read<IapProvider>().removeListener(_onIapChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GradientScaffold(
      appBar: AppBar(title: const Text('Griot Golds'), centerTitle: true),
      child: FutureBuilder<_GoldsSnapshot>(
        future: _snapshot,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 42,
                      color: colors.primary,
                    ),
                    const SizedBox(height: 12),
                    const Text('Griot Golds could not be loaded.'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _retry(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
              children: [
                GriotBrandedContainer(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  backgroundColor: colors.primaryContainer.withValues(
                    alpha: .28,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 88,
                        height: 88,
                        child: Image.asset(
                          'assets/coins_logo/griot_gold_nugget_3d.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Griot Golds',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Your balance',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${data.balance} Golds',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Internal Griot credits',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GriotBrandedContainer(
                  padding: const EdgeInsets.all(18),
                  backgroundColor: colors.primaryContainer.withValues(
                    alpha: .32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'One balance. More ways to participate.',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Use Griot Golds across the places where the community connects.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          _GoldUseChip(
                            icon: Icons.workspace_premium_rounded,
                            label: 'Griot Plus',
                          ),
                          _GoldUseChip(
                            icon: Icons.local_fire_department_rounded,
                            label: 'Griot Camps',
                          ),
                          _GoldUseChip(
                            icon: Icons.card_giftcard_rounded,
                            label: 'Gifts & tips',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Choose a Gold pack',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    Icon(Icons.lock_outline_rounded, size: 16, color: colors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('Secure purchase', style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Use Golds for creator tips, gifts, Camp features and Griot Plus.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                if (data.packages.isEmpty)
                  const Text('Gold packages are not available yet.')
                else
                  ...data.packages.map((item) => _GoldPackageCard(item: item)),
                const SizedBox(height: 18),
                GriotBrandedContainer(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: colors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Golds are internal Griot credits. They are not cryptocurrency and cannot currently be withdrawn as cash.',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GoldPackageCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _GoldPackageCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final golds = (item['golds'] as num?)?.toInt() ?? 0;
    final bonus = (item['bonus'] as num?)?.toInt() ?? 0;
    final productId = item['id']?.toString() ?? '';
    final iap = context.watch<IapProvider>();
    ProductDetails? product;
    for (final candidate in iap.goldProducts) {
      if (candidate.id == productId) product = candidate;
    }
    final displayedPrice = product?.price ?? 'Not available';
    final total = golds + bonus;
    final isPurchasing = iap.isVerifying && product != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GriotBrandedContainer(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Image.asset('assets/coins_logo/griot_gold_nugget_3d.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$total Griot Golds', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  Text(bonus > 0 ? '$golds Golds + $bonus bonus' : 'One-time Gold top-up', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: product == null || isPurchasing
                  ? null
                  : () => context.read<IapProvider>().buyGoldProduct(product!),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
              child: Text(isPurchasing ? '…' : displayedPrice),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoldUseChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _GoldUseChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.primary.withValues(alpha: .25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _GoldsSnapshot {
  final int balance;
  final List<Map<String, dynamic>> packages;

  const _GoldsSnapshot({required this.balance, required this.packages});
}

const _fallbackPackages = <Map<String, dynamic>>[
  {'id': 'griot_gold_100', 'golds': 100, 'bonus': 0, 'referencePriceUsd': 0.99},
  {
    'id': 'griot_gold_550',
    'golds': 550,
    'bonus': 50,
    'referencePriceUsd': 4.99,
  },
  {
    'id': 'griot_gold_1200',
    'golds': 1200,
    'bonus': 200,
    'referencePriceUsd': 9.99,
  },
  {
    'id': 'griot_gold_2600',
    'golds': 2600,
    'bonus': 600,
    'referencePriceUsd': 19.99,
  },
];
