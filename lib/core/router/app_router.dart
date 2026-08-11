import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/splash/splash_screen.dart';
import '../../features/splash/welcome_page_1.dart';
import '../../features/splash/welcome_page_2.dart';
import '../../features/splash/welcome_page_3.dart';
import '../../features/splash/welcome_page_4.dart';
import '../../features/splash/welcome_page_5.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/create_account.dart';
import '../../features/auth/screens/confirm_phrase.dart';
import '../../features/auth/screens/display_phrase.dart';
import '../../features/auth/screens/recover_account.dart';

import '../../features/local_auth/screens/create_password_screen.dart';
import '../../features/local_auth/screens/confirm_password_screen.dart';
import '../../features/local_auth/screens/enable_biometrics_screen.dart';

import '../../features/chat/screens/chat_home_screen.dart';
import '../../features/chat/screens/chatting_screen.dart';
import '../../features/chat/controllers/chat_controller.dart';

import '../../features/settings/pages/theme_settings_page.dart';
import '../../features/settings/setting_screen.dart';

import '../../features/wallet/screens/wallet_screen.dart';
import '../../features/p2p/screens/peer_2_peer.dart';
import '../../features/miner/screens/miner_screen.dart';

import '/core/ui/scaffolds/gradient_scaffold.dart';

import 'main_navigation.dart';
import '../theme/theme_controller.dart';

class AppRouter {
  // ============================================================
  // THEME CONTROLLER
  // ============================================================

  static late ThemeController themeController;

  static void setThemeController(
      ThemeController controller,
      ) {
    themeController = controller;
  }

  // ============================================================
  // ROUTER
  // ============================================================

  static final GoRouter router = GoRouter(
    initialLocation: '/',

    routes: [
      // ========================================================
      // ROOT
      // ========================================================

      GoRoute(
        path: '/',
        builder: (context, state) {
          return const SplashScreen();
        },
      ),

      // ========================================================
      // FULL SCREEN CHAT
      // ========================================================

      GoRoute(
        path: '/chat/:userId',
        builder: (context, state) {
          final userId =
          state.pathParameters['userId']!;

          return ChatScreen(
            userId: userId,
          );
        },
      ),

      // ========================================================
      // WELCOME
      // ========================================================

      GoRoute(
        path: '/welcome_one',
        builder: (context, state) {
          return const WelcomePage1();
        },
      ),

      GoRoute(
        path: '/welcome_two',
        builder: (context, state) {
          return const WelcomePage2();
        },
      ),

      GoRoute(
        path: '/welcome_three',
        builder: (context, state) {
          return const WelcomePage3();
        },
      ),

      GoRoute(
        path: '/welcome_four',
        builder: (context, state) {
          return const WelcomePage4();
        },
      ),

      GoRoute(
        path: '/welcome_five',
        builder: (context, state) {
          return const WelcomePage5();
        },
      ),

      // ========================================================
      // AUTH
      // ========================================================

      GoRoute(
        path: '/login',
        builder: (context, state) {
          return const LoginScreen();
        },
      ),

      GoRoute(
        path: '/create_account',
        builder: (context, state) {
          return const CreateAccountScreen();
        },
      ),

      GoRoute(
        path: '/recover_account',
        builder: (context, state) {
          return const RecoverAccountScreen();
        },
      ),

      GoRoute(
        path: '/set_password',
        builder: (context, state) {
          return const SetPassword();
        },
      ),

      GoRoute(
        path: '/verify_phrase',
        builder: (context, state) {
          return const VerifySeed();
        },
      ),

      GoRoute(
        path: '/display_phrase',
        builder: (context, state) {
          return const DisplayPhraseScreen();
        },
      ),

      GoRoute(
        path: '/confirm_password',
        builder: (context, state) {
          final input = state.extra as String;

          return VerifyPassword(
            input: input,
          );
        },
      ),

      GoRoute(
        path: '/enable_biometrics',
        builder: (context, state) {
          return const BiometricsScreen();
        },
      ),

      // ========================================================
      // THEME SETTINGS
      // ========================================================

      GoRoute(
        path: '/settings/theme',
        builder: (context, state) {
          return const ThemeSettingsPage();
        },
      ),

      // ========================================================
      // MAIN NAVIGATION SHELL
      // ========================================================

      StatefulShellRoute.indexedStack(
        builder: (
            context,
            state,
            navigationShell,
            ) {
          return GradientScaffold(
            child: MainNavigationShell(
              navigationShell: navigationShell,
            ),
          );
        },

        branches: [
          // ====================================================
          // CHAT
          // ====================================================

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) {
                  return ChangeNotifierProvider<ChatController>(
                    create: (_) =>
                    ChatController()..initialize(),
                    child: const ChatHomeScreen(),
                  );
                },
              ),
            ],
          ),

          // ====================================================
          // MINER
          // ====================================================

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/miner',
                builder: (context, state) {
                  return const MinerScreen();
                },
              ),
            ],
          ),

          // ====================================================
          // WALLET
          // ====================================================

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wallet',
                builder: (context, state) {
                  return const WalletScreen();
                },
              ),
            ],
          ),

          // ====================================================
          // P2P
          // ====================================================

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/p2p',
                builder: (context, state) {
                  return const P2PScreen();
                },
              ),
            ],
          ),

          // ====================================================
          // SETTINGS
          // ====================================================

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) {
                  return const SettingsScreen();
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}