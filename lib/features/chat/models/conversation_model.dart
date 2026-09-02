import 'chat_user.dart';
import 'chat_message.dart';

enum ConversationType {
  dm,
  group,
  channel,
}

class Conversation {
  final String id;
  final ConversationType type;
  final String? title;
  final String? avatarUrl;
  final List<String> memberIds;
  final String? ownerId;
  final String visibility;
  final String? role;
  final String? status;
  final int memberCount;
  final int subscriberCount;
  final String? username;
  final String? description;
  
  /// For DMs, this is the other user's info if available.
  final ChatUser? otherUser;
  
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;
  final DateTime createdAt;

  const Conversation({
    required this.id,
    required this.type,
    this.title,
    this.avatarUrl,
    required this.memberIds,
    this.ownerId,
    this.visibility = 'public',
    this.role,
    this.status,
    this.memberCount = 0,
    this.subscriberCount = 0,
    this.username,
    this.description,
    this.otherUser,
    this.lastMessage,
    this.unreadCount = 0,
    required this.updatedAt,
    required this.createdAt,
  });

  static int _intValue(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final typeString = (json['type'] ?? json['conversation_type'] ?? json['conversationType'])?.toString() ?? 'dm';
    final type = typeString == 'group' 
        ? ConversationType.group 
        : typeString == 'channel'
            ? ConversationType.channel
            : ConversationType.dm;

    ChatUser? otherUser;
    if (json['otherUser'] != null) {
      otherUser = ChatUser.fromJson(Map<String, dynamic>.from(json['otherUser']));
    } else if (json['other_user_id'] != null || json['otherUserId'] != null) {
      // Improved backend response format supporting multiple naming styles
      otherUser = ChatUser(
        id: (json['other_user_id'] ?? json['otherUserId']).toString(),
        walletAddress: (json['other_wallet_address'] ?? json['otherWalletAddress'] ?? '').toString(),
        username: (json['other_username'] ?? json['otherUsername'])?.toString(),
        displayName: (json['other_display_name'] ?? json['otherDisplayName'])?.toString(),
        profileUrl: (json['other_avatar_url'] ?? json['otherAvatarUrl'] ?? json['avatarUrl'])?.toString(),
        relationshipStatus: (json['relationship_status'] ?? json['relationshipStatus'])?.toString(),
        timestamp: (json['last_message_at'] ?? json['lastMessageAt'] ?? json['updated_at'] ?? json['updatedAt']) != null 
            ? DateTime.parse((json['last_message_at'] ?? json['lastMessageAt'] ?? json['updated_at'] ?? json['updatedAt']).toString()) 
            : DateTime.now(),
      );
    }

    return Conversation(
      id: json['id']?.toString() ?? '',
      type: type,
      title: json['title']?.toString() ?? json['name']?.toString(),
      avatarUrl: json['avatarUrl']?.toString() ??
          json['image_url']?.toString() ??
          json['other_avatar_url']?.toString() ??
          json['otherAvatarUrl']?.toString(),
      memberIds: (json['memberIds'] ?? json['member_ids'] ?? json['members'])
              is List
          ? (json['memberIds'] ?? json['member_ids'] ?? json['members'] as List)
              .map((e) => e.toString())
              .toList()
          : [],
      ownerId: (json['owner_id'] ?? json['ownerId'] ?? json['created_by'])
          ?.toString(),
      visibility: (json['visibility'] ?? 'public').toString(),
      role: json['role']?.toString(),
      status: json['status']?.toString(),
      memberCount: _intValue(json['member_count'] ?? json['memberCount']),
      subscriberCount: _intValue(json['subscriber_count'] ?? json['subscriberCount']),
      username: json['username']?.toString(),
      description: (json['description'] ?? json['bio'])?.toString(),
      otherUser: otherUser,
      lastMessage: json['last_message'] != null || json['lastMessage'] != null
          ? ChatMessage.fromJson(
            Map<String, dynamic>.from(json['last_message'] ?? json['lastMessage']),
          )
          : null,
      unreadCount: _intValue(json['unread_count'] ?? json['unreadCount']),
      updatedAt: (json['last_message_at'] ??
                  json['lastMessageAt'] ??
                  json['updated_at'] ??
                  json['updatedAt']) !=
              null
          ? DateTime.parse(
            (json['last_message_at'] ??
                    json['lastMessageAt'] ??
                    json['updated_at'] ??
                    json['updatedAt'])
                .toString(),
          )
          : DateTime.now(),
      createdAt: (json['created_at'] ?? json['createdAt']) != null
          ? DateTime.parse((json['created_at'] ?? json['createdAt']).toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'avatarUrl': avatarUrl,
      'memberIds': memberIds,
      'ownerId': ownerId,
      'visibility': visibility,
      'role': role,
      'status': status,
      'memberCount': memberCount,
      'subscriberCount': subscriberCount,
      'username': username,
      'description': description,
      'otherUser': otherUser?.toJson(),
      'lastMessage': lastMessage?.toJson(),
      'unreadCount': unreadCount,
      'updatedAt': updatedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Conversation copyWith({
    String? id,
    ConversationType? type,
    String? title,
    String? avatarUrl,
    List<String>? memberIds,
    String? ownerId,
    String? visibility,
    String? role,
    String? status,
    int? memberCount,
    int? subscriberCount,
    String? username,
    String? description,
    ChatUser? otherUser,
    ChatMessage? lastMessage,
    int? unreadCount,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) {
    return Conversation(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      memberIds: memberIds ?? this.memberIds,
      ownerId: ownerId ?? this.ownerId,
      visibility: visibility ?? this.visibility,
      role: role ?? this.role,
      status: status ?? this.status,
      memberCount: memberCount ?? this.memberCount,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      username: username ?? this.username,
      description: description ?? this.description,
      otherUser: otherUser ?? this.otherUser,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
