import 'chat_user.dart';
import 'chat_message.dart';

enum ConversationType {
  dm,
  group,
}

class Conversation {
  final String id;
  final ConversationType type;
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
    required this.memberIds,
    this.otherUser,
    this.lastMessage,
    this.unreadCount = 0,
    required this.updatedAt,
    required this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() == 'group' 
          ? ConversationType.group 
          : ConversationType.dm,
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
      'memberIds': memberIds,
      'otherUser': otherUser?.toJson(),
      'lastMessage': lastMessage?.toJson(),
      'unreadCount': unreadCount,
      'updatedAt': updatedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
