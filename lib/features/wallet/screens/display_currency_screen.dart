import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_branded_container.dart';
import '../providers/display_currency_provider.dart';

class DisplayCurrencyScreen extends StatelessWidget {
  const DisplayCurrencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<DisplayCurrencyProvider>();
    final colors = Theme.of(context).colorScheme;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text(
          'Display currency',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
        children: [
          GriotBrandedContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        currency.symbol,
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currency.label,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            currency.currency,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Wallet balances, asset prices, transaction estimates, and swap values will use this currency.',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  currency.formatUsd(1234.56),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Example wallet value',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Choose currency',
            style: TextStyle(
              color: colors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 9),
          GriotBrandedContainer(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < DisplayCurrencyProvider.supported.length;
                  index++
                ) ...[
                  _CurrencyOption(
                    code: DisplayCurrencyProvider.supported[index],
                    selected:
                        currency.currency ==
                        DisplayCurrencyProvider.supported[index],
                    onTap: () => currency.setCurrency(
                      DisplayCurrencyProvider.supported[index],
                    ),
                  ),
                  if (index != DisplayCurrencyProvider.supported.length - 1)
                    Divider(
                      height: 1,
                      indent: 74,
                      endIndent: 16,
                      color: colors.outline.withValues(alpha: 0.18),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyOption extends StatelessWidget {
  const _CurrencyOption({
    required this.code,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final symbol = DisplayCurrencyProvider.symbols[code]!;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? colors.primary.withValues(alpha: 0.16)
                    : colors.surfaceContainerHighest.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                symbol,
                style: TextStyle(
                  color: selected ? colors.primary : colors.onSurface,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DisplayCurrencyProvider.labels[code]!,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    code,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: colors.primary),
          ],
        ),
      ),
    );
  }
}
