import 'package:flutter/material.dart';
import '../utils/chain_assets.dart';

class TokenIcon extends StatelessWidget {
  final String imageUrl;
  final String? chainName;
  final double radius;

  const TokenIcon({
    super.key,
    required this.imageUrl,
    this.chainName,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: colors.surfaceContainerHighest,
          backgroundImage: NetworkImage(imageUrl),
          child: Image.network(
            imageUrl,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.token_rounded,
              color: colors.onSurfaceVariant,
              size: radius,
            ),
          ),
        ),
        if (chainName != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
              ),
              child: ChainAssets.getIcon(
                chainName!,
                size: radius * 0.6,
              ),
            ),
          ),
      ],
    );
  }
}
