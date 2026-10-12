import 'package:flutter/material.dart';

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
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.16)),
      ),
      child: ClipOval(
        child: hasUrl
            ? Padding(
                padding: EdgeInsets.all((radius * 0.09).clamp(2.5, 5.0)),
                child: ClipOval(
                  child: Image.network(
                    avatarUrl!,
                    fit: BoxFit.cover,
                    frameBuilder:
                        (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded || frame != null) {
                            return child;
                          }
                          return _buildEmpty(colorScheme);
                        },
                    errorBuilder: (context, error, stackTrace) =>
                        _buildEmpty(colorScheme),
                  ),
                ),
              )
            : _buildEmpty(colorScheme),
      ),
    );
  }

  Widget _buildEmpty(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const SizedBox.expand(),
    );
  }
}
