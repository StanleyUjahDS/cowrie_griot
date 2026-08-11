import '../models/message_request.dart';

class MessageRequestOperations {
  // ==========================================================
  // MOCK CURRENT USER
  // ==========================================================

  static const String mockCurrentWallet =
      '0x82A4B7C1D9E345678901234567890ABCDEF91F2';

  // ==========================================================
  // MOCK DATA
  // ==========================================================

  final List<MessageRequest> _requests = [
    MessageRequest(
      id: 'request_1',
      senderWalletAddress:
      '0x7A31B4C2D8E9F01234567890ABCDEF123456E921',
      receiverWalletAddress:
      mockCurrentWallet,
      senderUsername: 'davidk',
      senderDisplayName: 'David K',
      senderPhoneNumber: null,
      senderProfileUrl:
      'https://i.pravatar.cc/150?img=12',
      message:
      'Hey, I found you on Griot. Would like to connect.',
      senderIsOnline: true,
      createdAt:
      DateTime.now().subtract(
        const Duration(minutes: 15),
      ),
      status: RequestStatus.pending,
    ),

    MessageRequest(
      id: 'request_2',
      senderWalletAddress:
      '0x91BC72A4E8215678901234567890ABCDEF123456',
      receiverWalletAddress:
      mockCurrentWallet,
      senderUsername: 'amara',
      senderDisplayName: 'Amara Okafor',
      senderPhoneNumber: '+2348012345678',
      senderProfileUrl:
      'https://i.pravatar.cc/150?img=32',
      message:
      'Hi, I would like to send you a message.',
      senderIsOnline: false,
      createdAt:
      DateTime.now().subtract(
        const Duration(hours: 2),
      ),
      status: RequestStatus.pending,
    ),

    MessageRequest(
      id: 'request_3',
      senderWalletAddress:
      '0x22EF72A4719A5678901234567890ABCDEF123456',
      receiverWalletAddress:
      mockCurrentWallet,
      senderUsername: null,
      senderDisplayName: 'Michael Johnson',
      senderPhoneNumber: null,
      senderProfileUrl:
      'https://i.pravatar.cc/150?img=14',
      message:
      'Hello 👋 Let’s connect on Griot.',
      senderIsOnline: true,
      createdAt:
      DateTime.now().subtract(
        const Duration(days: 1),
      ),
      status: RequestStatus.pending,
    ),
  ];

  // ==========================================================
  // GET ALL REQUESTS
  // ==========================================================

  Future<List<MessageRequest>> getRequests() async {
    return List<MessageRequest>.from(_requests);
  }

  // ==========================================================
  // COMPATIBILITY METHOD
  // ==========================================================
  //
  // Existing ChatController calls this name.
  // Keep both names so the API replacement later is easy.
  // ==========================================================

  Future<List<MessageRequest>> getMessageRequests() async {
    return getRequests();
  }

  // ==========================================================
  // GET PENDING REQUESTS
  // ==========================================================

  Future<List<MessageRequest>> getPendingRequests(
      String walletAddress,
      ) async {
    final wallet =
    walletAddress.toLowerCase();

    return _requests
        .where(
          (request) =>
      request.receiverWalletAddress
          .toLowerCase() ==
          wallet &&
          request.status ==
              RequestStatus.pending,
    )
        .toList();
  }

  // ==========================================================
  // GET REQUEST BY ID
  // ==========================================================

  Future<MessageRequest?> getRequestById(
      String requestId,
      ) async {
    try {
      return _requests.firstWhere(
            (request) => request.id == requestId,
      );
    } catch (_) {
      return null;
    }
  }

  // ==========================================================
  // SEND REQUEST
  // ==========================================================

  Future<MessageRequest> sendRequest({
    required String senderWalletAddress,
    required String receiverWalletAddress,

    String? senderUsername,
    String? senderDisplayName,
    String? senderPhoneNumber,
    String? senderProfileUrl,

    String message = '',

    bool senderIsOnline = false,
  }) async {
    final request = MessageRequest(
      id:
      'request_${DateTime.now().microsecondsSinceEpoch}',

      senderWalletAddress:
      senderWalletAddress,

      receiverWalletAddress:
      receiverWalletAddress,

      senderUsername:
      senderUsername,

      senderDisplayName:
      senderDisplayName,

      senderPhoneNumber:
      senderPhoneNumber,

      senderProfileUrl:
      senderProfileUrl,

      message:
      message,

      senderIsOnline:
      senderIsOnline,

      createdAt:
      DateTime.now(),

      status:
      RequestStatus.pending,
    );

    _requests.insert(0, request);

    return request;
  }

  // ==========================================================
  // ACCEPT REQUEST
  // ==========================================================

  Future<MessageRequest?> acceptRequest(
      String requestId,
      ) async {
    final request =
    await getRequestById(requestId);

    if (request == null) {
      return null;
    }

    request.status =
        RequestStatus.accepted;

    return request;
  }

  // ==========================================================
  // DECLINE REQUEST
  // ==========================================================

