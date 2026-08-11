import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/chat_channel.dart';

class ChannelListItem extends StatelessWidget {
  final ChatChannel channel;

  const ChannelListItem({
    super.key,
    required this.channel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final imageUrl = channel.imageUrl;
    final hasImage =
        imageUrl != null && imageUrl.trim().isNotEmpty;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 6,
      ),

      // ==========================================================
      // CHANNEL IMAGE
      // ==========================================================

      leading: CircleAvatar(
        radius: 27,
        backgroundColor:
        colorScheme.secondary.withValues(
          alpha: 0.12,
        ),
        backgroundImage: hasImage
            ? NetworkImage(imageUrl)
            : null,
        child: !hasImage
            ? Icon(
          Icons.campaign_rounded,
          color: colorScheme.secondary,
        )
            : null,
      ),

      // ==========================================================
      // CHANNEL NAME + VERIFIED
      // ==========================================================

      title: Row(
        children: [
          Expanded(
            child: Text(
              channel.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (channel.verified)
            Padding(
              padding: const EdgeInsets.only(
                left: 5,
              ),
              child: Icon(
                Icons.verified_rounded,
                size: 17,
                color: colorScheme.primary,
              ),
            ),
        ],
      ),

      // ==========================================================
      // SUBSCRIBERS + LAST POST
      // ==========================================================

      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '${channel.subscriberCount} subscribers • '
              '${channel.lastPost}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),

      // ==========================================================
      // TIME
      // ==========================================================

      trailing: Text(
        channel.time,
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // ==========================================================
      // OPEN CHANNEL
      // ==========================================================

      onTap: () {
        context.push(
          '/channel/${channel.id}',
        );
      },
    );
  }
}