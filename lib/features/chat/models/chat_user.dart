import 'package:griot_cowrie/features/users/models/user_model.dart';

class ChatUser {
  final String id;
  final String walletAddress;
  final String? username;
  final String? displayName;
  final String? profileUrl;
  final bool isOnline;
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;
  final String? relationshipStatus;
  final bool isDiscoverableByPhone;
  final String? phoneNumber;
  final bool phoneDiscoveryEnabled;
  final UserReputationBadge? reputation;

  const ChatUser({
    required this.id,
    required this.walletAddress,
    this.username,
    this.displayName,
    this.profileUrl,
    this.isOnline = false,
    this.lastMessage = '',
    required this.timestamp,
    this.unreadCount = 0,
    this.relationshipStatus,
    this.isDiscoverableByPhone = false,
    this.phoneNumber,
    this.phoneDiscoveryEnabled = false,
    this.reputation,
  });

  String get effectiveDisplayName {
    if (displayName != null && displayName!.isNotEmpty) return displayName!;
    if (username != null && username!.isNotEmpty) return username!;
    return 'Griot User';
  }
  
  String? get formattedUsername => username != null ? '@$username' : null;

  String get shortWalletAddress {
    if (walletAddress.length <= 8) return walletAddress;
    return '${walletAddress.substring(0, 3)}...'
        '${walletAddress.substring(walletAddress.length - 3)}';
  }

  UserModel toUserModel() {
    return UserModel(
      id: id,
      walletAddress: walletAddress,
      username: username,
      displayName: displayName,
      avatarUrl: profileUrl,
      reputation: reputation,
      relationshipStatus: relationshipStatus,
    );
  }

  factory ChatUser.fromUserModel(UserModel user) {
    return ChatUser(
      id: user.id,
      walletAddress: user.walletAddress,
      username: user.username,
      displayName: user.displayName,
      profileUrl: user.avatarUrl,
      reputation: user.reputation,
      relationshipStatus: user.relationshipStatus,
      timestamp: DateTime.now(),
    );
  }

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      id: (json['id'] ?? json['userId'])?.toString() ?? '',
      walletAddress: (json['walletAddress'] ?? json['wallet_address'] ?? '').toString(),
      username: (json['username'] ?? json['other_username'])?.toString(),
      displayName: (json['displayName'] ?? json['display_name'] ?? json['other_display_name'])?.toString(),
      profileUrl: (json['profileUrl'] ?? json['avatarUrl'] ?? json['profile_url'] ?? json['other_avatar_url'])?.toString(),
      isOnline: json['isOnline'] == true || json['is_online'] == true,
      lastMessage: (json['lastMessage'] ?? json['last_message'] ?? '')?.toString() ?? '',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'].toString()) 
          : (json['last_message_at'] != null ? DateTime.parse(json['last_message_at'].toString()) : DateTime.now()),
      unreadCount: (json['unreadCount'] ?? json['unread_count'] ?? 0) as int,
      relationshipStatus: (json['relationshipStatus'] ?? json['relationship_status'])?.toString(),
      isDiscoverableByPhone: json['isDiscoverableByPhone'] == true || json['is_discoverable_by_phone'] == true,
      phoneNumber: (json['phoneNumber'] ?? json['phone_number'])?.toString(),
      phoneDiscoveryEnabled: json['phoneDiscoveryEnabled'] == true || json['phone_discovery_enabled'] == true,
      reputation: json['reputation'] != null 
          ? UserReputationBadge.fromJson(Map<String, dynamic>.from(json['reputation'])) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'walletAddress': walletAddress,
      'username': username,
      'displayName': displayName,
      'profileUrl': profileUrl,
      'isOnline': isOnline,
      'lastMessage': lastMessage,
      'timestamp': timestamp.toIso8601String(),
      'unreadCount': unreadCount,
      'relationshipStatus': relationshipStatus,
      'isDiscoverableByPhone': isDiscoverableByPhone,
      'phoneNumber': phoneNumber,
      'phoneDiscoveryEnabled': phoneDiscoveryEnabled,
      'reputation': reputation?.toJson(),
    };
  }

  ChatUser copyWith({
    String? id,
    String? walletAddress,
    String? username,
    String? displayName,
    String? profileUrl,
    bool? isOnline,
    String? lastMessage,
    DateTime? timestamp,
    int? unreadCount,
    String? relationshipStatus,
    bool? isDiscoverableByPhone,
    String? phoneNumber,
    bool? phoneDiscoveryEnabled,
    UserReputationBadge? reputation,
  }) {
    return ChatUser(
      id: id ?? this.id,
      walletAddress: walletAddress ?? this.walletAddress,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      profileUrl: profileUrl ?? this.profileUrl,
      isOnline: isOnline ?? this.isOnline,
      lastMessage: lastMessage ?? this.lastMessage,
      timestamp: timestamp ?? this.timestamp,
      unreadCount: unreadCount ?? this.unreadCount,
      relationshipStatus: relationshipStatus ?? this.relationshipStatus,
      isDiscoverableByPhone: isDiscoverableByPhone ?? this.isDiscoverableByPhone,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      phoneDiscoveryEnabled: phoneDiscoveryEnabled ?? this.phoneDiscoveryEnabled,
      reputation: reputation ?? this.reputation,
    );
  }
}
