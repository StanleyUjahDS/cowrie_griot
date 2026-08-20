import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../scaffolds/gradient_scaffold.dart';
import 'griot_loader.dart';

class GriotBrandedLoading extends StatelessWidget {
  final String message;
  final String? title;
  final IconData icon;
  final bool fullScreen;
  final bool avoidBottomNav;

  const GriotBrandedLoading({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.account_balance_wallet_outlined,
    this.fullScreen = true,
    this.avoidBottomNav = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final content = Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animation Stack (Exact match of AppLoadingScreen)
              _buildAnimation(context),

              const SizedBox(height: 28),

              // Brand
              Text(
                'Griot',
                style: textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              )
                  .animate()
                  .fadeIn(duration: 700.ms)
                  .slideY(begin: 0.15, end: 0, duration: 700.ms, curve: Curves.easeOut),

              const SizedBox(height: 6),

              Text(
                'By Cowrie',
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                ),
              ).animate().fadeIn(delay: 150.ms, duration: 700.ms),

              const SizedBox(height: 48),

              // Status
              Column(
                children: [
                  const GriotLoader(size: 40, strokeWidth: 3.5),
                  const SizedBox(height: 22),
                  if (title != null) ...[
                    Text(
                      title!,
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ).animate().fadeIn(duration: 500.ms),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.65),
                      height: 1.45,
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.12, end: 0, duration: 500.ms, curve: Curves.easeOut),
                ],
              ),

              const SizedBox(height: 30),

              // Security Message
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 15,
                    color: colorScheme.onSurface.withValues(alpha: 0.40),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Please keep this screen open',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.40),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Bottom Spacer / Navigation Bar Compensation
              if (avoidBottomNav) const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );

    if (fullScreen) {
      return GradientScaffold(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(child: content),
        ),
      );
    }

    return content;
  }

  Widget _buildAnimation(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Glow
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.18),
                  blurRadius: 70,
                  spreadRadius: 15,
                ),
              ],
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(0.85, 0.85), end: const Offset(1.15, 1.15), duration: 1800.ms, curve: Curves.easeInOut)
              .fade(begin: 0.45, end: 1, duration: 1800.ms),

          // Outer Ring
          Container(
            width: 122,
            height: 122,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.07),
              border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18), width: 1.5),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(0.94, 0.94), end: const Offset(1.06, 1.06), duration: 1600.ms, curve: Curves.easeInOut),

          // Main Icon
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.30),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, size: 58, color: colorScheme.onPrimary),
          ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.70, 0.70), end: const Offset(1, 1), duration: 700.ms, curve: Curves.easeOutBack).then().shimmer(duration: 1800.ms, color: colorScheme.onPrimary.withValues(alpha: 0.25)),

          // Orbit Dot
          Positioned(
            top: 34,
            right: 53,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.50),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
          ).animate(onPlay: (c) => c.repeat()).rotate(duration: 2600.ms),
        ],
      ),
    );
  }
}
