import 'package:flutter/material.dart';

class GradientScaffold extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool extendBodyBehindAppBar;
  final Widget? drawer;
  final Widget? endDrawer;
  final bool useSafeArea;

  const GradientScaffold({
    super.key,
    required this.child,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.extendBodyBehindAppBar = false,
    this.drawer,
    this.endDrawer,
    this.useSafeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final backgroundColor = theme.scaffoldBackgroundColor;

    return Scaffold(
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      backgroundColor: backgroundColor,
      appBar: appBar,
      drawer: drawer,
      endDrawer: endDrawer,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ==================================================
          // BACKGROUND GRADIENT & IMAGE
          // ==================================================
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    backgroundColor,
                    theme.brightness == Brightness.dark
                        ? Color.alphaBlend(
                            Colors.black.withValues(alpha: 0.2),
                            backgroundColor,
                          )
                        : Color.alphaBlend(
                            colors.primary.withValues(alpha: 0.04),
                            backgroundColor,
                          ),
                  ],
                ),
              ),
            ),
          ),

          // SPIRAL (Centered at top)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: IgnorePointer(
              child: Image.asset(
                'assets/cowrie_images/background_spiral.png',
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
              ),
            ),
          ),

          // ==================================================
          // CONTENT
          // ==================================================
          useSafeArea ? SafeArea(child: child) : child,
        ],
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}