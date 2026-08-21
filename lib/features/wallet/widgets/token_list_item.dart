import 'package:flutter/material.dart';
import '../models/token_model.dart';
import 'token_icon.dart';

class TokenListItem extends StatelessWidget {
  final TokenModel token;
  final VoidCallback? onTap;

  const TokenListItem({
    super.key,
    required this.token,
    this.onTap,
  });

  String _formatBalance(num value) {
    final amount = value.toDouble();
    if (amount == 0) return '0';
    if (amount >= 1000000000) return '${(amount / 1000000000).toStringAsFixed(2)}B';
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(2)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(2)}K';
    if (amount >= 1) return amount.toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '');
    return amount.toStringAsFixed(8).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _formatPrice(num value) {
    final price = value.toDouble();
    if (!token.hasMarketData || price <= 0) return '--';
    if (price >= 1) return '\$${price.toStringAsFixed(2)}';
    if (price >= 0.01) return '\$${price.toStringAsFixed(4)}';
    return '\$${price.toStringAsFixed(6)}';
  }

  String _formatUsd(num value) {
    final amount = value.toDouble().abs();
    if (!token.hasMarketData) return '--';
    if (amount >= 1000000) return '\$${(amount / 1000000).toStringAsFixed(2)}M';
    if (amount >= 1000) return '\$${(amount / 1000).toStringAsFixed(2)}K';
    return '\$${amount.toStringAsFixed(2)}';
  }

  String _formatChange(num value) {
    if (!token.hasMarketData) return '--';
    final change = value.toDouble();
    final sign = change > 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(2)}%';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final bool isPositive = token.changePercent >= 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            TokenIcon(
              imageUrl: token.imageUrl,
              symbol: token.symbol,
              name: token.name,
              chainName: token.chain,
              isNative: token.isNative,
              radius: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    token.name.isEmpty ? token.symbol : token.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        token.symbol,
                        style: text.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatPrice(token.priceUsd),
                        style: text.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatBalance(token.balance),
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatUsd(token.valueUsd),
                      style: text.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatChange(token.changePercent),
                      style: text.labelSmall?.copyWith(
                        color: !token.hasMarketData
                            ? colors.onSurfaceVariant
                            : isPositive
                                ? colors.tertiary
                                : colors.error,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
