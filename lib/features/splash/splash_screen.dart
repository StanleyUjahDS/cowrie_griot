// lib/features/auth/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/scaffolds/gradient_scaffold.dart';

import '../wallet/services/wallet_crypto_service.dart';
import '../wallet/services/wallet_service.dart';
import '../wallet/services/wallet_storage_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
  });

  @override
  State<SplashScreen> createState() =>
      _SplashScreenState();
}

class _SplashScreenState
    extends State<SplashScreen> {
  // ============================================================
  // WALLET SERVICE
  // ============================================================

  late final WalletService _walletService;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    // ----------------------------------------------------------
    // WALLET STORAGE
    // ----------------------------------------------------------

    final walletStorageService =
    WalletStorageService();

    // ----------------------------------------------------------
    // WALLET SERVICE
    // ----------------------------------------------------------

    _walletService = WalletService(
      cryptoService: WalletCryptoService(),
      storageService: walletStorageService,
    );

    // ----------------------------------------------------------
    // START LOCAL INITIALIZATION
    // ----------------------------------------------------------

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  // ============================================================
  // INITIALIZE APP
  // ============================================================
  //
  // Splash is LOCAL-FIRST.
  //
  // It ONLY determines whether a valid local wallet exists.
  //
  // It does NOT:
  //
  // - call the backend
  // - request a nonce
  // - authenticate the wallet
  // - refresh JWT tokens
  // - load the user profile
  // - load chats
  // - load wallet balances
  // - load transactions
  // - require internet access
  //
  // ============================================================

  Future<void> _initializeApp() async {
    try {
      // ----------------------------------------------------------
      // LOAD LOCAL WALLET
      // ----------------------------------------------------------
      //
      // WalletService currently exposes loadWallet(), not
      // hasWallet().
      //
      // A non-null WalletData means the local wallet is present
      // and all required wallet values were successfully loaded.
      //
      // ----------------------------------------------------------

      final wallet =
      await _walletService.loadWallet();

      if (!mounted) {
        return;
      }

      // ----------------------------------------------------------
      // NO WALLET
      // ----------------------------------------------------------
      //
      // This is the genuine local-new-user state.
      //
      // ----------------------------------------------------------

      if (wallet == null) {
        context.go('/welcome_one');
        return;
      }

      // ----------------------------------------------------------
      // WALLET EXISTS
      // ----------------------------------------------------------
      //
      // Splash does NOT authenticate against the backend.
      //
      // The authenticated application layer will handle:
      //
      // - access token restoration
      // - refresh token handling
      // - wallet authentication
      // - user synchronization
      // - cached data
      // - network recovery
      //
      // ----------------------------------------------------------

      context.go('/chat');
    } catch (error, stackTrace) {
      // ----------------------------------------------------------
      // LOCAL STORAGE FAILURE
      // ----------------------------------------------------------

      debugPrint(
        'Splash initialization error: $error',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      // ----------------------------------------------------------
      // IMPORTANT
      // ----------------------------------------------------------
      //
      // Do NOT:
      //
      // - delete the wallet
      // - replace the wallet
      // - recreate the wallet
      // - authenticate against the backend
      // - assume the user is new
      //
      // A storage failure is NOT the same thing as "no wallet".
      //
      // For now, remain on the splash rather than incorrectly
      // sending an existing user through onboarding.
      //
      // ----------------------------------------------------------

      _showInitializationError();
    }
  }

  // ============================================================
  // INITIALIZATION ERROR
  // ============================================================

  void _showInitializationError() {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Unable to load your wallet. Please try again.',
        ),
      ),
    );

    // Retry after the current frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _initializeApp();
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme =
    Theme.of(context);

    final textTheme =
        theme.textTheme;

    final colorScheme =
        theme.colorScheme;

    return GradientScaffold(
      child: Scaffold(
        backgroundColor:
        Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // ==================================================
                  // LOGO
                  // ==================================================

                  Image.asset(
                    'assets/cowrie_images/cowrie_stack.png',
                    width:
                    MediaQuery.of(context)
                        .size
                        .width *
                        0.8,
                    fit:
                    BoxFit.contain,
                  ),

                  // ==================================================
                  // BRAND
                  // ==================================================

                  Align(
                    alignment:
                    Alignment.topLeft,
                    child: Text(
                      'Griot',
                      style:
                      textTheme.displayLarge,
                    ),
                  ),

                  Align(
                    alignment:
                    Alignment.topLeft,
                    child: Text(
                      'By Cowrie',
                      style:
                      textTheme.titleSmall
                          ?.copyWith(
                        color:
                        colorScheme.primary,
                        fontStyle:
                        FontStyle.italic,
                        fontWeight:
                        FontWeight.w600,
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
                    alignment:
                    Alignment.topLeft,
                    child: Text(
                      'The first web3 super app to connect with others, earn, and tell your stories without censorship.',
                      textAlign:
                      TextAlign.justify,
                      style:
                      textTheme.bodyLarge,
                    ),
                  ),

                  const Spacer(),

                  // ==================================================
                  // LOADER
                  // ==================================================

                  CircularProgressIndicator(
                    color:
                    colorScheme.primary,
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  Text(
                    'Loading...',
                    style:
                    textTheme.bodyMedium
                        ?.copyWith(
                      color:
                      colorScheme.primary,
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