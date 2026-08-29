import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/startup/app_startup_service.dart';

import 'features/auth/services/auth_api_service.dart';
import 'features/auth/services/auth_session_service.dart';
import 'features/auth/services/auth_storage_service.dart';
import 'features/auth/services/wallet_auth_service.dart';
import 'features/auth/auth_controller.dart';
import 'features/users/providers/user_provider.dart';
import 'features/users/services/user_api_service.dart';
import 'features/wallet/services/wallet_crypto_service.dart';
import 'features/wallet/services/wallet_service.dart';
import 'features/wallet/services/wallet_storage_service.dart';

import 'features/wallet/services/wallet_api_service.dart';
import 'features/wallet/services/transaction_api_service.dart';
import 'features/wallet/services/swap_api_service.dart';
import 'features/wallet/services/wallet_rpc_service.dart';
import 'features/miner/services/mining_api_service.dart';
import 'features/miner/services/referral_api_service.dart';
import 'features/miner/services/reputation_api_service.dart';
import 'features/chat/services/messaging_api_service.dart';
import 'features/chat/services/message_cache_service.dart';
import 'features/chat/services/message_sync_service.dart';
import 'features/miner/providers/reputation_provider.dart';
import 'features/chat/providers/messaging_provider.dart';
import 'features/miner/providers/mining_provider.dart';
import 'features/miner/providers/referral_provider.dart';
import 'features/wallet/providers/wallet_provider.dart';
import 'features/iap/providers/iap_provider.dart';
import 'features/local_auth/services/app_lock_service.dart';
import 'features/local_auth/services/local_auth_service.dart';
import 'features/local_auth/providers/app_lock_provider.dart';
import 'features/local_auth/screens/pin_verification_screen.dart';
import 'core/services/navigation_scroll_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/push_notification_service.dart';

class GriotCowrieApp extends StatefulWidget {
  const GriotCowrieApp({super.key});

  @override
  State<GriotCowrieApp> createState() => _GriotCowrieAppState();
}

class _GriotCowrieAppState extends State<GriotCowrieApp> {
  final ThemeController _themeController = ThemeController.instance;

  late final ApiClient _apiClient;
  late final UserApiService _userApiService;
  late final WalletService _walletService;
  late final AuthApiService _authApiService;
  late final AuthSessionService _authSessionService;
  late final WalletApiService _walletApiService;
  late final TransactionApiService _transactionApiService;
  late final SwapApiService _swapApiService;
  late final WalletRpcService _walletRpcService;
  late final MiningApiService _miningApiService;
  late final ReferralApiService _referralApiService;
  late final ReputationApiService _reputationApiService;
  late final MessagingApiService _messagingApiService;
  late final MessageCacheService _messageCacheService;
  late final MessageSyncService _messageSyncService;
  late final AuthController _authController;
  late final AppLockService _appLockService;
  late final LocalAuthService _localAuthService;

