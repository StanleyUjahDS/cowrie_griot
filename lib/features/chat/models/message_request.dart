enum RequestStatus {
  pending,
  accepted,
  declined,
  withdrawn,
}

class MessageRequest {
  final String id;
  
  /// Real UUIDs of the users involved.
  final String? senderId;
  final String? receiverId;
  final String? conversationId;

  // ==========================================================
  // WALLET IDENTITY
  // ==========================================================

  final String senderWalletAddress;
  final String receiverWalletAddress;

  // ==========================================================
  // SENDER PROFILE
  // ==========================================================

  final String? senderUsername;
  final String? senderDisplayName;
  final String? senderProfileUrl;

  // ==========================================================
  // RECEIVER PROFILE
  // ==========================================================

  final String? receiverUsername;
  final String? receiverDisplayName;
  final String? receiverProfileUrl;

  // ==========================================================
  // REQUEST CONTENT
  // ==========================================================

  final String? requestType;
  final String message;

  // ==========================================================
  // PRESENCE
  // ==========================================================

  final bool senderIsOnline;

  // ==========================================================
  // TIMESTAMP
  // ==========================================================

  final DateTime createdAt;
  final DateTime? respondedAt;

  // ==========================================================
  // STATUS
  // ==========================================================

  RequestStatus status;

  // ==========================================================
  // CONSTRUCTOR
  // ==========================================================

  MessageRequest({
    required this.id,
    this.senderId,
    this.receiverId,
    this.conversationId,
    required this.senderWalletAddress,
    required this.receiverWalletAddress,
    this.senderUsername,
    this.senderDisplayName,
    this.senderProfileUrl,
    this.receiverUsername,
    this.receiverDisplayName,
    this.receiverProfileUrl,
    this.requestType,
    this.message = '',
    this.senderIsOnline = false,
    required this.createdAt,
    this.respondedAt,
    this.status = RequestStatus.pending,
  });

  // ==========================================================
  // COMPATIBILITY GETTERS
  // ==========================================================
  //
  // These allow the existing controller/widgets to use:
  //
  // request.walletAddress
  // request.username
  // request.profileUrl
  // request.isOnline
  //
  // without changing the underlying data model.
  // ==========================================================

  String get walletAddress => senderWalletAddress;

  String? get username => senderUsername;

  String? get profileUrl => senderProfileUrl;

  bool get isOnline => senderIsOnline;

  // ==========================================================
  // DISPLAY NAME
  // ==========================================================

  String get displayName {
    if (senderDisplayName != null &&
        senderDisplayName!.trim().isNotEmpty) {
      return senderDisplayName!.trim();
    }

    if (senderUsername != null &&
        senderUsername!.trim().isNotEmpty) {
      return senderUsername!.trim();
    }

    return shortWalletAddress;
  }

  // ==========================================================
  // FORMATTED USERNAME
  // ==========================================================

  String? get formattedUsername {
    final val = senderUsername?.trim();
    if (val == null || val.isEmpty) return null;
    return val.startsWith('@') ? val : '@$val';
  }

  // ==========================================================
  // SHORT WALLET ADDRESS (CONTRACT: 3...3)
  // ==========================================================

  String get shortWalletAddress {
    if (senderWalletAddress.length <= 8) {
      return senderWalletAddress;
    }

    return '${senderWalletAddress.substring(0, 3)}...'
        '${senderWalletAddress.substring(
      senderWalletAddress.length - 3,
    )}';
  }

  // ==========================================================
  // STATUS HELPERS
  // ==========================================================

  bool get isPending =>
      status == RequestStatus.pending;

  bool get isAccepted =>
      status == RequestStatus.accepted;

  bool get isDeclined =>
      status == RequestStatus.declined;

  bool get isWithdrawn =>
      status == RequestStatus.withdrawn;

  // ==========================================================
  // JSON
  // ==========================================================

  factory MessageRequest.fromJson(Map<String, dynamic> json) {
    return MessageRequest(
      id: json['id'] as String,
      senderId: (json['senderId'] ?? json['sender_id'])?.toString(),
      receiverId: (json['receiverId'] ?? json['receiver_id'])?.toString(),
      conversationId: (json['conversationId'] ?? json['conversation_id'])?.toString(),
      requestType: (json['requestType'] ?? json['request_type'])?.toString(),
      
      senderWalletAddress: (json['senderWalletAddress'] ?? json['sender_wallet_address'] ?? '').toString(),
      receiverWalletAddress: (json['receiverWalletAddress'] ?? json['receiver_wallet_address'] ?? '').toString(),
      
      senderUsername: (json['senderUsername'] ?? json['sender_username'])?.toString(),
      senderDisplayName: (json['senderDisplayName'] ?? json['sender_display_name'])?.toString(),
      senderProfileUrl: (json['senderProfileUrl'] ?? json['sender_avatar_url'])?.toString(),
      
      receiverUsername: (json['receiverUsername'] ?? json['receiver_username'])?.toString(),
      receiverDisplayName: (json['receiverDisplayName'] ?? json['receiver_display_name'])?.toString(),
      receiverProfileUrl: (json['receiverProfileUrl'] ?? json['receiver_avatar_url'])?.toString(),

      message: json['message']?.toString() ?? '',
      senderIsOnline: (json['senderIsOnline'] ?? json['sender_is_online']) as bool? ?? false,

      createdAt: DateTime.parse((json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()).toString()),
      respondedAt: (json['respondedAt'] ?? json['responded_at']) != null ? DateTime.parse((json['respondedAt'] ?? json['responded_at']).toString()) : null,

      status: RequestStatus.values.firstWhere(
        (v) => v.name == (json['status']?.toString().toLowerCase() ?? 'pending'),
        orElse: () => RequestStatus.pending,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'conversationId': conversationId,
      'requestType': requestType,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
      'senderWalletAddress': senderWalletAddress,
      'receiverWalletAddress': receiverWalletAddress,
      'senderUsername': senderUsername,
      'senderDisplayName': senderDisplayName,
      'senderProfileUrl': senderProfileUrl,
      'receiverUsername': receiverUsername,
      'receiverDisplayName': receiverDisplayName,
      'receiverProfileUrl': receiverProfileUrl,
    };
  }
}
