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
import 'features/users/providers/user_provider.dart';
import 'features/users/services/user_api_service.dart';
import 'features/wallet/services/wallet_crypto_service.dart';
import 'features/wallet/services/wallet_service.dart';
import 'features/wallet/services/wallet_storage_service.dart';

import 'features/wallet/services/wallet_api_service.dart';
import 'features/wallet/services/transaction_api_service.dart';
import 'features/wallet/services/swap_api_service.dart';
import 'features/miner/services/mining_api_service.dart';
import 'features/miner/services/referral_api_service.dart';
import 'features/wallet/providers/wallet_provider.dart';
import 'core/services/navigation_scroll_service.dart';

class GriotCowrieApp extends StatefulWidget {
  const GriotCowrieApp({
    super.key,
  });

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
  late final MiningApiService _miningApiService;
  late final ReferralApiService _referralApiService;

  @override
  void initState() {
    super.initState();

    // ----------------------------------------------------------
    // CORE INFRASTRUCTURE
    // ----------------------------------------------------------

    _apiClient = ApiClient();

    final walletStorage = WalletStorageService();
    final authStorage = AuthStorageService();

    _walletService = WalletService(
      cryptoService: WalletCryptoService(),
      storageService: walletStorage,
    );

    _userApiService = UserApiService(
      apiClient: _apiClient,
    );

    _walletApiService = WalletApiService(
      apiClient: _apiClient,
    );

    _transactionApiService = TransactionApiService(
      apiClient: _apiClient,
    );

    _swapApiService = SwapApiService(
      apiClient: _apiClient,
    );

    _miningApiService = MiningApiService(
      apiClient: _apiClient,
    );

    _referralApiService = ReferralApiService(
      apiClient: _apiClient,
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

    // ==========================================================
    // THEME CONTROLLER
    // ==========================================================

    AppRouter.setThemeController(
      _themeController,
    );
  }

  @override
  void dispose() {
    _apiClient.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return MultiProvider(
      providers: [
        // ======================================================
        // DATA SERVICES
        // ======================================================

        Provider<WalletService>.value(value: _walletService),
        Provider<AuthSessionService>.value(value: _authSessionService),
        Provider<WalletApiService>.value(value: _walletApiService),
        Provider<TransactionApiService>.value(value: _transactionApiService),
        Provider<SwapApiService>.value(value: _swapApiService),
        Provider<MiningApiService>.value(value: _miningApiService),
        Provider<ReferralApiService>.value(value: _referralApiService),
        ChangeNotifierProvider<NavigationScrollService>.value(
          value: NavigationScrollService.instance,
        ),

        // ======================================================
        // USER PROVIDER
        // ======================================================

        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider(
            userApiService: _userApiService,
          ),
        ),

        // ======================================================
        // WALLET PROVIDER
        // ======================================================

        ChangeNotifierProvider<WalletProvider>(
          create: (_) => WalletProvider(
            walletService: _walletService,
            walletApiService: _walletApiService,
          )..loadWallet(),
        ),

        // ======================================================
        // STARTUP SERVICE
        // ======================================================

        ProxyProvider2<AuthSessionService, UserProvider, AppStartupService>(
          update: (_, auth, user, previous) => AppStartupService(
            authSessionService: auth,
            userProvider: user,
          ),
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

            themeMode: _themeController.themeMode,

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
