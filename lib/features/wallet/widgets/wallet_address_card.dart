import 'package:flutter/material.dart';
import '../utils/wallet_formatters.dart';

class WalletAddressCard extends StatelessWidget {
  final String? address;
  final bool isLoading;
  final VoidCallback onTap;

  const WalletAddressCard({
    super.key,
    this.address,
    this.isLoading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (isLoading) {
      return Text(
        'Loading wallet...',
        style: text.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      );
    }

    if (address == null || address!.isEmpty) {
      return Text(
        'Wallet unavailable',
        style: text.bodySmall?.copyWith(
          color: colors.error,
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              WalletFormatters.shortenAddress(address!),
              style: text.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              Icons.verified_rounded,
              size: 14,
              color: colors.primary,
            ),
            const SizedBox(width: 5),
            Icon(
              Icons.content_copy_rounded,
              size: 13,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
