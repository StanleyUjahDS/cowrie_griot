import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/splash/splash_screen.dart';
import '../../features/splash/welcome_page_1.dart';
import '../../features/splash/welcome_page_2.dart';
import '../../features/splash/welcome_page_3.dart';
import '../../features/splash/welcome_page_4.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/create_account.dart';
import '../../features/auth/screens/confirm_phrase.dart';
import '../../features/auth/screens/display_phrase.dart';
import '../../features/auth/screens/recover_account.dart';

import '../../features/local_auth/screens/create_password_screen.dart';
import '../../features/local_auth/screens/confirm_password_screen.dart';
import '../../features/local_auth/screens/enable_biometrics_screen.dart';
import '../../features/local_auth/screens/pin_verification_screen.dart';

import '../../features/chat/screens/chat_home_screen.dart';
import '../../features/chat/screens/chatting_screen.dart';
import '../../features/chat/screens/user_discovery_screen.dart';
import '../../features/chat/screens/message_requests_screen.dart';
import '../../features/chat/screens/activity_screen.dart';
import '../../features/chat/screens/friends_list_screen.dart';
import '../../features/chat/screens/user_profile_screen.dart';
import '../../features/users/models/user_model.dart' as users;

import '../../features/settings/screens/setting_screen.dart';
import '../../features/settings/screens/appearance/theme_settings_screen.dart';
import '../../features/settings/screens/appearance/accent_color_screen.dart';
import '../../features/settings/screens/account/account_details_screen.dart';
import '../../features/settings/screens/account/griot_plus_screen.dart';
import '../../features/settings/screens/security/app_security_screen.dart';
import '../../features/settings/screens/wallet_security/backup_wallet_screen.dart';

import '../../features/wallet/screens/wallet_screen.dart';
import '../../features/wallet/screens/asset_search_screen.dart';
import '../../features/wallet/screens/scanner_screen.dart';
import '../../features/wallet/screens/asset_details_screen.dart';
import '../../features/wallet/screens/nft_details_screen.dart';
import '../../features/wallet/screens/send_screen.dart';
import '../../features/wallet/screens/receive_screen.dart';
import '../../features/wallet/screens/swap_screen.dart';
import '../../features/wallet/screens/flash_exchange_screen.dart';
import '../../features/wallet/screens/dapp_browser_screen.dart';
import '../../features/wallet/services/wallet_crypto_service.dart';
import '../../features/wallet/models/token_model.dart';
import '../../features/wallet/models/nft_model.dart';

