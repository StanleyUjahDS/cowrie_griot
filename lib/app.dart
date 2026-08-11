import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

class GriotCowrieApp extends StatefulWidget {
  const GriotCowrieApp({
    super.key,
  });

  @override
  State<GriotCowrieApp> createState() => _GriotCowrieAppState();
}

class _GriotCowrieAppState extends State<GriotCowrieApp> {
  final ThemeController _themeController =
      ThemeController.instance;

  @override
  void initState() {
    super.initState();

    AppRouter.setThemeController(
      _themeController,
    );
  }

  @override
  void dispose() {
    // DO NOT dispose the singleton here.
    //
    // The controller belongs to the entire application.
    super.dispose();
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (
          context,
          _,
          ) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,

          // ==================================================
          // LIGHT THEME
          // ==================================================

          theme: AppTheme.theme(
            style: _themeController.themeStyle,
            brightness: Brightness.light,
          ),

          // ==================================================
          // DARK THEME
          // ==================================================

          darkTheme: AppTheme.theme(
            style: _themeController.themeStyle,
            brightness: Brightness.dark,
          ),

          // ==================================================
          // CURRENT THEME MODE
          // ==================================================

          themeMode: _themeController.themeMode,

          // ==================================================
          // ROUTER
          // ==================================================

          routerConfig: AppRouter.router,
        );
      },
    );
  }
}