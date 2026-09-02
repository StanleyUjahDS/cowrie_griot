import 'chat_user.dart';

class ChannelComment {
  final String id;
  final String postId;
  final String content;
  final String authorId;
  final ChatUser? author;
  final String? replyToCommentId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;
  final Map<String, int> reactions;
  final List<ChannelComment> replies;

  ChannelComment({
    required this.id,
    required this.postId,
    required this.content,
    required this.authorId,
    this.author,
    this.replyToCommentId,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.reactions = const {},
    this.replies = const [],
  });

  factory ChannelComment.fromJson(Map<String, dynamic> json) {
    return ChannelComment(
      id: json['id'] as String,
      postId: json['postId'] as String,
      content: json['content'] as String,
      authorId: json['authorId'] as String,
      author: json['author'] != null 
          ? ChatUser.fromJson(Map<String, dynamic>.from(json['author'])) 
          : null,
      replyToCommentId: json['replyToCommentId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
      isDeleted: json['isDeleted'] as bool? ?? false,
      reactions: Map<String, int>.from(json['reactions'] ?? {}),
      replies: (json['replies'] as List?)?.map((r) => ChannelComment.fromJson(Map<String, dynamic>.from(r))).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'content': content,
      'authorId': authorId,
      'replyToCommentId': replyToCommentId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isDeleted': isDeleted,
      'reactions': reactions,
    };
  }

  ChannelComment copyWith({
    String? id,
    String? postId,
    String? content,
    String? authorId,
    ChatUser? author,
    String? replyToCommentId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    Map<String, int>? reactions,
    List<ChannelComment>? replies,
  }) {
    return ChannelComment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      author: author ?? this.author,
      replyToCommentId: replyToCommentId ?? this.replyToCommentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      reactions: reactions ?? this.reactions,
      replies: replies ?? this.replies,
    );
  }
}
