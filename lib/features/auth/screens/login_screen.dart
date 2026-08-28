import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '/core/ui/scaffolds/gradient_scaffold.dart';
import '/core/ui/widgets/griot_loader.dart';
import '../auth_controller.dart';
import '../services/auth_session_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _hasWallet = false;
  bool _isCheckingWallet = true;

  @override
  void initState() {
    super.initState();
    _checkWallet();
  }

  Future<void> _checkWallet() async {
    final sessionService = context.read<AuthSessionService>();
    final hasWallet = await sessionService.hasWallet();
    if (mounted) {
      setState(() {
        _hasWallet = hasWallet;
        _isCheckingWallet = false;
      });
    }
  }

  Future<void> _handleLogin(AuthController controller) async {
    final success = await controller.authenticateWallet();
    if (success && mounted) {
      context.go('/chat');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final authController = context.watch<AuthController>();

    final bool isDark = theme.brightness == Brightness.dark;

    // ============================================================
    // THEME-AWARE COLORS
    // ============================================================

    final Color primaryColor = colorScheme.primary;
    final Color primaryTextColor = colorScheme.onPrimary;
    final Color secondaryText = colorScheme.onSurfaceVariant;
    final Color borderColor = colorScheme.outline.withValues(alpha: isDark ? 0.22 : 0.18);

    final Color subtleSurface = isDark
        ? Colors.white.withValues(alpha: 0.045)
        : Colors.black.withValues(alpha: 0.025);

    if (_isCheckingWallet) {
      return const GradientScaffold(
        child: Center(child: GriotLoader()),
      );
    }

    return GradientScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // ======================================================
              // BRAND
              // ======================================================

              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Griot',
                        style: textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'By Cowrie',
                        style: textTheme.titleSmall?.copyWith(
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ======================================================
              // CONTENT
              // ======================================================

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),

                      // ==================================================
                      // COWRIE
                      // ==================================================

                      Container(
                        width: 176,
                        height: 176,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(44),
                          color: subtleSurface,
                          border: Border.all(
                            color: borderColor,
                          ),
                        ),
                        child: SvgPicture.asset(
                          'assets/cowrie_images/cowriesvg.svg',
                          fit: BoxFit.contain,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ==================================================
                      // TITLE
                      // ==================================================

                      Text(
                        _hasWallet ? 'Welcome back to Griot' : 'Your wallet. Your identity.',
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ==================================================
                      // DESCRIPTION
                      // ==================================================

                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 390,
                        ),
                        child: Text(
                          _hasWallet 
                            ? 'Sign in with your secure wallet to continue your decentralized journey.'
                            : 'Create a new wallet or import an existing one to continue to Griot.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: secondaryText,
                            height: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // ==================================================
                      // LOGIN WITH WALLET (Only if wallet exists)
                      // ==================================================
                      if (_hasWallet)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: authController.isAuthenticating 
                                ? null 
                                : () => _handleLogin(authController),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: primaryTextColor,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: authController.isAuthenticating
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Login with Wallet',
                                    style: textTheme.labelLarge?.copyWith(
                                      color: primaryTextColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                            ),
                          ),
                        ),

                      // ==================================================
                      // CREATE ACCOUNT
                      // ==================================================

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: _hasWallet 
                          ? OutlinedButton(
                              onPressed: authController.isAuthenticating 
                                ? null 
                                : () => context.push('/create_account'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colorScheme.onSurface,
                                side: BorderSide(color: borderColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Create New Account'),
                            )
                          : ElevatedButton(
                              onPressed: () => context.push('/create_account'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: primaryTextColor,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'Create Account',
                                style: textTheme.labelLarge?.copyWith(
                                  color: primaryTextColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                      ),

                      const SizedBox(height: 12),

                      // ==================================================
                      // IMPORT / RECOVER
                      // ==================================================

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: authController.isAuthenticating 
                            ? null 
                            : () => context.push('/recover_account'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.onSurface,
                            side: BorderSide(
                              color: borderColor,
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            _hasWallet ? 'Import Different Account' : 'Import or Login Account',
                            style: textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ======================================================
              // TERMS
              // ======================================================

              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
                child: Text(
                  'By proceeding you agree to our Terms and Conditions',
                  textAlign: TextAlign.center,
                  style: textTheme.labelSmall?.copyWith(
                    color: secondaryText,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
