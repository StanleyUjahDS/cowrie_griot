import 'package:flutter/material.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:url_launcher/url_launcher.dart';

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
}
