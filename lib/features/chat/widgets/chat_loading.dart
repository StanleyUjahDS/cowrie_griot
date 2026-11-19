import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ChatLoading extends StatelessWidget {
  const ChatLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final base = colors.surfaceContainerHighest.withValues(alpha: .42);
    final highlight = colors.onSurface.withValues(alpha: .08);
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: 7,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (_, index) => Row(
        children: [
          _shimmerBlock(52, 52, base, highlight, radius: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBlock(
                  150 - (index.isEven ? 0 : 24),
                  14,
                  base,
                  highlight,
                ),
                const SizedBox(height: 8),
                _shimmerBlock(210 - (index % 3) * 28, 11, base, highlight),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _shimmerBlock(28, 28, base, highlight, radius: 14),
        ],
      ),
    );
  }

  Widget _shimmerBlock(
    double width,
    double height,
    Color base,
    Color highlight, {
    double radius = 8,
  }) {
    return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(radius),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 1200.ms, color: highlight);
  }
}

/// Stable first-page placeholder for a conversation. It matches the shape of
/// message bubbles so entering a DM/group does not flash an empty wallpaper or
/// paint bubbles one at a time while the first page is reconciled.
class ConversationMessagesLoading extends StatelessWidget {
  const ConversationMessagesLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final base = colors.surfaceContainerHighest.withValues(alpha: .42);
    final highlight = colors.onSurface.withValues(alpha: .08);
    return ListView.builder(
      reverse: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      itemCount: 6,
      itemBuilder: (_, index) {
        final mine = index.isEven;
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child:
              Container(
                    width: 150 + (index % 3) * 34,
                    height: 54 + (index % 2) * 16,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(mine ? 18 : 5),
                        bottomRight: Radius.circular(mine ? 5 : 18),
                      ),
                    ),
                  )
                  .animate(onPlay: (controller) => controller.repeat())
                  .shimmer(duration: 1200.ms, color: highlight),
        );
      },
    );
  }
}
