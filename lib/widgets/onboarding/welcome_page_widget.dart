import 'package:flutter/material.dart';
import '../../core/ui/widgets/griot_branded_container.dart';

class WelcomePageWidget extends StatelessWidget {
  final int order;
  final String title;
  final String description;
  final String imagePath;
  final Widget bottomAction;

  const WelcomePageWidget({
    super.key,
    required this.order,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.bottomAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // ==================================================
          // BRAND
          // ==================================================
          Text(
            'Griot',
            style: textTheme.displayLarge?.copyWith(
              fontSize: 38,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'By Cowrie',
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.primary,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
            ),
          ),

          const Spacer(),

          // ==================================================
          // IMAGE
          // ==================================================
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: size.height * 0.28,
              ),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
              ),
            ),
          ),

          const Spacer(),

          // ==================================================
          // CONTENT BOX
          // ==================================================
          GriotBrandedContainer(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.left,
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  textAlign: TextAlign.left,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.75),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ==========================================================
          // FIXED BOTTOM ACTION
          // ==========================================================
          SafeArea(
            top: false,
            child: GriotBrandedContainer(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              borderRadius: 32,
              child: bottomAction,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
