import 'package:flutter/material.dart';
import '../models/token_model.dart';
import 'token_icon.dart';

class TokenListItem extends StatelessWidget {
  final TokenModel token;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TokenListItem({
    super.key,
    required this.token,
    this.onTap,
    this.onLongPress,
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
    final status = token.status.toLowerCase();
    final isBlocked = status == 'blocked' || token.isSpam;
    
    // Major assets (Native and Griot Assets) are always treated as Verified.
    final isVerified = status == 'verified' || token.isNative || token.isGriotAsset;
    final isUnknown = status == 'unknown' && !token.isNative && !token.isGriotAsset;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isBlocked 
            ? colors.error.withValues(alpha: 0.05) 
            : colors.surfaceContainerLow.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isBlocked 
              ? colors.error.withValues(alpha: 0.2) 
              : colors.outlineVariant.withValues(alpha: 0.05)
          ),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          token.name.isEmpty ? token.symbol : token.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: Colors.green,
                        ),
                      ],
                      if (token.isEcosystem) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.workspace_premium_rounded,
                          size: 16,
                          color: colors.primary,
                        ),
                      ],
                      if (isUnknown) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.help_outline_rounded,
                          size: 14,
                          color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ],
                      if (isBlocked) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.gpp_bad_rounded,
                          size: 14,
                          color: colors.error,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (isUnknown) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: colors.onSurfaceVariant.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "UNVERIFIED",
                            style: text.labelSmall?.copyWith(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          token.symbol,
                          style: text.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        ' • ${token.chain.toUpperCase()}',
                        style: text.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _formatPrice(token.priceUsd),
                          style: text.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
              mainAxisSize: MainAxisSize.min,
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
