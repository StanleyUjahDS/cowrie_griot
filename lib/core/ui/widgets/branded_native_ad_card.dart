import 'package:flutter/material.dart';

import 'griot_branded_container.dart';
import 'native_ad.dart';

/// Shared native-ad chrome for Wallet, Game Center and Camp surfaces.
/// The ad creative remains owned by Google Mobile Ads and mediation.
class BrandedNativeAdCard extends StatelessWidget {
  final Key? adKey;
  final String placement;
  final bool compact;
  final double height;

  const BrandedNativeAdCard({
    super.key,
    this.adKey,
    required this.placement,
    this.compact = true,
    this.height = 350,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GriotNativeAd(
      key: adKey,
      compact: compact,
      height: height,
      embedded: true,
      cardBuilder: (context, ad) => GriotBrandedContainer(
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.symmetric(vertical: 6),
        borderRadius: 22,
        backgroundColor: colors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 15,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Sponsored',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    placement,
                    style: TextStyle(
                      color: colors.onSurfaceVariant.withValues(alpha: .72),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: ad,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
