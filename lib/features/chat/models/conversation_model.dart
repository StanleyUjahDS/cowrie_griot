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
    this.otherUser,
    this.lastMessage,
    this.unreadCount = 0,
    required this.updatedAt,
    required this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final typeString = json['type']?.toString() ?? 'direct';
    final type = typeString == 'group' 
        ? ConversationType.group 
        : typeString == 'channel'
            ? ConversationType.channel
            : ConversationType.dm;

    return Conversation(
      id: json['id']?.toString() ?? '',
      type: type,
      title: json['title']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      memberIds: (json['memberIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      otherUser: json['otherUser'] != null 
          ? ChatUser.fromJson(Map<String, dynamic>.from(json['otherUser']))
          : null,
      lastMessage: json['lastMessage'] != null
          ? ChatMessage.fromJson(Map<String, dynamic>.from(json['lastMessage']))
          : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString())
          : DateTime.now(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
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
      otherUser: otherUser ?? this.otherUser,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
