enum MessageType {
  text,
  image,
  video,
  audio,
  file,
  voice,
  location,
  contact,
  system,
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

class ChatMessage {
  final String id;

  /// Conversation this message belongs to.
  final String conversationId;

  /// ID of the sender.
  final String senderId;

  /// Message text / content.
  final String text;

  String get content => text;

  final MessageType type;

  final MessageStatus status;

  final DateTime createdAt;

  /// Optional media URL.
  final String? mediaUrl;

  /// Optional thumbnail for media.
  final String? thumbnailUrl;

  /// Optional reply-to message ID.
  final String? replyToMessageId;

  /// Whether this message has been edited.
  final bool isEdited;

  /// Whether this message has been deleted.
  final bool isDeleted;

  /// Map of emojis to list of user IDs who reacted.
  final Map<String, List<String>> reactions;

  /// Optional media ID from the media service.
  final String? mediaId;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
    required this.createdAt,
    this.mediaUrl,
    this.thumbnailUrl,
    this.replyToMessageId,
    this.isEdited = false,
    this.isDeleted = false,
    this.reactions = const {},
    this.mediaId,
  });

  // ==========================================================
  // HELPERS
  // ==========================================================

  bool get isText => type == MessageType.text;

  bool get isMedia => type == MessageType.image || type == MessageType.video;

  bool get isAudio => type == MessageType.audio || type == MessageType.voice;

  bool get isFile => type == MessageType.file;

  bool get hasReply => replyToMessageId != null && replyToMessageId!.isNotEmpty;

  // ==========================================================
  // COPY WITH
  // ==========================================================

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? text,
    MessageType? type,
    MessageStatus? status,
    DateTime? createdAt,
    String? mediaUrl,
    String? thumbnailUrl,
    String? replyToMessageId,
    bool? isEdited,
    bool? isDeleted,
    Map<String, List<String>>? reactions,
    String? mediaId,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      reactions: reactions ?? this.reactions,
      mediaId: mediaId ?? this.mediaId,
    );
  }

  // ==========================================================
  // FROM JSON
  // ==========================================================

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final reactionsRaw = json['reactions'];
    Map<String, List<String>> reactions = {};
    if (reactionsRaw is Map) {
      reactions = reactionsRaw.map((key, value) => MapEntry(
            key.toString(),
            (value as List).map((e) => e.toString()).toList(),
          ));
    } else if (reactionsRaw is List) {
      for (final r in reactionsRaw) {
        if (r is Map) {
          final emoji = (r['reaction'] ?? r['emoji'])?.toString();
          final userId = (r['user_id'] ?? r['userId'])?.toString();
          if (emoji != null && userId != null) {
            reactions.putIfAbsent(emoji, () => []).add(userId);
          }
        }
      }
    }

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      conversationId:
          (json['conversation_id'] ?? json['conversationId'])?.toString() ?? '',
      senderId: (json['sender_id'] ?? json['senderId'])?.toString() ?? '',
      text: (json['content'] ?? json['text'])?.toString() ?? '',
      type: _messageTypeFromString(
        (json['message_type'] ?? json['messageType'] ?? json['type'])?.toString(),
      ),
      status: _messageStatusFromString(json['status']?.toString()),
      createdAt: (json['created_at'] ?? json['createdAt']) != null
          ? DateTime.parse((json['created_at'] ?? json['createdAt']).toString())
          : DateTime.now(),
      mediaUrl: json['mediaUrl']?.toString() ?? json['media_url']?.toString(),
      thumbnailUrl:
          json['thumbnailUrl']?.toString() ?? json['thumbnail_url']?.toString(),
      replyToMessageId:
          (json['reply_to_message_id'] ?? json['replyToMessageId'])?.toString(),
      isEdited: json['isEdited'] == true || json['is_edited'] == true,
      isDeleted: json['isDeleted'] == true || json['is_deleted'] == true,
      reactions: reactions,
      mediaId: (json['mediaId'] ?? json['media_id'])?.toString(),
    );
  }

  // ==========================================================
  // TO JSON
  // ==========================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'content': text,
      'messageType': type.name,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'replyToMessageId': replyToMessageId,
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      'mediaId': mediaId,
    };
  }

  // ==========================================================
  // MESSAGE TYPE PARSER
  // ==========================================================

  static MessageType _messageTypeFromString(String? value) {
    switch (value) {
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'audio':
        return MessageType.audio;
      case 'voice':
        return MessageType.voice;
      case 'location':
        return MessageType.location;
      case 'contact':
        return MessageType.contact;
      case 'file':
        return MessageType.file;
      case 'system':
        return MessageType.system;
      case 'text':
      default:
        return MessageType.text;
    }
  }

  // ==========================================================
  // MESSAGE STATUS PARSER
  // ==========================================================

  static MessageStatus _messageStatusFromString(String? value) {
    switch (value) {
      case 'sending':
        return MessageStatus.sending;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      case 'failed':
        return MessageStatus.failed;
      case 'sent':
      default:
        return MessageStatus.sent;
    }
  }

  // ==========================================================
  // EQUALITY
  // ==========================================================

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // ==========================================================
  // DEBUG
  // ==========================================================

  @override
  String toString() {
    return 'ChatMessage(id: $id, conversationId: $conversationId, sender: $senderId, type: ${type.name}, status: ${status.name})';
  }
}
