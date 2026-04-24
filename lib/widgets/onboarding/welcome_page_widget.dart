import 'package:flutter/material.dart';
import '/core/theme/app_colors.dart';

class WelcomePageWidget extends StatelessWidget {
  final int order;
  final String title;
  final String description;
  final String imagePath;
  final Widget bottomAction;

  final VoidCallback? onSkip;

  const WelcomePageWidget({
    super.key,
    required this.order,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.bottomAction,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.of(context).size;

    return SizedBox(
      height: size.height,
      child: Column(
        children: [
          // 🔥 SCROLLABLE CONTENT
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      'Griot',
                      style: textTheme.displayLarge,
                    ),

                    Text(
                      'By Cowrie',
                      style: textTheme.titleSmall?.copyWith(
                        color: AppColors.gold,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    SizedBox(height: size.height * 0.04),

                    // 🖼 CENTERED IMAGE
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

                    // 🧠 TITLE (LEFT)
                    Text(
                      title,
                      textAlign: TextAlign.left,
                      style: textTheme.headlineLarge,
                    ),

                    const SizedBox(height: 12),

                    //  DESCRIPTION (LEFT)
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

          // 🔻 FIXED BOTTOM ACTION
          SafeArea(
            top: false,
            child: bottomAction,
          ),
        ],
      ),
    );
  }
}