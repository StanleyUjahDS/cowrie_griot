import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:overlay_support/overlay_support.dart';

import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_loader.dart';
import '../../../core/services/notification_service.dart';
import '../../wallet/services/wallet_service.dart';
import '../../wallet/services/wallet_crypto_service.dart';
import '../../wallet/services/wallet_storage_service.dart';

class VerifySeed extends StatefulWidget {
  const VerifySeed({
    super.key,
  });

  @override
  State<VerifySeed> createState() => _VerifySeedState();
}

// ============================================================
// SEED OPTION
// ============================================================

class _SeedOption {
  final String word;
  final int originalIndex;

  const _SeedOption({
    required this.word,
    required this.originalIndex,
  });
}

// ============================================================
// VERIFY SEED STATE
// ============================================================

class _VerifySeedState extends State<VerifySeed> {
  // ==========================================================
  // WALLET SERVICE
  // ==========================================================

  late final WalletService _walletService;

  // ==========================================================
  // RECOVERY PHRASE
  // ==========================================================

  String? _mnemonic;

  List<String> get seedPhrase {
    if (_mnemonic == null) {
      return [];
    }

    return _mnemonic!.split(' ');
  }

  // ==========================================================
  // OPTIONS
  // ==========================================================

  List<_SeedOption> options = [];

  List<bool> isSelected = [];

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

