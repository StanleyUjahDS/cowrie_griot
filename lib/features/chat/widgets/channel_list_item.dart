import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/conversation_model.dart';
import 'conversation_actions_sheet.dart';

class ChannelListItem extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback? onLongPress;
  final VoidCallback? onPinToggle;
  final VoidCallback? onRemove;
  final bool isPinned;
  final String removeLabel;

  const ChannelListItem({
    super.key,
    required this.conversation,
    this.onLongPress,
    this.onPinToggle,
    this.onRemove,
    this.isPinned = false,
    this.removeLabel = 'Leave channel',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final imageUrl = conversation.imageUrl;
    final hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;

    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border(
          top: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.6),
            width: 1.2,
          ),
          bottom: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.push(
              '/conversation/${conversation.id}',
              extra: conversation,
            );
          },
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // ==========================================================
                // CHANNEL IMAGE
                // ==========================================================
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  child: ClipOval(
                    child: hasImage
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.sensors_rounded,
                              color: colorScheme.primary,
                              size: 30,
                            ),
                          )
                        : Icon(
                            Icons.sensors_rounded,
                            color: colorScheme.primary,
                            size: 30,
                          ),
                  ),
                ),
                const SizedBox(width: 16),

                // ==========================================================
                // INFO CONTENT
                // ==========================================================
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              conversation.name ?? 'Unknown Channel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (isPinned)
                            Icon(
                              Icons.push_pin_rounded,
                              size: 13,
                              color: colorScheme.primary,
                            ),
                          if (isPinned) const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'CHANNEL',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        conversation.lastMessage?.previewText ??
                            '${conversation.subscriberCount} subscribers',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // ==========================================================
                // TIME
                // ==========================================================
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(conversation.updatedAt),
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (conversation.unreadCount > 0) ...[
                      _UnreadBadge(count: conversation.unreadCount),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
                if (onPinToggle != null || onRemove != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Channel actions',
                    padding: EdgeInsets.zero,
                    onPressed: () => showConversationActionsSheet(
                      context: context,
                      isPinned: isPinned,
                      onPinToggle: onPinToggle,
                      onRemove: onRemove,
                      removeLabel: removeLabel,
                    ),
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${time.day}/${time.month}';
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;
  const _UnreadBadge({required this.count});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(10)),
      child: Text(count > 99 ? '99+' : '$count', style: TextStyle(color: colors.onPrimary, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }
}
