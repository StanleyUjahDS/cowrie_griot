import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final backgroundColor =
        theme.scaffoldBackgroundColor;

    return Scaffold(
      extendBodyBehindAppBar:
      extendBodyBehindAppBar,

      backgroundColor:
      backgroundColor,

      appBar: appBar,

      body: Container(
        color: backgroundColor,

        child: Stack(
          children: [

            // ==================================================
            // BACKGROUND IMAGE
            // ==================================================

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height:
              MediaQuery.of(context).size.height * 0.48,

              child: IgnorePointer(
                child: Image.asset(
                  'assets/cowrie_images/background_pattern.png',

                  fit: BoxFit.cover,

                  alignment:
                  Alignment.topCenter,

                  color: colors.onSurface.withValues(
                    alpha:
                    theme.brightness ==
                        Brightness.dark
                        ? 0.06
                        : 0.025,
                  ),

                  colorBlendMode:
                  BlendMode.srcIn,
                ),
              ),
            ),

            // ==================================================
            // CONTENT
            // ==================================================

            SafeArea(
              child: child,
            ),
          ],
        ),
      ),

      bottomNavigationBar:
      bottomNavigationBar,

      floatingActionButton:
      floatingActionButton,
    );
  }
}