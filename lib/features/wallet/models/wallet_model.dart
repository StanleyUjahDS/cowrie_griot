class WalletModel {
  final String address;
  final String? displayName;
  final String? avatarUrl;

  /// Total live wallet value in USD.
  final num totalBalance;

  /// Portfolio change percentage.
  final num changePercent;

  const WalletModel({
    required this.address,
    this.displayName,
    this.avatarUrl,
    this.totalBalance = 0,
    this.changePercent = 0,
  });

  WalletModel copyWith({
    String? address,
    String? displayName,
    String? avatarUrl,
    num? totalBalance,
    num? changePercent,
  }) {
    return WalletModel(
      address: address ?? this.address,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      totalBalance:
          totalBalance ?? this.totalBalance,
      changePercent:
          changePercent ?? this.changePercent,
    );
  }
}
