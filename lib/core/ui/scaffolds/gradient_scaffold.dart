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
  final bool resizeToAvoidBottomInset;

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
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      // The body gradient starts below the app bar when
      // extendBodyBehindAppBar is false. Keep the app-bar band themed too.
      backgroundColor: colorScheme.surface,
      appBar: appBar,
      drawer: drawer,
      endDrawer: endDrawer,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colorScheme.surface, theme.scaffoldBackgroundColor],
          ),
        ),
        child: Stack(
          children: [
            // Branded Background Image (Spiral)
            // Placed at the top center, visible and not "depreciated" (increased opacity)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: isDark ? 0.35 : 0.18,
                child: Image.asset(
                  'assets/cowrie_images/background_spiral.png',
                  alignment: Alignment.topCenter,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // Content
            Positioned.fill(
              child: useSafeArea ? SafeArea(child: child) : child,
            ),
          ],
        ),
      ),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }
}
