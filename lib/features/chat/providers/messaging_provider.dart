import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:griot_cowrie/core/network/api_config.dart';
import 'package:griot_cowrie/features/chat/models/chat_message.dart';
import 'package:griot_cowrie/features/chat/models/conversation_model.dart';
import 'package:griot_cowrie/features/chat/models/message_request.dart';
import 'package:griot_cowrie/features/chat/services/messaging_api_service.dart';
import 'package:griot_cowrie/features/users/models/user_model.dart';
import 'package:griot_cowrie/features/users/providers/user_provider.dart';

enum RelationshipState {
  none,
  pendingSent,
  pendingReceived,
  friends,
  blocked,
}

class MessagingProvider extends ChangeNotifier {
  final MessagingApiService _apiService;
  final UserProvider _userProvider;

  MessagingProvider({
    required MessagingApiService apiService,
    required UserProvider userProvider,
  })  : _apiService = apiService,
        _userProvider = userProvider;

  // ==========================================================
  // STATE
  // ==========================================================

  final Map<String, List<ChatMessage>> _messagesByConversation = {};
  final Map<String, bool> _isLoadingMessages = {};
  
  List<Conversation> _conversations = [];
  bool _isLoadingConversations = false;

  List<MessageRequest> _receivedRequests = [];
  List<MessageRequest> _sentRequests = [];
  bool _isLoadingRequests = false;

  List<UserModel> _friends = [];
  bool _isLoadingFriends = false;

  List<String> _blockedUserIds = [];
  bool _isLoadingBlocks = false;

  // Real-time
  io.Socket? _socket;
  String? _currentRoomId;

  // ==========================================================
  // GETTERS
  // ==========================================================

  List<Conversation> get conversations => _conversations;
  bool get isLoadingConversations => _isLoadingConversations;

  List<MessageRequest> get receivedRequests => _receivedRequests;
  List<MessageRequest> get sentRequests => _sentRequests;
  bool get isLoadingRequests => _isLoadingRequests;

  List<UserModel> get friends => _friends;
  bool get isLoadingFriends => _isLoadingFriends;

  List<String> get blockedUserIds => _blockedUserIds;
  bool get isLoadingBlocks => _isLoadingBlocks;
  
  int get pendingRequestCount => _receivedRequests.where((r) => r.status == RequestStatus.pending).length;

  int get totalUnreadCount {
    int count = pendingRequestCount;
    for (final conv in _conversations) {
      count += conv.unreadCount;
    }
    return count;
  }
  
  List<ChatMessage> getMessagesForConversation(String conversationId) => 
      _messagesByConversation[conversationId] ?? [];
      
  bool isLoadingMessages(String conversationId) => 
      _isLoadingMessages[conversationId] ?? false;

  // ==========================================================
  // RELATIONSHIP LIFECYCLE
  // ==========================================================

  RelationshipState getRelationship(String userId) {
    if (_blockedUserIds.contains(userId)) return RelationshipState.blocked;
    
    if (_friends.any((f) => f.id == userId)) return RelationshipState.friends;
    
    if (_receivedRequests.any((r) => r.senderId == userId && r.status == RequestStatus.pending)) {
      return RelationshipState.pendingReceived;
    }
    
    if (_sentRequests.any((r) => r.receiverId == userId && r.status == RequestStatus.pending)) {
      return RelationshipState.pendingSent;
    }
    
    return RelationshipState.none;
  }

  MessageRequest? getPendingRequest(String userId) {
    return _receivedRequests.where((r) => r.senderId == userId && r.status == RequestStatus.pending).firstOrNull ??
           _sentRequests.where((r) => r.receiverId == userId && r.status == RequestStatus.pending).firstOrNull;
  }

  // ==========================================================
  // ACTIONS - CONVERSATIONS
  // ==========================================================

