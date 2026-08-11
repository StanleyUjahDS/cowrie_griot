class ChatChannel {
  // ==========================================================
  // IDENTITY
  // ==========================================================

  final String id;

  /// Channel name shown in the UI.
  final String name;

  /// Optional channel image.
  final String? imageUrl;

  // ==========================================================
  // CHANNEL INFORMATION
  // ==========================================================

  final String description;

  final int subscriberCount;

  /// Whether the channel has been verified.
  final bool verified;

  // ==========================================================
  // LAST POST PREVIEW
  // ==========================================================

  final String lastPost;

  final DateTime timestamp;

  // ==========================================================
  // CONSTRUCTOR
  // ==========================================================

  const ChatChannel({
    required this.id,
    required this.name,
    this.imageUrl,
    this.description = '',
    this.subscriberCount = 0,
    this.verified = false,
    this.lastPost = '',
    required this.timestamp,
  });

  // ==========================================================
  // FORMATTED TIME
  // ==========================================================

  String get time {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d';
    }

    return '${timestamp.day}/${timestamp.month}';
  }

  // ==========================================================
  // FORMATTED SUBSCRIBERS
  // ==========================================================

  String get formattedSubscriberCount {
    if (subscriberCount >= 1000000) {
      return '${(subscriberCount / 1000000).toStringAsFixed(1)}M';
    }

    if (subscriberCount >= 1000) {
      return '${(subscriberCount / 1000).toStringAsFixed(1)}K';
    }

    return subscriberCount.toString();
  }

  // ==========================================================
  // COPY WITH
  // ==========================================================

  ChatChannel copyWith({
    String? id,
    String? name,
    String? imageUrl,
    String? description,
    int? subscriberCount,
    bool? verified,
    String? lastPost,
    DateTime? timestamp,
  }) {
    return ChatChannel(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      subscriberCount:
      subscriberCount ?? this.subscriberCount,
      verified: verified ?? this.verified,
      lastPost: lastPost ?? this.lastPost,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  // ==========================================================
  // JSON
  // ==========================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'description': description,
      'subscriberCount': subscriberCount,
      'verified': verified,
      'lastPost': lastPost,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // ==========================================================
  // FROM JSON
  // ==========================================================

  factory ChatChannel.fromJson(
      Map<String, dynamic> json,
      ) {
    return ChatChannel(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String?,
      description:
      json['description'] as String? ?? '',
      subscriberCount:
      json['subscriberCount'] as int? ?? 0,
      verified:
      json['verified'] as bool? ?? false,
      lastPost:
      json['lastPost'] as String? ?? '',
      timestamp: DateTime.parse(
        json['timestamp'] as String,
      ),
    );
  }

  // ==========================================================
  // DEBUG
  // ==========================================================

  @override
  String toString() {
    return 'ChatChannel('
        'id: $id, '
        'name: $name, '
        'subscriberCount: $subscriberCount, '
        'verified: $verified'
        ')';
  }

  // ==========================================================
  // EQUALITY
  // ==========================================================

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is ChatChannel &&
        other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}