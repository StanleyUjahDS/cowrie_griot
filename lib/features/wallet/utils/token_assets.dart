class TokenAssets {
  static const String _coinPath = 'assets/coins_logo';

  /// Frontend-owned token display registry.
  ///
  /// Only tokens explicitly registered here may use a local token logo.
  /// Unknown tokens intentionally fall back to their own initials.
  static const Map<String, String> _logosBySymbol = {
    'HBADG': '$_coinPath/hbadger_logo.png',
    'COWRIE': '$_coinPath/Cowrie.svg',
    'USDT': '$_coinPath/usdt.svg',
    'USDC': '$_coinPath/usdc.svg',
  };

  static String? getLogo(String symbol) {
    final key = symbol.trim().toUpperCase();
    if (key.isEmpty) return null;
    return _logosBySymbol[key];
  }
}
