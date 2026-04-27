import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class GradientScaffold extends StatelessWidget {
  final Widget child;

  const GradientScaffold({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.expand(
        child: Stack(
          children: [
            //  GRADIENT BACKGROUND (FROM APPCOLORS)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                    AppColors.darkPrimary,
                    AppColors.darkSurface,
                  ]
                      : [
                    AppColors.lightPrimary,
                    AppColors.lightSurface,
                  ],
                  stops: const [0.55, 1.0],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
            ),

            // OPTIONAL BACKGROUND IMAGE LAYER
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.48,
              child: Image.asset(
                'assets/cowrie_images/background_spiral.png',
                fit: BoxFit.cover,
              ),
            ),

            // 📦 CONTENT LAYER
            child,
          ],
        ),
      ),
    );
  }
}