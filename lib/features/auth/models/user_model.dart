class UserModel {
  final dynamic id;
  final String walletAddress;
  final String walletType;

  const UserModel({
    required this.id,
    required this.walletAddress,
    required this.walletType,
  });

  factory UserModel.fromJson(
      Map<String, dynamic> json,
      ) {
    return UserModel(
      id: json['id'],
      walletAddress:
      json['walletAddress']?.toString() ?? '',
      walletType:
      json['walletType']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'walletAddress': walletAddress,
      'walletType': walletType,
    };
  }
}