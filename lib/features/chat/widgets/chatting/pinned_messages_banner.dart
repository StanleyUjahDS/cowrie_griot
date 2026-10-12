import 'package:flutter/material.dart';

import '../../models/chat_message.dart';

class PinnedMessagesBanner extends StatefulWidget {
  final List<ChatMessage> messages;
  final ValueChanged<ChatMessage>? onMessageTap;

  const PinnedMessagesBanner({
    super.key,
    required this.messages,
    this.onMessageTap,
  });

  @override
  State<PinnedMessagesBanner> createState() => _PinnedMessagesBannerState();
}

class _PinnedMessagesBannerState extends State<PinnedMessagesBanner> {
  int _activeIndex = 0;

  @override
  Widget build(BuildContext context) {
    final messages = widget.messages;
    if (messages.isEmpty) return const SizedBox.shrink();
    if (_activeIndex >= messages.length) _activeIndex = 0;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final orderedIndexes = [
      _activeIndex,
      ...List<int>.generate(
        messages.length,
        (index) => index,
      ).where((index) => index != _activeIndex),
    ];
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: .92),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.push_pin_rounded, size: 17, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  messages.length == 1
                      ? 'Pinned message'
                      : 'Pinned ${_activeIndex + 1} of ${messages.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (messages.length > 1) ...[
                  Text(
                    'Swipe to browse',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next pinned message',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 15),
                    onPressed: () {
                      final next = (_activeIndex + 1) % messages.length;
                      setState(() => _activeIndex = next);
                      widget.onMessageTap?.call(messages[next]);
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: orderedIndexes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final originalIndex = orderedIndexes[index];
                  final message = messages[originalIndex];
                  return InkWell(
                    onTap: widget.onMessageTap == null
                        ? null
                        : () {
                            setState(() => _activeIndex = originalIndex);
                            widget.onMessageTap!(message);
                          },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 180,
                        maxWidth: 280,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: .65),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: .18),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '#${originalIndex + 1}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              message.previewText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (widget.onMessageTap != null) ...[
                            const SizedBox(width: 5),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: colors.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
