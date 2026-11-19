import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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

import '../ui/screens/document_viewer_screen.dart';
import '../../features/chat/screens/dm_chat_screen.dart';
import '../../features/chat/screens/group_chat_screen.dart';
import '../../features/chat/screens/chat_home_screen.dart';
import '../../features/chat/screens/channels/channel_feed_screen.dart';
import '../../features/chat/screens/user_discovery_screen.dart';
import '../../features/chat/screens/groups/create_group_screen.dart';
import '../../features/chat/screens/groups/group_details_screen.dart';
import '../../features/chat/screens/channels/create_channel_screen.dart';
import '../../features/chat/screens/channels/channel_details_screen.dart';
import '../../features/chat/screens/community_overview_screen.dart';
import '../../features/chat/screens/message_requests_screen.dart';
import '../../features/chat/screens/notifications_screen.dart';
import '../../features/chat/screens/spaces_status_screen.dart';
import '../../features/chat/screens/create_tale_screen.dart';
import '../../features/chat/screens/camp_profile_screen.dart';
import '../../features/chat/screens/camp_profile_connections_screen.dart';
import '../../features/chat/screens/create_campfire_screen.dart';
import '../../features/chat/screens/call_entry_screen.dart';
import '../../features/chat/services/active_call_controller.dart';
import '../../features/chat/screens/incoming_call_screen.dart';
import '../../features/chat/screens/join_call_screen.dart';
import '../../features/chat/screens/create_call_link_screen.dart';
import '../../features/chat/services/realtime_call_service.dart';
import '../../features/chat/screens/friends_list_screen.dart';
import '../../features/chat/screens/shared_content_screen.dart';
import '../../features/chat/screens/stories_screen.dart';
import '../../features/chat/screens/tale_public_screen.dart';
import '../../features/chat/screens/tale_drafts_screen.dart';
import '../../features/chat/screens/tale_bookmarks_screen.dart';
import '../../features/chat/screens/game_center_screen.dart';
import '../../features/chat/models/shared_content.dart';
import '../../features/chat/screens/user_profile_screen.dart';
import '../../features/chat/models/conversation_model.dart';
import '../../features/chat/models/chat_user.dart';
import '../../features/users/models/user_model.dart' as users;

import '../../features/settings/screens/setting_screen.dart';
import '../../features/settings/screens/appearance/theme_settings_screen.dart';
import '../../features/settings/screens/appearance/accent_color_screen.dart';
import '../../features/settings/screens/account/account_details_screen.dart';
import '../../features/settings/screens/account/griot_plus_screen.dart';
import '../../features/golds/screens/griot_golds_screen.dart';
import '../../features/settings/screens/account/delete_account_screen.dart';
import '../../features/settings/screens/preferences_settings_screen.dart';
import '../../features/settings/screens/general/about_griot_screen.dart';
import '../../features/settings/screens/general/community_guidelines_screen.dart';
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
import '../../features/wallet/screens/buy_coming_soon_screen.dart';
import '../../features/wallet/screens/dapp_browser_screen.dart';
import '../../features/wallet/screens/display_currency_screen.dart';
import '../../features/wallet/services/wallet_crypto_service.dart';
import '../../features/wallet/models/token_model.dart';
import '../../features/wallet/models/nft_model.dart';

import '../../features/miner/screens/miner_screen.dart';
import '../../features/miner/screens/mining_rules_screen.dart';
import '../../features/miner/screens/reputation_screen.dart';
import '../../features/miner/screens/referral_screen.dart';

