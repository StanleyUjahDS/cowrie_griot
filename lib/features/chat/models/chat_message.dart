enum MessageType {
  text,
  image,
  video,
  audio,
  file,
  voice,
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
    );
  }

  // ==========================================================
  // FROM JSON
  // ==========================================================

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      text: json['content']?.toString() ?? json['text']?.toString() ?? '',
      type: _messageTypeFromString(json['messageType']?.toString() ?? json['type']?.toString()),
      status: _messageStatusFromString(json['status']?.toString()),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      mediaUrl: json['mediaUrl']?.toString(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      replyToMessageId: json['replyToMessageId']?.toString(),
      isEdited: json['isEdited'] == true,
      isDeleted: json['isDeleted'] == true,
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
