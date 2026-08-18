// lib/features/users/models/user_model.dart

class UserModel {
  final String id;
  final String walletAddress;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;

  const UserModel({
    required this.id,
    required this.walletAddress,
    this.createdAt,
    this.updatedAt,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.bio,
  });

  factory UserModel.fromJson(
      Map<String, dynamic> json,
      ) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      walletAddress:
      json['wallet_address']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(
        json['created_at'].toString(),
      )
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(
        json['updated_at'].toString(),
      )
          : null,
      username: json['username']?.toString(),
      displayName:
      json['display_name']?.toString(),
      avatarUrl:
      json['avatar_url']?.toString(),
      bio: json['bio']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wallet_address': walletAddress,
      'created_at':
      createdAt?.toIso8601String(),
      'updated_at':
      updatedAt?.toIso8601String(),
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'bio': bio,
    };
  }

  UserModel copyWith({
    String? id,
    String? walletAddress,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
  }) {
    return UserModel(
      id: id ?? this.id,
      walletAddress:
      walletAddress ?? this.walletAddress,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      username:
      username ?? this.username,
      displayName:
      displayName ?? this.displayName,
      avatarUrl:
      avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
    );
  }
}