import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/ui/widgets/griot_branded_container.dart';
import '/features/wallet/services/wallet_crypto_service.dart';

class DisplayPhraseScreen extends StatelessWidget {
  final WalletData wallet;

  const DisplayPhraseScreen({
    super.key,
    required this.wallet,
  });

  Future<void> _copyPhrase(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: wallet.mnemonic));
    if (!context.mounted) return;
    NotificationService.showSuccess(context, 'Recovery phrase copied');
  }

  void _continue(BuildContext context) {
    context.push('/verify_phrase', extra: wallet);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final bool isDark = theme.brightness == Brightness.dark;

    final Color wordColor = isDark
        ? Colors.white.withValues(alpha: 0.055)
        : Colors.black.withValues(alpha: 0.025);

    final Color borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);

    final Color mutedColor =
        colorScheme.onSurfaceVariant.withValues(alpha: 0.78);

    final List<String> seedPhrase = wallet.mnemonic.split(' ');

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Recovery Phrase',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                child: Column(
                  children: [
                    Text(
                      'Write down your recovery phrase',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'These 12 words are the only way to recover '
                      'your wallet if you lose access to this device.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: mutedColor,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    GriotBrandedContainer(
                      padding: const EdgeInsets.all(16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: seedPhrase.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 3.2,
                        ),
                        itemBuilder: (context, index) {
                          final String word = seedPhrase[index];

                          return Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: wordColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border(
                                top: BorderSide(
                                  color: colorScheme.primary.withValues(alpha: 0.2),
                                  width: 1.0,
                                ),
                                bottom: BorderSide(
                                  color: colorScheme.primary.withValues(alpha: 0.2),
                                  width: 1.0,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 25,
                                  child: Text(
                                    '${index + 1}.',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: mutedColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      word,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurface,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () => _copyPhrase(context),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy Phrase'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.onSurface,
                        side: BorderSide(color: borderColor, width: 1.5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    GriotBrandedContainer(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.lock_outline_rounded,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Keep it private',
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Never share your recovery phrase. '
                                  'Griot will never ask you for these words.',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: mutedColor,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    GriotBrandedContainer(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'What is a Recovery Phrase?',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'A recovery phrase is a set of 12 unique words that acts as a master key to your digital assets. Think of it as a physical key to a safe that only you possess.',
                            style: textTheme.bodySmall?.copyWith(
                              color: mutedColor,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Why is it important?',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Griot is a non-custodial wallet, which means we do not store your keys. If you lose your phone or delete the app, these words are the ONLY way to get your money and messages back.',
                            style: textTheme.bodySmall?.copyWith(
                              color: mutedColor,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _continue(context),
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
            ),
          ],
        ),
      ),
    );
  }
}
