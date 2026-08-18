import 'package:flutter/foundation.dart';

import '../models/chat_user.dart';
import '../models/chat_message.dart';
import '../models/message_request.dart';
import '../services/chat_operations.dart';
import '../services/message_request_operations.dart';

class ChatController extends ChangeNotifier {
  // ==========================================================
  // SERVICES
  // ==========================================================

  final ChatOperations chatOperations;
  final MessageRequestOperations messageRequestOperations;

  ChatController({
    ChatOperations? chatOperations,
    MessageRequestOperations? messageRequestOperations,
  })  : chatOperations = chatOperations ?? ChatOperations(),
        messageRequestOperations =
            messageRequestOperations ?? MessageRequestOperations();

  // ==========================================================
  // STATE
  // ==========================================================

  List<ChatUser> _users = [];

  List<MessageRequest> _requests = [];

  final List<ChatMessage> _messages = [];

  bool _isLoading = false;

  String? _error;

  // ==========================================================
  // GETTERS
  // ==========================================================

  List<ChatUser> get users => List.unmodifiable(_users);

  List<MessageRequest> get requests =>
      List.unmodifiable(_requests);

  List<ChatMessage> get messages =>
      List.unmodifiable(_messages);

  bool get isLoading => _isLoading;

  String? get error => _error;

  // ==========================================================
  // INITIALIZE CHAT
  // ==========================================================

  Future<void> initialize() async {
    _setLoading(true);

    try {
      _error = null;

      await Future.wait([
        loadChats(),
        loadMessageRequests(),
      ]);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================================
  // LOAD CHATS
  // ==========================================================

  Future<void> loadChats() async {
    try {
      final result = await chatOperations.getChats();

      _users = List<ChatUser>.from(result);

      _users.sort(
            (a, b) => b.timestamp.compareTo(a.timestamp),
      );

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ==========================================================
  // LOAD MESSAGE REQUESTS
  // ==========================================================

  Future<void> loadMessageRequests() async {
    try {
      final result =
      await messageRequestOperations.getRequests();

      _requests =
      List<MessageRequest>.from(result);

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ==========================================================
  // PENDING REQUEST COUNT
  // ==========================================================

  int get pendingRequestCount {
    return _requests
        .where(
          (request) =>
      request.status == RequestStatus.pending,
    )
        .length;
  }

  // ==========================================================
  // ACCEPT REQUEST
  // ==========================================================

  Future<void> acceptRequest(
      MessageRequest request,
      ) async {
    try {
      final accepted =
      await messageRequestOperations.acceptRequest(
        request.id,
      );

      if (accepted == null) {
        return;
      }

      final index = _requests.indexWhere(
            (item) => item.id == request.id,
      );

      if (index != -1) {
        _requests[index] = accepted;
      }

      // ======================================================
      // ADD REQUESTER TO CHATS
      // ======================================================

      final alreadyExists = _users.any(
            (user) =>
        user.walletAddress.toLowerCase() ==
            request.senderWalletAddress.toLowerCase(),
      );

      if (!alreadyExists) {
        _users.insert(
          0,
          ChatUser(
            id: request.senderWalletAddress,
            walletAddress:
            request.senderWalletAddress,

            username:
            request.senderUsername,

            displayName:
            request.senderDisplayName,

            phoneNumber:
            request.senderPhoneNumber,

            phoneDiscoveryEnabled:
            request.senderPhoneNumber != null,

            profileUrl:
            request.senderProfileUrl,

            lastMessage:
            request.message,

            timestamp:
            request.createdAt,

            unreadCount: 1,

            isOnline:
            request.senderIsOnline,
          ),
        );
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ==========================================================
  // DECLINE REQUEST
  // ==========================================================

  Future<void> declineRequest(
      MessageRequest request,
      ) async {
    try {
      final declined =
      await messageRequestOperations.declineRequest(
        request.id,
      );

      if (declined == null) {
        return;
      }

      final index = _requests.indexWhere(
            (item) => item.id == request.id,
      );

      if (index != -1) {
        _requests[index] = declined;
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ==========================================================
  // SEND MESSAGE REQUEST
  // ==========================================================

  Future<MessageRequest?> sendMessageRequest({
    required String senderWalletAddress,
    required String receiverWalletAddress,
    String? senderUsername,
    String? senderDisplayName,
    String? senderPhoneNumber,
    String? senderProfileUrl,
    String message = '',
    bool senderIsOnline = false,
  }) async {
    try {
      final request =
      await messageRequestOperations.sendRequest(
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
      );

      _requests.insert(
        0,
        request,
      );

      notifyListeners();

      return request;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ==========================================================
  // SEARCH USERS
  // ==========================================================

  Future<List<ChatUser>> searchUsers(
      String query,
      ) async {
    final trimmed =
    query.trim().toLowerCase();

    if (trimmed.isEmpty) {
      return [];
    }

    try {
      final result =
      await chatOperations.searchUsers(
        trimmed,
      );

      return List<ChatUser>.from(result);
    } catch (e) {
      _error = e.toString();
      notifyListeners();

      return [];
    }
  }

  // ==========================================================
  // FIND USER BY WALLET
  // ==========================================================

  Future<ChatUser?> findUserByWallet(
      String walletAddress,
      ) async {
    try {
      return await chatOperations.findUserByWallet(
        walletAddress,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();

      return null;
    }
  }

  // ==========================================================
  // PHONE DISCOVERY
  // ==========================================================

  Future<List<ChatUser>> findUsersByPhoneNumbers(
      List<String> phoneNumbers,
      ) async {
    if (phoneNumbers.isEmpty) {
      return [];
    }

    try {
      final result =
      await chatOperations.findUsersByPhoneNumbers(
        phoneNumbers,
      );

      return List<ChatUser>.from(result);
    } catch (e) {
      _error = e.toString();
      notifyListeners();

      return [];
    }
  }

  // ==========================================================
  // UPDATE PHONE DISCOVERY
  // ==========================================================

  Future<void> updatePhoneDiscovery({
    required String walletAddress,
    required bool enabled,
  }) async {
    try {
      await chatOperations.updatePhoneDiscovery(
        walletAddress: walletAddress,
        enabled: enabled,
      );

      final index = _users.indexWhere(
            (user) =>
        user.walletAddress.toLowerCase() ==
            walletAddress.toLowerCase(),
      );

      if (index != -1) {
        _users[index] =
            _users[index].copyWith(
              phoneDiscoveryEnabled:
              enabled,
            );
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ==========================================================
  // OPEN CHAT
  // ==========================================================

  Future<void> openChat(
      String userId,
      ) async {
    final index = _users.indexWhere(
          (user) => user.id == userId,
    );

    if (index == -1) {
      return;
    }

    final user = _users[index];

    _users[index] = user.copyWith(
      unreadCount: 0,
    );

    notifyListeners();
  }

  // ==========================================================
  // REFRESH
  // ==========================================================

  Future<void> refresh() async {
    await initialize();
  }

  // ==========================================================
  // CLEAR ERROR
  // ==========================================================

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ==========================================================
  // LOADING
  // ==========================================================

  void _setLoading(
      bool value,
      ) {
    _isLoading = value;
    notifyListeners();
  }
}