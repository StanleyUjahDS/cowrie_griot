enum RequestStatus {
  pending,
  accepted,
  declined,
  cancelled,
}

class MessageRequest {
  final String id;

  // ==========================================================
  // WALLET IDENTITY
  // ==========================================================

  final String senderWalletAddress;
  final String receiverWalletAddress;

  // ==========================================================
  // SENDER PROFILE
  // ==========================================================

  /// Optional unique username.
  ///
  /// Example:
  /// davidk
  ///
  /// Username is different from display name.
  final String? senderUsername;

  /// Optional public display name.
  ///
  /// Example:
  /// David K
  final String? senderDisplayName;

  /// Optional phone number.
  final String? senderPhoneNumber;

  /// Profile image URL.
  final String? senderProfileUrl;

  // ==========================================================
  // REQUEST CONTENT
  // ==========================================================

  final String message;

  // ==========================================================
  // PRESENCE
  // ==========================================================

  final bool senderIsOnline;

  // ==========================================================
  // TIMESTAMP
  // ==========================================================

  final DateTime createdAt;

  // ==========================================================
  // STATUS
  // ==========================================================

  RequestStatus status;

  // ==========================================================
  // CONSTRUCTOR
  // ==========================================================

  MessageRequest({
    required this.id,
    required this.senderWalletAddress,
    required this.receiverWalletAddress,
    this.senderUsername,
    this.senderDisplayName,
    this.senderPhoneNumber,
    this.senderProfileUrl,
    this.message = '',
    this.senderIsOnline = false,
    required this.createdAt,
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
    if (senderUsername == null ||
        senderUsername!.trim().isEmpty) {
      return null;
    }

    final value = senderUsername!.trim();

    if (value.startsWith('@')) {
      return value;
    }

    return '@$value';
  }

  // ==========================================================
  // SHORT WALLET ADDRESS
  // ==========================================================

  String get shortWalletAddress {
    if (senderWalletAddress.length <= 12) {
      return senderWalletAddress;
    }

    return '${senderWalletAddress.substring(0, 6)}...'
        '${senderWalletAddress.substring(
      senderWalletAddress.length - 4,
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

  bool get isCancelled =>
      status == RequestStatus.cancelled;

  // ==========================================================
  // COPY WITH
  // ==========================================================

  MessageRequest copyWith({
    String? id,
    String? senderWalletAddress,
    String? receiverWalletAddress,
    String? senderUsername,
    String? senderDisplayName,
    String? senderPhoneNumber,
    String? senderProfileUrl,
    String? message,
    bool? senderIsOnline,
    DateTime? createdAt,
    RequestStatus? status,
  }) {
    return MessageRequest(
      id: id ?? this.id,
      senderWalletAddress:
      senderWalletAddress ??
          this.senderWalletAddress,
      receiverWalletAddress:
      receiverWalletAddress ??
          this.receiverWalletAddress,
      senderUsername:
      senderUsername ??
          this.senderUsername,
      senderDisplayName:
      senderDisplayName ??
          this.senderDisplayName,
      senderPhoneNumber:
      senderPhoneNumber ??
          this.senderPhoneNumber,
      senderProfileUrl:
      senderProfileUrl ??
          this.senderProfileUrl,
      message:
      message ??
          this.message,
      senderIsOnline:
      senderIsOnline ??
          this.senderIsOnline,
      createdAt:
      createdAt ??
          this.createdAt,
      status:
      status ??
          this.status,
    );
  }

  // ==========================================================
  // JSON
  // ==========================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderWalletAddress':
      senderWalletAddress,
      'receiverWalletAddress':
      receiverWalletAddress,
      'senderUsername':
      senderUsername,
      'senderDisplayName':
      senderDisplayName,
      'senderPhoneNumber':
      senderPhoneNumber,
      'senderProfileUrl':
      senderProfileUrl,
      'message':
      message,
      'senderIsOnline':
      senderIsOnline,
      'createdAt':
      createdAt.toIso8601String(),
      'status':
      status.name,
    };
  }

  // ==========================================================
  // FROM JSON
  // ==========================================================

  factory MessageRequest.fromJson(
      Map<String, dynamic> json,
      ) {
    return MessageRequest(
      id: json['id'] as String,

      senderWalletAddress:
      json['senderWalletAddress'] as String,

      receiverWalletAddress:
      json['receiverWalletAddress'] as String,

      senderUsername:
      json['senderUsername'] as String?,

      senderDisplayName:
      json['senderDisplayName'] as String?,

      senderPhoneNumber:
      json['senderPhoneNumber'] as String?,

      senderProfileUrl:
      json['senderProfileUrl'] as String?,

      message:
      json['message'] as String? ?? '',

      senderIsOnline:
      json['senderIsOnline'] as bool? ?? false,

      createdAt:
      DateTime.parse(
        json['createdAt'] as String,
      ),

      status:
      RequestStatus.values.firstWhere(
            (value) =>
        value.name == json['status'],
        orElse: () =>
        RequestStatus.pending,
      ),
    );
  }

  // ==========================================================
  // DEBUG
  // ==========================================================

  @override
  String toString() {
    return 'MessageRequest('
        'id: $id, '
        'senderWalletAddress: $senderWalletAddress, '
        'receiverWalletAddress: $receiverWalletAddress, '
        'senderUsername: $senderUsername, '
        'senderDisplayName: $senderDisplayName, '
        'senderPhoneNumber: $senderPhoneNumber, '
        'status: ${status.name}'
        ')';
  }
}