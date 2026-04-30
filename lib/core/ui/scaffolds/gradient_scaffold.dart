import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class GradientScaffold extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool extendBodyBehindAppBar;

  const GradientScaffold({
    super.key,
    required this.child,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: extendBodyBehindAppBar,

      appBar: appBar,

      body: Container(
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

        child: Stack(
          children: [

            ///  BACKGROUND IMAGE (safe overlay now)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.48,
              child: Image.asset(
                'assets/cowrie_images/background_pattern.png',
                fit: BoxFit.cover,
              ),
            ),

            /// 📦 CONTENT
            SafeArea(child: child),
          ],
        ),
      ),

      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}