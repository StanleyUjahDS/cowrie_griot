class WalletModel {
  final String address;
  final String? displayName;
  final String? avatarUrl;

  const WalletModel({
    required this.address,
    this.displayName,
    this.avatarUrl,
  });
}