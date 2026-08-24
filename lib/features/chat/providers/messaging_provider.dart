import 'package:flutter/foundation.dart';
import 'package:griot_cowrie/features/chat/models/chat_message.dart';
import 'package:griot_cowrie/features/chat/models/conversation_model.dart';
import 'package:griot_cowrie/features/chat/models/message_request.dart';
import 'package:griot_cowrie/features/chat/models/chat_group.dart';
import 'package:griot_cowrie/features/chat/models/chat_channel.dart';
import 'package:griot_cowrie/features/chat/services/messaging_api_service.dart';
import 'package:griot_cowrie/features/users/models/user_model.dart';
import 'package:griot_cowrie/features/users/providers/user_provider.dart';

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
  final Map<String, bool> _hasMoreMessages = {};
  
  List<Conversation> _conversations = [];
  bool _isLoadingConversations = false;

  List<MessageRequest> _receivedRequests = [];
  List<MessageRequest> _sentRequests = [];
  bool _isLoadingRequests = false;

  List<UserModel> _friends = [];
  bool _isLoadingFriends = false;

  List<ChatGroup> _groups = [];
  bool _isLoadingGroups = false;

  List<ChatChannel> _channels = [];
  bool _isLoadingChannels = false;

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

  List<ChatGroup> get groups => _groups;
  bool get isLoadingGroups => _isLoadingGroups;

  List<ChatChannel> get channels => _channels;
  bool get isLoadingChannels => _isLoadingChannels;
  
  int get pendingRequestCount => _receivedRequests.where((r) => r.status == RequestStatus.pending).length;
  
  List<ChatMessage> getMessagesForConversation(String conversationId) => 
      _messagesByConversation[conversationId] ?? [];
      
  bool isLoadingMessages(String conversationId) => 
      _isLoadingMessages[conversationId] ?? false;

  // ==========================================================
  // ACTIONS
  // ==========================================================

  Future<void> loadConversations() async {
    _isLoadingConversations = true;
    notifyListeners();

    try {
      final list = await _apiService.getConversations();
      // Sort by updatedAt (newest first)
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _conversations = list;
    } catch (e) {
      debugPrint('Error loading conversations: $e');
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

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

  Future<void> loadGroups() async {
    _isLoadingGroups = true;
    notifyListeners();

    try {
      _groups = await _apiService.getGroups();
    } catch (e) {
      debugPrint('Error loading groups: $e');
    } finally {
      _isLoadingGroups = false;
      notifyListeners();
    }
  }

  Future<void> loadChannels() async {
    _isLoadingChannels = true;
    notifyListeners();

    try {
      _channels = await _apiService.getChannels();
    } catch (e) {
      debugPrint('Error loading channels: $e');
    } finally {
      _isLoadingChannels = false;
      notifyListeners();
    }
  }

  Future<void> acceptRequest(String requestId) async {
    try {
      await _apiService.acceptRequest(requestId);
      // Reload everything to update conversations, requests, friends
      await Future.wait([loadConversations(), loadRequests(), loadFriends()]);
    } catch (e) {
      debugPrint('Error accepting request: $e');
      rethrow;
    }
  }

  Future<void> removeFriend(String friendId) async {
    try {
      await _apiService.removeFriend(friendId);
      await loadFriends();
    } catch (e) {
      debugPrint('Error removing friend: $e');
      rethrow;
    }
  }

  Future<void> createGroup({required String name, String? description, List<String>? memberIds}) async {
    try {
      await _apiService.createGroup(name: name, description: description, memberIds: memberIds);
      await loadGroups();
    } catch (e) {
      debugPrint('Error creating group: $e');
      rethrow;
    }
  }

  Future<void> createChannel({required String name, String? description}) async {
    try {
      await _apiService.createChannel(name: name, description: description);
      await loadChannels();
    } catch (e) {
      debugPrint('Error creating channel: $e');
      rethrow;
    }
  }

  Future<void> subscribeToChannel(String conversationId) async {
    try {
      await _apiService.subscribeToChannel(conversationId);
      await loadChannels();
    } catch (e) {
      debugPrint('Error subscribing to channel: $e');
      rethrow;
    }
  }

  Future<void> unsubscribeFromChannel(String conversationId) async {
    try {
      await _apiService.unsubscribeFromChannel(conversationId);
      await loadChannels();
    } catch (e) {
      debugPrint('Error unsubscribing from channel: $e');
      rethrow;
    }
  }

  Future<void> deleteMessage(String conversationId, String messageId) async {
    try {
      await _apiService.deleteMessage(messageId);
      final list = _messagesByConversation[conversationId] ?? [];
      list.removeWhere((m) => m.id == messageId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting message: $e');
      rethrow;
    }
  }

  Future<void> addReaction(String conversationId, String messageId, String reaction) async {
    try {
      await _apiService.addReaction(messageId, reaction);
      // In a real app, we might update the local message state here
      // For now, Socket.IO would ideally handle the realtime update
    } catch (e) {
      debugPrint('Error adding reaction: $e');
      rethrow;
    }
  }

  Future<void> removeReaction(String conversationId, String messageId) async {
    try {
      await _apiService.removeReaction(messageId);
    } catch (e) {
      debugPrint('Error removing reaction: $e');
      rethrow;
    }
  }

  Future<void> leaveGroup(String conversationId) async {
    try {
      await _apiService.leaveGroup(conversationId);
      await loadConversations();
      await loadGroups();
    } catch (e) {
      debugPrint('Error leaving group: $e');
      rethrow;
    }
  }

  Future<void> declineRequest(String requestId) async {
    try {
      await _apiService.declineRequest(requestId);
      await loadRequests();
    } catch (e) {
      debugPrint('Error declining request: $e');
      rethrow;
    }
  }

  Future<void> cancelRequest(String requestId) async {
    try {
      await _apiService.cancelRequest(requestId);
      await loadRequests();
    } catch (e) {
      debugPrint('Error cancelling request: $e');
      rethrow;
    }
  }

  Future<void> sendRequest(String recipientId) async {
    try {
      await _apiService.sendChatRequest(recipientId);
      await loadRequests();
    } catch (e) {
      debugPrint('Error sending request: $e');
      rethrow;
    }
  }

  Future<void> loadMessages(String conversationId, {bool refresh = false}) async {
    if (_isLoadingMessages[conversationId] == true) return;
    
    final currentMessages = _messagesByConversation[conversationId] ?? [];
    String? before;
    if (!refresh && currentMessages.isNotEmpty) {
      // Find the oldest message to use as cursor
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

      final List<ChatMessage> combined;
      if (refresh) {
        combined = newMessages;
      } else {
        combined = [...currentMessages, ...newMessages];
      }
      
      // Normalize ordering by createdAt (newest first for the UI ListView.builder reverse: true)
      combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      _messagesByConversation[conversationId] = combined;
      _hasMoreMessages[conversationId] = newMessages.length >= 50;
    } catch (e) {
      debugPrint('Error loading messages: $e');
    } finally {
      _isLoadingMessages[conversationId] = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String conversationId, String content) async {
    final currentUserId = _userProvider.user?.id ?? '';
    
    // 1. Optimistic Update
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
      // 2. Real API call
      final realMessage = await _apiService.sendMessage(
        conversationId: conversationId,
        content: content,
      );

      // 3. Replace optimistic message
      final list = _messagesByConversation[conversationId] ?? [];
      final index = list.indexWhere((m) => m.id == tempId);
      if (index != -1) {
        list[index] = realMessage;
        // Re-sort to be safe, although usually it would be the first anyway
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        notifyListeners();
      }
    } catch (e) {
      // 4. Handle failure
      final list = _messagesByConversation[conversationId] ?? [];
      final index = list.indexWhere((m) => m.id == tempId);
      if (index != -1) {
        list[index] = optimisticMessage.copyWith(status: MessageStatus.failed);
        notifyListeners();
      }
    }
  }

  Future<Conversation> startDirectChat(String otherUserId) async {
    final conversation = await _apiService.findOrCreateDirectConversation(otherUserId);
    if (!_conversations.any((c) => c.id == conversation.id)) {
      _conversations.insert(0, conversation);
    }
    notifyListeners();
    return conversation;
  }

  void markAsRead(String conversationId, String messageId) {
    _apiService.markMessageReceipt(messageId, 'read');
  }
}