    _loadMnemonic();
  }

  // ==========================================================
  // LOAD MNEMONIC
  // ==========================================================

  Future<void> _loadMnemonic() async {
    try {
      final mnemonic =
      await _walletService.getMnemonic();

      if (!mounted) {
        return;
      }

      if (mnemonic == null || mnemonic.isEmpty) {
        _showWalletError();
        return;
      }

      setState(() {
        _mnemonic = mnemonic;
      });

      _prepareOptions();
    } catch (error) {
      debugPrint(
        'Failed to load recovery phrase: $error',
      );

      if (!mounted) {
        return;
      }

      _showWalletError();
    }
  }

  // ==========================================================
  // PREPARE OPTIONS
  // ==========================================================

  void _prepareOptions() {
    if (seedPhrase.length < 9) {
      return;
    }

    const Set<int> mandatory = {
      3,
      8,
    };

    final List<_SeedOption> selected = mandatory
        .map(
          (index) => _SeedOption(
        word: seedPhrase[index],
        originalIndex: index,
      ),
    )
        .toList();

    final List<int> remaining =
    List<int>.generate(
      seedPhrase.length,
          (index) => index,
    )
        .where(
          (index) =>
      !mandatory.contains(index),
    )
        .toList()
      ..shuffle();

    while (selected.length < 6) {
      final int index =
      remaining.removeLast();

      selected.add(
        _SeedOption(
          word: seedPhrase[index],
          originalIndex: index,
        ),
      );
    }

    selected.shuffle();

    setState(() {
      options = selected;

      isSelected = List<bool>.filled(
        options.length,
        false,
      );
    });
  }

  // ==========================================================
  // SELECTED WORD INDEXES
  // ==========================================================

  Set<int> get _selectedIndexes {
    final Set<int> selected = {};

    for (int i = 0; i < options.length; i++) {
      if (isSelected[i]) {
        selected.add(
          options[i].originalIndex,
        );
      }
    }

    return selected;
  }

  // ==========================================================
  // VERIFY SELECTION
  // ==========================================================

  bool _isSelectionCorrect() {
    final Set<int> selected =
        _selectedIndexes;

    return selected.length == 2 &&
        selected.contains(3) &&
        selected.contains(8);
  }

  // ==========================================================
  // INCORRECT SELECTION
  // ==========================================================

  void _showIncorrectSelection() {
    NotificationService.showError('Incorrect selection. Please try again.');
  }

  // ==========================================================
  // WALLET ERROR
  // ==========================================================

  void _showWalletError() {
    NotificationService.showError('Wallet could not be loaded.');
  }

  // ==========================================================
  // CONTINUE
  // ==========================================================

  void _continue() {
    if (_selectedIndexes.length != 2) {
      _showIncorrectSelection();
      return;
    }

    if (_isSelectionCorrect()) {
      context.push('/set_password');
      return;
    }

    _showIncorrectSelection();
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme =
    Theme.of(context);

    final ColorScheme colorScheme =
        theme.colorScheme;

    final TextTheme textTheme =
        theme.textTheme;

    if (_mnemonic == null ||
        options.isEmpty) {
      return GradientScaffold(
        appBar: AppBar(
          backgroundColor:
          Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor:
          Colors.transparent,
          title: const Text(
            'Verify Recovery Phrase',
          ),
        ),
        child: const Center(
          child: GriotLoader(),
        ),
      );
    }

    return GradientScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor:
        Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor:
        Colors.transparent,
        title: const Text(
          'Verify Recovery Phrase',
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 20,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              Text(
                'Verify your recovery phrase',
                style: textTheme
                    .headlineSmall
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Select the 4th and 9th words from your recovery phrase to confirm that you have written it down correctly.',
                style: textTheme
                    .bodyMedium
                    ?.copyWith(
                  color: colorScheme
                      .onSurfaceVariant,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.all(16),
                decoration:
                BoxDecoration(
                  color: colorScheme.surface
                      .withValues(
                    alpha: 0.65,
                  ),
                  borderRadius:
                  BorderRadius.circular(18),
                  border: Border.all(
                    color: colorScheme.outline
                        .withValues(
                      alpha: 0.15,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration:
                      BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme
                            .primary
                            .withValues(
                          alpha: 0.12,
                        ),
                      ),
                      child: Icon(
                        Icons.security_rounded,
                        color:
                        colorScheme.primary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Text(
                            'Select exactly 2 words',
                            style: textTheme
                                .bodyLarge
                                ?.copyWith(
                              fontWeight:
                              FontWeight.w700,
                            ),
                          ),
                          const SizedBox(
                            height: 3,
                          ),
                          Text(
                            'Choose the 4th and 9th words.',
                            style: textTheme
                                .bodySmall
                                ?.copyWith(
                              color: colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: ListView.builder(
                  padding:
                  const EdgeInsets.only(
                    top: 4,
                    bottom: 16,
                  ),
                  itemCount: options.length,
                  itemBuilder:
                      (
                      BuildContext context,
                      int index,
                      ) {
                    final _SeedOption option =
                    options[index];

                    final bool selected =
                    isSelected[index];

                    return Padding(
                      padding:
                      const EdgeInsets.only(
                        bottom: 10,
                      ),
                      child: Material(
                        color:
                        Colors.transparent,
                        child: InkWell(
                          borderRadius:
                          BorderRadius
                              .circular(
                            16,
                          ),
                          onTap: () {
                            setState(() {
                              if (!selected &&
                                  _selectedIndexes
                                      .length >=
                                      2) {
                                return;
                              }

                              isSelected[index] =
                              !selected;
                            });
                          },
                          child:
                          AnimatedContainer(
                            duration:
                            const Duration(
                              milliseconds: 180,
                            ),
                            curve:
                            Curves.easeOut,
                            width:
                            double.infinity,
                            padding:
                            const EdgeInsets
                                .symmetric(
                              horizontal: 18,
                              vertical: 17,
                            ),
                            decoration:
                            BoxDecoration(
                              color: selected
                                  ? colorScheme
                                  .primary
                                  : colorScheme
                                  .surface,
                              borderRadius:
                              BorderRadius
                                  .circular(
                                16,
                              ),
                              border:
                              Border.all(
                                color: selected
                                    ? colorScheme
                                    .primary
                                    : colorScheme
                                    .outline
                                    .withValues(
                                  alpha: 0.20,
                                ),
                                width: selected
                                    ? 1.4
                                    : 1,
                              ),
                              boxShadow:
                              selected
                                  ? [
                                BoxShadow(
                                  color: colorScheme
                                      .primary
                                      .withValues(
                                    alpha:
                                    0.16,
                                  ),
                                  blurRadius:
                                  12,
                                  offset:
                                  const Offset(
                                    0,
                                    4,
                                  ),
                                ),
                              ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  alignment:
                                  Alignment
                                      .center,
                                  decoration:
                                  BoxDecoration(
                                    shape:
                                    BoxShape
                                        .circle,
                                    color: selected
                                        ? colorScheme
                                        .onPrimary
                                        .withValues(
                                      alpha:
                                      0.15,
                                    )
                                        : colorScheme
                                        .onSurface
                                        .withValues(
                                      alpha:
                                      0.05,
                                    ),
                                  ),
                                  child: Text(
                                    '${option.originalIndex + 1}',
                                    style: textTheme
                                        .bodySmall
                                        ?.copyWith(
                                      color: selected
                                          ? colorScheme
                                          .onPrimary
                                          : colorScheme
                                          .onSurfaceVariant,
                                      fontWeight:
                                      FontWeight
                                          .w700,
                                    ),
                                  ),
                                ),

                                const SizedBox(
                                  width: 14,
                                ),

                                Expanded(
                                  child: Text(
                                    option.word,
                                    maxLines: 1,
                                    overflow:
                                    TextOverflow
                                        .ellipsis,
                                    style: textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                      color: selected
                                          ? colorScheme
                                          .onPrimary
                                          : colorScheme
                                          .onSurface,
                                      fontWeight: selected
                                          ? FontWeight
                                          .w600
                                          : FontWeight
                                          .w500,
                                    ),
                                  ),
                                ),

                                const SizedBox(
                                  width: 12,
                                ),

                                AnimatedSwitcher(
                                  duration:
                                  const Duration(
                                    milliseconds:
                                    150,
                                  ),
                                  child: Icon(
                                    selected
                                        ? Icons
                                        .check_circle_rounded
                                        : Icons
                                        .radio_button_unchecked_rounded,
                                    key:
                                    ValueKey<
                                        bool>(
                                      selected,
                                    ),
                                    size: 22,
                                    color: selected
                                        ? colorScheme
                                        .onPrimary
                                        : colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              Padding(
                padding:
                const EdgeInsets.only(
                  bottom: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedIndexes.length ==
                          2
                          ? Icons
                          .check_circle_rounded
                          : Icons
                          .info_outline_rounded,
                      size: 18,
                      color:
                      _selectedIndexes.length ==
                          2
                          ? colorScheme
                          .primary
                          : colorScheme
                          .onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedIndexes.length}/2 words selected',
                      style: textTheme
                          .bodySmall
                          ?.copyWith(
                        color: colorScheme
                            .onSurfaceVariant,
                        fontWeight:
                        FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _continue,
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    colorScheme.primary,
                    foregroundColor:
                    colorScheme.onPrimary,
                    elevation: 0,
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
                    style: textTheme
                        .labelLarge
                        ?.copyWith(
                      color: colorScheme
                          .onPrimary,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}