import 'package:flutter/material.dart';
import '../models/conversation_model.dart';

// Group list item component for the chat home screen.
class GroupListItem extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback? onTap;

  const GroupListItem({
    super.key,
    required this.conversation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final description = (conversation.description ?? '').trim();
    final hasImage = conversation.imageUrl != null && conversation.imageUrl!.trim().isNotEmpty;

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
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // ==========================================================
                // GROUP IMAGE
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
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  ),
                  child: ClipOval(
                    child: hasImage
                        ? Image.network(conversation.imageUrl!, fit: BoxFit.cover)
                        : Icon(
                      Icons.groups_rounded,
                      size: 30,
                      color: colorScheme.primary,
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
                      Text(
                        conversation.name ?? 'Unknown Group',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description.isNotEmpty ? description : 'Group conversation',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // ==========================================================
                // TRAILING INFO
                // ==========================================================
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (conversation.memberCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_rounded, size: 12, color: colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              conversation.memberCount.toString(),
                              style: TextStyle(
                                color: colorScheme.primary.computeLuminance() > 0.6
                                    ? colorScheme.onSurface
                                    : colorScheme.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
