// lib/features/users/models/user_model.dart

class UserReputationBadge {
  final String tierName;
  final String badgeColor;

  const UserReputationBadge({
    required this.tierName,
    required this.badgeColor,
  });

  factory UserReputationBadge.fromJson(Map<String, dynamic> json) {
    return UserReputationBadge(
      tierName: (json['tierName'] ?? json['tier_name'] ?? json['name'])?.toString() ?? '',
      badgeColor: (json['badgeColor'] ?? json['badge_color'] ?? json['color'])?.toString() ?? '#64748B',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tierName': tierName,
      'badgeColor': badgeColor,
    };
  }
}

class UserModel {
  final String id;
  final String walletAddress;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final UserReputationBadge? reputation;

  const UserModel({
    required this.id,
    required this.walletAddress,
    this.createdAt,
    this.updatedAt,
    this.username,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.reputation,
  });

  factory UserModel.fromJson(
      Map<String, dynamic> json,
      ) {
    final reputationJson = json['reputation'];

    return UserModel(
      id: json['id']?.toString() ?? '',
      walletAddress:
      (json['wallet_address'] ?? json['walletAddress'])?.toString() ?? '',
      createdAt: (json['created_at'] ?? json['createdAt']) != null
          ? DateTime.tryParse(
        (json['created_at'] ?? json['createdAt']).toString(),
      )
          : null,
      updatedAt: (json['updated_at'] ?? json['updatedAt']) != null
          ? DateTime.tryParse(
        (json['updated_at'] ?? json['updatedAt']).toString(),
      )
          : null,
      username: json['username']?.toString(),
      displayName:
      (json['display_name'] ?? json['displayName'])?.toString(),
      avatarUrl:
      (json['avatar_url'] ?? json['avatarUrl'])?.toString(),
      bio: json['bio']?.toString(),
      reputation: reputationJson is Map
          ? UserReputationBadge.fromJson(
        Map<String, dynamic>.from(reputationJson),
      )
          : null,
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
      'reputation': reputation?.toJson(),
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
    UserReputationBadge? reputation,
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
      reputation: reputation ?? this.reputation,
    );
  }
}