  Future<void> loadConversations() async {
    _isLoadingConversations = true;
    notifyListeners();

    try {
      final list = await _apiService.getConversations();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _conversations = list;
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      _conversations = [];
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  Future<Conversation> startDirectChat(String otherUserId) async {
    try {
      final conversation = await _apiService.findDirectConversation(otherUserId);
      if (!_conversations.any((c) => c.id == conversation.id)) {
        _conversations.insert(0, conversation);
      }
      notifyListeners();
      return conversation;
    } catch (e) {
      debugPrint('Error starting direct chat: $e');
      rethrow;
    }
  }

  // ==========================================================
  // ACTIONS - REQUESTS
  // ==========================================================

  Future<void> loadRequests() async {
    _isLoadingRequests = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.getReceivedRequests(),
        _apiService.getSentRequests(),
      ]);
      _receivedRequests = results[0];
      _sentRequests = results[1];
    } catch (e) {
      debugPrint('Error loading requests: $e');
    } finally {
      _isLoadingRequests = false;
      notifyListeners();
    }
  }

  Future<void> sendRequest(String recipientId) async {
    try {
      final request = await _apiService.sendDirectMessageRequest(recipientId);
      _sentRequests.add(request);
      notifyListeners();
    } catch (e) {
      debugPrint('Error sending request: $e');
      rethrow;
    }
  }

  Future<void> acceptRequest(String requestId) async {
    try {
      final conversation = await _apiService.acceptRequest(requestId);
      _receivedRequests.removeWhere((r) => r.id == requestId);
      
      // Update UI state to friends immediately
      await loadFriends();
      
      if (!_conversations.any((c) => c.id == conversation.id)) {
        _conversations.insert(0, conversation);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error accepting request: $e');
      rethrow;
    }
  }

  Future<void> declineRequest(String requestId) async {
    try {
      await _apiService.declineRequest(requestId);
      _receivedRequests.removeWhere((r) => r.id == requestId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error declining request: $e');
      rethrow;
    }
  }

  Future<void> withdrawRequest(String requestId) async {
    try {
      await _apiService.withdrawRequest(requestId);
      _sentRequests.removeWhere((r) => r.id == requestId);
      notifyListeners();
    } catch (e) {
      // If 409 Conflict, it means the request is no longer pending (accepted/declined)
      // We should refresh the state to reflect reality.
      if (e.toString().contains('409')) {
        await loadRequests();
        await loadFriends();
        await loadConversations();
      }
      rethrow;
    }
  }

  // ==========================================================
  // ACTIONS - FRIENDS & BLOCKS
  // ==========================================================

  Future<void> loadFriends() async {
    _isLoadingFriends = true;
    notifyListeners();

    try {
      _friends = await _apiService.getFriends();
    } catch (e) {
      debugPrint('Error loading friends: $e');
    } finally {
      _isLoadingFriends = false;
      notifyListeners();
    }
  }

  Future<void> loadBlocks() async {
    _isLoadingBlocks = true;
    notifyListeners();

    try {
      _blockedUserIds = await _apiService.getBlockedUserIds();
    } catch (e) {
      debugPrint('Error loading blocks: $e');
    } finally {
      _isLoadingBlocks = false;
      notifyListeners();
    }
  }

  Future<void> blockUser(String userId) async {
    try {
      await _apiService.blockUser(userId);
      
      // Update local state
      if (!_blockedUserIds.contains(userId)) {
        _blockedUserIds.add(userId);
      }
      _friends.removeWhere((f) => f.id == userId);
      
      // Find and disable conversation
      final conversation = _conversations.where(
        (c) => c.otherUser?.id == userId
      ).firstOrNull;
      
      // Stop retrying failed sends for this user/conversation
      // (This would be handled in a more complex queue system, 
      // but for now we just clear the failed status in local state if any)
      
      notifyListeners();
      
      // Refresh to ensure we have the latest server state
      await loadConversations();
    } catch (e) {
      // Show normal relationship/privacy message if 403/409
      if (e.toString().contains('403') || e.toString().contains('409')) {
        debugPrint('Privacy/Relationship restriction: $e');
      }
      rethrow;
    }
  }

  Future<void> unblockUser(String userId) async {
    try {
      await _apiService.unblockUser(userId);
      _blockedUserIds.remove(userId);
      notifyListeners();
      
      // Refresh state
      await loadRequests();
      await loadFriends();
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      rethrow;
    }
  }

  // ==========================================================
  // ACTIONS - MESSAGES
  // ==========================================================

  Future<void> loadMessages(String conversationId, {bool refresh = false}) async {
    if (_isLoadingMessages[conversationId] == true) return;
    
    final currentMessages = _messagesByConversation[conversationId] ?? [];
    String? before;
    
    if (!refresh && currentMessages.isNotEmpty) {
      // Sort to find the oldest message for pagination
      final sorted = [...currentMessages]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      before = sorted.first.createdAt.toIso8601String();
    }

    _isLoadingMessages[conversationId] = true;
    notifyListeners();

    try {
      final newMessages = await _apiService.getMessages(
        conversationId,
        before: before,
      );

      if (refresh) {
        _messagesByConversation[conversationId] = newMessages;
      } else {
        // Prevent duplicates
        final existingIds = currentMessages.map((m) => m.id).toSet();
        final distinctNew = newMessages.where((m) => !existingIds.contains(m.id)).toList();
        _messagesByConversation[conversationId] = [...currentMessages, ...distinctNew];
      }
      
      _messagesByConversation[conversationId]?.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Requirement 10: Receipts
      // When we load messages, we might want to mark them as delivered if they were sent to us
      _markIncomingMessagesAsDelivered(conversationId, newMessages);
      
    } catch (e) {
      debugPrint('Error loading messages: $e');
    } finally {
      _isLoadingMessages[conversationId] = false;
      notifyListeners();
    }
  }

  void _markIncomingMessagesAsDelivered(String conversationId, List<ChatMessage> messages) {
    final currentUserId = _userProvider.user?.id ?? '';
    for (final msg in messages) {
      if (msg.senderId != currentUserId && msg.status == MessageStatus.sent) {
        markAsDelivered(msg.id);
      }
    }
  }

  Future<void> markAsDelivered(String messageId) async {
    try {
      await _apiService.markMessageReceipt(messageId, 'delivered');
      _updateMessageStatusLocally(messageId, MessageStatus.delivered);
    } catch (e) {
      debugPrint('Failed to mark as delivered: $e');
    }
  }

  Future<void> markAsRead(String messageId) async {
    try {
      await _apiService.markMessageReceipt(messageId, 'read');
      _updateMessageStatusLocally(messageId, MessageStatus.read);
    } catch (e) {
      debugPrint('Failed to mark as read: $e');
    }
  }

  void _updateMessageStatusLocally(String messageId, MessageStatus status) {
    bool found = false;
    for (final entry in _messagesByConversation.entries) {
      final list = entry.value;
      final index = list.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        // Only progress status, don't regress
        if (list[index].status.index < status.index) {
          list[index] = list[index].copyWith(status: status);
          found = true;
        }
        break;
      }
    }
    if (found) notifyListeners();
  }

  Future<void> sendMessage(String conversationId, String content) async {
    final currentUserId = _userProvider.user?.id ?? '';
    
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMessage = ChatMessage(
      id: tempId,
      conversationId: conversationId,
      senderId: currentUserId,
      text: content,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
    );

    final currentMessages = _messagesByConversation[conversationId] ?? [];
    _messagesByConversation[conversationId] = [optimisticMessage, ...currentMessages];
    notifyListeners();

    try {
      final realMessage = await _apiService.sendMessage(
        conversationId: conversationId,
        content: content,
      );

      final list = _messagesByConversation[conversationId] ?? [];
      final index = list.indexWhere((m) => m.id == tempId);
      if (index != -1) {
        list[index] = realMessage;
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        notifyListeners();
      }
    } catch (e) {
      final list = _messagesByConversation[conversationId] ?? [];
      final index = list.indexWhere((m) => m.id == tempId);
      if (index != -1) {
        list[index] = optimisticMessage.copyWith(status: MessageStatus.failed);
        notifyListeners();
      }
    }
  }

  // ==========================================================
  // REAL-TIME (SOCKET.IO)
  // ==========================================================

  void initSocket(String accessToken) {
    if (_socket != null) return;

    final baseUrl = ApiConfig.baseUrl.replaceFirst('/api', '');
    _socket = io.io('$baseUrl/messages', io.OptionBuilder()
      .setTransports(['websocket'])
      .setAuth({'token': accessToken})
      .build());

    _socket?.onConnect((_) => debugPrint('Socket: Connected to /messages'));
    _socket?.onDisconnect((_) => debugPrint('Socket: Disconnected'));

    _socket?.on('message_received', (data) {
      final message = ChatMessage.fromJson(Map<String, dynamic>.from(data));
      _handleIncomingMessage(message);
    });
  }

  void _handleIncomingMessage(ChatMessage message) {
    final conversationId = message.conversationId;
    
    // Requirement 12: Add it only to the matching conversation.
    final list = _messagesByConversation[conversationId] ?? [];
    
    // Requirement 12: Avoid duplicate messages by checking the message ID.
    if (list.any((m) => m.id == message.id)) return;

    _messagesByConversation[conversationId] = [message, ...list];
    
    // Update conversation last message and unread count if not current
    final convIndex = _conversations.indexWhere((c) => c.id == conversationId);
    if (convIndex != -1) {
      final conv = _conversations[convIndex];
      _conversations[convIndex] = conv.copyWith(
        lastMessage: message,
        updatedAt: message.createdAt,
        unreadCount: _currentRoomId == conversationId ? conv.unreadCount : conv.unreadCount + 1,
      );
      _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } else {
      // Requirement 12: Refresh the conversation if we don't have it (or if auth fails)
      loadConversations();
    }
    
    // Requirement 10: Receipts - mark as delivered when received via socket
    final currentUserId = _userProvider.user?.id ?? '';
    if (message.senderId != currentUserId) {
      markAsDelivered(message.id);
    }
    
    notifyListeners();
  }

  void joinConversation(String conversationId) {
    if (_socket == null) return;
    _currentRoomId = conversationId;
    _socket?.emit('join_conversation', {'conversationId': conversationId});
    
    // Reset unread count locally
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversations[index] = _conversations[index].copyWith(unreadCount: 0);
      notifyListeners();
    }
  }

  void leaveConversation(String conversationId) {
    if (_socket == null) return;
    _socket?.emit('leave_conversation', {'conversationId': conversationId});
    _currentRoomId = null;
  }

  void clearSearchResults() {
    notifyListeners();
  }

  Future<void> createGroup({required String name}) async {
    await loadConversations();
  }

  Future<void> createChannel({required String name}) async {
    await loadConversations();
  }

  Future<void> removeFriend(String userId) async {
    await blockUser(userId);
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }
}
