import 'package:flutter/material.dart';

class TokenIcon extends StatelessWidget {
  final String imageUrl;
  final double radius;

  const TokenIcon({
    super.key,
    required this.imageUrl,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.surfaceContainerHighest,
      backgroundImage: NetworkImage(imageUrl),
      child: Image.network(
        imageUrl,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.token_rounded,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
