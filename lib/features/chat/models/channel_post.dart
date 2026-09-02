import 'chat_user.dart';

class ChannelPost {
  final String id;
  final String conversationId;
  final String content;
  final String authorId;
  final ChatUser? author;
  final DateTime createdAt;
  final int commentCount;
  final Map<String, int> reactions;
  final bool isDeleted;

  ChannelPost({
    required this.id,
    required this.conversationId,
    required this.content,
    required this.authorId,
    this.author,
    required this.createdAt,
    this.commentCount = 0,
    this.reactions = const {},
    this.isDeleted = false,
  });

  factory ChannelPost.fromJson(Map<String, dynamic> json) {
    return ChannelPost(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      content: json['content'] as String,
      authorId: json['authorId'] as String,
      author: json['author'] != null 
          ? ChatUser.fromJson(Map<String, dynamic>.from(json['author'])) 
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      commentCount: json['commentCount'] as int? ?? 0,
      reactions: Map<String, int>.from(json['reactions'] ?? {}),
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'content': content,
      'authorId': authorId,
      'createdAt': createdAt.toIso8601String(),
      'commentCount': commentCount,
      'reactions': reactions,
      'isDeleted': isDeleted,
    };
  }

  ChannelPost copyWith({
    String? id,
    String? conversationId,
    String? content,
    String? authorId,
    ChatUser? author,
    DateTime? createdAt,
    int? commentCount,
    Map<String, int>? reactions,
    bool? isDeleted,
  }) {
    return ChannelPost(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      commentCount: commentCount ?? this.commentCount,
      reactions: reactions ?? this.reactions,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
