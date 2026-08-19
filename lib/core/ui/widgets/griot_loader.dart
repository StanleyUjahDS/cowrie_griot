import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GriotLoader extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;

  const GriotLoader({
    super.key,
    this.size = 36,
    this.strokeWidth = 3,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final loaderColor = color ?? colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: strokeWidth,
            color: loaderColor,
            backgroundColor: loaderColor.withValues(alpha: 0.1),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .rotate(duration: 1500.ms, curve: Curves.easeInOutCubic),
          
          // Small dot orbiting or brand element
          Positioned(
            top: 0,
            child: Container(
              width: strokeWidth * 2,
              height: strokeWidth * 2,
              decoration: BoxDecoration(
                color: loaderColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: loaderColor.withValues(alpha: 0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .rotate(duration: 1500.ms, curve: Curves.easeInOutCubic),
        ],
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