  Future<MessageRequest?> declineRequest(
      String requestId,
      ) async {
    final request =
    await getRequestById(requestId);

    if (request == null) {
      return null;
    }

    request.status =
        RequestStatus.declined;

    return request;
  }

  // ==========================================================
  // CANCEL REQUEST
  // ==========================================================

  Future<MessageRequest?> cancelRequest(
      String requestId,
      ) async {
    final request =
    await getRequestById(requestId);

    if (request == null) {
      return null;
    }

    request.status =
        RequestStatus.cancelled;

    return request;
  }

  // ==========================================================
  // DELETE REQUEST
  // ==========================================================

  Future<bool> deleteRequest(
      String requestId,
      ) async {
    final index =
    _requests.indexWhere(
          (request) =>
      request.id == requestId,
    );

    if (index == -1) {
      return false;
    }

    _requests.removeAt(index);

    return true;
  }

  // ==========================================================
  // FIND EXISTING PENDING REQUEST
  // ==========================================================

  Future<MessageRequest?>
  findExistingRequest({
    required String senderWalletAddress,
    required String receiverWalletAddress,
  }) async {
    try {
      return _requests.firstWhere(
            (request) =>
        request.senderWalletAddress
            .toLowerCase() ==
            senderWalletAddress
                .toLowerCase() &&
            request.receiverWalletAddress
                .toLowerCase() ==
                receiverWalletAddress
                    .toLowerCase() &&
            request.status ==
                RequestStatus.pending,
      );
    } catch (_) {
      return null;
    }
  }

  // ==========================================================
  // CHECK IF REQUEST EXISTS
  // ==========================================================

  Future<bool> requestExists({
    required String senderWalletAddress,
    required String receiverWalletAddress,
  }) async {
    final request =
    await findExistingRequest(
      senderWalletAddress:
      senderWalletAddress,
      receiverWalletAddress:
      receiverWalletAddress,
    );

    return request != null;
  }

  // ==========================================================
  // GET SENT REQUESTS
  // ==========================================================

  Future<List<MessageRequest>> getSentRequests(
      String walletAddress,
      ) async {
    final wallet =
    walletAddress.toLowerCase();

    return _requests
        .where(
          (request) =>
      request.senderWalletAddress
          .toLowerCase() ==
          wallet,
    )
        .toList();
  }

  // ==========================================================
  // GET RECEIVED REQUESTS
  // ==========================================================

  Future<List<MessageRequest>>
  getReceivedRequests(
      String walletAddress,
      ) async {
    final wallet =
    walletAddress.toLowerCase();

    return _requests
        .where(
          (request) =>
      request.receiverWalletAddress
          .toLowerCase() ==
          wallet,
    )
        .toList();
  }

  // ==========================================================
  // PENDING COUNT
  // ==========================================================

  Future<int> getPendingCount(
      String walletAddress,
      ) async {
    final requests =
    await getPendingRequests(
      walletAddress,
    );

    return requests.length;
  }

  // ==========================================================
  // RESET MOCK DATA
  // ==========================================================

  void resetMockData() {
    _requests
      ..clear()
      ..addAll([
        MessageRequest(
          id: 'request_1',
          senderWalletAddress:
          '0x7A31B4C2D8E9F01234567890ABCDEF123456E921',
          receiverWalletAddress:
          mockCurrentWallet,
          senderUsername: 'davidk',
          senderDisplayName: 'David K',
          senderPhoneNumber: null,
          senderProfileUrl:
          'https://i.pravatar.cc/150?img=12',
          message:
          'Hey, I found you on Griot. Would like to connect.',
          senderIsOnline: true,
          createdAt:
          DateTime.now().subtract(
            const Duration(minutes: 15),
          ),
          status:
          RequestStatus.pending,
        ),

        MessageRequest(
          id: 'request_2',
          senderWalletAddress:
          '0x91BC72A4E8215678901234567890ABCDEF123456',
          receiverWalletAddress:
          mockCurrentWallet,
          senderUsername: 'amara',
          senderDisplayName:
          'Amara Okafor',
          senderPhoneNumber:
          '+2348012345678',
          senderProfileUrl:
          'https://i.pravatar.cc/150?img=32',
          message:
          'Hi, I would like to send you a message.',
          senderIsOnline: false,
          createdAt:
          DateTime.now().subtract(
            const Duration(hours: 2),
          ),
          status:
          RequestStatus.pending,
        ),

        MessageRequest(
          id: 'request_3',
          senderWalletAddress:
          '0x22EF72A4719A5678901234567890ABCDEF123456',
          receiverWalletAddress:
          mockCurrentWallet,
          senderUsername: null,
          senderDisplayName:
          'Michael Johnson',
          senderPhoneNumber: null,
          senderProfileUrl:
          'https://i.pravatar.cc/150?img=14',
          message:
          'Hello 👋 Let’s connect on Griot.',
          senderIsOnline: true,
          createdAt:
          DateTime.now().subtract(
            const Duration(days: 1),
          ),
          status:
          RequestStatus.pending,
        ),
      ]);
  }
}