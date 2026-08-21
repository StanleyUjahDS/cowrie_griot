class TokenModel {
  final String name;
  final String symbol;
  final num balance;
  final num priceUsd;
  final num valueUsd;
  final num changePercent;
  final String chain;
  final String contractAddress;
  final String imageUrl;
  final int decimals;
  final bool hasMarketData;
  final bool isSpam;
  final Map<String, dynamic>? security;

  const TokenModel({
    required this.name,
    required this.symbol,
    required this.balance,
    this.priceUsd = 0,
    required this.valueUsd,
    required this.changePercent,
    required this.chain,
    required this.contractAddress,
    required this.imageUrl,
    this.decimals = 18,
    this.hasMarketData = false,
    this.isSpam = false,
    this.security,
  });

  bool get isNative => contractAddress.isEmpty;

  bool get isProfit => changePercent >= 0;

  double get value => valueUsd.toDouble();

  factory TokenModel.fromJson(Map<String, dynamic> json) {
    final hasPrice =
        json['priceUsd'] != null || json['price'] != null;
    final hasChange =
        json['changePercent24h'] != null ||
        json['changePercent'] != null ||
        json['priceChangePercent'] != null;
    final hasValue =
        json['valueUsd'] != null ||
        json['balanceUsd'] != null ||
        json['usdValue'] != null;

    final securityData = json['security'] is Map ? Map<String, dynamic>.from(json['security']) : null;

    return TokenModel(
      name: _string(json['name']),
      symbol: _string(json['symbol']),
      balance: _num(json['balance']),
      priceUsd: _num(json['priceUsd'] ?? json['price']),
      valueUsd: _num(
        json['valueUsd'] ??
            json['balanceUsd'] ??
            json['usdValue'],
      ),
      changePercent: _num(
        json['changePercent24h'] ??
            json['changePercent'] ??
            json['priceChangePercent'],
      ),
      chain: _string(json['chain'] ?? json['network']),
      contractAddress: _string(
        json['contractAddress'] ?? json['tokenAddress'],
      ),
      imageUrl: _string(
        json['imageUrl'] ??
            json['logo'] ??
            json['logoUrl'],
      ),
      decimals: _resolveDecimals(
        _string(json['symbol']),
        _int(json['decimals'], fallback: 18),
      ),
      hasMarketData: hasPrice || hasChange || hasValue,
      isSpam: json['isSpam'] == true || (securityData != null && securityData['isSpam'] == true),
      security: securityData,
    );
  }

  static String _string(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static num _num(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    return num.tryParse(value.toString()) ?? 0;
  }

  static int _int(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int _resolveDecimals(String symbol, int defaultDecimals) {
    final cleanSymbol = symbol.trim().toUpperCase();
    if (cleanSymbol == 'USDT' || cleanSymbol == 'USDC' || cleanSymbol == 'USDC.E') {
      return 6;
    }
    if (cleanSymbol == 'WBTC') {
      return 8;
    }
    return defaultDecimals;
  }
}
