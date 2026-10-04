/// Human-friendly formatting for tip messages and activity entries.
///
/// The underlying transaction metadata keeps its exact base-unit values; this
/// helper only shortens what people read in the app.
class TipDisplay {
  static final RegExp _numberPattern = RegExp(r'(?<![\w.])-?\d+\.\d+');
  static final RegExp _walletAddressPattern = RegExp(r'^0x[a-fA-F0-9]{40}$');

  static String amount(String value, {int maxFractionDigits = 4}) {
    return value.replaceAllMapped(_numberPattern, (match) {
      final raw = match.group(0)!;
      final decimalIndex = raw.indexOf('.');
      final whole = raw.substring(0, decimalIndex);
      final fraction = raw.substring(decimalIndex + 1);
      if (fraction.length <= maxFractionDigits) return raw;

      // Preserve meaningful digits for very small balances instead of
      // rendering them as zero.
      final firstSignificant = fraction.indexOf(RegExp(r'[1-9]'));
      final keep = whole == '0' && firstSignificant >= maxFractionDigits
          ? firstSignificant + maxFractionDigits
          : maxFractionDigits;
      final shortened = fraction
          .substring(0, keep)
          .replaceFirst(RegExp(r'0+$'), '');
      return shortened.isEmpty ? whole : '$whole.$shortened';
    });
  }

  static String person({String? username, String? displayName}) {
    final cleanUsername = username?.trim();
    if (cleanUsername != null &&
        cleanUsername.isNotEmpty &&
        !_walletAddressPattern.hasMatch(cleanUsername)) {
      return cleanUsername.startsWith('@')
          ? cleanUsername.substring(1)
          : cleanUsername;
    }

    final cleanDisplayName = displayName?.trim();
    if (cleanDisplayName != null &&
        cleanDisplayName.isNotEmpty &&
        !_walletAddressPattern.hasMatch(cleanDisplayName)) {
      return cleanDisplayName;
    }
    return 'Griot user';
  }
}
