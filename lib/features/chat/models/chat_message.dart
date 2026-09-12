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
  tip,
}

enum MessageStatus { sending, sent, delivered, read, failed }

class ChatMessage {
  final String id;

  /// Temporary client-side ID used for deduplication during delivery.
  final String? clientMessageId;

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

  /// Structured data for tips.
  final Map<String, dynamic>? tipData;

  const ChatMessage({
    required this.id,
    this.clientMessageId,
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
    this.tipData,
  });

  // ==========================================================
  // HELPERS
  // ==========================================================

  bool get isText => type == MessageType.text;

  bool get isMedia => type == MessageType.image || type == MessageType.video;

  bool get isAudio => type == MessageType.audio || type == MessageType.voice;

  bool get isFile => type == MessageType.file;

  /// Human-readable text used in conversation overviews and notifications.
  /// The full message bubble renders the actual payload; list previews need a
  /// useful label even when a message has no text body.
  String get previewText {
    if (isDeleted) return 'Message deleted';
    final trimmed = text.trim();
    if (type == MessageType.text && trimmed.isNotEmpty) return trimmed;
    return switch (type) {
      MessageType.image => 'Photo',
      MessageType.video => 'Video',
      MessageType.audio => 'Audio message',
      MessageType.voice => 'Voice message',
      MessageType.file => trimmed.isNotEmpty ? trimmed : 'File',
      MessageType.location => 'Location',
      MessageType.contact => 'Contact',
      MessageType.tip => 'Tip',
      MessageType.system => trimmed.isNotEmpty ? trimmed : 'System message',
      MessageType.text => trimmed.isNotEmpty ? trimmed : 'Message',
    };
  }

  bool get hasReply => replyToMessageId != null && replyToMessageId!.isNotEmpty;

  // ==========================================================
  // COPY WITH
  // ==========================================================

  ChatMessage copyWith({
    String? id,
    String? clientMessageId,
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
    Map<String, dynamic>? tipData,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      clientMessageId: clientMessageId ?? this.clientMessageId,
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
      tipData: tipData ?? this.tipData,
    );
  }

  // ==========================================================
  // FROM JSON
  // ==========================================================

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final reactionsRaw = json['reactions'];
    Map<String, List<String>> reactions = {};
    if (reactionsRaw is Map) {
      reactions = reactionsRaw.map(
        (key, value) => MapEntry(
          key.toString(),
          (value as List).map((e) => e.toString()).toList(),
        ),
      );
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
      id:
          (json['id'] ?? json['messageId'] ?? json['message_id'])?.toString() ??
          '',
      clientMessageId: (json['clientMessageId'] ?? json['client_message_id'])
          ?.toString(),
      conversationId:
          (json['conversation_id'] ?? json['conversationId'])?.toString() ?? '',
      senderId:
          (json['sender_id'] ??
                  json['senderId'] ??
                  json['author_id'] ??
                  json['authorId'])
              ?.toString() ??
          '',
      text: (json['content'] ?? json['text'])?.toString() ?? '',
      type: _messageTypeFromString(
        (json['message_type'] ?? json['messageType'] ?? json['type'])
            ?.toString(),
      ),
      status: _messageStatusFromString(json['status']?.toString()),
      createdAt: (json['created_at'] ?? json['createdAt']) != null
          ? DateTime.parse((json['created_at'] ?? json['createdAt']).toString())
          : DateTime.now(),
      mediaUrl: json['mediaUrl'] ?? json['media_url'],
      thumbnailUrl: json['thumbnailUrl'] ?? json['thumbnail_url'],
      replyToMessageId:
          (json['reply_to_message_id'] ?? json['replyToMessageId'])?.toString(),
      isEdited: json['isEdited'] == true || json['is_edited'] == true,
      isDeleted: json['isDeleted'] == true || json['is_deleted'] == true,
      reactions: reactions,
      mediaId: (json['mediaId'] ?? json['media_id'])?.toString(),
      tipData: json['tip_data'] != null || json['tipData'] != null
          ? Map<String, dynamic>.from(json['tip_data'] ?? json['tipData'])
          : null,
    );
  }

  // ==========================================================
  // TO JSON
  // ==========================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientMessageId': clientMessageId,
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
      'tipData': tipData,
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
      case 'tip':
        return MessageType.tip;
      case 'text':
      default:
        return MessageType.text;
    }
  }

  // ==========================================================
  // MESSAGE STATUS PARSER
  // ==========================================================

  static MessageStatus _messageStatusFromString(String? value) {
    if (value == null) return MessageStatus.sent;
    switch (value.toLowerCase()) {
      case 'read':
      case 'seen':
        return MessageStatus.read;
      case 'delivered':
      case 'received':
        return MessageStatus.delivered;
      case 'sent':
      case 'pending':
      case 'accepted':
        return MessageStatus.sent;
      case 'failed':
      case 'error':
        return MessageStatus.failed;
      case 'sending':
        return MessageStatus.sending;
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
