import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

  /// Signed media URLs often contain a fresh query string on every API
  /// response. The object itself is identified by its host/path, so use that
  /// stable identity for the disk cache and avoid a placeholder flash.
  static String stableCacheKey(String url) {
    final parsed = Uri.tryParse(url.trim());
    if (parsed == null || parsed.host.isEmpty) return url.trim();
    return Uri(
      scheme: parsed.scheme,
      host: parsed.host,
      port: parsed.hasPort ? parsed.port : null,
      path: parsed.path,
    ).toString();
  }

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
                  child: CachedNetworkImage(
                    imageUrl: avatarUrl!,
                    cacheKey: stableCacheKey(avatarUrl!),
                    fit: BoxFit.cover,
                    useOldImageOnUrlChange: true,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholder: (context, url) => _buildEmpty(colorScheme),
                    errorWidget: (context, url, error) =>
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
      padding: EdgeInsets.all((radius * 0.16).clamp(3.0, 8.0)),
      child: Image.asset(
        'assets/coins_logo/hbadger_logo.png',
        fit: BoxFit.contain,
        semanticLabel: 'HBadge profile image',
      ),
    );
  }
}