import '../ui/scaffolds/gradient_scaffold.dart';
import '../ui/screens/app_loading_screen.dart';
import '../ui/screens/public_deep_link_recovery_screen.dart';

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

  static void setThemeController(ThemeController controller) {
    themeController = controller;
  }

  /// Shared route motion for chat and deep-link destinations. A full-width
  /// horizontal slide makes the outgoing page remain visually present while
  /// the destination paints, instead of looking like a delayed rebuild.
  static Widget _conversationTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return CupertinoPageTransition(
      primaryRouteAnimation: animation,
      secondaryRouteAnimation: secondaryAnimation,
      linearTransition: false,
      child: child,
    );
  }

  // ==========================================================
  // ROUTER
  // ==========================================================

  static final GoRouter router = GoRouter(
    initialLocation: '/',

    // A public URL can be delivered to Flutter's router before app_links has
    // emitted it, especially on a cold start or Flutter web. Recover known
    // public destinations instead of showing GoRouter's red error screen.
    errorBuilder: (context, state) {
      if (PublicDeepLinkRecoveryScreen.supports(state.uri)) {
        return PublicDeepLinkRecoveryScreen(uri: state.uri);
      }
      return _InvalidRoute(message: 'Page not found.');
    },

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

      // Full-screen status route. It intentionally sits outside the indexed
      // navigation shell so the bottom navbar cannot cover its actions.
      GoRoute(
        path: '/stories',
        builder: (context, state) => const StoriesScreen(),
      ),
      GoRoute(
        path: '/tale/:taleId',
        builder: (context, state) => TalePublicScreen(
          taleId: state.pathParameters['taleId']!,
          initialTale: state.extra is Map
              ? Map<String, dynamic>.from(state.extra as Map)
              : null,
        ),
      ),
      // Social share aliases (tweet/post) resolve to the same canonical Tale
      // reader. Keeping these routes registered prevents a cold-start red
      // screen before app_links hands the URL to DeepLinkService.
      GoRoute(
        path: '/tweet/:taleId',
        builder: (context, state) =>
            TalePublicScreen(taleId: state.pathParameters['taleId']!),
      ),
      GoRoute(
        path: '/post/:taleId',
        builder: (context, state) =>
            TalePublicScreen(taleId: state.pathParameters['taleId']!),
      ),
      GoRoute(
        path: '/campfires/:destinationId',
        builder: (context, state) =>
            PublicDeepLinkRecoveryScreen(uri: state.uri),
      ),
      GoRoute(
        path: '/campfire/:destinationId',
        builder: (context, state) =>
            PublicDeepLinkRecoveryScreen(uri: state.uri),
      ),
      GoRoute(
        path: '/spaces/:destinationId',
        builder: (context, state) =>
            PublicDeepLinkRecoveryScreen(uri: state.uri),
      ),
      GoRoute(
        path: '/campfires/tale/:destinationId',
        builder: (context, state) =>
            PublicDeepLinkRecoveryScreen(uri: state.uri),
      ),
      GoRoute(
        path: '/campfires/tales/:destinationId',
        builder: (context, state) =>
            PublicDeepLinkRecoveryScreen(uri: state.uri),
      ),
      GoRoute(
        path: '/camp/tales/:destinationId',
        builder: (context, state) =>
            PublicDeepLinkRecoveryScreen(uri: state.uri),
      ),

      // Public links may reach GoRouter before app_links emits the platform
      // link. Register their shapes explicitly so a cold start never falls
      // through to GoRouter's red "no routes" screen.
      GoRoute(
        path: '/join',
        builder: (context, state) => PublicDeepLinkRecoveryScreen(
          uri: Uri(path: '/join', queryParameters: state.uri.queryParameters),
        ),
      ),
      GoRoute(
        path: '/plus',
        builder: (context, state) =>
            PublicDeepLinkRecoveryScreen(uri: Uri(path: '/plus')),
      ),
      GoRoute(
        path: '/profile/:identifier',
        builder: (context, state) => PublicDeepLinkRecoveryScreen(
          uri: Uri(path: '/profile/${state.pathParameters['identifier']}'),
        ),
      ),
      GoRoute(
        path: '/camp/profile',
        builder: (context, state) => const CampProfileScreen(),
      ),
      GoRoute(
        path: '/camp/tales/drafts',
        builder: (context, state) => const TaleDraftsScreen(),
      ),
      GoRoute(
        path: '/camp/tales/bookmarks',
        builder: (context, state) => const TaleBookmarksScreen(),
      ),
      GoRoute(
        path: '/camp/profile/:identifier',
        builder: (context, state) => CampProfileScreen(
          profileIdentifier: state.pathParameters['identifier'],
          profileUser: state.extra is users.UserModel
              ? state.extra as users.UserModel
              : null,
          isPublic: true,
        ),
      ),
      GoRoute(
        path: '/camp/profile/:identifier/followers',
        builder: (context, state) => CampProfileConnectionsScreen(
          profileIdentifier: state.pathParameters['identifier']!,
          connectionType: CampConnectionType.followers,
        ),
      ),
      GoRoute(
        path: '/camp/profile/:identifier/following',
        builder: (context, state) => CampProfileConnectionsScreen(
          profileIdentifier: state.pathParameters['identifier']!,
          connectionType: CampConnectionType.following,
        ),
      ),
      GoRoute(
        path: '/group/:username',
        builder: (context, state) => PublicDeepLinkRecoveryScreen(
          uri: Uri(path: '/group/${state.pathParameters['username']}'),
        ),
      ),
      GoRoute(
        path: '/circle/:username',
        builder: (context, state) => PublicDeepLinkRecoveryScreen(
          uri: Uri(path: '/circle/${state.pathParameters['username']}'),
        ),
      ),
      GoRoute(
        path: '/channel/:username',
        builder: (context, state) => PublicDeepLinkRecoveryScreen(
          uri: Uri(path: '/channel/${state.pathParameters['username']}'),
        ),
      ),

      // ======================================================
      // FULL SCREEN CHAT
      // ======================================================
      GoRoute(
        path: '/conversation/:conversationId',
        pageBuilder: (context, state) {
          final conversationId = state.pathParameters['conversationId'];
          if (conversationId == null || conversationId.isEmpty) {
            return CustomTransitionPage<void>(
              key: state.pageKey,
              child: const _InvalidRoute(message: 'Invalid conversation.'),
              transitionsBuilder: _conversationTransition,
            );
          }

          final extra = state.extra;
          final extraMap = extra is Map ? extra : null;
          final conversationExtra = extraMap?['conversation'] is Conversation
              ? extraMap!['conversation'] as Conversation
              : extra is Conversation
              ? extra
              : null;
          final messageId = extraMap?['messageId']?.toString();
          Widget destination;
          if (conversationExtra != null) {
            if (conversationExtra.type == ConversationType.channel) {
              destination = ChannelFeedScreen(conversation: conversationExtra);
            } else if (conversationExtra.type == ConversationType.group) {
              destination = GroupChatScreen(
                conversationId: conversationId,
                initialConversation: conversationExtra,
                initialMessageId: messageId,
              );
            } else {
              destination = DMChatScreen(
                conversationId: conversationId,
                initialConversation: conversationExtra,
                initialMessageId: messageId,
              );
            }
          } else {
            // The screen can still hydrate from the provider when a deep link
            // has no Conversation object attached.
            destination = DMChatScreen(conversationId: conversationId);
          }

          return CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: const Duration(milliseconds: 220),
            reverseTransitionDuration: const Duration(milliseconds: 180),
            child: destination,
            transitionsBuilder: _conversationTransition,
          );
        },
      ),

      GoRoute(
        path: '/games',
        builder: (context, state) => const GameCenterScreen(),
      ),
      GoRoute(
        path: '/viewer',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! Map<String, dynamic>) {
            return const _InvalidRoute(message: 'Document data missing.');
          }
          return DocumentViewerScreen(
            url: extra['url'] as String,
            title: extra['title'] as String,
          );
        },
      ),

      // Moving /chat/:userId here would still conflict.
      // Let's use /messages/user/:userId to be safe and clean.
      GoRoute(
        path: '/chat/user/:userId',
        pageBuilder: (context, state) {
          final userId = state.pathParameters['userId'];
          if (userId == null || userId.isEmpty) {
            return CustomTransitionPage<void>(
              key: state.pageKey,
              child: const _InvalidRoute(message: 'Invalid chat user.'),
              transitionsBuilder: _conversationTransition,
            );
          }
          final routeExtra = state.extra is Map
              ? Map<String, dynamic>.from(state.extra as Map)
              : null;
          return CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: const Duration(milliseconds: 220),
            reverseTransitionDuration: const Duration(milliseconds: 180),
            child: DMChatScreen(
              userId: userId,
              initialUser: state.extra is ChatUser
                  ? state.extra as ChatUser
                  : routeExtra?['initialUser'] is ChatUser
                  ? routeExtra!['initialUser'] as ChatUser
                  : null,
              initialStoryReply: routeExtra?['initialStoryReply'] is Map
                  ? Map<String, dynamic>.from(
                      routeExtra!['initialStoryReply'] as Map,
                    )
                  : null,
            ),
            transitionsBuilder: _conversationTransition,
          );
        },
      ),

      GoRoute(
        path: '/chat/friends',
        builder: (context, state) => const FriendsListScreen(),
      ),

      GoRoute(
        path: '/shared-content',
        builder: (context, state) {
          final content = state.extra;
          if (content is! SharedContent) {
            return const _InvalidRoute(message: 'Shared content missing.');
          }
          return SharedContentScreen(content: content);
        },
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
        path: '/chat/groups/create',
        builder: (context, state) => const CreateGroupScreen(),
      ),

      GoRoute(
        path: '/chat/groups/:conversationId/details',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! Conversation) {
            return const _InvalidRoute(message: 'Conversation data missing.');
          }
          return GroupDetailsScreen(conversation: extra);
        },
      ),

      GoRoute(
        path: '/chat/community/:conversationId',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! Conversation) {
            return const _InvalidRoute(message: 'Community data missing.');
          }
          return CommunityOverviewScreen(conversation: extra);
        },
      ),

      GoRoute(
        path: '/chat/channels/create',
        builder: (context, state) => const CreateChannelScreen(),
      ),

      GoRoute(
        path: '/chat/channels/:conversationId/details',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! Conversation) {
            return const _InvalidRoute(message: 'Conversation data missing.');
          }
          return ChannelDetailsScreen(conversation: extra);
        },
      ),

      GoRoute(
        path: '/user/profile',
        builder: (context, state) {
          final extra = state.extra;
          // Conversation lists carry ChatUser instances, while discovery and
          // profile flows may carry UserModel instances. Long-pressing a DM
          // must support both representations instead of throwing a runtime
          // type-cast error.
          final user = extra is users.UserModel
              ? extra
              : extra is ChatUser
              ? extra.toUserModel()
              : null;
          if (user == null) {
            return const _InvalidRoute(message: 'User data missing.');
          }
          return UserProfileScreen(user: user);
        },
      ),

      // ======================================================
      // ONBOARDING & AUTH SHELL
      // ======================================================
      ShellRoute(
        builder: (context, state, child) {
          return GradientScaffold(useSafeArea: false, child: child);
        },
        routes: [
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
            path: '/login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: '/create_account',
            builder: (context, state) => const CreateAccountScreen(),
          ),
          GoRoute(
            path: '/recover_account',
            builder: (context, state) => const RecoverAccountScreen(),
          ),
          GoRoute(
            path: '/display_phrase',
            builder: (context, state) {
              final extra = state.extra;
              if (extra is! WalletData) {
                return const _InvalidRoute(message: 'Wallet data missing.');
              }
              return DisplayPhraseScreen(wallet: extra);
            },
          ),
          GoRoute(
            path: '/loading',
            builder: (context, state) {
              final extra = state.extra;
              if (extra is! AppLoadingRouteData) {
                return const _InvalidRoute(
                  message: 'Invalid loading screen configuration.',
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
          GoRoute(
            path: '/verify_phrase',
            builder: (context, state) => const VerifySeed(),
          ),
          GoRoute(
            path: '/set_password',
            builder: (context, state) {
              final extra = state.extra;
              return SetPassword(
                onSuccess: extra is Future<void> Function(BuildContext)
                    ? extra
                    : extra is Map<String, dynamic>
                    ? extra['onSuccess'] as Future<void> Function(BuildContext)?
                    : null,
                setupBiometrics: extra is Map<String, dynamic>
                    ? extra['setupBiometrics'] == true
                    : false,
              );
            },
          ),
          GoRoute(
            path: '/confirm_password',
            builder: (context, state) {
              final extra = state.extra;
              if (extra is String) {
                return VerifyPassword(input: extra);
              }
              if (extra is Map<String, dynamic>) {
                return VerifyPassword(
                  input: extra['pin'] as String,
                  onSuccess:
                      extra['onSuccess']
                          as Future<void> Function(BuildContext)?,
                  setupBiometrics: extra['setupBiometrics'] == true,
                );
              }
              return const _InvalidRoute(message: 'Invalid configuration.');
            },
          ),
        ],
      ),

      // ======================================================
      // BIOMETRICS
      // ======================================================
      GoRoute(
        path: '/enable_biometrics',
        builder: (context, state) {
          final extra = state.extra;
          return BiometricsScreen(
            onSuccess: extra is Future<void> Function(BuildContext)
                ? extra
                : null,
          );
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
            onSuccess: extra is Future<void> Function(BuildContext)
                ? extra
                : null,
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
            return const _InvalidRoute(message: 'Asset data was not provided.');
          }

          return AssetDetailsScreen(token: extra);
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
            return const _InvalidRoute(message: 'NFT data was not provided.');
          }

          return NftDetailsScreen(nft: extra);
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
          return ReceiveScreen(token: extra is TokenModel ? extra : null);
        },
      ),

      GoRoute(
        path: '/wallet/swap',
        builder: (context, state) {
          final extra = state.extra;

          if (extra is Map<String, dynamic>) {
            return SwapScreen(
              initialFromToken: extra['from'] as TokenModel?,
              initialToToken: extra['to'] as TokenModel?,
            );
          }

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
        path: '/wallet/buy',
        builder: (context, state) => const BuyComingSoonScreen(),
      ),

      GoRoute(
        path: '/wallet/browser',
        builder: (context, state) {
          final url = state.extra as String?;
          return DAppBrowserScreen(
            initialUrl: url ?? 'https://app.uniswap.org',
          );
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
        path: '/settings/chat-settings',
        builder: (_, _) => const ChatSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/currency',
        builder: (_, _) => const DisplayCurrencyScreen(),
      ),
      GoRoute(
        path: '/settings/chat-privacy',
        builder: (_, _) => const ChatPrivacyScreen(),
      ),
      GoRoute(
        path: '/settings/privacy',
        builder: (_, _) => const PrivacySettingsScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (_, _) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/notifications/:category',
        builder: (_, state) {
          final category = NotificationSettingsScreen.categoryFor(
            state.pathParameters['category'] ?? '',
          );
          return category == null
              ? const NotificationSettingsScreen()
              : NotificationCategorySettingsScreen(category: category);
        },
      ),
      GoRoute(
        path: '/settings/about',
        builder: (_, _) => const AboutGriotScreen(),
      ),
      GoRoute(
        path: '/settings/community-guidelines',
        builder: (_, _) => const CommunityGuidelinesScreen(),
      ),

      GoRoute(
        path: '/settings/delete-account',
        builder: (_, _) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: '/settings/griot-plus',
        builder: (context, state) {
          return const GriotPlusScreen();
        },
      ),
      GoRoute(
        path: '/settings/griot-golds',
        builder: (context, state) => const GriotGoldsScreen(),
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
          return ReferralScreen(initialCode: state.uri.queryParameters['ref']);
        },
      ),

      GoRoute(
        path: '/miner/rules',
        builder: (context, state) => const MiningRulesScreen(),
      ),

      // Notifications are opened from the messaging header rather than the
      // primary navigation, but remain a top-level route for deep links and
      // push-notification navigation.
      GoRoute(
        path: '/notifications',
        builder: (context, state) {
          final extra = state.extra;
          final campOnly = extra is Map && extra['campOnly'] == true;
          return NotificationsScreen(campOnly: campOnly);
        },
      ),
      GoRoute(
        path: '/chat/call-link/create',
        builder: (context, state) => const CreateCallLinkScreen(),
      ),
      GoRoute(
        path: '/calls/incoming',
        builder: (context, state) {
          final extra = state.extra is Map
              ? Map<String, dynamic>.from(state.extra as Map)
              : <String, dynamic>{};
          return IncomingCallScreen(
            conversationId: extra['conversationId']?.toString() ?? '',
            conversationType: extra['contextType']?.toString() ?? 'direct',
            mode: extra['mode']?.toString() ?? 'voice',
            callId: extra['callId']?.toString() ?? '',
            roomId: extra['roomId']?.toString(),
            callerName: extra['callerName']?.toString() ?? 'Griot contact',
            callerAvatarUrl: extra['callerAvatarUrl']?.toString(),
            callerWalletAddress: extra['callerWalletAddress']?.toString(),
          );
        },
      ),
      GoRoute(
        path: '/call/join',
        builder: (context, state) => JoinCallScreen(
          invite:
              (state.uri.queryParameters['invite'] ??
                      state.uri.queryParameters['token'] ??
                      state.uri.queryParameters['code'] ??
                      '')
                  .trim(),
        ),
      ),
      GoRoute(
        path: '/calls/:conversationId',
        builder: (context, state) {
          final conversationId = state.pathParameters['conversationId'];
          final extra = state.extra;
          final type = extra is Map<String, dynamic>
              ? extra['type']?.toString() ?? 'direct'
              : 'direct';
          final mode = extra is Map<String, dynamic>
              ? extra['mode']?.toString() ?? 'voice'
              : 'voice';
          final session =
              extra is Map<String, dynamic> &&
                  extra['session'] is RealtimeCallSession
              ? extra['session'] as RealtimeCallSession
              : null;
          final roomId = extra is Map<String, dynamic>
              ? extra['roomId']?.toString()
              : null;
          final callId = extra is Map<String, dynamic>
              ? extra['callId']?.toString()
              : null;
          final title = extra is Map<String, dynamic>
              ? extra['title']?.toString()
              : null;
          final openParticipants =
              extra is Map<String, dynamic> &&
              (extra['openParticipants'] == true ||
                  extra['openParticipants']?.toString() == 'true');
          if (conversationId == null || conversationId.isEmpty) {
            return const _InvalidRoute(message: 'Invalid call conversation.');
          }
          return CallEntryScreen(
            request: CallRequest(
              conversationId: conversationId,
              conversationType: type,
              mode: mode,
              callId: callId,
              session: session,
              roomId: roomId,
              title: title,
              openParticipants: openParticipants,
            ),
          );
        },
      ),

      // Campfire creation is outside the navigation shell so this is a true
      // full-screen form and never renders behind Griot's bottom bar.
      GoRoute(
        path: '/campfires/create',
        builder: (context, state) {
          final extra = state.extra;
          final options = extra is Map
              ? Map<String, dynamic>.from(extra)
              : const <String, dynamic>{};
          return CreateCampfireScreen(
            conversationId: options['conversationId']?.toString(),
            conversationType: options['conversationType']?.toString(),
          );
        },
      ),

      GoRoute(
        path: '/campfires/tales/create',
        builder: (context, state) {
          final extra = state.extra;
          final draftId = extra is Map ? extra['draftId']?.toString() : null;
          return CreateTaleScreen(
            draftId: draftId,
            initialText: extra is Map ? extra['initialText']?.toString() : null,
            initialThreadId: extra is Map
                ? extra['initialThreadId']?.toString()
                : null,
            initialRetellOfTaleId: extra is Map
                ? extra['initialRetellOfTaleId']?.toString()
                : null,
            initialReferenceText: extra is Map
                ? extra['initialReferenceText']?.toString()
                : null,
            initialReferenceLabel: extra is Map
                ? extra['initialReferenceLabel']?.toString()
                : null,
            initialReferenceMediaUrls:
                extra is Map && extra['initialReferenceMediaUrls'] is List
                ? (extra['initialReferenceMediaUrls'] as List)
                      .map((item) => item.toString())
                      .where((item) => item.isNotEmpty)
                      .toList()
                : const [],
            composerTitle: extra is Map
                ? extra['composerTitle']?.toString()
                : null,
          );
        },
      ),

      // ======================================================
      // MAIN NAVIGATION SHELL
      // ======================================================
      StatefulShellRoute(
        builder: (context, state, navigationShell) {
          return GradientScaffold(
            useSafeArea: false,
            // Discovery screens keep their FAB and global GNav anchored while
            // search is active. Child chat screens still resize their own
            // composer scaffolds when they open the keyboard.
            resizeToAvoidBottomInset: false,
            child: MainNavigationShell(navigationShell: navigationShell),
          );
        },
        navigatorContainerBuilder: (context, navigationShell, children) =>
            _AnimatedBranchContainer(
              currentIndex: navigationShell.currentIndex,
              children: children,
            ),
        branches: [
          // ==================================================
          // CHAT
          // ==================================================

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => ChatHomeScreen(
                  initialTab: state.uri.queryParameters['tab'] ?? 'direct',
                ),
              ),
            ],
          ),

          // ==================================================
          // CAMPFIRES & STATUS
          // ==================================================
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/campfires',
                builder: (context, state) => const SpacesStatusScreen(),
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
                  return WalletScreen(
                    initialTab: state.uri.queryParameters['tab'] ?? 'tokens',
                  );
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

  const _InvalidRoute({required this.message});

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

/// Keeps each branch navigator alive while giving main-section changes the
/// short horizontal movement users expect from a mobile social app.
class _AnimatedBranchContainer extends StatelessWidget {
  const _AnimatedBranchContainer({
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var index = 0; index < children.length; index++)
            _branch(index, children[index]),
        ],
      ),
    );
  }

  Widget _branch(int index, Widget child) {
    final active = index == currentIndex;
    final direction = index > currentIndex ? 1.0 : -1.0;
    // Keep inactive navigators mounted for state preservation, but take them
    // completely out of layout and hit testing. An IgnorePointer around a
    // live scrollable can still let Flutter traverse a half-detached
    // RenderViewport during a route transition, which causes the null-check
    // hit-test exception seen when opening the Tale editor.
    return Offstage(
      offstage: !active,
      child: TickerMode(
        enabled: active,
        child: AnimatedSlide(
          offset: active ? Offset.zero : Offset(direction * 0.035, 0),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: active ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: child,
          ),
        ),
      ),
    );
  }
}
