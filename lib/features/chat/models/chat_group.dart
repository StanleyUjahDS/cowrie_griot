class ChatGroup {
  final String id;
  final String name;
  final String description;

  /// Wallet address of the group creator/admin.
  final String ownerWalletAddress;

  /// Optional group image.
  final String? imageUrl;

  final String lastMessage;
  final DateTime? lastMessageAt;

  final int memberCount;
  final int unreadCount;

  final bool isPrivate;
  final bool isMuted;

  const ChatGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerWalletAddress,
    this.imageUrl,
    required this.lastMessage,
    this.lastMessageAt,
    this.memberCount = 0,
    this.unreadCount = 0,
    this.isPrivate = true,
    this.isMuted = false,
  });

  // ==========================================================
  // HELPERS
  // ==========================================================

  bool get hasUnreadMessages {
    return unreadCount > 0;
  }

  bool get hasImage {
    return imageUrl != null &&
        imageUrl!.trim().isNotEmpty;
  }

  // ==========================================================
  // COPY WITH
  // ==========================================================

  ChatGroup copyWith({
    String? id,
    String? name,
    String? description,
    String? ownerWalletAddress,
    String? imageUrl,
    String? lastMessage,
    DateTime? lastMessageAt,
    int? memberCount,
    int? unreadCount,
    bool? isPrivate,
    bool? isMuted,
  }) {
    return ChatGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      description:
      description ?? this.description,
      ownerWalletAddress:
      ownerWalletAddress ??
          this.ownerWalletAddress,
      imageUrl:
      imageUrl ?? this.imageUrl,
      lastMessage:
      lastMessage ?? this.lastMessage,
      lastMessageAt:
      lastMessageAt ?? this.lastMessageAt,
      memberCount:
      memberCount ?? this.memberCount,
      unreadCount:
      unreadCount ?? this.unreadCount,
      isPrivate:
      isPrivate ?? this.isPrivate,
      isMuted:
      isMuted ?? this.isMuted,
    );
  }

  // ==========================================================
  // FROM JSON
  // ==========================================================

  factory ChatGroup.fromJson(
      Map<String, dynamic> json,
      ) {
    return ChatGroup(
      id: json['id']?.toString() ?? '',

      name:
      json['name']?.toString() ?? '',

      description:
      json['description']?.toString() ?? '',

      ownerWalletAddress:
      json['ownerWalletAddress']
          ?.toString() ??
          '',

      imageUrl:
      json['imageUrl']?.toString(),

      lastMessage:
      json['lastMessage']?.toString() ?? '',

      lastMessageAt:
      json['lastMessageAt'] != null
          ? DateTime.tryParse(
        json['lastMessageAt']
            .toString(),
      )
          : null,

      memberCount:
      _parseInt(
        json['memberCount'],
      ),

      unreadCount:
      _parseInt(
        json['unreadCount'],
      ),

      isPrivate:
      json['isPrivate'] ?? true,

      isMuted:
      json['isMuted'] ?? false,
    );
  }

  // ==========================================================
  // TO JSON
  // ==========================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'ownerWalletAddress':
      ownerWalletAddress,
      'imageUrl': imageUrl,
      'lastMessage': lastMessage,
      'lastMessageAt':
      lastMessageAt?.toIso8601String(),
      'memberCount': memberCount,
      'unreadCount': unreadCount,
      'isPrivate': isPrivate,
      'isMuted': isMuted,
    };
  }

  // ==========================================================
  // INTEGER PARSER
  // ==========================================================

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
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

    return other is ChatGroup &&
        other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // ==========================================================
  // DEBUG
  // ==========================================================

  @override
  String toString() {
    return 'ChatGroup('
        'id: $id, '
        'name: $name, '
        'members: $memberCount'
        ')';
  }
}