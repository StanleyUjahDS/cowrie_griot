class WalletModel {
  final String address;
  final String? displayName;
  final String? avatarUrl;
  final num totalBalance;
  final num changePercent;

  const WalletModel({
    required this.address,
    this.displayName,
    this.avatarUrl,
    this.totalBalance = 0,
    this.changePercent = 0,
  });
}
