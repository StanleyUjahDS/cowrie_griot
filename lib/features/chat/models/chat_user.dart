class ChatUser {
  // ==========================================================
  // IDENTITY
  // ==========================================================

  final String id;

  /// Wallet address is the primary identity.
  final String walletAddress;

  /// Optional username.
  final String? username;

  /// Optional display name.
  final String? displayName;

  // ==========================================================
  // PHONE DISCOVERY
  // ==========================================================

  final String? phoneNumber;

  final bool phoneDiscoveryEnabled;

  // ==========================================================
  // PROFILE
  // ==========================================================

  final String? profileUrl;

  // ==========================================================
  // CHAT PREVIEW
  // ==========================================================

  final String lastMessage;

  final DateTime timestamp;

  final int unreadCount;

  // ==========================================================
  // PRESENCE
  // ==========================================================

  final bool isOnline;

  // ==========================================================
  // CONSTRUCTOR
  // ==========================================================

  const ChatUser({
    required this.id,
    required this.walletAddress,
    this.username,
    this.displayName,
    this.phoneNumber,
    this.phoneDiscoveryEnabled = false,
    this.profileUrl,
    this.lastMessage = '',
    required this.timestamp,
    this.unreadCount = 0,
    this.isOnline = false,
  });

  // ==========================================================
  // EFFECTIVE DISPLAY NAME
  // ==========================================================

  String get effectiveDisplayName {
    final name = displayName?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    final user = username?.trim();

    if (user != null && user.isNotEmpty) {
      return user.startsWith('@')
          ? user
          : '@$user';
    }

    return shortWalletAddress;
  }

  // ==========================================================
  // FORMATTED USERNAME
  // ==========================================================

  String? get formattedUsername {
    final value = username?.trim();

    if (value == null || value.isEmpty) {
      return null;
    }

    if (value.startsWith('@')) {
      return value;
    }

    return '@$value';
  }

  // ==========================================================
  // SHORT WALLET ADDRESS
  // ==========================================================

  String get shortWalletAddress {
    if (walletAddress.length <= 12) {
      return walletAddress;
    }

    return '${walletAddress.substring(0, 6)}...'
        '${walletAddress.substring(
      walletAddress.length - 4,
    )}';
  }

  // ==========================================================
  // PHONE DISCOVERY
  // ==========================================================

  bool get isDiscoverableByPhone {
    final phone = phoneNumber?.trim();

    return phone != null &&
        phone.isNotEmpty &&
        phoneDiscoveryEnabled;
  }

  // ==========================================================
  // COPY WITH
  // ==========================================================

  ChatUser copyWith({
    String? id,
    String? walletAddress,
    String? username,
    String? displayName,
    String? phoneNumber,
    bool? phoneDiscoveryEnabled,
    String? profileUrl,
    String? lastMessage,
    DateTime? timestamp,
    int? unreadCount,
    bool? isOnline,
  }) {
    return ChatUser(
      id: id ?? this.id,
      walletAddress:
      walletAddress ?? this.walletAddress,
      username:
      username ?? this.username,
      displayName:
      displayName ?? this.displayName,
      phoneNumber:
      phoneNumber ?? this.phoneNumber,
      phoneDiscoveryEnabled:
      phoneDiscoveryEnabled ??
          this.phoneDiscoveryEnabled,
      profileUrl:
      profileUrl ?? this.profileUrl,
      lastMessage:
      lastMessage ?? this.lastMessage,
      timestamp:
      timestamp ?? this.timestamp,
      unreadCount:
      unreadCount ?? this.unreadCount,
      isOnline:
      isOnline ?? this.isOnline,
    );
  }

  // ==========================================================
  // JSON
  // ==========================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'walletAddress': walletAddress,
      'username': username,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'phoneDiscoveryEnabled':
      phoneDiscoveryEnabled,
      'profileUrl': profileUrl,
      'lastMessage': lastMessage,
      'timestamp':
      timestamp.toIso8601String(),
      'unreadCount': unreadCount,
      'isOnline': isOnline,
    };
  }

  // ==========================================================
  // FROM JSON
  // ==========================================================

  factory ChatUser.fromJson(
      Map<String, dynamic> json,
      ) {
    return ChatUser(
      id:
      json['id'] as String,

      walletAddress:
      json['walletAddress'] as String,

      username:
      json['username'] as String?,

      displayName:
      json['displayName'] as String?,

      phoneNumber:
      json['phoneNumber'] as String?,

      phoneDiscoveryEnabled:
      json['phoneDiscoveryEnabled']
      as bool? ??
          false,

      profileUrl:
      json['profileUrl'] as String?,

      lastMessage:
      json['lastMessage'] as String? ??
          '',

      timestamp:
      DateTime.parse(
        json['timestamp'] as String,
      ),

      unreadCount:
      json['unreadCount'] as int? ??
          0,

      isOnline:
      json['isOnline'] as bool? ??
          false,
    );
  }

  // ==========================================================
  // EQUALITY
  // ==========================================================

  @override
  bool operator ==(
      Object other,
      ) {
    if (identical(this, other)) {
      return true;
    }

    return other is ChatUser &&
        other.walletAddress
            .toLowerCase() ==
            walletAddress.toLowerCase();
  }

  @override
  int get hashCode {
    return walletAddress
        .toLowerCase()
        .hashCode;
  }

  // ==========================================================
  // DEBUG
  // ==========================================================

  @override
  String toString() {
    return 'ChatUser('
        'walletAddress: $walletAddress, '
        'username: $username, '
        'displayName: $displayName, '
        'phoneDiscoveryEnabled: '
        '$phoneDiscoveryEnabled'
        ')';
  }
}