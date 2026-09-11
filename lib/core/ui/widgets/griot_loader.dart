import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GriotLoader extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;
  final bool useLogo;

  const GriotLoader({
    super.key,
    this.size = 36,
    this.strokeWidth = 3,
    this.color,
    this.useLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final loaderColor = color ?? colorScheme.primary;

    if (useLogo) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow/ring
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: loaderColor.withValues(alpha: 0.1),
                  width: strokeWidth,
                ),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .shimmer(duration: 2.seconds, color: loaderColor.withValues(alpha: 0.2)),

            // Brand Logo Pulsing
            SvgPicture.asset(
              'assets/coins_logo/hbadger_logo.svg',
              width: size * 0.7,
              height: size * 0.7,
              colorFilter: ColorFilter.mode(loaderColor, BlendMode.srcIn),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.1, 1.1),
                  duration: 800.ms,
                  curve: Curves.easeInOutBack,
                )
                .shake(hz: 2, rotation: 0.02, duration: 2.seconds),

            // Orbital dot
            Positioned(
              top: 0,
              child: Container(
                width: strokeWidth * 1.5,
                height: strokeWidth * 1.5,
                decoration: BoxDecoration(
                  color: loaderColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: loaderColor.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .rotate(duration: 2.seconds, curve: Curves.linear),
          ],
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(loaderColor),
        backgroundColor: loaderColor.withValues(alpha: 0.1),
      ),
    );
  }
}

/// A full-screen or centered overlay loader
class GriotOverlayLoader extends StatelessWidget {
  final String? message;

  const GriotOverlayLoader({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
              width: 1.5,
            ),
            bottom: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GriotLoader(size: 44, strokeWidth: 3.5),
            if (message != null) ...[
              const SizedBox(height: 18),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A smaller, pulsing indicator for inline status or typing
class GriotPulseIndicator extends StatelessWidget {
  final double size;
  final Color? color;
  final int dotCount;

  const GriotPulseIndicator({
    super.key,
    this.size = 14,
    this.color,
    this.dotCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dotColor = color ?? colorScheme.primary;

    return Container(
      height: size,
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(dotCount, (index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Container(
              width: size * 0.25,
              height: size * 0.25,
              decoration: BoxDecoration(
                color: dotColor.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(0.6, 0.6),
                  end: const Offset(1.4, 1.4),
                  delay: (index * 200).ms,
                  duration: 600.ms,
                  curve: Curves.easeInOut,
                )
                .fade(
                  begin: 0.4,
                  end: 1.0,
                  delay: (index * 200).ms,
                  duration: 600.ms,
                ),
          );
        }),
      ),
    );
  }
}
