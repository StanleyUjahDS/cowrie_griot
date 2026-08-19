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
    return '$balance $symbol'.trim();
  }

  static String formatCurrency(num amount) {
    // Simple formatting for now, can be improved with intl package
    return '\$${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }
}
