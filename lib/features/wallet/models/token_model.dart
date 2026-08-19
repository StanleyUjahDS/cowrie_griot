class TokenModel {
  final String name;
  final String symbol;

  /// Human-readable token balance.
  final num balance;

  /// Current USD value of this wallet holding.
  final num valueUsd;

  /// Percentage price change.
  final num changePercent;

  /// Network/chain identifier.
  final String chain;

  /// Token contract address.
  ///
  /// Empty string means this is a native asset.
  final String contractAddress;

  /// Token logo URL.
  final String imageUrl;

  const TokenModel({
    required this.name,
    required this.symbol,
    required this.balance,
    required this.valueUsd,
    required this.changePercent,
    required this.chain,
    required this.contractAddress,
    required this.imageUrl,
  });

  bool get isNative =>
      contractAddress.isEmpty;

  bool get isProfit =>
      changePercent >= 0;

  double get value =>
      valueUsd.toDouble();

  factory TokenModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return TokenModel(
      name: _string(json['name']),
      symbol: _string(json['symbol']),

      balance: _num(
        json['balance'],
      ),

      valueUsd: _num(
        json['valueUsd'] ??
        json['balanceUsd'] ??
        json['usdValue'] ??
        0,
      ),

      changePercent: _num(
        json['changePercent'] ??
        json['priceChangePercent'] ??
        0,
      ),

      chain: _string(
        json['chain'] ??
        json['network'],
      ),

      contractAddress: _string(
        json['contractAddress'] ??
        json['tokenAddress'],
      ),

      imageUrl: _string(
        json['imageUrl'] ??
        json['logo'] ??
        json['logoUrl'],
      ),
    );
  }

  static String _string(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString();
  }

  static num _num(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value;
    }

    return num.tryParse(
          value.toString(),
        ) ??
        0;
  }
}
