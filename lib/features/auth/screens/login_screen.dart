import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/ui/widgets/griot_branded_container.dart';
import '../services/auth_session_service.dart';
import '../auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static final Uri _termsUri = Uri.parse('https://griot.network/terms');
  bool _hasWallet = false;
  bool _checkingWallet = true;

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
        _checkingWallet = false;
      });
    }
  }

  Future<void> _openTerms() async {
    final opened = await launchUrl(
      _termsUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open Terms and Conditions.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingWallet) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final bool isDark = theme.brightness == Brightness.dark;

    // ============================================================
    // THEME-AWARE COLORS
    // ============================================================

    final Color primaryColor = colorScheme.primary;
    final Color primaryTextColor = colorScheme.onPrimary;
    final Color secondaryText = colorScheme.onSurfaceVariant;
    final Color borderColor = colorScheme.outline.withValues(
      alpha: isDark ? 0.22 : 0.18,
    );

    return Scaffold(
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
                    // COWRIE ILLUSTRATION
                    // ==================================================
                    GriotBrandedContainer(
                      padding: const EdgeInsets.all(28),
                      borderRadius: 48,
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: SvgPicture.asset(
                          'assets/cowrie_images/cowriesvg.svg',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    Text(
                      _hasWallet
                          ? 'Welcome back'
                          : 'Your wallet. Your identity.',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ==================================================
                    // DESCRIPTION
                    // ==================================================
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 390),
                      child: Text(
                        _hasWallet
                            ? 'Unlock your wallet to continue to your stories and circles.'
                            : 'Create a new wallet or import an existing one to continue to Griot.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: secondaryText,
                          height: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ==================================================
                    // PRIMARY ACTION
                    // ==================================================
                    if (_hasWallet)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => context.push(
                            '/verify_pin',
                            extra: (BuildContext ctx) async {
                              final authController = ctx.read<AuthController>();
                              // Staging may not yet have an account for a
                              // locally stored wallet. Wallet verification
                              // therefore also completes registration and
                              // policy acceptance when required.
                              await authController.authenticateWallet(
                                acceptPolicies: true,
                              );
                              if (!ctx.mounted) return;
                              // Re-run normal startup so pending profile,
                              // group, and channel links are replayed after
                              // the backend session has been restored.
                              ctx.go('/');
                            },
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: primaryTextColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Unlock Wallet',
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
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
                            'Create New Wallet',
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    // ==================================================
                    // SECONDARY ACTION
                    // ==================================================
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () => context.push('/recover_account'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.onSurface,
                          side: BorderSide(color: borderColor, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _hasWallet
                              ? 'Import Different Wallet'
                              : 'Import Existing Wallet',
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
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: textTheme.labelSmall?.copyWith(
                    color: secondaryText,
                    height: 1.35,
                  ),
                  children: [
                    const TextSpan(text: 'By proceeding you agree to our '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: InkWell(
                        onTap: _openTerms,
                        child: Text(
                          'Terms and Conditions',
                          style: textTheme.labelSmall?.copyWith(
                            color: primaryColor,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
