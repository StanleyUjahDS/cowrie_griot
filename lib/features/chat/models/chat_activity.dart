enum ActivityType {
  requestReceived,
  requestAccepted,
  requestDeclined,
  tipReceived,
  plusSubscribed,
}

class ChatActivity {
  final String id;
  final ActivityType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final String? relatedId; // e.g. requestId, userId
  final String? avatarUrl;

  const ChatActivity({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.relatedId,
    this.avatarUrl,
  });

  factory ChatActivity.fromRequest(dynamic request, ActivityType type) {
    final json = request is Map
        ? Map<String, dynamic>.from(request)
        : <String, dynamic>{};
    final sender =
        (json['senderDisplayName'] ?? json['senderUsername'] ?? 'Someone')
            .toString();
    final recipient =
        (json['receiverDisplayName'] ?? json['receiverUsername'] ?? 'Someone')
            .toString();
    final isReceived = type == ActivityType.requestReceived;
    return ChatActivity(
      id: (json['id'] ?? '').toString(),
      type: type,
      title: isReceived ? 'New connection request' : 'Connection update',
      message: isReceived
          ? '$sender wants to connect with you'
          : 'Your connection with $recipient was updated',
      timestamp:
          DateTime.tryParse(
            (json['createdAt'] ??
                    json['created_at'] ??
                    DateTime.now().toIso8601String())
                .toString(),
          ) ??
          DateTime.now(),
      relatedId: json['senderId']?.toString() ?? json['receiverId']?.toString(),
      avatarUrl: (json['senderProfileUrl'] ?? json['sender_avatar_url'])
          ?.toString(),
    );
  }
}
