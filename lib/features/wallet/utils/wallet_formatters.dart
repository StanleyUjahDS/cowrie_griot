class WalletFormatters {
  static String shortenAddress(String address) {
    final String cleanAddress = address.trim();
    if (cleanAddress.length <= 12) {
      return cleanAddress;
    }
    return '${cleanAddress.substring(0, 6)}...'
        '${cleanAddress.substring(cleanAddress.length - 4)}';
  }

  static String formatBalance(num balance, {String symbol = ''}) {
    final double val = balance.toDouble();
    if (val == 0) {
      return symbol.isEmpty ? '0.00' : '0.00 $symbol';
    }

    String formatted;
    if (val < 0.001) {
      formatted = val.toStringAsFixed(6);
    } else if (val < 1.0) {
      formatted = val.toStringAsFixed(4);
    } else {
      formatted = val.toStringAsFixed(3);
    }

    // Clean up trailing zeros in decimal part to keep it compact and neat
    if (formatted.contains('.')) {
      formatted = formatted.replaceAll(RegExp(r'0+$'), '');
      if (formatted.endsWith('.')) {
        formatted = formatted.substring(0, formatted.length - 1);
      }
    }

    // Format with thousands separator
    final parts = formatted.split('.');
    final int? wholeVal = int.tryParse(parts[0].replaceAll(RegExp(r'\D'), ''));
    if (wholeVal == null) return symbol.isEmpty ? formatted : '$formatted $symbol';

    final String formattedWhole = wholeVal.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    // Reconstruct final string with decimals
    final String finalValue = parts.length == 2
        ? '$formattedWhole.${parts[1]}'
        : formattedWhole;

    return symbol.isEmpty ? finalValue : '$finalValue $symbol';
  }

  static String formatCurrency(num amount) {
    // Simple formatting for now, can be improved with intl package
    return '\$${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }
}
