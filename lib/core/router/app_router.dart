import 'package:flutter/material.dart';
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

import '../../features/settings/screens/setting_screen.dart';
import '../../features/settings/screens/appearance/theme_settings_screen.dart';
import '../../features/settings/screens/appearance/accent_color_screen.dart';
import '../../features/settings/screens/account/account_details_screen.dart';

import '../../features/wallet/screens/wallet_screen.dart';
import '../../features/wallet/services/wallet_crypto_service.dart';

import '../../features/p2p/screens/peer_2_peer.dart';
import '../../features/miner/screens/miner_screen.dart';

import '../ui/scaffolds/gradient_scaffold.dart';
import '../ui/screens/app_loading_screen.dart';

import 'main_navigation.dart';
import '../theme/theme_controller.dart';

// ============================================================
// APP ROUTER
// ============================================================

class AppRouter {
  // ==========================================================
  // THEME CONTROLLER
  // ==========================================================

  static late ThemeController themeController;

  static void setThemeController(
      ThemeController controller,
      ) {
    themeController = controller;
  }

  // ==========================================================
  // ROUTER
  // ==========================================================

  static final GoRouter router = GoRouter(
    initialLocation: '/',

    routes: [
      // ======================================================
      // ROOT
      // ======================================================

      GoRoute(
        path: '/',
        builder: (context, state) {
          return const SplashScreen();
        },
      ),

      // ======================================================
      // FULL SCREEN CHAT
      // ======================================================

      GoRoute(
        path: '/chat/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId'];

          if (userId == null || userId.isEmpty) {
            return const _InvalidRoute(
              message: 'Invalid chat user.',
            );
          }

          return ChatScreen(
            userId: userId,
          );
        },
      ),

      // ======================================================
      // WELCOME
      // ======================================================

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

      // ======================================================
      // AUTH
      // ======================================================

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

      // ======================================================
      // GENERIC APP LOADING
      // ======================================================

      GoRoute(
        path: '/loading',
        builder: (context, state) {
          final extra = state.extra;

          if (extra is! AppLoadingRouteData) {
            return const _InvalidRoute(
              message:
              'Invalid loading screen configuration.',
            );
          }

          return AppLoadingScreen(
            title: extra.title,
            message: extra.message,
            icon: extra.icon,
            operation: extra.operation,
            onSuccess: extra.onSuccess,
          );
        },
      ),

      // ======================================================
      // PASSWORD
      // ======================================================

      GoRoute(
        path: '/set_password',
        builder: (context, state) {
          return const SetPassword();
        },
      ),

      GoRoute(
        path: '/confirm_password',
        builder: (context, state) {
          final extra = state.extra;

          if (extra is! String) {
            return const _InvalidRoute(
              message:
              'Invalid password configuration.',
            );
          }

          return VerifyPassword(
            input: extra,
          );
        },
      ),

      // ======================================================
      // RECOVERY PHRASE
      // ======================================================

      GoRoute(
        path: '/display_phrase',
        builder: (context, state) {
          final extra = state.extra;

          if (extra is! WalletData) {
            return const _InvalidRoute(
              message:
              'Wallet data was not provided.',
            );
          }

          return DisplayPhraseScreen(
            wallet: extra,
          );
        },
      ),

      // ======================================================
      // VERIFY PHRASE
      // ======================================================

      GoRoute(
        path: '/verify_phrase',
        builder: (context, state) {
          return const VerifySeed();
        },
      ),

      // ======================================================
      // BIOMETRICS
      // ======================================================

      GoRoute(
        path: '/enable_biometrics',
        builder: (context, state) {
          return const BiometricsScreen();
        },
      ),

      // ======================================================
      // SETTINGS — THEME
      // ======================================================

      GoRoute(
        path: '/settings/theme',
        builder: (context, state) {
          return const ThemeSettingsPage();
        },
      ),

      // ======================================================
      // SETTINGS — ACCENT COLOR
      // ======================================================

      GoRoute(
        path: '/settings/accent-color',
        builder: (context, state) {
          return const AccentColorScreen();
        },
      ),

      // ======================================================
      // SETTINGS — USER DETAILS
      // ======================================================

      GoRoute(
        path: '/settings/user-details',
        builder: (context, state) {
          return const AccountDetailsScreen();
        },
      ),

      // ======================================================
      // MAIN NAVIGATION SHELL
      // ======================================================

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
          // ==================================================
          // CHAT
          // ==================================================

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) {
                  return ChangeNotifierProvider<
                      ChatController>(
                    create: (_) =>
                    ChatController()..initialize(),
                    child: const ChatHomeScreen(),
                  );
                },
              ),
            ],
          ),

          // ==================================================
          // MINER
          // ==================================================

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

          // ==================================================
          // WALLET
          // ==================================================

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

          // ==================================================
          // P2P
          // ==================================================

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

          // ==================================================
          // SETTINGS
          // ==================================================

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

// ============================================================
// INVALID ROUTE
// ============================================================

class _InvalidRoute extends StatelessWidget {
  final String message;

  const _InvalidRoute({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}