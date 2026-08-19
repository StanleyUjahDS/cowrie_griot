import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GriotAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? iconColor;

  const GriotAvatar({
    super.key,
    this.avatarUrl,
    this.radius = 24,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasUrl = avatarUrl != null && avatarUrl!.trim().isNotEmpty;

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? colorScheme.primary.withValues(alpha: 0.10),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: ClipOval(
        child: hasUrl
            ? Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFallback(colorScheme),
              )
            : _buildFallback(colorScheme),
      ),
    );
  }

  Widget _buildFallback(ColorScheme colorScheme) {
    return Center(
      child: SvgPicture.asset(
        'assets/chains/Hbadger.svg',
        width: radius * 1.4,
        height: radius * 1.4,
        fit: BoxFit.contain,
        placeholderBuilder: (context) => Icon(
          Icons.person_outline_rounded,
          color: iconColor ?? colorScheme.primary,
          size: radius,
        ),
      ),
    );
  }
}
