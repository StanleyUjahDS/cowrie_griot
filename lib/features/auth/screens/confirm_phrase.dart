import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/ui/widgets/griot_loader.dart';
import '../../../core/ui/widgets/griot_branded_container.dart';
import '../../../core/services/notification_service.dart';
import '../auth_controller.dart';
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

class _SeedOption {
  final String word;
  final int originalIndex;

  const _SeedOption({
    required this.word,
    required this.originalIndex,
  });
}

class _VerifySeedState extends State<VerifySeed> {
  late final WalletService _walletService;
  String? _mnemonic;

  List<String> get seedPhrase {
    if (_mnemonic == null) return [];
    return _mnemonic!.split(' ');
  }

  List<_SeedOption> options = [];
  List<bool> isSelected = [];

  @override
  void initState() {
    super.initState();
    _walletService = WalletService(
      cryptoService: WalletCryptoService(),
      storageService: WalletStorageService(),
    );
    _loadMnemonic();
  }

  Future<void> _loadMnemonic() async {
    try {
      final mnemonic = await _walletService.getMnemonic();
      if (!mounted) return;
      if (mnemonic == null || mnemonic.isEmpty) {
        _showWalletError();
        return;
      }
      setState(() => _mnemonic = mnemonic);
      _prepareOptions();
    } catch (error) {
      debugPrint('Failed to load recovery phrase: $error');
      if (!mounted) return;
      _showWalletError();
    }
  }

  void _prepareOptions() {
    if (seedPhrase.length < 9) return;
    const Set<int> mandatory = {3, 8};
    final List<_SeedOption> selected = mandatory
        .map((index) => _SeedOption(
              word: seedPhrase[index],
              originalIndex: index,
            ))
        .toList();
    final List<int> remaining = List<int>.generate(
      seedPhrase.length,
      (index) => index,
    ).where((index) => !mandatory.contains(index)).toList()
      ..shuffle();
    while (selected.length < 6) {
      final int index = remaining.removeLast();
      selected.add(_SeedOption(word: seedPhrase[index], originalIndex: index));
    }
    selected.shuffle();
    setState(() {
      options = selected;
      isSelected = List<bool>.filled(options.length, false);
    });
  }

  Set<int> get _selectedIndexes {
    final Set<int> selected = {};
    for (int i = 0; i < options.length; i++) {
      if (isSelected[i]) selected.add(options[i].originalIndex);
    }
    return selected;
  }

  bool _isSelectionCorrect() {
    final Set<int> selected = _selectedIndexes;
    return selected.length == 2 && selected.contains(3) && selected.contains(8);
  }

  void _showIncorrectSelection() {
    NotificationService.showError(
        context, 'Incorrect selection. Please try again.');
  }

  void _showWalletError() {
    NotificationService.showError(context, 'Wallet could not be loaded.');
  }

  void _continue() {
    if (_selectedIndexes.length != 2) {
      _showIncorrectSelection();
      return;
    }
    if (_isSelectionCorrect()) {
      context.pushReplacement(
        '/set_password',
        extra: (BuildContext ctx) async {
          final authController = ctx.read<AuthController>();
          await authController.authenticateWallet();
        },
      );
      return;
    }
    _showIncorrectSelection();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    if (_mnemonic == null || options.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          title: const Text('Verify Recovery Phrase'),
        ),
        body: const Center(child: GriotLoader()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Verify Recovery Phrase'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      'Verify your recovery phrase',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select the 4th and 9th words from your recovery phrase to confirm that you have written it down correctly.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    GriotBrandedContainer(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.primary.withValues(alpha: 0.12),
                            ),
                            child: Icon(
                              Icons.security_rounded,
                              color: colorScheme.primary,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select exactly 2 words',
                                  style: textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Choose the 4th and 9th words.',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Options List
                    ...options.asMap().entries.map((entry) {
                      final index = entry.key;
                      final option = entry.value;
                      final bool selected = isSelected[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {
                              setState(() {
                                if (!selected && _selectedIndexes.length >= 2) {
                                  return;
                                }
                                isSelected[index] = !selected;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? colorScheme.primary
                                    : colorScheme.surface.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(18),
                                border: selected
                                  ? Border.all(color: colorScheme.primary, width: 1.5)
                                  : Border(
                                      top: BorderSide(
                                        color: colorScheme.primary.withValues(alpha: 0.4),
                                        width: 1.2,
                                      ),
                                      bottom: BorderSide(
                                        color: colorScheme.primary.withValues(alpha: 0.4),
                                        width: 1.2,
                                      ),
                                    ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: colorScheme.primary
                                              .withValues(alpha: 0.2),
                                          blurRadius: 15,
                                          offset: const Offset(0, 5),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: selected
                                          ? colorScheme.onPrimary
                                              .withValues(alpha: 0.2)
                                          : colorScheme.onSurface
                                              .withValues(alpha: 0.05),
                                    ),
                                    child: Text(
                                      '${option.originalIndex + 1}',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: selected
                                            ? colorScheme.onPrimary
                                            : colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      option.word,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodyLarge?.copyWith(
                                        color: selected
                                            ? colorScheme.onPrimary
                                            : colorScheme.onSurface,
                                        fontWeight: selected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 150),
                                    child: Icon(
                                      selected
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked_rounded,
                                      key: ValueKey<bool>(selected),
                                      size: 24,
                                      color: selected
                                          ? colorScheme.onPrimary
                                          : colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 24),
                    GriotBrandedContainer(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Why verify?',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Verification ensures that you have accurately backed up your 12 words. Without this backup, your account and assets cannot be recovered if this device is lost.',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Fixed Bottom Area
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        _selectedIndexes.length == 2
                            ? Icons.check_circle_rounded
                            : Icons.info_outline_rounded,
                        size: 18,
                        color: _selectedIndexes.length == 2
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedIndexes.length}/2 words selected',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _continue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        'Continue',
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
