import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ChatLoading extends StatelessWidget {
  const ChatLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 116, bottom: 170),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 10,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        indent: 80,
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
      ),
      itemBuilder: (context, index) {
        return const _ShimmerChatItem();
      },
    );
  }
}

class _ShimmerChatItem extends StatelessWidget {
  const _ShimmerChatItem();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color shimmerBase = colorScheme.surfaceContainerHighest.withValues(
      alpha: isDark ? 0.3 : 0.5,
    );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 5,
      ),
      leading: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: shimmerBase,
          shape: BoxShape.circle,
        ),
      ),
      title: Container(
        width: 140,
        height: 16,
        margin: const EdgeInsets.only(right: 80),
        decoration: BoxDecoration(
          color: shimmerBase,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          width: 200,
          height: 12,
          margin: const EdgeInsets.only(right: 40),
          decoration: BoxDecoration(
            color: shimmerBase,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 30,
            height: 10,
            decoration: BoxDecoration(
              color: shimmerBase,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: 1500.ms,
          color: colorScheme.primary.withValues(alpha: 0.05),
        );
  }
}
