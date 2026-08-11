import 'package:flutter/material.dart';

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

    return SizedBox(
      height: size.height,
      child: Column(
        children: [
          // ======================================================
          // SCROLLABLE CONTENT
          // ======================================================

          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==================================================
                    // BRAND
                    // ==================================================

                    Text(
                      'Griot',
                      style: textTheme.displayLarge,
                    ),

                    Text(
                      'By Cowrie',
                      style: textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    SizedBox(
                      height: size.height * 0.04,
                    ),

                    // ==================================================
                    // IMAGE
                    // ==================================================

                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: size.height * 0.35,
                          maxWidth: size.width * 0.8,
                        ),
                        child: Image.asset(
                          imagePath,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==================================================
                    // TITLE
                    // ==================================================

                    Text(
                      title,
                      textAlign: TextAlign.left,
                      style: textTheme.headlineLarge,
                    ),

                    const SizedBox(height: 12),

                    // ==================================================
                    // DESCRIPTION
                    // ==================================================

                    Text(
                      description,
                      textAlign: TextAlign.left,
                      style: textTheme.bodyMedium,
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          // ==========================================================
          // FIXED BOTTOM ACTION
          // ==========================================================

          SafeArea(
            top: false,
            child: bottomAction,
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}