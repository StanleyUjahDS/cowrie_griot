import 'package:griot_cowrie/core/network/api_client.dart';
import 'package:griot_cowrie/core/network/api_config.dart';
import 'package:griot_cowrie/core/network/api_exception.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../models/conversation_model.dart';
import '../models/message_request.dart';
import '../../users/models/user_model.dart';

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

  Future<Conversation> getConversation(String conversationId) async {
    final response = await _apiClient.get('${ApiConfig.messagingBase}/conversations/$conversationId');
    return Conversation.fromJson(Map<String, dynamic>.from(_getData(response)));
  }

  Future<List<Conversation>> getGroups() async {
    final response = await _apiClient.get(ApiConfig.messagingGroups);
    return _conversationList(_getData(response), fallbackType: 'group');
  }

  Future<Conversation> getGroup(String conversationId) async {
    final response = await _apiClient.get(ApiConfig.messagingGroupById(conversationId));
    return Conversation.fromJson(Map<String, dynamic>.from(_getData(response)));
  }

  Future<Conversation> getGroupByUsername(String username) async {
    final response = await _apiClient.get(ApiConfig.messagingGroupByUsername(username));
    return Conversation.fromJson(Map<String, dynamic>.from(_getData(response)));
  }

  Future<Conversation> createGroup({
    required String name,
    List<String> memberIds = const [],
    String visibility = 'public',
    String? username,
  }) async {
    final response = await _apiClient.post(ApiConfig.messagingGroups, body: {
      'name': name,
      'memberIds': memberIds,
      'visibility': visibility,
      if (username != null && username.trim().isNotEmpty) 'username': username.trim().toLowerCase(),
    });
    return Conversation.fromJson(Map<String, dynamic>.from(_getData(response)));
  }

  Future<List<Conversation>> getChannels() async {
    final response = await _apiClient.get(ApiConfig.messagingChannelsMe);
    return _conversationList(_getData(response), fallbackType: 'channel');
  }

  Future<Conversation> getChannel(String conversationId) async {
    final response = await _apiClient.get(ApiConfig.messagingChannelById(conversationId));
    return Conversation.fromJson(Map<String, dynamic>.from(_getData(response)));
  }

  Future<Conversation> getChannelByUsername(String username) async {
    final response = await _apiClient.get(ApiConfig.messagingChannelByUsername(username));
    return Conversation.fromJson(Map<String, dynamic>.from(_getData(response)));
  }

  Future<Conversation> createChannel({
    required String name,
    required String username,
    String? description,
    String visibility = 'public',
  }) async {
    final response = await _apiClient.post(ApiConfig.messagingChannels, body: {
      'name': name,
      'username': username,
      if (description != null) 'description': description,
      'visibility': visibility,
    });
    return Conversation.fromJson(Map<String, dynamic>.from(_getData(response)));
  }

  Future<void> subscribeToChannel(String conversationId) async {
    final response = await _apiClient.post(ApiConfig.messagingChannelSubscribe(conversationId));
    _checkSuccess(response);
  }

  Future<void> unsubscribeFromChannel(String conversationId) async {
    final response = await _apiClient.delete(ApiConfig.messagingChannelSubscribe(conversationId));
    _checkSuccess(response);
  }

  Future<void> addGroupMember(String conversationId, String userId) async {
    final response = await _apiClient.post(
      ApiConfig.messagingGroupMembers(conversationId),
      body: {'memberId': userId},
    );
    _checkSuccess(response);
  }

  Future<void> removeGroupMember(String conversationId, String userId) async {
    final response = await _apiClient.delete(
      ApiConfig.messagingGroupMemberById(conversationId, userId),
    );
    _checkSuccess(response);
  }

  Future<void> leaveGroup(String conversationId) async {
    final response = await _apiClient.post(ApiConfig.messagingGroupLeave(conversationId));
    _checkSuccess(response);
  }

  Future<Conversation> updateGroup(
    String conversationId, {
    String? name,
    String? description,
    String? imageUrl,
    String? visibility,
  }) async {
    final response = await _apiClient.patch(
      ApiConfig.messagingGroupById(conversationId),
      body: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (visibility != null) 'visibility': visibility,
      },
    );
    return Conversation.fromJson(Map<String, dynamic>.from(_getData(response)));
  }

  Future<Conversation> updateChannel(
    String conversationId, {
    String? name,
    String? description,
    String? imageUrl,
    String? visibility,
  }) async {
    final response = await _apiClient.patch(
      ApiConfig.messagingChannelById(conversationId),
      body: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (visibility != null) 'visibility': visibility,
      },
    );
    return Conversation.fromJson(Map<String, dynamic>.from(_getData(response)));
  }

  Future<void> deleteChannel(String conversationId) async {
    final response = await _apiClient.delete(ApiConfig.messagingChannelById(conversationId));
    _checkSuccess(response);
  }

  Future<List<ChatUser>> getConversationMembers(String conversationId, {bool isGroup = false}) async {
    final url = isGroup 
        ? ApiConfig.messagingGroupMembers(conversationId) 
        : ApiConfig.messagingDirectMembers(conversationId);
    final response = await _apiClient.get(url);
    final data = _getData(response);
    if (data is List) {
      return data.map((c) => ChatUser.fromJson(Map<String, dynamic>.from(c))).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getGroupMembers(String conversationId) async {
    final response = await _apiClient.get(ApiConfig.messagingGroupMembers(conversationId));
    final data = _getData(response);
    if (data is List) {
      return data.map((c) => Map<String, dynamic>.from(c)).toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getChannelMembers(String conversationId) async {
    final response = await _apiClient.get(ApiConfig.messagingChannelById(conversationId) + '/members');
    final data = _getData(response);
    if (data is List) {
      return data.map((c) => Map<String, dynamic>.from(c)).toList();
    }
    return [];
  }

  // ==========================================================
  // MESSAGES
  // ==========================================================

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String content,
    String messageType = 'text',
    String? replyToMessageId,
    String? mediaId,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.messagingMessages,
      body: {
        'conversationId': conversationId,
        'content': content,
        'messageType': messageType,
        if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
        if (mediaId != null) 'mediaId': mediaId,
      },
    );
    final data = _getData(response);
    return ChatMessage.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> deleteMessage(String messageId) async {
    final response = await _apiClient.delete(ApiConfig.messagingMessageById(messageId));
    _checkSuccess(response);
  }

  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) async {
    // Cap limit at 100 as per spec
    final effectiveLimit = limit.clamp(1, 100);
    
    final response = await _apiClient.get(
      ApiConfig.messagingMessagesByConversation(conversationId, limit: effectiveLimit, before: before),
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

  Future<void> toggleReaction(String messageId, String emoji) async {
    // Reference: POST /api/messaging/messages/:messageId/reactions { "reaction": "❤️" }
    final response = await _apiClient.post(
      ApiConfig.messagingReactions(messageId),
      body: {'reaction': emoji},
    );
    _checkSuccess(response);
  }

  Future<void> removeReaction(String messageId, String emoji) async {
    // Reference: DELETE /api/messaging/messages/:messageId/reactions { "reaction": "❤️" }
    final response = await _apiClient.delete(
      ApiConfig.messagingReactions(messageId),
      body: {'reaction': emoji},
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

  Future<MessageRequest> sendDirectMessageRequest(
    String recipientId, {
    String? message,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.messagingRequests,
      body: {
        'recipientId': recipientId,
        'message': ?message,
        'requestType': 'dm',
      },
    );
    final data = _getData(response);
    return MessageRequest.fromJson(Map<String, dynamic>.from(data));
  }

  Future<MessageRequest> sendFriendRequest(
    String recipientId, {
    String? message,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.messagingRequests,
      body: {
        'recipientId': recipientId,
        'message': ?message,
        'requestType': 'dm',
      },
    );
    final data = _getData(response);
    return MessageRequest.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Map<String, dynamic>> acceptRequest(String requestId) async {
    final response = await _apiClient.post(ApiConfig.messagingRequestAccept(requestId));
    final data = _getData(response);
    return Map<String, dynamic>.from(data);
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

  Future<Map<String, dynamic>> getFriendsPage({int limit = 20, int offset = 0}) async {
    final response = await _apiClient.get(ApiConfig.messagingFriendsPaged(limit: limit, offset: offset));
    final data = _getData(response);
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> searchFriends({required String query, int limit = 20, int offset = 0}) async {
    final response = await _apiClient.get(ApiConfig.messagingFriendsSearch(query, limit: limit, offset: offset));
    final data = _getData(response);
    return Map<String, dynamic>.from(data);
  }

  Future<int> getFriendsCount() async {
    final response = await _apiClient.get(ApiConfig.messagingFriendsCount);
    final data = _getData(response);
    return (data['total'] ?? 0) as int;
  }

  Future<void> removeFriend(String friendId) async {
    final response = await _apiClient.delete(ApiConfig.messagingFriendById(friendId));
    _checkSuccess(response);
  }

  // ==========================================================
  // CHANNELS - POSTS & COMMENTS
  // ==========================================================

  Future<List<ChatMessage>> getChannelPosts(String conversationId) async {
    final response = await _apiClient.get(ApiConfig.messagingChannelPosts(conversationId));
    final data = _getData(response);
    if (data is List) {
      return data.map((p) => ChatMessage.fromJson(Map<String, dynamic>.from(p))).toList();
    }
    return [];
  }

  Future<ChatMessage> createChannelPost(
    String conversationId,
    String content, {
    String? mediaId,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.messagingChannelPosts(conversationId),
      body: {
        'content': content,
        'mediaId': ?mediaId,
      },
    );
    final data = _getData(response);
    return ChatMessage.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<Map<String, dynamic>>> getChannelComments(String conversationId, String postId) async {
    final response = await _apiClient.get(ApiConfig.messagingChannelComments(conversationId, postId));
    final data = _getData(response);
    if (data is List) {
      return data.map((c) => Map<String, dynamic>.from(c)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> createChannelComment({
    required String conversationId,
    required String postId,
    required String content,
    String? replyToCommentId,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.messagingChannelComments(conversationId, postId),
      body: {
        'content': content,
        'replyToCommentId': replyToCommentId,
      },
    );
    final data = _getData(response);
    return Map<String, dynamic>.from(data);
  }

  Future<void> deleteChannelComment(String conversationId, String postId, String commentId) async {
    final response = await _apiClient.delete(
      '${ApiConfig.messagingChannelComments(conversationId, postId)}/$commentId',
    );
    _checkSuccess(response);
  }

  // ==========================================================
  // HELPERS
  // ==========================================================

  dynamic _getData(dynamic response) {
    if (response is Map<String, dynamic>) {
      if (response['success'] == true) {
        return response['data'];
      }
      throw ApiException(
        message: response['message'] ?? 'Request failed',
        data: response['data'],
      );
    }
    return response;
  }

  void _checkSuccess(dynamic response) {
    if (response is Map<String, dynamic> && response['success'] != true) {
      throw ApiException(
        message: response['message'] ?? 'Request failed',
        data: response['data'],
      );
    }
  }

  List<Conversation> _conversationList(dynamic data, {required String fallbackType}) {
    if (data is! List) return [];
    return data.map((item) {
      final json = Map<String, dynamic>.from(item);
      json['type'] ??= fallbackType;
      json['title'] ??= json['name'];
      json['avatarUrl'] ??= json['image_url'] ?? json['imageUrl'];
      json['memberIds'] ??= <String>[];
      return Conversation.fromJson(json);
    }).toList();
  }
}
