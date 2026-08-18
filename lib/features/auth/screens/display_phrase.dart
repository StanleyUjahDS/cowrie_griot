import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:overlay_support/overlay_support.dart';

import '/core/ui/scaffolds/gradient_scaffold.dart';

import '/features/wallet/services/wallet_crypto_service.dart';

class DisplayPhraseScreen extends StatelessWidget {
  // ==========================================================
  // WALLET
  // ==========================================================

  final WalletData wallet;

  const DisplayPhraseScreen({
    super.key,
    required this.wallet,
  });

  // ==========================================================
  // COPY RECOVERY PHRASE
  // ==========================================================

  Future<void> _copyPhrase(
      BuildContext context,
      ) async {
    await Clipboard.setData(
      ClipboardData(
        text: wallet.mnemonic,
      ),
    );

    if (!context.mounted) {
      return;
    }

    final theme = Theme.of(context);

    showSimpleNotification(
      const Text(
        'Recovery phrase copied',
      ),
      leading: const Icon(
        Icons.check_circle_outline_rounded,
      ),
      position: NotificationPosition.top,
      background: theme.colorScheme.surface,
      foreground: theme.colorScheme.onSurface,
      duration: const Duration(
        seconds: 2,
      ),
    );
  }

  // ==========================================================
  // CONTINUE
  // ==========================================================

  void _continue(
      BuildContext context,
      ) {
    context.push(
      '/verify_phrase',
      extra: wallet,
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final bool isDark =
        theme.brightness == Brightness.dark;

    // ========================================================
    // COLORS
    // ========================================================

    final Color cardColor = isDark
        ? Colors.white.withValues(
      alpha: 0.035,
    )
        : Colors.black.withValues(
      alpha: 0.018,
    );

    final Color wordColor = isDark
        ? Colors.white.withValues(
      alpha: 0.055,
    )
        : Colors.black.withValues(
      alpha: 0.025,
    );

    final Color borderColor = isDark
        ? Colors.white.withValues(
      alpha: 0.10,
    )
        : Colors.black.withValues(
      alpha: 0.08,
    );

    final Color mutedColor = colorScheme
        .onSurfaceVariant
        .withValues(
      alpha: 0.78,
    );

    // ========================================================
    // MNEMONIC
    // ========================================================

    final List<String> seedPhrase =
    wallet.mnemonic.split(' ');

    // ========================================================
    // SCREEN
    // ========================================================

    return GradientScaffold(
      appBar: AppBar(
        title: Text(
          'Recovery Phrase',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            18,
            8,
            18,
            16,
          ),
          child: Column(
            children: [
              // ==================================================
              // HEADER
              // ==================================================

              Text(
                'Write down your recovery phrase',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                'These 12 words are the only way to recover '
                    'your wallet if you lose access to this device.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: mutedColor,
                  height: 1.45,
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              // ==================================================
              // CONTENT
              // ==================================================

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // ==========================================
                      // SEED PHRASE CARD
                      // ==========================================

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(
                          12,
                        ),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius:
                          BorderRadius.circular(
                            18,
                          ),
                          border: Border.all(
                            color: borderColor,
                          ),
                        ),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics:
                          const NeverScrollableScrollPhysics(),
                          itemCount:
                          seedPhrase.length,
                          gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 9,
                            crossAxisSpacing: 9,
                            childAspectRatio: 3.2,
                          ),
                          itemBuilder: (
                              context,
                              index,
                              ) {
                            final String word =
                            seedPhrase[index];

                            return Container(
                              padding:
                              const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration:
                              BoxDecoration(
                                color: wordColor,
                                borderRadius:
                                BorderRadius.circular(
                                  12,
                                ),
                                border: Border.all(
                                  color: borderColor,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // =================================
                                  // NUMBER
                                  // =================================

                                  SizedBox(
                                    width: 25,
                                    child: Text(
                                      '${index + 1}.',
                                      style: textTheme
                                          .bodySmall
                                          ?.copyWith(
                                        color:
                                        mutedColor,
                                        fontWeight:
                                        FontWeight
                                            .w600,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(
                                    width: 6,
                                  ),

                                  // =================================
                                  // WORD
                                  // =================================

                                  Expanded(
                                    child: Text(
                                      word,
                                      style: textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                        color:
                                        colorScheme
                                            .onSurface,
                                        fontWeight:
                                        FontWeight
                                            .w500,
                                      ),
                                      overflow:
                                      TextOverflow
                                          .ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      // ==========================================
                      // COPY
                      // ==========================================

                      OutlinedButton.icon(
                        onPressed: () {
                          _copyPhrase(
                            context,
                          );
                        },
                        icon: const Icon(
                          Icons.copy_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'Copy Phrase',
                        ),
                        style:
                        OutlinedButton.styleFrom(
                          foregroundColor:
                          colorScheme.onSurface,
                          side: BorderSide(
                            color: borderColor,
                          ),
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(
                              14,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 18,
                      ),

                      // ==========================================
                      // SECURITY NOTICE
                      // ==========================================

                      Container(
                        width: double.infinity,
                        padding:
                        const EdgeInsets.all(
                          15,
                        ),
                        decoration:
                        BoxDecoration(
                          color: cardColor,
                          borderRadius:
                          BorderRadius.circular(
                            15,
                          ),
                          border: Border.all(
                            color: borderColor,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                          children: [
                            Container(
                              padding:
                              const EdgeInsets.all(
                                8,
                              ),
                              decoration:
                              BoxDecoration(
                                color: isDark
                                    ? Colors.white
                                    .withValues(
                                  alpha: 0.06,
                                )
                                    : Colors.black
                                    .withValues(
                                  alpha: 0.04,
                                ),
                                shape:
                                BoxShape.circle,
                              ),
                              child: Icon(
                                Icons
                                    .lock_outline_rounded,
                                size: 19,
                                color:
                                mutedColor,
                              ),
                            ),

                            const SizedBox(
                              width: 11,
                            ),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                                children: [
                                  Text(
                                    'Keep it private',
                                    style: textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                      fontWeight:
                                      FontWeight
                                          .w700,
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 4,
                                  ),

                                  Text(
                                    'Never share your recovery phrase. '
                                        'Griot will never ask you for these words.',
                                    style: textTheme
                                        .bodySmall
                                        ?.copyWith(
                                      color:
                                      mutedColor,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              // ==================================================
              // CONTINUE
              // ==================================================

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    _continue(
                      context,
                    );
                  },
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    colorScheme.primary,
                    foregroundColor:
                    colorScheme.onPrimary,
                    elevation: 0,
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 20,
                    ),
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        16,
                      ),
                    ),
                  ),
                  child: Text(
                    'Continue',
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
            ],
          ),
        ),
      ),
    );
  }
}