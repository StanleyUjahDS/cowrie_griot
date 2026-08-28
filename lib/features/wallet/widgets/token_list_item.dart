import 'package:flutter/material.dart';
import '../models/token_model.dart';
import '../utils/wallet_formatters.dart';
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

  String _formatBalance(TokenModel token) {
    return WalletFormatters.formatBalance(token.balance);
  }

  String _formatPrice(num? value) {
    if (value == null || !token.hasMarketData || value <= 0) return '—';
    final price = value.toDouble();
    if (price >= 1) return '\$${price.toStringAsFixed(2)}';
    if (price >= 0.01) return '\$${price.toStringAsFixed(4)}';
    return '\$${price.toStringAsFixed(6)}';
  }

  String _formatUsd(num? value) {
    if (value == null || !token.hasMarketData) return '—';
    final amount = value.toDouble().abs();
    if (amount >= 1000000) return '\$${(amount / 1000000).toStringAsFixed(2)}M';
    if (amount >= 1000) return '\$${(amount / 1000).toStringAsFixed(2)}K';
    return '\$${amount.toStringAsFixed(2)}';
  }

  String _formatChange(num? value) {
    if (value == null || !token.hasMarketData) return '—';
    final change = value.toDouble();
    final sign = change > 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(2)}%';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final bool isPositive = (token.changePercent ?? 0) >= 0;
    
    final bool isEcosystem = token.isEcosystem;
    final bool isNative = token.isNative;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.primary.withValues(alpha: 0.1)),
                  ),
                  child: TokenIcon(
                    imageUrl: token.imageUrl,
                    symbol: token.symbol,
                    name: token.name,
                    chainName: token.chain,
                    isNative: token.isNative,
                    radius: 22,
                  ),
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
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          if (isEcosystem || isNative) ...[
                            const SizedBox(width: 6),
                            if (isEcosystem)
                              _Tag(
                                label: 'Ecosystem',
                                color: colors.primary,
                                icon: Icons.workspace_premium_rounded,
                              )
                            else if (isNative)
                              _Tag(label: 'Native', color: colors.secondary),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${token.symbol} • ${token.chain.toUpperCase()}',
                            style: text.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
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
                    Flexible(
                      child: Text(
                        _formatUsd(token.valueUsd),
                        style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w900, fontSize: 17),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _formatBalance(token),
                            style: text.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Tag({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color.withValues(alpha: 0.8)),
            const SizedBox(width: 2),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
