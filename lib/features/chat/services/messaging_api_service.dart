import 'package:griot_cowrie/core/network/api_client.dart';
import 'package:griot_cowrie/core/network/api_config.dart';
import 'package:griot_cowrie/features/chat/models/chat_message.dart';
import 'package:griot_cowrie/features/chat/models/conversation_model.dart';
import 'package:griot_cowrie/features/chat/models/message_request.dart';
import 'package:griot_cowrie/features/chat/models/chat_group.dart';
import 'package:griot_cowrie/features/chat/models/chat_channel.dart';
import 'package:griot_cowrie/features/users/models/user_model.dart';

class MessagingApiService {
  final ApiClient _apiClient;

  MessagingApiService({required ApiClient apiClient}) : _apiClient = apiClient;

  // ==========================================================
  // CONVERSATIONS
  // ==========================================================

  Future<List<Conversation>> getConversations() async {
    final response = await _apiClient.get(ApiConfig.messagingDirectList());
    final data = response['data'] ?? response;
    if (data is List) {
      return data.map((c) => Conversation.fromJson(Map<String, dynamic>.from(c))).toList();
    }
    return [];
  }

  Future<Conversation> findOrCreateDirectConversation(String otherUserId) async {
    final response = await _apiClient.get(ApiConfig.messagingDirectFind(otherUserId));
    final data = response['data'] ?? response;
    return Conversation.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Conversation> getConversation(String conversationId) async {
    final response = await _apiClient.get(ApiConfig.messagingDirectById(conversationId));
    final data = response['data'] ?? response;
    return Conversation.fromJson(Map<String, dynamic>.from(data));
  }

  // ==========================================================
  // MESSAGES
  // ==========================================================

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String content,
    String messageType = 'text',
  }) async {
    final response = await _apiClient.post(
      ApiConfig.messagingMessages,
      body: {
        'conversationId': conversationId,
        'content': content,
        'messageType': messageType,
      },
    );
    final data = response['message'] ?? response['data'] ?? response;
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
    final data = response['data'] ?? response['messages'] ?? response;
    if (data is List) {
      return data.map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m))).toList();
    }
    return [];
  }

  Future<void> deleteMessage(String messageId) async {
    await _apiClient.delete(ApiConfig.messagingMessageById(messageId));
  }

  // ==========================================================
  // RECEIPTS & REACTIONS
  // ==========================================================

  Future<void> markMessageReceipt(String messageId, String status) async {
    await _apiClient.post(
      ApiConfig.messagingReceipts(messageId),
      body: {'status': status},
    );
  }

  Future<void> addReaction(String messageId, String reaction) async {
    await _apiClient.post(
      ApiConfig.messagingReactions(messageId),
      body: {'reaction': reaction},
    );
  }

  // ==========================================================
  // REQUESTS
  // ==========================================================

  Future<List<MessageRequest>> getReceivedRequests() async {
    final response = await _apiClient.get(ApiConfig.messagingRequestsReceived);
    final data = response['data'] ?? response;
    if (data is List) {
      return data.map((r) => MessageRequest.fromJson(Map<String, dynamic>.from(r))).toList();
    }
    return [];
  }

  Future<List<MessageRequest>> getSentRequests() async {
    final response = await _apiClient.get(ApiConfig.messagingRequestsSent);
    final data = response['data'] ?? response;
    if (data is List) {
      return data.map((r) => MessageRequest.fromJson(Map<String, dynamic>.from(r))).toList();
    }
    return [];
  }

  Future<void> sendChatRequest(String recipientId) async {
    await _apiClient.post(
      ApiConfig.messagingRequests,
      body: {
        'recipientId': recipientId,
        'requestType': 'dm',
      },
    );
  }

  Future<void> acceptRequest(String requestId) async {
    await _apiClient.post(ApiConfig.messagingRequestAccept(requestId));
  }

  Future<void> declineRequest(String requestId) async {
    await _apiClient.post(ApiConfig.messagingRequestDecline(requestId));
  }

  Future<void> cancelRequest(String requestId) async {
    await _apiClient.post(ApiConfig.messagingRequestCancel(requestId));
  }

  // ==========================================================
  // FRIENDS
  // ==========================================================

  Future<List<UserModel>> getFriends() async {
    final response = await _apiClient.get(ApiConfig.messagingFriends);
    final data = response['data'] ?? response;
    if (data is List) {
      return data.map((u) => UserModel.fromJson(Map<String, dynamic>.from(u))).toList();
    }
    return [];
  }

  Future<List<UserModel>> searchFriends(String query) async {
    final response = await _apiClient.get(ApiConfig.messagingFriendsSearch(query));
    final data = response['data'] ?? response;
    if (data is List) {
      return data.map((u) => UserModel.fromJson(Map<String, dynamic>.from(u))).toList();
    }
    return [];
  }

  Future<void> removeFriend(String friendId) async {
    await _apiClient.delete(ApiConfig.messagingFriendById(friendId));
  }

  // ==========================================================
  // GROUPS
  // ==========================================================

  Future<List<ChatGroup>> getGroups() async {
    final response = await _apiClient.get(ApiConfig.messagingGroups);
    final data = response['data'] ?? response;
    if (data is List) {
      return data.map((g) => ChatGroup.fromJson(Map<String, dynamic>.from(g))).toList();
    }
    return [];
  }

  Future<ChatGroup> createGroup({required String name, String? description, List<String>? memberIds}) async {
    final response = await _apiClient.post(
      ApiConfig.messagingGroups,
      body: {
        'name': name,
        if (description != null) 'description': description,
        if (memberIds != null) 'memberIds': memberIds,
      },
    );
    final data = response['data'] ?? response;
    return ChatGroup.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> addGroupMember(String conversationId, String userId) async {
    await _apiClient.post(
      ApiConfig.messagingGroupMembers(conversationId),
      body: {'userId': userId},
    );
  }

  Future<void> leaveGroup(String conversationId) async {
    await _apiClient.post('${ApiConfig.messagingGroupById(conversationId)}/leave');
  }

  Future<void> removeGroupMember(String conversationId, String memberId) async {
    await _apiClient.delete('${ApiConfig.messagingGroupMembers(conversationId)}/$memberId');
  }

  Future<void> updateGroup(String conversationId, Map<String, dynamic> data) async {
    await _apiClient.patch(ApiConfig.messagingGroupById(conversationId), body: data);
  }

  // ==========================================================
  // CHANNELS
  // ==========================================================

  Future<List<ChatChannel>> getChannels() async {
    final response = await _apiClient.get(ApiConfig.messagingChannels);
    final data = response['data'] ?? response;
    if (data is List) {
      return data.map((c) => ChatChannel.fromJson(Map<String, dynamic>.from(c))).toList();
    }
    return [];
  }

  Future<ChatChannel> createChannel({required String name, String? description}) async {
    final response = await _apiClient.post(
      ApiConfig.messagingChannels,
      body: {
        'name': name,
        if (description != null) 'description': description,
      },
    );
    final data = response['data'] ?? response;
    return ChatChannel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> subscribeToChannel(String conversationId) async {
    await _apiClient.post(ApiConfig.messagingChannelSubscribe(conversationId));
  }

  Future<void> unsubscribeFromChannel(String conversationId) async {
    await _apiClient.delete(ApiConfig.messagingChannelSubscribe(conversationId));
  }

  Future<void> updateChannel(String conversationId, Map<String, dynamic> data) async {
    await _apiClient.patch(ApiConfig.messagingChannelById(conversationId), body: data);
  }

  Future<void> deleteChannel(String conversationId) async {
    await _apiClient.delete(ApiConfig.messagingChannelById(conversationId));
  }

  // ==========================================================
  // RECEIPTS & REACTIONS
  // ==========================================================

  Future<List<dynamic>> getMessageReceipts(String messageId) async {
    final response = await _apiClient.get(ApiConfig.messagingReceipts(messageId));
    return response['data'] ?? response;
  }

  Future<List<dynamic>> getMessageReactions(String messageId) async {
    final response = await _apiClient.get(ApiConfig.messagingReactions(messageId));
    return response['data'] ?? response;
  }

  Future<void> removeReaction(String messageId) async {
    await _apiClient.delete(ApiConfig.messagingReactions(messageId));
  }
}
