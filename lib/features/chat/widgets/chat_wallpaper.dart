import 'package:flutter/material.dart';

/// A subtle tiled wallpaper for conversation screens.
class ChatWallpaper extends StatelessWidget {
  final Widget child;

  const ChatWallpaper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Establish the active theme surface first. The tile itself is
        // transparent, so the conversation theme remains visible underneath.
        Positioned.fill(child: ColoredBox(color: colors.surface)),
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              // The replacement tile uses crisp single-color strokes and
              // real alpha. Keep it restrained in both themes so light-mode
              // surfaces do not wash the line art into a grey haze.
              opacity: isDark ? 0.13 : 0.14,
              child: Image.asset(
                'assets/cowrie_images/chat_wallpaper_tile_v3.png',
                repeat: ImageRepeat.repeat,
                alignment: Alignment.topLeft,
                cacheWidth: 720,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
