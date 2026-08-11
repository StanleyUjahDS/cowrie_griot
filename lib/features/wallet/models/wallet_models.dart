class WalletToken {
  final String name;
  final String symbol;
  final num balance;
  final num changePercent;
  final String chain;
  final String contractAddress;
  final String imageUrl;

  const WalletToken({
    required this.name,
    required this.symbol,
    required this.balance,
    required this.changePercent,
    required this.chain,
    required this.contractAddress,
    required this.imageUrl,
  });

  bool get isProfit => changePercent >= 0;
}