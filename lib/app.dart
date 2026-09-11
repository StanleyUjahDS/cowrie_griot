import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'features/chat/services/media_api_service.dart';
import 'features/chat/services/tip_api_service.dart';
import 'features/chat/services/message_cache_service.dart';
import 'features/chat/services/message_sync_service.dart';
import 'features/miner/providers/reputation_provider.dart';
import 'features/chat/providers/messaging_provider.dart';
import 'features/miner/providers/mining_provider.dart';
import 'features/miner/providers/referral_provider.dart';
import 'features/wallet/providers/wallet_provider.dart';
import 'features/iap/providers/iap_provider.dart';
import 'features/iap/services/plus_api_service.dart';
import 'features/users/providers/user_preference_provider.dart';
import 'features/local_auth/services/app_lock_service.dart';
import 'features/local_auth/services/local_auth_service.dart';
import 'features/local_auth/providers/app_lock_provider.dart';
import 'features/local_auth/screens/pin_verification_screen.dart';
import 'core/services/navigation_scroll_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/deep_link_service.dart';
import 'features/chat/models/shared_content.dart';
import 'features/chat/services/shared_content_service.dart';

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
  late final MediaApiService _mediaApiService;
  late final TipApiService _tipApiService;
  late final PlusApiService _plusApiService;
  late final MessageCacheService _messageCacheService;
  late final MessageSyncService _messageSyncService;
  late final AuthController _authController;
  late final AppLockService _appLockService;
  late final LocalAuthService _localAuthService;
  StreamSubscription<SharedContent>? _sharedContentSubscription;

  @override
  void initState() {
    super.initState();

    // ----------------------------------------------------------
    // CORE INFRASTRUCTURE
    // ----------------------------------------------------------

    final authStorage = AuthStorageService();
    final walletStorage = WalletStorageService();

    _apiClient = ApiClient(authStorageService: authStorage);

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

    _mediaApiService = MediaApiService(apiClient: _apiClient);

    _tipApiService = TipApiService(apiClient: _apiClient);

    _plusApiService = PlusApiService(apiClient: _apiClient);

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

    // Cache initialization is best-effort because storage is unavailable in
    // some test and newly supported platform environments.
    unawaited(_initializeMessageCache());
    _messageSyncService.initialize();

    ConnectivityService.instance.initialize();
    DeepLinkService.instance.initialize();

    // ==========================================================
    // THEME CONTROLLER
    // ==========================================================

    AppRouter.setThemeController(_themeController);
    _initializeSharedContent();
  }

  void _initializeSharedContent() {
    _sharedContentSubscription = SharedContentService.instance.stream.listen(
      _openSharedContent,
      onError: (error) => debugPrint('Share receiver error: $error'),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final content = await SharedContentService.instance.getInitial();
      if (content != null && mounted) _openSharedContent(content);
    });
  }

  void _openSharedContent(SharedContent content) {
    if (!content.isSupported) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppRouter.router.go('/shared-content', extra: content);
      }
    });
  }

  Future<void> _initializeMessageCache() async {
    try {
      await _messageCacheService.initialize();
    } catch (error, stackTrace) {
      debugPrint('Message cache initialization deferred: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    _sharedContentSubscription?.cancel();
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
        Provider<MediaApiService>.value(value: _mediaApiService),
        Provider<TipApiService>.value(value: _tipApiService),
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
          create: (_) => UserProvider(
            userApiService: _userApiService,
            mediaApiService: _mediaApiService,
          ),
        ),

        // ======================================================
        // USER PREFERENCE PROVIDER
        // ======================================================
        ChangeNotifierProvider<UserPreferenceProvider>(
          create: (_) => UserPreferenceProvider(apiService: _userApiService),
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
          create: (pCtx) => MessagingProvider(
            apiService: _messagingApiService,
            mediaApiService: _mediaApiService,
            userProvider: pCtx.read<UserProvider>(),
            messageCache: _messageCacheService,
            miningApi: _miningApiService,
            transactionApi: _transactionApiService,
            tipApi: _tipApiService,
            walletService: _walletService,
            walletApi: _walletApiService,
            walletRpc: _walletRpcService,
          ),
          update: (_, userProvider, messaging) {
            final provider =
                (messaging ??
                      MessagingProvider(
                        apiService: _messagingApiService,
                        mediaApiService: _mediaApiService,
                        userProvider: userProvider,
                        messageCache: _messageCacheService,
                        miningApi: _miningApiService,
                        transactionApi: _transactionApiService,
                        tipApi: _tipApiService,
                        walletService: _walletService,
                        walletApi: _walletApiService,
                        walletRpc: _walletRpcService,
                      ))
                  ..updateUserProvider(userProvider);

            // Ensure AuthController is kept in sync
            _authController.setMessagingProvider(provider);
            _apiClient.onAccessTokenRefreshed = provider.initSocket;
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
          create: (_) => IapProvider(apiService: _plusApiService),
        ),

        // ======================================================
        // STARTUP SERVICE
        // ======================================================
        ProxyProvider<WalletProvider, AppStartupService>(
          update: (ctx, wallet, previous) => AppStartupService(
            authSessionService: ctx.read<AuthSessionService>(),
            authController: ctx.read<AuthController>(),
            userProvider: ctx.read<UserProvider>(),
            messagingProvider: ctx.read<MessagingProvider>(),
            walletProvider: wallet,
            miningProvider: ctx.read<MiningProvider>(),
            referralProvider: ctx.read<ReferralProvider>(),
            reputationProvider: ctx.read<ReputationProvider>(),
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
              final theme = Theme.of(context);
              final overlayStyle =
                  theme.appBarTheme.systemOverlayStyle ??
                  SystemUiOverlayStyle(
                    statusBarColor: theme.scaffoldBackgroundColor,
                    statusBarIconBrightness: theme.brightness == Brightness.dark
                        ? Brightness.light
                        : Brightness.dark,
                    statusBarBrightness: theme.brightness == Brightness.dark
                        ? Brightness.dark
                        : Brightness.light,
                    systemNavigationBarColor: theme.scaffoldBackgroundColor,
                    systemNavigationBarIconBrightness:
                        theme.brightness == Brightness.dark
                        ? Brightness.light
                        : Brightness.dark,
                    systemNavigationBarDividerColor:
                        theme.scaffoldBackgroundColor,
                  );

              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlayStyle,
                child: TipNotificationListener(
                  child: _AppLockOverlay(child: child),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class TipNotificationListener extends StatefulWidget {
  final Widget child;
  const TipNotificationListener({super.key, required this.child});

  @override
  State<TipNotificationListener> createState() =>
      _TipNotificationListenerState();
}

class _TipNotificationListenerState extends State<TipNotificationListener> {
  StreamSubscription? _subscription;
  MessagingProvider? _messagingProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final messaging = Provider.of<MessagingProvider>(context);
    if (_messagingProvider != messaging) {
      _subscription?.cancel();
      _messagingProvider = messaging;
      _subscription = messaging.tipReceivedStream.listen(_onTipReceived);
    }
  }

  void _onTipReceived(Map<String, dynamic> data) {
    if (!mounted) return;

    final userProvider = context.read<UserProvider>();
    final walletProvider = context.read<WalletProvider>();

    final currentUserId = userProvider.user?.id;
    final senderId = data['senderUserId']?.toString();

    // Don't show toast to the sender (duplicates)
    if (senderId != null && senderId == currentUserId) return;

    final amount = data['amount']?.toString() ?? '0';
    final symbol = data['symbol']?.toString() ?? 'COWRIE';
    final fromName = data['senderName']?.toString() ?? 'Someone';

    NotificationService.showTipReceived(
      context,
      amount: amount,
      symbol: symbol,
      fromName: fromName,
    );

    // Also refresh wallet balance
    walletProvider.loadWallet(force: true);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
        // If not locked, don't show the overlay.
        if (!lockProvider.isLocked) {
          return widget.child ?? const SizedBox.shrink();
        }

        // Check if we're on a public onboarding/auth screen.
        // We use the router instance directly as this builder is outside the route context.
        final String location =
            AppRouter.router.routerDelegate.currentConfiguration.uri.path;

        // Robust check for public routes. We include the splash, onboarding, and auth screens.
        // These screens should never be obscured by the App Lock PIN overlay.
        final bool isPublicRoute =
            location == '/' ||
            location.startsWith('/login') ||
            location.startsWith('/create_account') ||
            location.startsWith('/recover_account') ||
            location.startsWith('/display_phrase') ||
            location.startsWith('/loading') ||
            location.startsWith('/verify_phrase') ||
            location.startsWith('/set_password') ||
            location.startsWith('/confirm_password') ||
            location.startsWith('/verify_pin') ||
            location.startsWith('/enable_biometrics') ||
            location.startsWith('/welcome_');

        if (isPublicRoute) {
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
