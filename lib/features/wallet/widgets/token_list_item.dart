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

    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(2)}B';
    }

    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(2)}M';
    }

    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(2)}K';
    }

    if (amount >= 1) {
      return amount.toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '');
    }

    return amount.toStringAsFixed(8).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _formatPrice(num value) {
    final price = value.toDouble();

    if (!token.hasMarketData || price <= 0) return '--';

    if (price >= 1000000) {
      return '\$${(price / 1000000).toStringAsFixed(2)}M';
    }

    if (price >= 1000) {
      return '\$${(price / 1000).toStringAsFixed(2)}K';
    }

    if (price >= 1) {
      return '\$${price.toStringAsFixed(2)}';
    }

    if (price >= 0.01) {
      return '\$${price.toStringAsFixed(4)}';
    }

    if (price >= 0.0001) {
      return '\$${price.toStringAsFixed(6)}';
    }

    return '\$${price.toStringAsFixed(8)}';
  }

  String _formatUsd(num value) {
    final amount = value.toDouble().abs();

    if (!token.hasMarketData) return '--';

    if (amount >= 1000000000) {
      return '\$${(amount / 1000000000).toStringAsFixed(2)}B';
    }

    if (amount >= 1000000) {
      return '\$${(amount / 1000000).toStringAsFixed(2)}M';
    }

    if (amount >= 1000) {
      return '\$${(amount / 1000).toStringAsFixed(2)}K';
    }

    if (amount >= 0.01) {
      return '\$${amount.toStringAsFixed(2)}';
    }

    return '\$${amount.toStringAsFixed(4)}';
  }

  String _formatChange(num value) {
    if (!token.hasMarketData) return '--';

    final change = value.toDouble();
    final sign = change > 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(2)}%';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final bool isPositive = token.changePercent >= 0;
    final bool isDark = theme.brightness == Brightness.dark;

    final Color borderColor = colorScheme.outline.withValues(alpha: isDark ? 0.20 : 0.12);

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            TokenIcon(
              imageUrl: token.imageUrl,
              symbol: token.symbol,
              name: token.name,
              chainName: token.chain,
              isNative: token.isNative,
              radius: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    token.name.isEmpty ? token.symbol : token.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          token.symbol,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatPrice(token.priceUsd),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
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
                  style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatUsd(token.valueUsd),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatChange(token.changePercent),
                      style: textTheme.bodySmall?.copyWith(
                        color: !token.hasMarketData
                            ? colorScheme.onSurfaceVariant
                            : isPositive
                                ? colorScheme.tertiary
                                : colorScheme.error,
                        fontWeight: FontWeight.w600,
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
