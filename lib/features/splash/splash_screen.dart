import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_loader.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/startup/app_startup_service.dart';

import '../wallet/services/wallet_service.dart';

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
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    // ----------------------------------------------------------
    // START INITIALIZATION
    // ----------------------------------------------------------

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  // ============================================================
  // INITIALIZE APP
  // ============================================================
  //
  // Splash orchestrates the full application startup via 
  // AppStartupService.
  //
  // It determines whether to go to:
  // 1. Welcome flow (no local wallet)
  // 2. Login screen (wallet exists but session expired)
  // 3. Main app (authenticated successfully)
  //
  // ============================================================

  Future<void> _initializeApp() async {
    try {
      final walletService = context.read<WalletService>();
      final startupService = context.read<AppStartupService>();

      // ----------------------------------------------------------
      // 1. CHECK LOCAL WALLET
      // ----------------------------------------------------------

      final wallet = await walletService.loadWallet();

      if (!mounted) return;

      if (wallet == null) {
        debugPrint('Splash: No local wallet found. Redirecting to onboarding.');
        context.go('/welcome_one');
        return;
      }

      // ----------------------------------------------------------
      // 2. RUN FULL STARTUP (Session Restore + Profile Sync)
      // ----------------------------------------------------------

      final success = await startupService.initialize();

      if (!mounted) return;

      // Always go to the main app if a wallet exists.
      // AppStartupService returns true if a wallet was confirmed.
      if (success) {
        debugPrint('Splash: Identity confirmed. Entering app...');
        context.go('/chat');
      } else {
        debugPrint('Splash: Startup failed or no wallet found.');
        context.go('/login');
      }
    } catch (error, stackTrace) {
      debugPrint('Splash: Initialization error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      _showInitializationError();
    }
  }

  // ============================================================
  // INITIALIZATION ERROR
  // ============================================================

  void _showInitializationError() {
    if (!mounted) return;

    NotificationService.showError(
      context,
      'An error occurred during startup. Retrying...',
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _initializeApp();
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
                  const Spacer(flex: 3),

                  // ==================================================
                  // LOGO
                  // ==================================================

                  SvgPicture.asset(
                    'assets/cowrie_images/cowriesvg.svg',
                    width: MediaQuery.of(context).size.width * 0.4,
                    fit: BoxFit.contain,
                  ),

                  const Spacer(),

                  // ==================================================
                  // BRAND
                  // ==================================================

                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Griot',
                          style: textTheme.displayLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                          ),
                        ),
                        Text(
                          'By Cowrie',
                          style: textTheme.titleSmall?.copyWith(
                            color: colorScheme.primary,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  // ==================================================
                  // DESCRIPTION
                  // ==================================================

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'The first web3 super app to connect with others, earn, and tell your stories without censorship.',
                      textAlign:
                      TextAlign.center,
                      style:
                      textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // ==================================================
                  // LOADER
                  // ==================================================

                  const GriotLoader(size: 40),

                  const SizedBox(
                    height: 48,
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
