import 'package:flutter/material.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/deep_link_service.dart';

class LinkPreviewWidget extends StatelessWidget {
  final String url;
  final bool isMe;

  /// Metadata saved with a Tale is preferred when it is available. This keeps
  /// previews stable for sites that block a second client-side fetch while
  /// still allowing AnyLinkPreview to refresh missing/stale values.
  final String? title;
  final String? description;
  final String? imageUrl;

  const LinkPreviewWidget({
    super.key,
    required this.url,
    required this.isMe,
    this.title,
    this.description,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final normalizedUrl = _normalizeUrl(url);
    final parsedUri = Uri.tryParse(normalizedUrl);
    if (parsedUri == null || !parsedUri.hasScheme || parsedUri.host.isEmpty) {
      return _buildFallback(context, normalizedUrl, colorScheme);
    }
    final uri = parsedUri;
    final isGriotLink =
        uri != null &&
        (uri.host.toLowerCase() == 'griot.network' ||
            uri.host.toLowerCase() == 'www.griot.network');
    if (isGriotLink) {
      return _buildGriotPreview(context, uri, colorScheme);
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AnyLinkPreview(
          // The URL key is important: AnyLinkPreview is stateful and otherwise
          // can retain metadata from the previous Tale/message when a list row
          // is recycled. A short cache keeps previews current without fetching
          // the same URL on every rebuild.
          key: ValueKey('link-preview:$normalizedUrl'),
          link: normalizedUrl,
          cache: const Duration(minutes: 15),
          backgroundColor: isMe
              ? colorScheme.onPrimary.withValues(alpha: 0.1)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          placeholderWidget: Container(
            height: 100,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: _buildFallback(context, normalizedUrl, colorScheme),
          titleStyle: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isMe ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
          bodyStyle: theme.textTheme.labelSmall?.copyWith(
            color: isMe
                ? colorScheme.onPrimary.withValues(alpha: 0.7)
                : colorScheme.onSurfaceVariant,
          ),
          onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
        ),
      ),
    );
  }

  String _normalizeUrl(String value) {
    var result = value.trim();
    if (result.startsWith('<') && result.endsWith('>')) {
      result = result.substring(1, result.length - 1).trim();
    }
    // URLs commonly arrive followed by sentence punctuation. Sending that
    // punctuation to the metadata parser produces an invalid/empty preview.
    result = result.replaceFirst(RegExp(r'[.,!?;:\)\]\}]+$'), '');
    if (!RegExp(
      r'^[a-z][a-z0-9+.-]*://',
      caseSensitive: false,
    ).hasMatch(result)) {
      result = 'https://$result';
    }
    return result;
  }

  Widget _buildFallback(
    BuildContext context,
    String value,
    ColorScheme colorScheme,
  ) {
    final theme = Theme.of(context);
    final parsed = Uri.tryParse(value);
    final host = parsed?.host.isNotEmpty == true ? parsed!.host : value;
    final fallbackTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : host;
    final fallbackBody = description?.trim().isNotEmpty == true
        ? description!.trim()
        : value;
    final image = imageUrl?.trim();
    return InkWell(
      onTap: () {
        final target = Uri.tryParse(value);
        if (target != null) {
          launchUrl(target, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (image != null && image.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  image,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.link_rounded,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                ),
              )
            else
              Icon(Icons.link_rounded, color: colorScheme.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fallbackTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isMe
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    fallbackBody,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isMe
                          ? colorScheme.onPrimary.withValues(alpha: 0.72)
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGriotPreview(
    BuildContext context,
    Uri uri,
    ColorScheme colorScheme,
  ) {
    final theme = Theme.of(context);
    final segments = uri.pathSegments;
    final kind = segments.isNotEmpty ? segments.first.toLowerCase() : '';
    final value = segments.length > 1 ? segments[1] : null;
    final (String title, String subtitle, IconData icon) = switch (kind) {
      'group' || 'circle' => (
        value == null ? 'Griot group' : 'Griot group · @$value',
        'Open this group in Griot',
        Icons.groups_rounded,
      ),
      'channel' => (
        value == null ? 'Griot channel' : 'Griot channel · @$value',
        'Open this channel in Griot',
        Icons.campaign_rounded,
      ),
      'profile' => (
        value == null ? 'Griot profile' : 'Griot profile · @$value',
        'View this profile in Griot',
        Icons.person_rounded,
      ),
      'join' => (
        'Join Griot Network',
        'Open your invitation in Griot',
        Icons.link_rounded,
      ),
      'plus' => (
        'Griot Plus',
        'Open Griot Plus in the app',
        Icons.star_rounded,
      ),
      _ => ('Griot Network', 'Open in Griot', Icons.public_rounded),
    };

    final cardColor = isMe
        ? colorScheme.onPrimary.withValues(alpha: 0.12)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: InkWell(
        onTap: () => DeepLinkService.instance.handleUri(
          uri.replace(host: 'griot.network'),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isMe
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isMe
                            ? colorScheme.onPrimary.withValues(alpha: 0.72)
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isMe ? colorScheme.onPrimary : colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
