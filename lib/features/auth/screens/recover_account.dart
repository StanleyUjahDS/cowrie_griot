import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/notification_service.dart';
import '../services/mnemonic_validation_service.dart';
import '../auth_controller.dart';

import '../../wallet/services/wallet_crypto_service.dart';
import '../../wallet/services/wallet_storage_service.dart';
import '../../wallet/services/wallet_service.dart';

import '/core/ui/scaffolds/gradient_scaffold.dart';
import '/core/ui/screens/app_loading_screen.dart';

class RecoverAccountScreen extends StatefulWidget {
  const RecoverAccountScreen({
    super.key,
  });

  @override
  State<RecoverAccountScreen> createState() =>
      _RecoverAccountScreenState();
}

class _RecoverAccountScreenState
    extends State<RecoverAccountScreen> {
  // ============================================================
  // SERVICES
  // ============================================================

  final MnemonicValidationService _mnemonicService =
  MnemonicValidationService();

  late final WalletService _walletService;

  // ============================================================
  // SEED WORD CONTROLLERS
  // ============================================================

  final List<TextEditingController> _controllers =
  List.generate(
    12,
        (_) => TextEditingController(),
  );

  // ============================================================
  // WORD VALIDATION STATE
  // ============================================================

  final List<bool> _validWords =
  List.generate(
    12,
        (_) => false,
  );

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _walletService = WalletService(
      cryptoService: WalletCryptoService(),
      storageService: WalletStorageService(),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }

    super.dispose();
  }


  // ============================================================
  // WORD CHANGED
  // ============================================================

  void _onWordChanged(
      int index,
      String value,
      ) {
    final normalized =
    value.trim().toLowerCase();

    // ----------------------------------------------------------
    // KEEP FIELD LOWERCASE
    // ----------------------------------------------------------

    if (value != normalized) {
      _controllers[index].value =
          _controllers[index].value.copyWith(
            text: normalized,
            selection:
            TextSelection.collapsed(
              offset: normalized.length,
            ),
          );
    }

    // ----------------------------------------------------------
    // EMPTY WORD
    // ----------------------------------------------------------

    if (normalized.isEmpty) {
      if (_validWords[index]) {
        setState(() {
          _validWords[index] = false;
        });
      }

      return;
    }

    // ----------------------------------------------------------
    // VALIDATE WORD
    // ----------------------------------------------------------

    final isValid =
    _mnemonicService.isValidWord(
      normalized,
    );

    if (_validWords[index] == isValid) {
      return;
    }

    setState(() {
      _validWords[index] = isValid;
    });
  }

  // ============================================================
  // PASTE FROM CLIPBOARD
  // ============================================================

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(
      Clipboard.kTextPlain,
    );

    final text =
        data?.text?.trim() ?? '';

    if (!mounted || text.isEmpty) {
      return;
    }

    final words =
    text.split(RegExp(r'\s+'));

    // ----------------------------------------------------------
    // MUST CONTAIN EXACTLY 12 WORDS
    // ----------------------------------------------------------

    if (words.length != 12) {
      NotificationService.showError(
        context,
        'Recovery phrase must contain exactly 12 words.',
      );

      return;
    }

    // ----------------------------------------------------------
    // NORMALIZE
    // ----------------------------------------------------------

    final normalizedWords = words
        .map(
          (word) => word.trim().toLowerCase(),
    )
        .toList();

    // ----------------------------------------------------------
    // UPDATE FIELDS
    // ----------------------------------------------------------

    setState(() {
      for (int i = 0; i < 12; i++) {
        _controllers[i].text =
        normalizedWords[i];

        _validWords[i] =
            _mnemonicService.isValidWord(
              normalizedWords[i],
            );
      }
    });

    // ----------------------------------------------------------
    // CHECK INDIVIDUAL WORDS
    // ----------------------------------------------------------

    final invalidIndex =
    normalizedWords.indexWhere(
          (word) =>
      !_mnemonicService.isValidWord(
        word,
      ),
    );

    if (invalidIndex != -1) {
      NotificationService.showError(
        context,
        'Word ${invalidIndex + 1} is not a valid BIP-39 recovery word.',
      );

      return;
    }

    // ----------------------------------------------------------
    // CHECK COMPLETE PHRASE
    // ----------------------------------------------------------

    final isValidPhrase =
    _mnemonicService.isValidPhrase(
      normalizedWords,
    );

    if (!isValidPhrase) {
      NotificationService.showError(
        context,
        'The recovery phrase is not valid. Check the words and their order.',
      );

      return;
    }

    // ----------------------------------------------------------
    // SUCCESS
    // ----------------------------------------------------------

    NotificationService.showSuccess(
      context,
      'Valid recovery phrase.',
    );
  }

  // ============================================================
  // CLEAR ALL
  // ============================================================

  void _clearAll() {
    setState(() {
      for (int i = 0; i < 12; i++) {
        _controllers[i].clear();
        _validWords[i] = false;
      }
    });

    NotificationService.showInfo(
      context,
      'All fields cleared.',
    );
  }

  // ============================================================
  // GET WORDS
  // ============================================================

  List<String> _getWords() {
    return _controllers
        .map(
          (controller) =>
          controller.text.trim().toLowerCase(),
    )
        .toList();
  }

  // ============================================================
  // RECOVER ACCOUNT
  // ============================================================

  void _recoverAccount() {
    final words = _getWords();

    // ----------------------------------------------------------
    // CHECK EMPTY WORD
    // ----------------------------------------------------------

    final emptyIndex =
    words.indexWhere(
          (word) => word.isEmpty,
    );

    if (emptyIndex != -1) {
      NotificationService.showError(
        context,
        'Please enter recovery word ${emptyIndex + 1}.',
      );

      return;
    }

    // ----------------------------------------------------------
    // VALIDATE EVERY WORD
    // ----------------------------------------------------------

    final invalidIndex =
    words.indexWhere(
          (word) =>
      !_mnemonicService.isValidWord(
        word,
      ),
    );

    if (invalidIndex != -1) {
      setState(() {
        _validWords[invalidIndex] = false;
      });

      NotificationService.showError(
        context,
        'Word ${invalidIndex + 1} is not a valid BIP-39 recovery word.',
      );

      return;
    }

    // ----------------------------------------------------------
    // VALIDATE COMPLETE PHRASE
    // ----------------------------------------------------------

    final isValidPhrase =
    _mnemonicService.isValidPhrase(
      words,
    );

    if (!isValidPhrase) {
      NotificationService.showError(
        context,
        'The recovery phrase is invalid. Check the words and their order.',
      );

      return;
    }

    // ----------------------------------------------------------
    // BUILD MNEMONIC
    // ----------------------------------------------------------

    final mnemonic =
    words.join(' ');

    // ----------------------------------------------------------
    // GO TO GENERIC LOADING SCREEN
    // ----------------------------------------------------------

    context.push(
      '/loading',
      extra: AppLoadingRouteData(
        icon: Icons.restore_rounded,
        title: 'Recovering your wallet',
        message:
        'Restoring your secure wallet from your recovery phrase...',

        // ----------------------------------------------------
        // OPERATION
        // ----------------------------------------------------

        operation: () async {
          return await _walletService.restoreWallet(
            mnemonic,
          );
        },

        // ----------------------------------------------------
        // SUCCESS
        // ----------------------------------------------------

        onSuccess: (
            BuildContext context,
            dynamic result,
            ) {
          if (!context.mounted) {
            return;
          }

          context.pushReplacement(
            '/set_password',
            extra: (BuildContext ctx) async {
              final authController = ctx.read<AuthController>();
              await authController.authenticateWallet();
            },
          );
        },
      ),
    );
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

    final colors =
        theme.colorScheme;

    final text =
        theme.textTheme;

    final bool isDark =
        theme.brightness ==
            Brightness.dark;

    // ==========================================================
    // THEME COLORS
    // ==========================================================

    final Color fieldColor =
    colors.surfaceContainerHighest
        .withValues(alpha: isDark ? 0.35 : 0.55);

    final Color containerColor =
    colors.surface.withValues(alpha: isDark ? 0.45 : 0.75);

    final Color borderColor =
    colors.outline.withValues(alpha: isDark ? 0.35 : 0.45);

    final Color mutedColor =
    colors.onSurfaceVariant
        .withValues(alpha: 0.75);

    // ==========================================================
    // SCREEN
    // ==========================================================

    return GradientScaffold(
      appBar: AppBar(
        title: Text(
          'Recover Account',
          style:
          text.titleLarge?.copyWith(
            fontWeight:
            FontWeight.w700,
          ),
        ),
        backgroundColor:
        Colors.transparent,
        foregroundColor:
        colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor:
        Colors.transparent,
      ),
      child: SafeArea(
        child: Padding(
          padding:
          const EdgeInsets.fromLTRB(
            18,
            8,
            18,
            18,
          ),
          child: Column(
            children: [
              // ==================================================
              // HEADER
              // ==================================================

              Text(
                'Recover your wallet',
                textAlign:
                TextAlign.center,
                style: text
                    .headlineSmall
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w700,
                ),
              ),

              const SizedBox(
                height: 7,
              ),

              Text(
                'Enter your 12-word recovery phrase to '
                    'restore access to your wallet.',
                textAlign:
                TextAlign.center,
                style: text.bodyMedium
                    ?.copyWith(
                  color: mutedColor,
                  height: 1.45,
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              // ==================================================
              // SECURITY NOTICE
              // ==================================================

              Container(
                width:
                double.infinity,
                padding:
                const EdgeInsets.all(
                  13,
                ),
                decoration:
                BoxDecoration(
                  color:
                  containerColor,
                  borderRadius:
                  BorderRadius.circular(
                    14,
                  ),
                  border:
                  Border.all(
                    color:
                    borderColor,
                  ),
                ),
                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Icon(
                      Icons
                          .lock_outline_rounded,
                      size: 19,
                      color:
                      mutedColor,
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: Text(
                        'Your recovery phrase stays on this '
                            'device. Never share it with anyone.',
                        style: text
                            .bodySmall
                            ?.copyWith(
                          color:
                          mutedColor,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              // ==================================================
              // WORD GRID
              // ==================================================

              Expanded(
                child: Container(
                  width:
                  double.infinity,
                  padding:
                  const EdgeInsets.all(
                    11,
                  ),
                  decoration:
                  BoxDecoration(
                    color:
                    containerColor,
                    borderRadius:
                    BorderRadius.circular(
                      18,
                    ),
                    border:
                    Border.all(
                      color:
                      borderColor,
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                      final childAspectRatio = constraints.maxWidth > 600 ? 4.0 : 3.2;
                      
                      return GridView.builder(
                        padding: const EdgeInsets.all(2),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: 12,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 9,
                          crossAxisSpacing: 9,
                          childAspectRatio: childAspectRatio,
                        ),
                        itemBuilder: (context, index) {
                          return _SeedWordField(
                            controller: _controllers[index],
                            index: index,
                            isValid: _validWords[index],
                            fieldColor: fieldColor,
                            borderColor: borderColor,
                            colorScheme: colors,
                            textTheme: text,
                            onChanged: (value) {
                              _onWordChanged(index, value);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(
                height: 13,
              ),

              // ==================================================
              // CLEAR / PASTE
              // ==================================================

              Row(
                children: [
                  Expanded(
                    child:
                    OutlinedButton.icon(
                      onPressed:
                      _clearAll,
                      icon:
                      const Icon(
                        Icons.clear_rounded,
                        size: 18,
                      ),
                      label:
                      const Text(
                        'Clear',
                      ),
                      style:
                      OutlinedButton.styleFrom(
                        foregroundColor:
                        colors.onSurface,
                        side:
                        BorderSide(
                          color:
                          borderColor,
                        ),
                        padding:
                        const EdgeInsets
                            .symmetric(
                          vertical: 13,
                        ),
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            14,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child:
                    OutlinedButton.icon(
                      onPressed:
                      _pasteFromClipboard,
                      icon:
                      const Icon(
                        Icons
                            .content_paste_rounded,
                        size: 18,
                      ),
                      label:
                      const Text(
                        'Paste',
                      ),
                      style:
                      OutlinedButton.styleFrom(
                        foregroundColor:
                        colors.onSurface,
                        side:
                        BorderSide(
                          color:
                          borderColor,
                        ),
                        padding:
                        const EdgeInsets
                            .symmetric(
                          vertical: 13,
                        ),
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 10,
              ),

              // ==================================================
              // RECOVER BUTTON
              // ==================================================

              SizedBox(
                width:
                double.infinity,
                height: 54,
                child:
                ElevatedButton(
                  onPressed:
                  _recoverAccount,
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    colors.primary,
                    foregroundColor:
                    colors.onPrimary,
                    elevation: 0,
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 20,
                    ),
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius
                          .circular(
                        16,
                      ),
                    ),
                  ),
                  child: Text(
                    'Recover Wallet',
                    style: text
                        .labelLarge
                        ?.copyWith(
                      color:
                      colors.onPrimary,
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

// ================================================================
// SEED WORD FIELD
// ================================================================

class _SeedWordField
    extends StatelessWidget {
  final TextEditingController controller;

  final int index;

  final bool isValid;

  final Color fieldColor;

  final Color borderColor;

  final ColorScheme colorScheme;

  final TextTheme textTheme;

  final ValueChanged<String> onChanged;

  const _SeedWordField({
    required this.controller,
    required this.index,
    required this.isValid,
    required this.fieldColor,
    required this.borderColor,
    required this.colorScheme,
    required this.textTheme,
    required this.onChanged,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final bool hasText =
        controller.text
            .trim()
            .isNotEmpty;

    // ==========================================================
    // EFFECTIVE BORDER COLOR
    // ==========================================================

    Color effectiveBorderColor =
        borderColor;

    if (hasText && isValid) {
      effectiveBorderColor =
          Colors.green;
    }

    if (hasText && !isValid) {
      effectiveBorderColor =
          colorScheme.error;
    }

    // ==========================================================
    // FIELD
    // ==========================================================

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction:
      index == 11
          ? TextInputAction.done
          : TextInputAction.next,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization:
      TextCapitalization.none,
      style: textTheme.bodyMedium
          ?.copyWith(
        color:
        colorScheme.onSurface,
        fontWeight:
        FontWeight.w500,
      ),
      decoration:
      InputDecoration(
        filled: true,
        fillColor: fieldColor,

        // ======================================================
        // NUMBER
        // ======================================================

        prefixText:
        '${index + 1}. ',

        prefixStyle:
        textTheme.bodySmall
            ?.copyWith(
          color: colorScheme
              .onSurfaceVariant,
          fontWeight:
          FontWeight.w600,
        ),

        // ======================================================
        // HINT
        // ======================================================

        hintText:
        'Word ${index + 1}',

        hintStyle:
        textTheme.bodySmall
            ?.copyWith(
          color: colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.55),
        ),

        // ======================================================
        // VALIDATION ICON
        // ======================================================

        suffixIcon:
        !hasText
            ? null
            : Icon(
          isValid
              ? Icons
              .check_circle_rounded
              : Icons
              .error_outline_rounded,
          size: 19,
          color: isValid
              ? Colors.green
              : colorScheme
              .error,
        ),

        // ======================================================
        // PADDING
        // ======================================================

        contentPadding:
        const EdgeInsets
            .symmetric(
          horizontal: 12,
          vertical: 12,
        ),

        // ======================================================
        // BORDER
        // ======================================================

        border:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            12,
          ),
          borderSide:
          BorderSide(
            color:
            effectiveBorderColor,
          ),
        ),

        enabledBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            12,
          ),
          borderSide:
          BorderSide(
            color:
            effectiveBorderColor,
          ),
        ),

        focusedBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            12,
          ),
          borderSide:
          BorderSide(
            color: hasText
                ? effectiveBorderColor
                : colorScheme.primary,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}