import '../../features/miner/screens/miner_screen.dart';
import '../../features/miner/screens/mining_rules_screen.dart';
import '../../features/miner/screens/reputation_screen.dart';
import '../../features/miner/screens/referral_screen.dart';

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
        path: '/conversation/:conversationId',
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId'];
          if (conversationId == null || conversationId.isEmpty) {
            return const _InvalidRoute(message: 'Invalid conversation.');
          }
          return ChatScreen(conversationId: conversationId);
        },
      ),
      
      // Moving /chat/:userId here would still conflict. 
      // Let's use /messages/user/:userId to be safe and clean.
      GoRoute(
        path: '/chat/user/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId'];
          if (userId == null || userId.isEmpty) {
            return const _InvalidRoute(message: 'Invalid chat user.');
          }
          return ChatScreen(userId: userId);
        },
      ),

      GoRoute(
        path: '/chat/friends',
        builder: (context, state) => const FriendsListScreen(),
      ),

      GoRoute(
        path: '/chat/requests',
        builder: (context, state) => const MessageRequestsScreen(),
      ),

      GoRoute(
        path: '/chat/discover',
        builder: (context, state) => const UserDiscoveryScreen(),
      ),

      GoRoute(
        path: '/user/profile',
        builder: (context, state) {
          final user = state.extra as users.UserModel?;
          if (user == null) {
            return const _InvalidRoute(message: 'User data missing.');
          }
          return UserProfileScreen(user: user);
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
          final extra = state.extra;
          return SetPassword(
            onSuccess: extra is Future<void> Function(BuildContext) ? extra : null,
          );
        },
      ),

      GoRoute(
        path: '/confirm_password',
        builder: (context, state) {
          final extra = state.extra;

          if (extra is String) {
            return VerifyPassword(
              input: extra,
            );
          }

          if (extra is Map<String, dynamic>) {
            return VerifyPassword(
              input: extra['pin'] as String,
              onSuccess: extra['onSuccess'] as Future<void> Function(BuildContext)?,
            );
          }

          return const _InvalidRoute(
            message: 'Invalid password configuration.',
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
      // PIN VERIFICATION
      // ======================================================

      GoRoute(
        path: '/verify_pin',
        builder: (context, state) {
          final extra = state.extra;
          return PinVerificationScreen(
            onSuccess: extra is Future<void> Function(BuildContext) ? extra : null,
          );
        },
      ),

      // ======================================================
      // WALLET SCAN
      // ======================================================

      GoRoute(
        path: '/wallet/scan',
        builder: (context, state) {
          return const ScannerScreen();
        },
      ),

      // ======================================================
      // WALLET SEARCH
      // ======================================================

      GoRoute(
        path: '/wallet/search',
        builder: (context, state) {
          final extra = state.extra;
          final isSelectMode = state.uri.queryParameters['mode'] == 'select';
          return AssetSearchScreen(
            initialQuery: extra is String ? extra : null,
            isSelectMode: isSelectMode,
          );
        },
      ),

      // ======================================================
      // ASSET DETAILS
      // ======================================================

      GoRoute(
        path: '/wallet/asset',
        builder: (context, state) {
          final extra = state.extra;

          if (extra is! TokenModel) {
            return const _InvalidRoute(
              message: 'Asset data was not provided.',
            );
          }

          return AssetDetailsScreen(
            token: extra,
          );
        },
      ),

      // ======================================================
      // NFT DETAILS
      // ======================================================

      GoRoute(
        path: '/wallet/nft',
        builder: (context, state) {
          final extra = state.extra;

          if (extra is! NftModel) {
            return const _InvalidRoute(
              message: 'NFT data was not provided.',
            );
          }

          return NftDetailsScreen(
            nft: extra,
          );
        },
      ),

      // ======================================================
      // WALLET ACTIONS
      // ======================================================

      GoRoute(
        path: '/wallet/send',
        builder: (context, state) {
          final extra = state.extra;
          return SendScreen(
            initialToken: extra is TokenModel ? extra : null,
            initialAddress: extra is String ? extra : null,
          );
        },
      ),

      GoRoute(
        path: '/wallet/receive',
        builder: (context, state) {
          final extra = state.extra;
          return ReceiveScreen(
            token: extra is TokenModel ? extra : null,
          );
        },
      ),

      GoRoute(
        path: '/wallet/swap',
        builder: (context, state) {
          final extra = state.extra;
          return SwapScreen(
            initialFromToken: extra is TokenModel ? extra : null,
          );
        },
      ),

      GoRoute(
        path: '/wallet/flash',
        builder: (context, state) => const FlashExchangeScreen(),
      ),

      GoRoute(
        path: '/wallet/browser',
        builder: (context, state) {
          final url = state.extra as String?;
          return DAppBrowserScreen(initialUrl: url ?? 'https://app.uniswap.org');
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
      // SETTINGS — SECURITY
      // ======================================================

      GoRoute(
        path: '/settings/app-security',
        builder: (context, state) {
          return const AppSecurityScreen();
        },
      ),

      GoRoute(
        path: '/settings/backup-wallet',
        builder: (context, state) {
          return const BackupWalletScreen();
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

      GoRoute(
        path: '/settings/griot-plus',
        builder: (context, state) {
          return const GriotPlusScreen();
        },
      ),

      GoRoute(
        path: '/settings/reputation',
        builder: (context, state) {
          return const ReputationScreen();
        },
      ),

      GoRoute(
        path: '/settings/referrals',
        builder: (context, state) {
          return const ReferralScreen();
        },
      ),

      GoRoute(
        path: '/miner/rules',
        builder: (context, state) => const MiningRulesScreen(),
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
            useSafeArea: false,
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
                builder: (context, state) => const ChatHomeScreen(),
              ),
            ],
          ),

          // ==================================================
          // ACTIVITY
          // ==================================================

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/activity',
                builder: (context, state) => const ActivityScreen(),
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