class TokenAssets {
  static const String _coinPath = 'assets/coins_logo';

  /// Frontend-owned token display registry.
  ///
  /// Only tokens explicitly registered here may use a local token logo.
  /// Unknown tokens intentionally fall back to their own initials.
  static const Map<String, String> _logosBySymbol = {
    'HBADG': 'assets/chains/Hbadger.svg',
    'COWRIE': '$_coinPath/Cowrie.svg',
  };

  static String? getLogo(String symbol) {
    final key = symbol.trim().toUpperCase();
    if (key.isEmpty) return null;
    return _logosBySymbol[key];
  }
}
