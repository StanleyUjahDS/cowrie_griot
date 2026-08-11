import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/core/ui/scaffolds/gradient_scaffold.dart';

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
  // STATE
  // ==========================================================

  bool _isLoading = false;

  // ==========================================================
  // GENERATE ACCOUNT
  // ==========================================================

  Future<void> _generateAccount() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Allow the loading spinner to render before navigation.
    await Future<void>.delayed(
      const Duration(milliseconds: 150),
    );

    if (!mounted) {
      return;
    }

    await context.push('/display_phrase');

    // If the user comes back to this screen,
    // allow the button to be used again.
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
    });
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
      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: const Text(
          'Create Account',
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),

      // ========================================================
      // BODY
      // ========================================================

      child: SafeArea(
        child: Column(
          children: [
            // ====================================================
            // MAIN CONTENT
            // ====================================================

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
                    // ==================================================
                    // RECOVERY PHRASE WARNING
                    // ==================================================

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
                                .withValues(
                              alpha: 0.82,
                            ),
                            borderRadius:
                            BorderRadius.circular(
                              18,
                            ),
                            border: Border.all(
                              color: colorScheme
                                  .onSurface
                                  .withValues(
                                alpha: 0.08,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              // ======================================
                              // ICON
                              // ======================================

                              Container(
                                width: 48,
                                height: 48,
                                decoration:
                                BoxDecoration(
                                  color: colorScheme
                                      .primary
                                      .withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius:
                                  BorderRadius
                                      .circular(
                                    14,
                                  ),
                                ),
                                child: Icon(
                                  Icons
                                      .shield_outlined,
                                  color:
                                  colorScheme
                                      .primary,
                                  size: 26,
                                ),
                              ),

                              const SizedBox(
                                height: 20,
                              ),

                              // ======================================
                              // TITLE
                              // ======================================

                              Text(
                                'Write it Down!',
                                style: textTheme
                                    .titleLarge
                                    ?.copyWith(
                                  fontWeight:
                                  FontWeight.w700,
                                  color:
                                  colorScheme
                                      .onSurface,
                                ),
                              ),

                              const SizedBox(
                                height: 10,
                              ),

                              // ======================================
                              // DESCRIPTION
                              // ======================================

                              Text(
                                'There is no way to recover your account if you lose your recovery phrase. '
                                    'Make sure to store it in a safe place.',
                                style: textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                  color: colorScheme
                                      .onSurface
                                      .withValues(
                                    alpha: 0.70,
                                  ),
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

                    // ==================================================
                    // BACKUP INFORMATION
                    // ==================================================

                    Text(
                      'Backup your recovery phrase to ensure you do not lose access to Griot when the app is uninstalled or your device is lost.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium
                          ?.copyWith(
                        color: colorScheme.onSurface
                            .withValues(
                          alpha: 0.65,
                        ),
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(
                      height: 24,
                    ),

                    // ==================================================
                    // SECURITY MESSAGE
                    // ==================================================

                    Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons
                              .lock_outline_rounded,
                          size: 20,
                          color:
                          colorScheme.primary,
                        ),

                        const SizedBox(
                          width: 10,
                        ),

                        Expanded(
                          child: Text(
                            'Your recovery phrase belongs to you. Griot will never ask you to send it to us.',
                            style: textTheme
                                .bodySmall
                                ?.copyWith(
                              color: colorScheme
                                  .onSurface
                                  .withValues(
                                alpha: 0.60,
                              ),
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

            // ====================================================
            // GENERATE ACCOUNT BUTTON
            // ====================================================

            Padding(
              padding:
              const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                16,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                  _isLoading
                      ? null
                      : _generateAccount,

                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    colorScheme.primary,
                    foregroundColor:
                    colorScheme.onPrimary,
                    disabledBackgroundColor:
                    colorScheme.primary
                        .withValues(
                      alpha: 0.75,
                    ),
                    disabledForegroundColor:
                    colorScheme.onPrimary,
                    elevation: 0,
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        16,
                      ),
                    ),
                  ),

                  // ==================================================
                  // BUTTON CONTENT
                  // ==================================================

                  child: _isLoading
                      ? SizedBox(
                    width: 22,
                    height: 22,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color:
                      colorScheme
                          .onPrimary,
                    ),
                  )
                      : Text(
                    'Generate Account',
                    style: textTheme
                        .labelLarge
                        ?.copyWith(
                      color:
                      colorScheme
                          .onPrimary,
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