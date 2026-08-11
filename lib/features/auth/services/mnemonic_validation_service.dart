import 'package:bip39_mnemonic/bip39_mnemonic.dart';

class MnemonicValidationService {
  // ============================================================
  // NORMALIZE WORD
  // ============================================================

  String normalizeWord(String word) {
    return word.trim().toLowerCase();
  }

  // ============================================================
  // VALIDATE INDIVIDUAL BIP-39 WORD
  // ============================================================

  bool isValidWord(String word) {
    final normalized = normalizeWord(word);

    if (normalized.isEmpty) {
      return false;
    }

    return Language.english.isValid(normalized);
  }

  // ============================================================
  // VALIDATE COMPLETE 12-WORD PHRASE
  // ============================================================

  bool isValidPhrase(List<String> words) {
    if (words.length != 12) {
      return false;
    }

    final normalizedWords = words
        .map(normalizeWord)
        .toList();

    if (normalizedWords.any(
          (word) => word.isEmpty,
    )) {
      return false;
    }

    // First check every word belongs to BIP-39.
    if (normalizedWords.any(
          (word) => !isValidWord(word),
    )) {
      return false;
    }

    // Then check the complete mnemonic checksum.
    final mnemonic = normalizedWords.join(' ');

    try {
      final mnemonicObject = Mnemonic.fromSentence(
        mnemonic,
        Language.english,
      );

      return mnemonicObject.sentence == mnemonic;
    } catch (_) {
      return false;
    }
  }
}