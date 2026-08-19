class TokenModel {
  final String name;
  final String symbol;
  final num balance;
  final num changePercent;
  final String chain;
  final String contractAddress;
  final String imageUrl;
  final num valueUsd;

  const TokenModel({
    required this.name,
    required this.symbol,
    required this.balance,
    required this.changePercent,
    required this.chain,
    required this.contractAddress,
    required this.imageUrl,
    this.valueUsd = 0,
  });

  bool get isProfit => changePercent >= 0;

  double get value => valueUsd.toDouble(); 
}
