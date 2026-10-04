import 'package:flutter/material.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/deep_link_service.dart';

class LinkPreviewWidget extends StatelessWidget {
  final String url;
  final bool isMe;

  const LinkPreviewWidget({
    super.key,
    required this.url,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final uri = Uri.tryParse(url);
    final isGriotLink = uri != null &&
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
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AnyLinkPreview(
          link: url,
          cache: const Duration(hours: 24),
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
          errorWidget: Container(
            height: 60,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.link_rounded, color: colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isMe ? colorScheme.onPrimary.withValues(alpha: 0.7) : colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          titleStyle: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isMe ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
          bodyStyle: theme.textTheme.labelSmall?.copyWith(
            color: isMe ? colorScheme.onPrimary.withValues(alpha: 0.7) : colorScheme.onSurfaceVariant,
          ),
          onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        ),
      ),
    );
  }

  Widget _buildGriotPreview(
    BuildContext context,
    Uri uri,
    ColorScheme colorScheme,
  ) {
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
      'join' => ('Join Griot Network', 'Open your invitation in Griot', Icons.link_rounded),
      'plus' => ('Griot Plus', 'Open Griot Plus in the app', Icons.star_rounded),
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
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700,
                            color: isMe ? colorScheme.onPrimary : colorScheme.onSurface)),
                    const SizedBox(height: 3),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12,
                            color: isMe ? colorScheme.onPrimary.withValues(alpha: 0.72) : colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14,
                  color: isMe ? colorScheme.onPrimary : colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
