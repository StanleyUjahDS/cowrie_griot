import 'chat_user.dart';
import 'chat_message.dart';
import '../../users/models/user_model.dart';

enum ConversationType { dm, group, channel }

class Conversation {
  final String id;
  final ConversationType type;
  final String? name;
  final String? imageUrl;
  final List<String> memberIds;
  final String? ownerId;
  final String visibility;
  final bool messagesLocked;
  final bool commentsLocked;
  final String? role;
  final String? status;
  final int memberCount;
  final int subscriberCount;
  final int postCount;
  final String? username;
  final String? description;
  final bool joinRequestPending;

  /// For DMs, this is the other user's info if available.
  final ChatUser? otherUser;

  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;
  final DateTime createdAt;

  const Conversation({
    required this.id,
    required this.type,
    this.name,
    this.imageUrl,
    required this.memberIds,
    this.ownerId,
    this.visibility = 'public',
    this.messagesLocked = false,
    this.commentsLocked = false,
    this.role,
    this.status,
    this.memberCount = 0,
    this.subscriberCount = 0,
    this.postCount = 0,
    this.username,
    this.description,
    this.joinRequestPending = false,
    this.otherUser,
    this.lastMessage,
    this.unreadCount = 0,
    required this.updatedAt,
    required this.createdAt,
  });

  // Backward compatibility getters
  String? get title => name;
  String? get avatarUrl => imageUrl;

