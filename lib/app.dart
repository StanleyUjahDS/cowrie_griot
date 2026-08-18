import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

import 'features/users/providers/user_provider.dart';
import 'features/users/services/user_api_service.dart';

class GriotCowrieApp extends StatefulWidget {
  const GriotCowrieApp({
    super.key,
  });

  @override
  State<GriotCowrieApp> createState() =>
      _GriotCowrieAppState();
}

class _GriotCowrieAppState
    extends State<GriotCowrieApp> {
  final ThemeController _themeController =
      ThemeController.instance;

  late final ApiClient _apiClient;
  late final UserApiService _userApiService;

  @override
  void initState() {
    super.initState();

    // ==========================================================
    // API CLIENT
    // ==========================================================

    _apiClient = ApiClient();

    // ==========================================================
    // USER API SERVICE
    // ==========================================================

    _userApiService = UserApiService(
      apiClient: _apiClient,
    );

    // ==========================================================
    // THEME CONTROLLER
    // ==========================================================

    AppRouter.setThemeController(
      _themeController,
    );
  }

  @override
  void dispose() {
    // ==========================================================
    // API CLIENT
    // ==========================================================

    _apiClient.dispose();

    // ==========================================================
    // THEME CONTROLLER
    // ==========================================================
    //
    // DO NOT dispose the singleton.
    //
    // The controller belongs to the entire application.
    //

    super.dispose();
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return MultiProvider(
      providers: [
        // ======================================================
        // USER PROVIDER
        // ======================================================

        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider(
            userApiService: _userApiService,
          )..loadUser(),
        ),
      ],

      // ========================================================
      // APP
      // ========================================================

      child: AnimatedBuilder(
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

            themeMode:
            _themeController.themeMode,

            // ==================================================
            // ROUTER
            // ==================================================

            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}