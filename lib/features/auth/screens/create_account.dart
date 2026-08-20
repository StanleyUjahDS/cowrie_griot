import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/screens/app_loading_screen.dart';
import '../../../core/services/notification_service.dart';

import '../../wallet/services/wallet_service.dart';
import '../../wallet/services/wallet_crypto_service.dart';
import '../../wallet/services/wallet_storage_service.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({
    super.key,
  });

  @override
  State<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState
    extends State<CreateAccountScreen> {
  // ==========================================================
  // WALLET SERVICE
  // ==========================================================

  late final WalletService _walletService;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    _walletService = WalletService(
      cryptoService: WalletCryptoService(),
      storageService: WalletStorageService(),
    );
  }

  // ==========================================================
  // GENERATE ACCOUNT
  // ==========================================================

  void _generateAccount() {
    context.push(
      '/loading',
      extra: AppLoadingRouteData(
        // ----------------------------------------------------
        // LOADING UI
        // ----------------------------------------------------

        title: 'Preparing your account',

        message:
        'Creating your secure wallet...',

        // This icon is specific to THIS operation.
        //
        // The loading screen itself remains generic.
        icon: Icons.account_balance_wallet_outlined,

        // ----------------------------------------------------
        // OPERATION
        // ----------------------------------------------------

        operation: () async {
          return await _walletService.createWallet();
        },

        // ----------------------------------------------------
        // SUCCESS
        // ----------------------------------------------------

        onSuccess: (
            BuildContext context,
            dynamic result,
            ) {
          // The generic loading route returns dynamic.
          // We restore the expected type here.

          if (result is! WalletData) {
            NotificationService.showError(context, 'Unable to create wallet.');

            return;
          }

          context.pushReplacement(
            '/display_phrase',
            extra: result,
          );
        },
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text(
          'Create Account',
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // CONTENT
            // ==================================================

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,
                  children: [
                    // ==========================================
                    // WARNING CARD
                    // ==========================================

                    ClipRRect(
                      borderRadius:
                      BorderRadius.circular(18),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 18,
                          sigmaY: 18,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding:
                          const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colorScheme.surface
                                .withValues(alpha: 0.82),
                            borderRadius:
                            BorderRadius.circular(
                              18,
                            ),
                            border: Border.all(
                              color: colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration:
                                BoxDecoration(
                                  color: colorScheme
                                      .primary
                                      .withValues(alpha: 0.12),
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                    14,
                                  ),
                                ),
                                child: Icon(
                                  Icons.shield_outlined,
                                  color:
                                  colorScheme.primary,
                                  size: 26,
                                ),
                              ),

                              const SizedBox(
                                height: 20,
                              ),

                              Text(
                                'Write it Down!',
                                style: textTheme
                                    .titleLarge
                                    ?.copyWith(
                                  fontWeight:
                                  FontWeight.w700,
                                ),
                              ),

                              const SizedBox(
                                height: 10,
                              ),

                              Text(
                                'There is no way to recover '
                                    'your account if you lose your '
                                    'recovery phrase. Make sure to '
                                    'store it in a safe place.',
                                style: textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                  color: colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.70),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 40,
                    ),

                    // ==========================================
                    // BACKUP MESSAGE
                    // ==========================================

                    Text(
                      'Backup your recovery phrase to ensure '
                          'you do not lose access to Griot when the '
                          'app is uninstalled or your device is lost.',
                      textAlign: TextAlign.center,
                      style:
                      textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface
                            .withValues(alpha: 0.65),
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(
                      height: 24,
                    ),

                    // ==========================================
                    // SECURITY MESSAGE
                    // ==========================================

                    Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                          color: colorScheme.primary,
                        ),

                        const SizedBox(
                          width: 10,
                        ),

                        Expanded(
                          child: Text(
                            'Your recovery phrase belongs '
                                'to you. Griot will never ask you '
                                'to send it to us.',
                            style: textTheme
                                .bodySmall
                                ?.copyWith(
                              color: colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.60),
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ==================================================
            // GENERATE BUTTON
            // ==================================================

            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _generateAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    colorScheme.primary,
                    foregroundColor:
                    colorScheme.onPrimary,
                    elevation: 0,
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Generate Account',
                    style: textTheme.labelLarge
                        ?.copyWith(
                      color:
                      colorScheme.onPrimary,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}