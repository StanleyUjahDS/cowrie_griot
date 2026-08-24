import 'package:flutter/material.dart';

class WalletBalanceCard extends StatelessWidget {
  final String balance;
  final String change;
  final bool isProfit;

  const WalletBalanceCard({
    super.key,
    required this.balance,
    required this.change,
    this.isProfit = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colors.primary.withValues(alpha: 0.12),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Branded Background Elements
              Positioned(
                left: -20,
                top: -30,
                child: Opacity(
                  opacity: 0.05,
                  child: Image.asset(
                    'assets/cowrie_images/cowrie_ring.png',
                    width: 140,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                right: -40,
                bottom: -30,
                child: Opacity(
                  opacity: 0.08,
                  child: Image.asset(
                    'assets/cowrie_images/cowrie_stack.png',
                    width: 180,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total Balance',
                            style: text.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: (isProfit ? colors.tertiary : colors.error).withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                size: 14,
                                color: isProfit ? colors.tertiary : colors.error,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                change,
                                style: text.labelMedium?.copyWith(
                                  color: isProfit ? colors.tertiary : colors.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        balance,
                        style: text.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Across all assets',
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
