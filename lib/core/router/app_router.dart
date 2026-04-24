import 'package:go_router/go_router.dart';

import '../../features/splash/splash_screen.dart';
import '../../features/settings/theme_settings_page.dart';
import '../theme/theme_controller.dart';
import '../../features/splash/welcome_page_1.dart';
import '../../features/splash/welcome_page_2.dart';
import '../../features/splash/welcome_page_3.dart';
import '../../features/splash/welcome_page_4.dart';
import '../../features/splash/welcome_page_5.dart';







class AppRouter {
  static late ThemeController themeController;

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),

      GoRoute(
        path: '/theme-settings',
        builder: (context, state) {
          return ThemeSettingsPage(
            themeController: themeController,
          );
        },
      ),
      GoRoute(
        path: '/welcome_one',
        builder: (context, state) => const WelcomePage1(),
      ),
      GoRoute(
        path: '/welcome_two',
        builder: (context, state) => const WelcomePage2(),
      ),
      GoRoute(
        path: '/welcome_three',
        builder: (context, state) => const WelcomePage3(),
      ),
      GoRoute(
        path: '/welcome_four',
        builder: (context, state) => const WelcomePage4(),
      ),
      GoRoute(
        path: '/welcome_five',
        builder: (context, state) => const WelcomePage5(),
      ),


    ],
  );

  // call this in main/app before runApp
  static void setThemeController(ThemeController controller) {
    themeController = controller;
  }
}