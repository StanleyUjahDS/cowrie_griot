import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:griot_cowrie/core/network/api_config.dart';
import 'package:griot_cowrie/features/chat/models/chat_message.dart';
import 'package:griot_cowrie/features/chat/models/conversation_model.dart';
import 'package:griot_cowrie/features/chat/models/message_request.dart';
import 'package:griot_cowrie/features/chat/services/messaging_api_service.dart';
import 'package:griot_cowrie/features/chat/services/message_cache_service.dart';
import 'package:griot_cowrie/features/chat/services/message_sync_service.dart';
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
  final MessageCacheService _messageCache;
  final MessageSyncService _messageSync;

  MessagingProvider({
    required MessagingApiService apiService,
    required UserProvider userProvider,
    required MessageCacheService messageCache,
    required MessageSyncService messageSync,
  })  : _apiService = apiService,
        _userProvider = userProvider,
        _messageCache = messageCache,
        _messageSync = messageSync;

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
  int _friendsTotal = 0;
  bool _hasMoreFriends = false;
  int _friendsOffset = 0;
  String? _currentFriendsSearchQuery;
  bool _isLoadingMoreFriends = false;

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
  int get friendsTotal => _friendsTotal;
  bool get hasMoreFriends => _hasMoreFriends;
  bool get isLoadingMoreFriends => _isLoadingMoreFriends;

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

  Future<void> loadFriends({bool refresh = true}) async {
    if (_isLoadingFriends) return;

    if (refresh) {
      _friendsOffset = 0;
      _currentFriendsSearchQuery = null;
    }

    _isLoadingFriends = true;
    notifyListeners();

    try {
      final result = await _apiService.getFriendsPage(
        limit: 20,
        offset: _friendsOffset,
      );

      final List<dynamic> friendsJson = result['friends'] ?? [];
      final newFriends = friendsJson.map((f) => UserModel.fromJson(Map<String, dynamic>.from(f))).toList();

      if (refresh) {
        _friends = newFriends;
      } else {
        _friends.addAll(newFriends);
      }

      _friendsTotal = result['total'] ?? 0;
      _hasMoreFriends = result['hasMore'] ?? false;
      _friendsOffset = result['offset'] + newFriends.length;
    } catch (e) {
      debugPrint('Error loading friends: $e');
      if (refresh) _friends = [];
    } finally {
      _isLoadingFriends = false;
      notifyListeners();
    }
  }

  Future<void> searchFriends(String query, {bool refresh = true}) async {
    if (query.isEmpty) {
      loadFriends(refresh: true);
      return;
    }

    if (refresh) {
      _friendsOffset = 0;
      _currentFriendsSearchQuery = query;
      _friends = []; // Clear for new search
    } else if (_currentFriendsSearchQuery != query) {
      // Discard if query changed mid-load
      return;
    }

    _isLoadingFriends = true;
    notifyListeners();

    try {
      final result = await _apiService.searchFriends(
        query: query,
        limit: 20,
        offset: _friendsOffset,
      );

      // Check if query is still relevant
      if (_currentFriendsSearchQuery != query) return;

      final List<dynamic> friendsJson = result['friends'] ?? [];
      final newFriends = friendsJson.map((f) => UserModel.fromJson(Map<String, dynamic>.from(f))).toList();

      if (refresh) {
        _friends = newFriends;
      } else {
        _friends.addAll(newFriends);
      }

      _friendsTotal = result['total'] ?? 0;
      _hasMoreFriends = result['hasMore'] ?? false;
      _friendsOffset = result['offset'] + newFriends.length;
    } catch (e) {
      debugPrint('Error searching friends: $e');
    } finally {
      if (_currentFriendsSearchQuery == query) {
        _isLoadingFriends = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreFriends() async {
    if (_isLoadingFriends || _isLoadingMoreFriends || !_hasMoreFriends) return;

    _isLoadingMoreFriends = true;
    notifyListeners();

    try {
      if (_currentFriendsSearchQuery != null) {
        await searchFriends(_currentFriendsSearchQuery!, refresh: false);
      } else {
        await loadFriends(refresh: false);
      }
    } finally {
      _isLoadingMoreFriends = false;
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
    
    final cachedMessages = await _messageCache.getMessages(conversationId);
    final currentMessages = _messagesByConversation[conversationId] ?? cachedMessages;
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

      await _messageCache.saveMessages(newMessages);
      final merged = <String, ChatMessage>{
        for (final message in currentMessages) message.id: message,
        for (final message in newMessages) message.id: message,
      };
      _messagesByConversation[conversationId] = merged.values.toList();
      
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

    await _messageCache.saveMessage(optimisticMessage);

    final currentMessages = _messagesByConversation[conversationId] ?? [];
    _messagesByConversation[conversationId] = [optimisticMessage, ...currentMessages];
    notifyListeners();

    try {
      final realMessage = await _apiService.sendMessage(
        conversationId: conversationId,
        content: content,
      );
      await _messageCache.saveMessage(realMessage);
      await _messageCache.markSynced(realMessage.id);

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
      rethrow;
    }
  }

  // ==========================================================
  // REAL-TIME (SOCKET.IO)
  // ==========================================================

  void initSocket(String accessToken) {
    if (_socket != null) {
      if (!_socket!.connected) _socket!.connect();
      return;
    }

    final baseUrl = ApiConfig.baseUrl.replaceFirst('/api', '');
    _socket = io.io('$baseUrl/messages', io.OptionBuilder()
      .setTransports(['websocket'])
      .setAuth({'token': accessToken})
      .enableAutoConnect()
      .build());

    _socket?.onConnect((_) {
      debugPrint('Socket: Connected to /messages');
      // On reconnect, re-fetch lists in case we missed events
      _refreshAllData();
    });

    _socket?.onDisconnect((_) => debugPrint('Socket: Disconnected'));

    _socket?.on('message_received', (data) {
      final message = ChatMessage.fromJson(Map<String, dynamic>.from(data));
      _handleIncomingMessage(message);
    });

    // ==========================================================
    // MESSAGE REQUEST EVENTS
    // ==========================================================

    _socket?.on('message_request_received', (data) {
      debugPrint('Socket: message_request_received');
      final request = MessageRequest.fromJson(Map<String, dynamic>.from(data));
      _handleRequestReceived(request);
    });

    _socket?.on('message_request_accepted', (data) {
      debugPrint('Socket: message_request_accepted');
      final request = MessageRequest.fromJson(Map<String, dynamic>.from(data));
      _handleRequestAccepted(request);
    });

    _socket?.on('message_request_declined', (data) {
      debugPrint('Socket: message_request_declined');
      final request = MessageRequest.fromJson(Map<String, dynamic>.from(data));
      _handleRequestDeclined(request);
    });

    _socket?.on('message_request_withdrawn', (data) {
      debugPrint('Socket: message_request_withdrawn');
      final request = MessageRequest.fromJson(Map<String, dynamic>.from(data));
      _handleRequestWithdrawn(request);
    });
  }

  void disconnectSocket() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  Future<void> _refreshAllData() async {
    await Future.wait([
      loadRequests(),
      loadFriends(),
      loadConversations(),
    ]);
  }

  void _handleRequestReceived(MessageRequest request) {
    // Add to received requests if not already there
    final index = _receivedRequests.indexWhere((r) => r.id == request.id);
    if (index == -1) {
      _receivedRequests.insert(0, request);
    } else {
      _receivedRequests[index] = request;
    }
    notifyListeners();
  }

  void _handleRequestAccepted(MessageRequest request) {
    // Remove from pending lists
    _receivedRequests.removeWhere((r) => r.id == request.id);
    _sentRequests.removeWhere((r) => r.id == request.id);
    
    // Refresh friends and conversations since a new friendship/DM is created
    loadFriends();
    loadConversations();
    
    notifyListeners();
  }

  void _handleRequestDeclined(MessageRequest request) {
    _receivedRequests.removeWhere((r) => r.id == request.id);
    _sentRequests.removeWhere((r) => r.id == request.id);
    notifyListeners();
  }

  void _handleRequestWithdrawn(MessageRequest request) {
    _receivedRequests.removeWhere((r) => r.id == request.id);
    _sentRequests.removeWhere((r) => r.id == request.id);
    notifyListeners();
  }

  void _handleIncomingMessage(ChatMessage message) {
    _messageSync.saveIncomingMessage(message);
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
    try {
      await _apiService.removeFriend(userId);
      _friends.removeWhere((f) => f.id == userId);
      notifyListeners();
      
      // Refresh state to ensure lists are in sync
      await loadConversations();
    } catch (e) {
      debugPrint('Error removing friend: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }
}
