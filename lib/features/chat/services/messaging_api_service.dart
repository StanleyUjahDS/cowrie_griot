import 'package:griot_cowrie/core/network/api_client.dart';
import 'package:griot_cowrie/core/network/api_config.dart';
import 'package:griot_cowrie/features/chat/models/chat_message.dart';
import 'package:griot_cowrie/features/chat/models/conversation_model.dart';
import 'package:griot_cowrie/features/chat/models/message_request.dart';
import 'package:griot_cowrie/features/users/models/user_model.dart';

class MessagingApiService {
  final ApiClient _apiClient;

  MessagingApiService({required ApiClient apiClient}) : _apiClient = apiClient;

  // ==========================================================
  // CONVERSATIONS
  // ==========================================================

  Future<List<Conversation>> getConversations() async {
    final response = await _apiClient.get(ApiConfig.messagingConversations);
    final data = _getData(response);
    if (data is List) {
      return data.map((c) => Conversation.fromJson(Map<String, dynamic>.from(c))).toList();
    }
    return [];
  }

  Future<Conversation> findDirectConversation(String otherUserId) async {
    final response = await _apiClient.get(ApiConfig.messagingDirectFind(otherUserId));
    final data = _getData(response);
    return Conversation.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Conversation> getConversationDetails(String conversationId) async {
    final response = await _apiClient.get(ApiConfig.messagingDirectById(conversationId));
    final data = _getData(response);
    return Conversation.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Conversation> getConversation(String conversationId) => getConversationDetails(conversationId);

  // ==========================================================
  // MESSAGES
  // ==========================================================

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.messagingMessages,
      body: {
        'conversationId': conversationId,
        'content': content,
        'messageType': 'text',
      },
    );
    final data = _getData(response);
    return ChatMessage.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.messagingMessagesByConversation(conversationId, limit: limit, before: before),
    );
    final data = _getData(response);
    if (data is List) {
      return data.map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m))).toList();
    }
    return [];
  }

  // ==========================================================
  // RECEIPTS & REACTIONS
  // ==========================================================

  Future<void> markMessageReceipt(String messageId, String status) async {
    final response = await _apiClient.post(
      ApiConfig.messagingReceipts(messageId),
      body: {'status': status},
    );
    _checkSuccess(response);
  }

  // ==========================================================
  // REQUESTS
  // ==========================================================

  Future<List<MessageRequest>> getReceivedRequests() async {
    final response = await _apiClient.get(ApiConfig.messagingRequestsReceived);
    final data = _getData(response);
    if (data is List) {
      return data.map((r) => MessageRequest.fromJson(Map<String, dynamic>.from(r))).toList();
    }
    return [];
  }

  Future<List<MessageRequest>> getSentRequests() async {
    final response = await _apiClient.get(ApiConfig.messagingRequestsSent);
    final data = _getData(response);
    if (data is List) {
      return data.map((r) => MessageRequest.fromJson(Map<String, dynamic>.from(r))).toList();
    }
    return [];
  }

  Future<MessageRequest> sendDirectMessageRequest(String recipientId) async {
    final response = await _apiClient.post(
      ApiConfig.messagingRequests,
      body: {
        'recipientId': recipientId,
        'requestType': 'dm',
      },
    );
    final data = _getData(response);
    return MessageRequest.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Conversation> acceptRequest(String requestId) async {
    final response = await _apiClient.post(ApiConfig.messagingRequestAccept(requestId));
    final data = _getData(response);
    // Backend should return the conversation object on success
    return Conversation.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> declineRequest(String requestId) async {
    final response = await _apiClient.post(ApiConfig.messagingRequestDecline(requestId));
    _checkSuccess(response);
  }

  Future<void> withdrawRequest(String requestId) async {
    final response = await _apiClient.post(ApiConfig.messagingRequestCancel(requestId));
    _checkSuccess(response);
  }

  // ==========================================================
  // BLOCKING
  // ==========================================================

  Future<List<String>> getBlockedUserIds() async {
    final response = await _apiClient.get(ApiConfig.messagingBlocks);
    final data = _getData(response);
    if (data is List) {
      return data.map((u) => (u['id'] ?? u['userId']).toString()).toList();
    }
    return [];
  }

  Future<void> blockUser(String userId) async {
    final response = await _apiClient.post(ApiConfig.messagingBlockUser(userId));
    _checkSuccess(response);
  }

  Future<void> unblockUser(String userId) async {
    final response = await _apiClient.delete(ApiConfig.messagingBlockUser(userId));
    _checkSuccess(response);
  }

  // ==========================================================
  // FRIENDS
  // ==========================================================

  Future<List<UserModel>> getFriends() async {
    final response = await _apiClient.get(ApiConfig.messagingFriends);
    final data = _getData(response);
    if (data is List) {
      return data.map((u) => UserModel.fromJson(Map<String, dynamic>.from(u))).toList();
    }
    return [];
  }

  // ==========================================================
  // HELPERS
  // ==========================================================

  dynamic _getData(dynamic response) {
    if (response is Map<String, dynamic>) {
      if (response['success'] == true) {
        return response['data'];
      }
      throw Exception(response['message'] ?? 'Request failed');
    }
    return response;
  }

  void _checkSuccess(dynamic response) {
    if (response is Map<String, dynamic> && response['success'] != true) {
      throw Exception(response['message'] ?? 'Request failed');
    }
  }
}
