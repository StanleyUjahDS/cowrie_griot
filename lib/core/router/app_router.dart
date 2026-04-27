import 'package:go_router/go_router.dart';

import '../../features/splash/splash_screen.dart';
import '../../features/settings/theme_settings_page.dart';
import '../theme/theme_controller.dart';

import '../../features/splash/welcome_page_1.dart';
import '../../features/splash/welcome_page_2.dart';
import '../../features/splash/welcome_page_3.dart';
import '../../features/splash/welcome_page_4.dart';
import '../../features/splash/welcome_page_5.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/create_account.dart';
import '../../features/auth/confirm_phrase.dart';
import '../../features/auth/display_phrase.dart';
import '../../features/auth/recover_account.dart';

import '../../features/local_auth/create_password_screen.dart';
import '../../features/local_auth/confirm_password_screen.dart';

import '../../features/local_auth/enable_biometrics_screen.dart';


import '../../features/chat/chat_home_screen.dart';
import '../../features/wallet/wallet_screen.dart';
import '../../features/p2p/peer_2_peer.dart';
import '../../features/miner/miner_screen.dart';
import '../../features/settings/setting_screen.dart';
import '/core/ui/scaffolds/gradient_scaffold.dart';


import 'main_navigation.dart';

class AppRouter {
  static late ThemeController themeController;

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [

      // ================= SPLASH =================
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),

      // ================= THEME =================
      GoRoute(
        path: '/theme-settings',
        builder: (context, state) => ThemeSettingsPage(
          themeController: themeController,
        ),
      ),

      // ================= WELCOME =================
      GoRoute(path: '/welcome_one', builder: (context, state) => const WelcomePage1()),
      GoRoute(path: '/welcome_two', builder: (context, state) => const WelcomePage2()),
      GoRoute(path: '/welcome_three', builder: (context, state) => const WelcomePage3()),
      GoRoute(path: '/welcome_four', builder: (context, state) => const WelcomePage4()),
      GoRoute(path: '/welcome_five', builder: (context, state) => const WelcomePage5()),

      // ================= AUTH =================
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/create_account', builder: (context, state) => const CreateAccountScreen()),
      GoRoute(path: '/recover_account', builder: (context, state) => const ImportWalletScreen()),
      GoRoute(path: '/set_password', builder: (context, state) => const SetPassword()),
      GoRoute(path: '/verify_phrase', builder: (context, state) => const VerifySeed()),
      GoRoute(path: '/display_phrase', builder: (context, state) => const  DisplayPhraseScreen()),



      GoRoute(
        path: '/confirm_password',
        builder: (context, state) {
          final input = state.extra as String;
          return VerifyPassword(input: input);
        },
      ),

      GoRoute(
        path: '/enable_biometrics',
        builder: (context, state) => const BiometricsScreen(),
      ),

      // ================= WHATSAPP STYLE SHELL =================
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return GradientScaffold(
              child: MainNavigationShell(navigationShell: navigationShell));
        },

        branches: [

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const ChatHomeScreen(),
              ),
            ],
          ),

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/miner',
                builder: (context, state) => const MinerScreen(),
              ),
            ],
          ),

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wallet',
                builder: (context, state) => const WalletScreen(),
              ),
            ],
          ),

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/p2p',
                builder: (context, state) => const P2PScreen(),
              ),
            ],
          ),

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  static void setThemeController(ThemeController controller) {
    themeController = controller;
  }
}