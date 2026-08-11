import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/core/ui/scaffolds/gradient_scaffold.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
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

    final Color subtleSurface = isDark
        ? Colors.white.withValues(alpha: 0.045)
        : Colors.black.withValues(alpha: 0.025);

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
                  padding: const EdgeInsets.fromLTRB(
                    22,
                    10,
                    22,
                    0,
                  ),
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
                  padding: const EdgeInsets.fromLTRB(
                    22,
                    18,
                    22,
                    12,
                  ),
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
                          shape: BoxShape.circle,
                          color: subtleSurface,
                          border: Border.all(
                            color: borderColor,
                          ),
                        ),
                        child: Image.asset(
                          'assets/cowrie_images/wolrd_cowrie.png',
                          fit: BoxFit.contain,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ==================================================
                      // TITLE
                      // ==================================================

                      Text(
                        'Your wallet. Your identity.',
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
                          'Create a new wallet or import an existing '
                              'one to continue to Griot.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: secondaryText,
                            height: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // ==================================================
                      // CREATE ACCOUNT
                      // ==================================================

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            context.push('/create_account');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: primaryTextColor,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                            ),
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
                      // IMPORT / LOGIN
                      // ==================================================

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: () {
                            context.push('/recover_account');
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.onSurface,
                            side: BorderSide(
                              color: borderColor,
                              width: 1,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Import or Login Account',
                            style: textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ==================================================
                      // DIVIDER
                      // ==================================================

                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: borderColor,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                            ),
                            child: Text(
                              'Or continue with',
                              style: textTheme.bodySmall?.copyWith(
                                color: secondaryText,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: borderColor,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ==================================================
                      // HARDWARE WALLET
                      // ==================================================

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // Hardware wallet integration later.
                          },
                          icon: Icon(
                            Icons.usb_rounded,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          label: Text(
                            'Hardware Wallet',
                            style: textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.onSurface,
                            side: BorderSide(
                              color: borderColor,
                              width: 1,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // ======================================================
              // TERMS
              // ======================================================

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  22,
                  4,
                  22,
                  12,
                ),
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