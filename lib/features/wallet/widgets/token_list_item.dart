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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final bool isPositive = token.changePercent >= 0;
    final bool isDark = theme.brightness == Brightness.dark;

    final Color borderColor = colorScheme.outline.withValues(
      alpha: isDark ? 0.20 : 0.12,
    );

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
          ),
        ),
        child: Row(
          children: [
            TokenIcon(
              imageUrl: token.imageUrl,
              chainName: token.chain,
              radius: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    token.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    token.symbol,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${token.balance}",
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "${isPositive ? '+' : ''}${token.changePercent}%",
                  style: textTheme.bodySmall?.copyWith(
                    color: isPositive ? colorScheme.tertiary : colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