  @override
  void initState() {
    super.initState();

    // ----------------------------------------------------------
    // CORE INFRASTRUCTURE
    // ----------------------------------------------------------

    _apiClient = ApiClient();

    PushNotificationService.instance.configure(
      apiClient: _apiClient,
      onNotificationTap: (data) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final type = data['type']?.toString();
          if (type == 'chat_message') {
            final conversationId = data['conversationId']?.toString();
            if (conversationId != null && conversationId.isNotEmpty) {
              AppRouter.router.push('/conversation/$conversationId');
            }
          } else if (type == 'message_request') {
            AppRouter.router.push('/chat/requests');
          }
        });
      },
    );

    final walletStorage = WalletStorageService();
    final authStorage = AuthStorageService();

    _walletService = WalletService(
      cryptoService: WalletCryptoService(),
      storageService: walletStorage,
    );

    _appLockService = AppLockService();
    _localAuthService = LocalAuthService();

    _userApiService = UserApiService(apiClient: _apiClient);

    _walletApiService = WalletApiService(apiClient: _apiClient);

    _transactionApiService = TransactionApiService(apiClient: _apiClient);

    _swapApiService = SwapApiService(apiClient: _apiClient);

    _walletRpcService = WalletRpcService(apiClient: _apiClient);

    _miningApiService = MiningApiService(apiClient: _apiClient);

    _referralApiService = ReferralApiService(apiClient: _apiClient);

    _reputationApiService = ReputationApiService(apiClient: _apiClient);

    _messagingApiService = MessagingApiService(apiClient: _apiClient);

    _messageCacheService = MessageCacheService();
    _messageSyncService = MessageSyncService(
      cache: _messageCacheService,
      api: _messagingApiService,
    );

    _authApiService = AuthApiService(
      apiClient: _apiClient,
      authStorageService: authStorage,
    );

    final walletAuthService = WalletAuthService(
      walletService: _walletService,
      authApiService: _authApiService,
    );

    _authSessionService = AuthSessionService(
      walletService: _walletService,
      authApiService: _authApiService,
      authStorageService: authStorage,
      walletAuthService: walletAuthService,
    );

    _authController = AuthController(
      authService: _authApiService,
      walletService: _walletService,
    );

    _messageCacheService.initialize();
    _messageSyncService.initialize();

    ConnectivityService.instance.initialize();

    // ==========================================================
    // THEME CONTROLLER
    // ==========================================================

    AppRouter.setThemeController(_themeController);
  }

  @override
  void dispose() {
    _apiClient.dispose();
    _walletRpcService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ======================================================
        // DATA SERVICES
        // ======================================================

        Provider<WalletService>.value(value: _walletService),
        Provider<UserApiService>.value(value: _userApiService),
        Provider<AuthSessionService>.value(value: _authSessionService),
        Provider<WalletApiService>.value(value: _walletApiService),
        Provider<TransactionApiService>.value(value: _transactionApiService),
        Provider<SwapApiService>.value(value: _swapApiService),
        Provider<WalletRpcService>.value(value: _walletRpcService),
        Provider<MiningApiService>.value(value: _miningApiService),
        Provider<ReferralApiService>.value(value: _referralApiService),
        Provider<ReputationApiService>.value(value: _reputationApiService),
        Provider<MessagingApiService>.value(value: _messagingApiService),
        Provider<MessageCacheService>.value(value: _messageCacheService),
        Provider<MessageSyncService>.value(value: _messageSyncService),
        Provider<AppLockService>.value(value: _appLockService),
        Provider<LocalAuthService>.value(value: _localAuthService),
        ChangeNotifierProvider<AuthController>.value(value: _authController),
        ChangeNotifierProvider<NavigationScrollService>.value(
          value: NavigationScrollService.instance,
        ),

        // ======================================================
        // APP LOCK PROVIDER
        // ======================================================
        ChangeNotifierProvider<AppLockProvider>(
          create: (_) => AppLockProvider(appLockService: _appLockService),
        ),

        // ======================================================
        // USER PROVIDER
        // ======================================================
        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider(userApiService: _userApiService),
        ),

        // ======================================================
        // WALLET PROVIDER
        // ======================================================
        ChangeNotifierProvider<WalletProvider>(
          create: (_) => WalletProvider(
            walletService: _walletService,
            walletApiService: _walletApiService,
          ),
        ),

        // ======================================================
        // REPUTATION PROVIDER
        // ======================================================
        ChangeNotifierProxyProvider<UserProvider, ReputationProvider>(
          create: (_) => ReputationProvider(apiService: _reputationApiService),
          update: (_, userProvider, reputation) =>
              (reputation ??
                    ReputationProvider(apiService: _reputationApiService))
                ..updateUserProvider(userProvider),
        ),

        // ======================================================
        // MESSAGING PROVIDER
        // ======================================================
        ChangeNotifierProxyProvider<UserProvider, MessagingProvider>(
          create: (context) => MessagingProvider(
            apiService: _messagingApiService,
            userProvider: context.read<UserProvider>(),
            messageCache: _messageCacheService,
            messageSync: _messageSyncService,
          ),
          update: (_, userProvider, messaging) {
            final provider = messaging ??
                MessagingProvider(
                  apiService: _messagingApiService,
                  userProvider: userProvider,
                  messageCache: _messageCacheService,
                  messageSync: _messageSyncService,
                );
            _authController.setMessagingProvider(provider);
            return provider;
          },
        ),

        // ======================================================
        // REFERRAL PROVIDER
        // ======================================================
        ChangeNotifierProvider<ReferralProvider>(
          create: (_) => ReferralProvider(apiService: _referralApiService),
        ),

        // ======================================================
        // MINING PROVIDER
        // ======================================================
        ChangeNotifierProvider<MiningProvider>(
          create: (_) => MiningProvider(apiService: _miningApiService),
        ),

        // ======================================================
        // IAP PROVIDER
        // ======================================================
        ChangeNotifierProvider<IapProvider>(
          create: (_) => IapProvider(),
        ),

        // ======================================================
        // STARTUP SERVICE
        // ======================================================
        ProxyProvider4<
          AuthSessionService,
          AuthController,
          UserProvider,
          MessagingProvider,
          AppStartupService
        >(
          update: (_, auth, controller, user, messaging, previous) => AppStartupService(
            authSessionService: auth,
            authController: controller,
            userProvider: user,
            messagingProvider: messaging,
          ),
        ),
      ],

      // ========================================================
      // APP
      // ========================================================
      child: AnimatedBuilder(
        animation: _themeController,
        builder: (context, child) {
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

            // ==================================================
            // APP LOCK BUILDER
            // ==================================================
            builder: (context, child) {
              return _AppLockOverlay(child: child);
            },
          );
        },
      ),
    );
  }
}

class _AppLockOverlay extends StatefulWidget {
  final Widget? child;
  const _AppLockOverlay({this.child});

  @override
  State<_AppLockOverlay> createState() => _AppLockOverlayState();
}

class _AppLockOverlayState extends State<_AppLockOverlay> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppLockProvider>(
      builder: (context, lockProvider, _) {
        if (!lockProvider.isLocked) {
          return widget.child ?? const SizedBox.shrink();
        }

        return Stack(
          children: [
            if (widget.child != null) widget.child!,
            Positioned.fill(
              child: PinVerificationScreen(
                showAppBar: false,
                autoBiometrics: true,
                title: 'App Locked',
                description: 'Please enter your PIN to continue.',
                onSuccess: (BuildContext ctx) async {
                  final authController = ctx.read<AuthController>();
                  if (!authController.hasValidSession) {
                    await authController.authenticateWallet();
                  }
                  lockProvider.unlock();
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