  static int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static bool _boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value?.toString().toLowerCase() == 'true';
  }

  static String? _firstNonEmptyString(Iterable<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  static UserReputationBadge? _reputationFromJson(Map<String, dynamic> json) {
    final raw =
        json['other_reputation'] ??
        json['reputation'] ??
        json['otherReputation'] ??
        json['reputationBadge'] ??
        json['reputation_badge'];
    if (raw is Map) {
      return UserReputationBadge.fromJson(Map<String, dynamic>.from(raw));
    }

    final tierName =
        json['other_reputation_tier_name'] ??
        json['otherReputationTierName'] ??
        json['reputation_tier_name'] ??
        json['reputationTierName'];
    if (tierName == null || tierName.toString().trim().isEmpty) return null;

    return UserReputationBadge.fromJson({
      'tierName': tierName,
      'badgeColor':
          json['other_reputation_badge_color'] ??
          json['otherReputationBadgeColor'] ??
          json['reputation_badge_color'] ??
          json['reputationBadgeColor'] ??
          json['other_reputation_color'] ??
          json['reputationColor'],
    });
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final typeString =
        ((json['type'] ?? json['conversation_type'] ?? json['conversationType'])
                    ?.toString() ??
                'dm')
            .trim()
            .toLowerCase();
    final type = typeString == 'group' || typeString == 'group_chat'
        ? ConversationType.group
        : typeString == 'channel' || typeString == 'broadcast'
        ? ConversationType.channel
        : ConversationType.dm;

    ChatUser? otherUser;
    if (json['otherUser'] != null) {
      otherUser = ChatUser.fromJson(
        Map<String, dynamic>.from(json['otherUser']),
      );
      // Some conversation endpoints return the participant object separately
      // and keep reputation in flat `other_*` fields. Merge both shapes so a
      // refresh cannot make the reputation badge disappear from the card.
      final topLevelReputation = _reputationFromJson(json);
      if (otherUser.reputation == null && topLevelReputation != null) {
        otherUser = otherUser.copyWith(reputation: topLevelReputation);
      }
    } else if (json['other_user_id'] != null || json['otherUserId'] != null) {
      otherUser = ChatUser(
        id: (json['other_user_id'] ?? json['otherUserId']).toString(),
        walletAddress:
            (json['other_wallet_address'] ?? json['otherWalletAddress'] ?? '')
                .toString(),
        username: (json['other_username'] ?? json['otherUsername'])?.toString(),
        displayName: (json['other_display_name'] ?? json['otherDisplayName'])
            ?.toString(),
        profileUrl:
            (json['other_avatar_url'] ??
                    json['otherAvatarUrl'] ??
                    json['other_profile_url'] ??
                    json['otherProfileUrl'] ??
                    json['image_url'] ??
                    json['imageUrl'])
                ?.toString(),
        relationshipStatus:
            (json['relationship_status'] ?? json['relationshipStatus'])
                ?.toString(),
        reputation: _reputationFromJson(json),
        isPlus: json['other_is_plus'] == true || json['is_plus'] == true,
        isPioneer:
            json['other_is_pioneer'] == true ||
            json['otherIsPioneer'] == true ||
            json['is_pioneer'] == true ||
            json['isPioneer'] == true,
        timestamp:
            (json['last_message_at'] ??
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
              ).toLocal()
            : DateTime.now(),
      );
    }

    final rawMemberIds =
        json['memberIds'] ?? json['member_ids'] ?? json['members'];
    final memberIds = rawMemberIds is List
        ? rawMemberIds.map((value) => value.toString()).toList()
        : <String>[];

    final nestedGroup = json['group'] is Map
        ? Map<String, dynamic>.from(json['group'] as Map)
        : null;
    final nestedChannel = json['channel'] is Map
        ? Map<String, dynamic>.from(json['channel'] as Map)
        : null;
    final communityImage = _firstNonEmptyString([
      json['image_url'],
      json['imageUrl'],
      json['avatar_url'],
      json['avatarUrl'],
      nestedGroup?['image_url'],
      nestedGroup?['imageUrl'],
      nestedGroup?['avatar_url'],
      nestedGroup?['avatarUrl'],
      nestedChannel?['image_url'],
      nestedChannel?['imageUrl'],
      nestedChannel?['avatar_url'],
      nestedChannel?['avatarUrl'],
      json['other_avatar_url'],
      json['otherAvatarUrl'],
    ]);

    return Conversation(
      id: json['id']?.toString() ?? '',
      type: type,
      name: json['name']?.toString() ?? json['title']?.toString(),
      imageUrl: communityImage,
      memberIds: memberIds,
      ownerId: (json['owner_id'] ?? json['ownerId'] ?? json['created_by'])
          ?.toString(),
      visibility: (json['visibility'] ?? 'public').toString(),
      messagesLocked: _boolValue(
        json['messages_locked'] ?? json['messagesLocked'],
      ),
      commentsLocked: _boolValue(
        json['comments_locked'] ?? json['commentsLocked'],
      ),
      role: json['role']?.toString(),
      status: json['status']?.toString(),
      memberCount: _intValue(
        json['member_count'] ?? json['memberCount'] ?? memberIds.length,
      ),
      subscriberCount: _intValue(
        json['subscriber_count'] ??
            json['subscriberCount'] ??
            json['subscribers'] ??
            json['subscribers_count'] ??
            json['subscriber_total'] ??
            (json['channel'] is Map
                ? (json['channel']['subscriber_count'] ??
                      json['channel']['subscriberCount'] ??
                      json['channel']['subscribers'] ??
                      json['channel']['subscribers_count'])
                : null) ??
            (json['stats'] is Map
                ? (json['stats']['subscriber_count'] ??
                      json['stats']['subscriberCount'] ??
                      json['stats']['subscribers'])
                : null) ??
            (json['metadata'] is Map
                ? (json['metadata']['subscriber_count'] ??
                      json['metadata']['subscriberCount'] ??
                      json['metadata']['subscribers'])
                : null) ??
            (type == ConversationType.channel
                ? (json['member_count'] ?? json['memberCount'])
                : null) ??
            (type == ConversationType.channel ? memberIds.length : 0),
      ),
      postCount: _intValue(json['post_count'] ?? json['postCount']),
      username: json['username']?.toString(),
      description: (json['description'] ?? json['bio'])?.toString(),
      joinRequestPending:
          json['join_request_pending'] == true ||
          json['joinRequestPending'] == true,
      otherUser: otherUser,
      lastMessage: json['last_message'] != null || json['lastMessage'] != null
          ? ChatMessage.fromJson(
              Map<String, dynamic>.from(
                json['last_message'] ?? json['lastMessage'],
              ),
            )
          : null,
      unreadCount: _intValue(json['unread_count'] ?? json['unreadCount']),
      updatedAt:
          (json['last_message_at'] ??
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
            ).toLocal()
          : DateTime.now(),
      createdAt: (json['created_at'] ?? json['createdAt']) != null
          ? DateTime.parse(
              (json['created_at'] ?? json['createdAt']).toString(),
            ).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'name': name,
      'image_url': imageUrl,
      'member_ids': memberIds,
      'owner_id': ownerId,
      'visibility': visibility,
      'messages_locked': messagesLocked,
      'role': role,
      'status': status,
      'member_count': memberCount,
      'subscriber_count': subscriberCount,
      'post_count': postCount,
      'username': username,
      'description': description,
      'join_request_pending': joinRequestPending,
      'otherUser': otherUser?.toJson(),
      'lastMessage': lastMessage?.toJson(),
      'unread_count': unreadCount,
      'updated_at': updatedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  Conversation copyWith({
    String? id,
    ConversationType? type,
    String? name,
    String? imageUrl,
    List<String>? memberIds,
    String? ownerId,
    String? visibility,
    bool? messagesLocked,
    String? role,
    String? status,
    int? memberCount,
    int? subscriberCount,
    int? postCount,
    String? username,
    String? description,
    bool? joinRequestPending,
    ChatUser? otherUser,
    ChatMessage? lastMessage,
    int? unreadCount,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) {
    return Conversation(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      memberIds: memberIds ?? this.memberIds,
      ownerId: ownerId ?? this.ownerId,
      visibility: visibility ?? this.visibility,
      messagesLocked: messagesLocked ?? this.messagesLocked,
      role: role ?? this.role,
      status: status ?? this.status,
      memberCount: memberCount ?? this.memberCount,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      postCount: postCount ?? this.postCount,
      username: username ?? this.username,
      description: description ?? this.description,
      joinRequestPending: joinRequestPending ?? this.joinRequestPending,
      otherUser: otherUser ?? this.otherUser,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
