// lib/features/settings/screens/account/widgets/identity_card.dart

import 'package:flutter/material.dart';

class IdentityCard extends StatelessWidget {
  const IdentityCard({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        color: colorScheme.primary.withValues(alpha: 0.045),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.11),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.fingerprint_rounded,
              color: colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Griot Identity',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your wallet address is your identity on Griot. '
                      'It is used to identify your account across the network.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.4,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}