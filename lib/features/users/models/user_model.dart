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
  final String? relationshipStatus;

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
    this.relationshipStatus,
  });

  factory UserModel.fromJson(
      Map<String, dynamic> json,
      ) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      walletAddress: (json['walletAddress'] ?? json['wallet_address'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? json['created_at']) != null
          ? DateTime.tryParse((json['createdAt'] ?? json['created_at']).toString())
          : null,
      updatedAt: (json['updatedAt'] ?? json['updated_at']) != null
          ? DateTime.tryParse((json['updatedAt'] ?? json['updated_at']).toString())
          : null,
      username: json['username']?.toString(),
      displayName: json['displayName'] ?? json['display_name']?.toString(),
      avatarUrl: json['avatarUrl'] ?? json['avatar_url']?.toString(),
      bio: json['bio']?.toString(),
      reputation: json['reputation'] is Map
          ? UserReputationBadge.fromJson(Map<String, dynamic>.from(json['reputation']))
          : null,
      relationshipStatus: json['relationshipStatus'] ?? json['relationship_status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'walletAddress': walletAddress,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'username': username,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'reputation': reputation?.toJson(),
      'relationshipStatus': relationshipStatus,
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
