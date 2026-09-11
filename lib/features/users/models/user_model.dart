// lib/features/users/models/user_model.dart

class UserReputationBadge {
  final String tierName;
  final String badgeColor;

  const UserReputationBadge({required this.tierName, required this.badgeColor});

  factory UserReputationBadge.fromJson(Map<String, dynamic> json) {
    return UserReputationBadge(
      tierName:
          (json['tierName'] ?? json['tier_name'] ?? json['name'])?.toString() ??
          '',
      badgeColor:
          (json['badgeColor'] ?? json['badge_color'] ?? json['color'])
              ?.toString() ??
          '#64748B',
    );
  }

  Map<String, dynamic> toJson() {
    return {'tierName': tierName, 'badgeColor': badgeColor};
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
  final bool isOnline;

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
    this.isOnline = false,
  });

  String get effectiveName {
    if (displayName != null && displayName!.trim().isNotEmpty) return displayName!.trim();
    if (username != null && username!.trim().isNotEmpty) return username!.trim();
    return shortWalletAddress;
  }

  String get formattedUsername {
    if (username == null || username!.trim().isEmpty) return '';
    final u = username!.trim();
    if (u.startsWith('@')) return u;
    return '@$u';
  }

  String get shortWalletAddress {
    if (walletAddress.length <= 8) return walletAddress;
    return '${walletAddress.substring(0, 3)}...'
        '${walletAddress.substring(walletAddress.length - 3)}';
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final String? rawAvatarUrl = (json['avatarUrl'] ??
            json['avatar_url'] ??
            json['profileUrl'] ??
            json['profile_url'] ??
            json['other_avatar_url'])
        ?.toString();
    final String? avatarUrl =
        (rawAvatarUrl != null && rawAvatarUrl.trim().isNotEmpty)
            ? rawAvatarUrl.trim()
            : null;

    return UserModel(
      id: (json['id'] ?? json['userId'] ?? json['user_id'] ?? '').toString(),
      walletAddress:
          (json['walletAddress'] ?? json['wallet_address'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? json['created_at']) != null
          ? DateTime.tryParse(
              (json['createdAt'] ?? json['created_at']).toString(),
            )
          : null,
      updatedAt: (json['updatedAt'] ?? json['updated_at']) != null
          ? DateTime.tryParse(
              (json['updatedAt'] ?? json['updated_at']).toString(),
            )
          : null,
      username: (json['username'] ?? json['other_username'])?.toString(),
      displayName: (json['displayName'] ??
              json['display_name'] ??
              json['other_display_name'])
          ?.toString(),
      avatarUrl: avatarUrl,
      bio: (json['bio'] ?? json['userBio'] ?? json['user_bio'])?.toString(),
      reputation: json['reputation'] is Map
          ? UserReputationBadge.fromJson(
              Map<String, dynamic>.from(json['reputation']),
            )
          : null,
      relationshipStatus:
          (json['relationshipStatus'] ?? json['relationship_status'])
              ?.toString(),
      isOnline: json['isOnline'] == true || json['is_online'] == true,
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
      'isOnline': isOnline,
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
    String? relationshipStatus,
    bool? isOnline,
  }) {
    return UserModel(
      id: id ?? this.id,
      walletAddress: walletAddress ?? this.walletAddress,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      reputation: reputation ?? this.reputation,
      relationshipStatus: relationshipStatus ?? this.relationshipStatus,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
