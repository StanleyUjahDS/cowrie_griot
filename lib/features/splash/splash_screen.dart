// lib/features/auth/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/core/network/api_client.dart';
import '/core/ui/scaffolds/gradient_scaffold.dart';

import '/features/auth/services/auth_api_service.dart';
import '/features/auth/services/auth_session_service.dart';
import '/features/auth/services/auth_storage_service.dart';
import '/features/auth/services/wallet_auth_service.dart';

import '/features/users/providers/user_provider.dart';
import '/features/users/services/user_api_service.dart';

import '/features/wallet/services/wallet_crypto_service.dart';
import '/features/wallet/services/wallet_service.dart';
import '/features/wallet/services/wallet_storage_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // ============================================================
  // SERVICES
  // ============================================================

  late final AuthSessionService _authSessionService;
  late final UserApiService _userApiService;
  late final UserProvider _userProvider;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    // ----------------------------------------------------------
    // WALLET STORAGE
    // ----------------------------------------------------------

    final walletStorageService = WalletStorageService();

    // ----------------------------------------------------------
    // WALLET SERVICE
    // ----------------------------------------------------------

    final walletService = WalletService(
      cryptoService: WalletCryptoService(),
      storageService: walletStorageService,
    );

    // ----------------------------------------------------------
    // AUTH STORAGE
    // ----------------------------------------------------------

    final authStorageService = AuthStorageService();

    // ----------------------------------------------------------
    // API CLIENT
    // ----------------------------------------------------------

    final apiClient = ApiClient();

    // ----------------------------------------------------------
    // AUTH API SERVICE
    // ----------------------------------------------------------

    final authApiService = AuthApiService(
      apiClient: apiClient,
      authStorageService: authStorageService,
    );

    // ----------------------------------------------------------
    // WALLET AUTH SERVICE
    // ----------------------------------------------------------
    //
    // Used when the existing wallet needs to establish a new
    // backend authentication session.
    //
    // This NEVER deletes, replaces, or recreates the wallet.
    //
    // ----------------------------------------------------------

    final walletAuthService = WalletAuthService(
      walletService: walletService,
      authApiService: authApiService,
    );

    // ----------------------------------------------------------
    // AUTH SESSION SERVICE
    // ----------------------------------------------------------

    _authSessionService = AuthSessionService(
      walletService: walletService,
      authApiService: authApiService,
      authStorageService: authStorageService,
      walletAuthService: walletAuthService,
    );

    // ----------------------------------------------------------
    // USER API SERVICE
    // ----------------------------------------------------------

    _userApiService = UserApiService(
      apiClient: apiClient,
    );

    // ----------------------------------------------------------
    // USER PROVIDER
    // ----------------------------------------------------------

    _userProvider = UserProvider(
      userApiService: _userApiService,
    );

    // ----------------------------------------------------------
    // START APPLICATION INITIALIZATION
    // ----------------------------------------------------------

    _initializeApp();
  }

  // ============================================================
  // INITIALIZE APP
  // ============================================================

  Future<void> _initializeApp() async {
    try {
      // ========================================================
      // STEP 1
      // RESTORE / ESTABLISH SESSION
      // ========================================================
      //
      // AuthSessionService handles:
      //
      // No wallet
      //     → /welcome_one
      //
      // Valid refresh token
      //     → refresh session
      //     → /chat
      //
      // Expired/invalid refresh token
      //     → silently authenticate existing wallet
      //     → /chat
      //
      // Existing wallet cannot authenticate
      //     → /login
      //
      // ========================================================

      final destination =
      await _authSessionService.getStartupDestination();

      if (!mounted) {
        return;
      }

      // ========================================================
      // STEP 2
      // FOLLOW THE AUTH SESSION DECISION
      // ========================================================

      if (destination != '/chat') {
        context.go(destination);
        return;
      }

      // ========================================================
      // STEP 3
      // AUTHENTICATED SESSION EXISTS
      // ========================================================
      //
      // At this point:
      //
      // - wallet exists
      // - backend session has been restored/created
      // - access token is stored
      //
      // Load the current user's profile.
      //
      // ========================================================

      await _userProvider.loadUser();

      // ========================================================
      // STEP 4
      // VERIFY USER PROFILE
      // ========================================================

      if (!_userProvider.hasUser) {
        throw Exception(
          'Unable to load current user.',
        );
      }

      // ========================================================
      // STEP 5
      // EXISTING USER → CHAT
      // ========================================================

      if (!mounted) {
        return;
      }

      context.go('/chat');
    } catch (error) {
      // ========================================================
      // STARTUP FAILURE
      // ========================================================
      //
      // We only arrive here if something unexpected happened
      // while restoring the session or loading the user.
      //
      // We NEVER delete the wallet.
      //
      // We check whether the wallet exists.
      //
      // Existing wallet:
      //     → /login
      //
      // No wallet:
      //     → /welcome_one
      //
      // ========================================================

      debugPrint(
        'Splash initialization error: $error',
      );

      if (!mounted) {
        return;
      }

      try {
        final hasWallet =
        await _authSessionService.hasWallet();

        if (!mounted) {
          return;
        }

        if (hasWallet) {
          // ----------------------------------------------------
          // Existing wallet but something genuinely failed.
          //
          // Do not onboard the user.
          // Do not delete the wallet.
          //
          // Login is only the final recovery path when the
          // automatic session restoration could not succeed.
          // ----------------------------------------------------

          context.go('/login');
        } else {
          // ----------------------------------------------------
          // No wallet means genuinely new user.
          // ----------------------------------------------------

          context.go('/welcome_one');
        }
      } catch (error) {
        debugPrint(
          'Unable to determine wallet state: $error',
        );

        if (!mounted) {
          return;
        }

        // ------------------------------------------------------
        // Last-resort destination.
        //
        // No wallet operation is performed here.
        // ------------------------------------------------------

        context.go('/welcome_one');
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return GradientScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // ==================================================
                  // LOGO
                  // ==================================================

                  Image.asset(
                    'assets/cowrie_images/cowrie_stack.png',
                    width:
                    MediaQuery.of(context).size.width * 0.8,
                    fit: BoxFit.contain,
                  ),

                  // ==================================================
                  // BRAND
                  // ==================================================

                  Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      'Griot',
                      style: textTheme.displayLarge,
                    ),
                  ),

                  Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      'By Cowrie',
                      style: textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  // ==================================================
                  // DESCRIPTION
                  // ==================================================

                  Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      'The first web3 super app to connect with others, earn, and tell your stories without censorship.',
                      textAlign: TextAlign.justify,
                      style: textTheme.bodyLarge,
                    ),
                  ),

                  const Spacer(),

                  // ==================================================
                  // LOADER
                  // ==================================================

                  CircularProgressIndicator(
                    color: colorScheme.primary,
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  Text(
                    'Loading...',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),

                  const SizedBox(
                    height: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}