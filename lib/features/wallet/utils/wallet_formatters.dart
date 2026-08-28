class WalletFormatters {
  static String shortenAddress(String address) {
    final String cleanAddress = address.trim();
    if (cleanAddress.length <= 12) {
      return cleanAddress;
    }
    return '${cleanAddress.substring(0, 6)}...'
        '${cleanAddress.substring(cleanAddress.length - 4)}';
  }

  static String formatBalance(dynamic balance, {String? symbol = '', int? decimals}) {
    final double? parsedVal = balance is num ? balance.toDouble() : double.tryParse(balance?.toString() ?? '0');
    final double val = parsedVal ?? 0.0;
    final String cleanSymbol = symbol ?? '';

    if (val == 0) {
      return cleanSymbol.isEmpty ? '0' : '0 $cleanSymbol';
    }

    // Large number shorthands
    if (val >= 1000000000) {
      final formatted = '${(val / 1000000000).toStringAsFixed(2)}B';
      return cleanSymbol.isEmpty ? formatted : '$formatted $cleanSymbol';
    }
    if (val >= 1000000) {
      final formatted = '${(val / 1000000).toStringAsFixed(2)}M';
      return cleanSymbol.isEmpty ? formatted : '$formatted $cleanSymbol';
    }

    String formatted;
    if (val < 0.000001) {
      // Very small numbers
      formatted = val.toStringAsFixed(8);
    } else if (val < 0.01) {
      // Small/Dust
      formatted = val.toStringAsFixed(6);
    } else if (val < 1.0) {
      // Standard sub-zero
      formatted = val.toStringAsFixed(4);
    } else {
      // Main tokens: use 2 decimals if it's large, up to 4 if smaller than 1000
      formatted = val >= 1000 ? val.toStringAsFixed(2) : val.toStringAsFixed(4);
    }

    // Remove trailing zeros
    if (formatted.contains('.')) {
      formatted = formatted.replaceAll(RegExp(r'0+$'), '');
      if (formatted.endsWith('.')) {
        formatted = formatted.substring(0, formatted.length - 1);
      }
    }

    // Add thousands separators for the whole part
    final parts = formatted.split('.');
    String wholePart = parts[0];
    
    // Add commas only if it's a valid integer string
    if (RegExp(r'^\d+$').hasMatch(wholePart)) {
      wholePart = wholePart.replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    }

    final String finalValue = parts.length == 2
        ? '$wholePart.${parts[1]}'
        : wholePart;

    return cleanSymbol.isEmpty ? finalValue : '$finalValue $cleanSymbol';
  }

  static String formatCurrency(num? amount, {bool isUnitPrice = false}) {
    if (amount == null) return '--';
    final double val = amount.toDouble();
    
    if (val == 0) return '\$0.00';

    String formatted;
    if (isUnitPrice) {
      if (val >= 1.0) {
        formatted = val.toStringAsFixed(2);
      } else if (val >= 0.0001) {
        formatted = val.toStringAsFixed(4);
      } else {
        formatted = val.toStringAsFixed(8);
      }
    } else {
      formatted = val.toStringAsFixed(2);
    }

    // Add thousands separators
    final parts = formatted.split('.');
    String wholePart = parts[0];
    wholePart = wholePart.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    return '\$${parts.length == 2 ? '$wholePart.${parts[1]}' : wholePart}';
  }
}
