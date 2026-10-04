import 'package:griot_cowrie/core/network/api_client.dart';
import 'package:griot_cowrie/core/network/api_config.dart';
import 'package:griot_cowrie/core/network/api_exception.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../models/conversation_model.dart';
import '../models/message_request.dart';
import '../models/space_model.dart';
import '../../users/models/user_model.dart';

class MessagingApiService {
  final ApiClient _apiClient;

  MessagingApiService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<Map<String, dynamic>>> getActivityEvents({
    int limit = 30,
    int offset = 0,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.notificationActivity(limit: limit, offset: offset),
    );
    final data = _getData(response);
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  // ==========================================================
  // CONVERSATIONS
  // ==========================================================

  Future<List<Conversation>> getConversations() async {
    final response = await _apiClient.get(ApiConfig.messagingConversations);
    final data = _getData(response);
    if (data is List) {
      return data
          .map((c) => Conversation.fromJson(Map<String, dynamic>.from(c)))
          .toList();
    }
    return [];
  }

  Future<Conversation> findDirectConversation(String otherUserId) async {
    final response = await _apiClient.get(
      ApiConfig.messagingDirectFind(otherUserId),
    );
    final data = _getData(response);
    return Conversation.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Conversation> getConversationDetails(String conversationId) async {
    final response = await _apiClient.get(
      ApiConfig.messagingDirectById(conversationId),
    );
    final data = _getData(response);
    return Conversation.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Conversation> getConversation(String conversationId) async {
    final response = await _apiClient.get(
      ApiConfig.messagingDirectById(conversationId),
    );
    return Conversation.fromJson(Map<String, dynamic>.from(_getData(response)));
  }

  Future<ChatUser> getOtherDirectUser(String conversationId) async {
    final response = await _apiClient.get(
      ApiConfig.messagingDirectOtherUser(conversationId),
    );
    return ChatUser.fromJson(Map<String, dynamic>.from(_getData(response)));
  }

  Future<List<Conversation>> getGroups() async {
    final response = await _apiClient.get(ApiConfig.messagingGroups);
    return _conversationList(_getData(response), fallbackType: 'group');
  }

  Future<Map<String, dynamic>> getActiveCampfires({
    int limit = 20,
    int offset = 0,
    String region = 'GLOBAL',
    bool forceRefresh = false,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.messagingCampfires(
        limit: limit,
        offset: offset,
        region: region,
      ),
      forceRefresh: forceRefresh,
    );
    var data = _getData(response);
    for (var depth = 0; depth < 3 && data is Map; depth++) {
      final map = Map<String, dynamic>.from(data);
      if (map['items'] is List ||
          map['spaces'] is List ||
          map['campfires'] is List) {
        return {
          ...map,
          'items': map['items'] ?? map['spaces'] ?? map['campfires'],
        };
      }
      data = map['data'];
    }
    if (data is List) return {'items': data, 'hasMore': false};
    if (response is Map && response['items'] is List) {
      return Map<String, dynamic>.from(response);
    }
    return {'items': <dynamic>[], 'hasMore': false};
  }

  Future<Map<String, dynamic>> getUpcomingCampfires({
    int limit = 10,
    int offset = 0,
    String region = 'GLOBAL',
    bool forceRefresh = false,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.messagingCampfiresUpcoming(
        limit: limit,
        offset: offset,
        region: region,
      ),
      forceRefresh: forceRefresh,
    );
    var data = _getData(response);
    for (var depth = 0; depth < 3 && data is Map; depth++) {
      final map = Map<String, dynamic>.from(data);
      if (map['items'] is List ||
          map['spaces'] is List ||
          map['campfires'] is List) {
        return {
          ...map,
          'items': map['items'] ?? map['spaces'] ?? map['campfires'],
        };
      }
      data = map['data'];
    }
    if (data is List) return {'items': data, 'hasMore': false};
    return {'items': <dynamic>[], 'hasMore': false};
  }

  Future<Map<String, dynamic>> createCampfire({
    required String title,
    String? description,
    String mode = 'voice',
    String regionCode = 'GLOBAL',
    bool recordingEnabled = false,
    DateTime? scheduledAt,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.messagingCampfiresCreate,
      body: {
        'title': title,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        'mode': mode,
        'regionCode': regionCode,
        'recordingEnabled': recordingEnabled,
        if (scheduledAt != null)
          'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      },
    );
    return Map<String, dynamic>.from(_getData(response));
  }

  Future<void> joinCampfire(String id) async {
    await _apiClient.post(ApiConfig.messagingCampfireJoin(id));
  }

  Future<void> leaveCampfire(String id) async {
    await _apiClient.post(ApiConfig.messagingCampfireLeave(id));
  }

  Future<List<SpaceParticipant>> getCampfireParticipants(String id) async {
    final response = await _apiClient.get(
      ApiConfig.messagingCampfireParticipants(id),
      forceRefresh: true,
    );
    final data = _getData(response);
    final raw = data is Map
        ? (data['items'] ?? data['participants'] ?? [])
        : data;
    return raw is List
        ? raw
              .whereType<Map>()
              .map(
                (item) =>
                    SpaceParticipant.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <SpaceParticipant>[];
  }

  Future<void> requestCampfireSpeaker(String id, {bool raised = true}) async {
    await _apiClient.post(
      ApiConfig.messagingCampfireRequestSpeaker(id),
      body: {'raised': raised},
    );
  }

  Future<void> moderateCampfireParticipant({
    required String campfireId,
    required String userId,
    required String action,
  }) async {
    await _apiClient.patch(
      ApiConfig.messagingCampfireModerateParticipant(campfireId, userId),
      body: {'action': action},
    );
  }

  Future<void> endCampfire(String id) async {
    await _apiClient.post(ApiConfig.messagingCampfireEnd(id));
  }

  Future<Conversation> getGroup(String conversationId) async {
    final response = await _apiClient.get(
      ApiConfig.messagingGroupById(conversationId),
    );
    return Conversation.fromJson(Map<String, dynamic>.from(_getData(response)));
  }

  Future<Conversation> getGroupByUsername(String username) async {
    final response = await _apiClient.get(
      ApiConfig.messagingGroupByUsername(username),
    );
    return Conversation.fromJson(Map<String, dynamic>.from(_getData(response)));
  }

  Future<void> joinPublicGroup(String conversationId) async {
    final response = await _apiClient.post(
      ApiConfig.messagingGroupJoin(conversationId),
    );
    _checkSuccess(response);
  }

  Future<List<Conversation>> discoverGroups(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.messagingGroupsDiscover(query, page: page, limit: limit),
    );
    return _conversationList(_getData(response), fallbackType: 'group');
  }

  Future<Conversation> createGroup({
    required String name,
    List<String> memberIds = const [],
    String visibility = 'public',
    bool messagesLocked = false,
    String? username,
    String? description,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.messagingGroups,
      body: {
        'name': name,
        'memberIds': memberIds,
        'member_ids': memberIds,
        'visibility': visibility,
        'messagesLocked': messagesLocked,
        'messages_locked': messagesLocked,
        if (username != null && username.trim().isNotEmpty)
          'username': username.trim().toLowerCase(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
    return Conversation.fromJson(Map<String, dynamic>.from(_getData(response)));
  }

  Future<List<Conversation>> getChannels() async {
    final response = await _apiClient.get(ApiConfig.messagingChannelsMe);
    return _conversationList(_getData(response), fallbackType: 'channel');
  }

  Future<Conversation> getChannel(String conversationId) async {
    final response = await _apiClient.get(
      ApiConfig.messagingChannelById(conversationId),
    );
    return Conversation.fromJson(Map<String, dynamic>.from(_getData(response)));
  }

  Future<Conversation> getChannelByUsername(String username) async {
    final response = await _apiClient.get(
      '${ApiConfig.messagingChannels}/username/${Uri.encodeComponent(username)}',
    );
    return Conversation.fromJson(Map<String, dynamic>.from(_getData(response)));
  }

  Future<List<Conversation>> discoverChannels(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.messagingChannelsDiscover(query, page: page, limit: limit),
    );
    return _conversationList(_getData(response), fallbackType: 'channel');
  }

  Future<Conversation> createChannel({
    required String name,
    required String username,
    String? description,
    String visibility = 'public',
    String? imageUrl,
    bool commentsLocked = false,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.messagingChannels,
      body: {
        'name': name,
        'username': username,
        ...?description == null ? null : {'description': description},
        'visibility': visibility,
        ...?imageUrl == null ? null : {'imageUrl': imageUrl},
        'commentsLocked': commentsLocked,
      },
    );
    return Conversation.fromJson(Map<String, dynamic>.from(_getData(response)));
  }

  Future<void> subscribeToChannel(String conversationId) async {
    final response = await _apiClient.post(
      ApiConfig.messagingChannelSubscribe(conversationId),
    );
    _checkSuccess(response);
  }

  Future<void> unsubscribeFromChannel(String conversationId) async {
    final response = await _apiClient.delete(
      ApiConfig.messagingChannelSubscribe(conversationId),
    );
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

  Future<void> updateGroupMemberRole(
    String conversationId,
    String userId,
    String role,
  ) async {
    final response = await _apiClient.patch(
      ApiConfig.messagingGroupMemberById(conversationId, userId),
      body: {'role': role},
    );
    _checkSuccess(response);
  }

  Future<void> leaveGroup(String conversationId) async {
    final response = await _apiClient.post(
      ApiConfig.messagingGroupLeave(conversationId),
    );
    _checkSuccess(response);
  }

  Future<void> deleteConversation(String conversationId) async {
    final response = await _apiClient.delete(
      ApiConfig.messagingConversationById(conversationId),
    );
    _checkSuccess(response);
  }

  Future<Conversation> updateGroup(
    String conversationId, {
    String? name,
    String? description,
    String? imageUrl,
    String? visibility,
    bool? messagesLocked,
    String? username,
  }) async {
    final response = await _apiClient.patch(
      ApiConfig.messagingGroupById(conversationId),
      body: {
        ...?name == null ? null : {'name': name},
        ...?description == null ? null : {'description': description},
        ...?imageUrl == null ? null : {'imageUrl': imageUrl},
        ...?visibility == null ? null : {'visibility': visibility},
        ...?messagesLocked == null ? null : {'messagesLocked': messagesLocked},
        ...?username == null
            ? null
            : {'username': username.trim().toLowerCase()},
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
    String? username,
    bool? commentsLocked,
  }) async {
    final response = await _apiClient.patch(
      ApiConfig.messagingChannelById(conversationId),
      body: {
        ...?name == null ? null : {'name': name},
        ...?description == null ? null : {'description': description},
        ...?imageUrl == null ? null : {'imageUrl': imageUrl},
        ...?visibility == null ? null : {'visibility': visibility},
        ...?username == null
            ? null
            : {'username': username.trim().toLowerCase()},
        ...?commentsLocked == null ? null : {'commentsLocked': commentsLocked},
      },
    );
    return Conversation.fromJson(Map<String, dynamic>.from(_getData(response)));
  }

  Future<void> deleteChannel(String conversationId) async {
    final response = await _apiClient.delete(
      ApiConfig.messagingChannelById(conversationId),
    );
    _checkSuccess(response);
  }

  Future<void> addChannelAdmin(String conversationId, String userId) async {
    final response = await _apiClient.post(
      '${ApiConfig.messagingChannelById(conversationId)}/admins',
      body: {'memberId': userId},
    );
    _checkSuccess(response);
  }

  Future<void> removeChannelAdmin(String conversationId, String userId) async {
    final response = await _apiClient.delete(
      '${ApiConfig.messagingChannelById(conversationId)}/admins',
      body: {'memberId': userId},
    );
    _checkSuccess(response);
  }

  Future<void> removeChannelMember(
    String conversationId,
    String memberId,
  ) async {
    final response = await _apiClient.delete(
      '${ApiConfig.messagingChannelById(conversationId)}/members/$memberId',
    );
    _checkSuccess(response);
  }

  Future<List<ChatUser>> getConversationMembers(
    String conversationId, {
    bool isGroup = false,
  }) async {
    final url = isGroup
        ? ApiConfig.messagingGroupMembers(conversationId)
        : ApiConfig.messagingDirectMembers(conversationId);
    final response = await _apiClient.get(url);
    final data = _getData(response);
    if (data is List) {
      return data
          .map((c) => ChatUser.fromJson(Map<String, dynamic>.from(c)))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getGroupMembers(
    String conversationId,
  ) async {
    final response = await _apiClient.get(
      ApiConfig.messagingGroupMembers(conversationId),
    );
    final data = _getData(response);
    if (data is List) {
      return data.map((c) => Map<String, dynamic>.from(c)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getGroupMember(
    String conversationId,
    String userId,
  ) async {
    final response = await _apiClient.get(
      '${ApiConfig.messagingGroupMembers(conversationId)}/$userId',
    );
    return Map<String, dynamic>.from(_getData(response));
  }

  Future<List<Map<String, dynamic>>> getChannelMembers(
    String conversationId,
  ) async {
    final response = await _apiClient.get(
      '${ApiConfig.messagingChannelById(conversationId)}/members',
    );
    final data = _getData(response);
    if (data is List) {
      return data.map((c) => Map<String, dynamic>.from(c)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getChannelMember(
    String conversationId,
    String memberId,
  ) async {
    final response = await _apiClient.get(
      '${ApiConfig.messagingChannelById(conversationId)}/members/$memberId',
    );
    return Map<String, dynamic>.from(_getData(response));
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
    String? clientMessageId,
    Map<String, dynamic>? tipData,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.messagingMessages,
      body: {
        'conversationId': conversationId,
        'conversation_id': conversationId,
        'content': content,
        'messageType': messageType,
        'message_type': messageType,
        if (clientMessageId != null) ...{
          'clientMessageId': clientMessageId,
          'client_message_id': clientMessageId,
        },
        if (replyToMessageId != null) ...{
          'replyToMessageId': replyToMessageId,
          'reply_to_message_id': replyToMessageId,
        },
        if (mediaId != null) ...{'mediaId': mediaId, 'media_id': mediaId},
        if (tipData != null) ...{'tipData': tipData, 'tip_data': tipData},
      },
    );
    final data = _getData(response);
    return ChatMessage.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> deleteMessage(String messageId) async {
    final response = await _apiClient.delete(
      ApiConfig.messagingMessageById(messageId),
      body: {'scope': 'everyone'},
    );
    _checkSuccess(response);
  }

  Future<void> deleteMessageForMe(String messageId) async {
    final response = await _apiClient.delete(
      ApiConfig.messagingMessageById(messageId),
      body: {'scope': 'me'},
    );
    _checkSuccess(response);
  }

  Future<int> clearGroupMessages(String conversationId) async {
    final response = await _apiClient.delete(
      '${ApiConfig.messagingGroupById(conversationId)}/messages',
    );
    final data = Map<String, dynamic>.from(_getData(response));
    return (data['deletedCount'] as num?)?.toInt() ?? 0;
  }

  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    String? before,
  }) async {
    // Cap limit at 100 as per spec
    final effectiveLimit = limit.clamp(1, 100);

    final response = await _apiClient.get(
      '${ApiConfig.messagingMessages}/conversation/$conversationId?limit=$effectiveLimit${before != null ? '&before=$before' : ''}',
      forceRefresh: true,
    );
    final data = _getData(response);
    if (data is List) {
      return data
          .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
          .toList();
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
      return data
          .map((r) => MessageRequest.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    }
    return [];
  }

  Future<List<MessageRequest>> getSentRequests() async {
    final response = await _apiClient.get(ApiConfig.messagingRequestsSent);
    final data = _getData(response);
    if (data is List) {
      return data
          .map((r) => MessageRequest.fromJson(Map<String, dynamic>.from(r)))
          .toList();
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
        'recipient_id': recipientId,
        ...?message == null ? null : {'message': message},
        'requestType': 'dm',
        'request_type': 'dm',
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
        'recipient_id': recipientId,
        ...?message == null ? null : {'message': message},
        'requestType': 'friend',
        'request_type': 'friend',
      },
    );
    final data = _getData(response);
    return MessageRequest.fromJson(Map<String, dynamic>.from(data));
  }

  Future<MessageRequest> sendConversationInvitation({
    required String recipientId,
    required String conversationId,
    required String requestType,
  }) async {
    if (requestType != 'group' && requestType != 'channel') {
      throw ArgumentError('requestType must be group or channel');
    }
    final response = await _apiClient.post(
      ApiConfig.messagingRequests,
      body: {
        'recipientId': recipientId,
        'recipient_id': recipientId,
        'conversationId': conversationId,
        'conversation_id': conversationId,
        'requestType': requestType,
        'request_type': requestType,
      },
    );
    final data = _getData(response);
    return MessageRequest.fromJson(Map<String, dynamic>.from(data));
  }

  Future<MessageRequest> requestToJoinConversation({
    required String ownerId,
    required String conversationId,
    required String requestType,
  }) async {
    if (requestType != 'group' && requestType != 'channel') {
      throw ArgumentError('requestType must be group or channel');
    }
    final response = await _apiClient.post(
      ApiConfig.messagingRequests,
      body: {
        'recipientId': ownerId,
        'recipient_id': ownerId,
        'conversationId': conversationId,
        'conversation_id': conversationId,
        'requestType': requestType,
        'request_type': requestType,
      },
    );
    return MessageRequest.fromJson(
      Map<String, dynamic>.from(_getData(response)),
    );
  }

  Future<Map<String, dynamic>> acceptRequest(String requestId) async {
    final response = await _apiClient.post(
      ApiConfig.messagingRequestAccept(requestId),
    );
    final data = _getData(response);
    return Map<String, dynamic>.from(data);
  }

  Future<void> declineRequest(String requestId) async {
    final response = await _apiClient.post(
      ApiConfig.messagingRequestDecline(requestId),
    );
    _checkSuccess(response);
  }

  Future<void> withdrawRequest(String requestId) async {
    final response = await _apiClient.post(
      ApiConfig.messagingRequestCancel(requestId),
    );
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
    final response = await _apiClient.post(
      ApiConfig.messagingBlockUser(userId),
    );
    _checkSuccess(response);
  }

  Future<void> unblockUser(String userId) async {
    final response = await _apiClient.delete(
      ApiConfig.messagingBlockUser(userId),
    );
    _checkSuccess(response);
  }

  Future<void> reportContent({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.messagingReports,
      body: {
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        if (details != null && details.trim().isNotEmpty)
          'details': details.trim(),
      },
    );
    _checkSuccess(response);
  }

  // ==========================================================
  // FRIENDS
  // ==========================================================

  Future<List<UserModel>> getFriends() async {
    final response = await _apiClient.get(ApiConfig.messagingFriends);
    final data = _getData(response);
    if (data is List) {
      return data
          .map((u) => UserModel.fromJson(Map<String, dynamic>.from(u)))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getFriendsPage({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.messagingFriendsPaged(limit: limit, offset: offset),
    );
    final data = _getData(response);
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> searchFriends({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _apiClient.get(
      ApiConfig.messagingFriendsSearch(query, limit: limit, offset: offset),
    );
    final data = _getData(response);
    return Map<String, dynamic>.from(data);
  }

  Future<int> getFriendsCount() async {
    final response = await _apiClient.get(ApiConfig.messagingFriendsCount);
    final data = _getData(response);
    final count = data['count'] ?? data['total'] ?? 0;
    return count is num ? count.toInt() : int.tryParse('$count') ?? 0;
  }

  Future<void> removeFriend(String friendId) async {
    final response = await _apiClient.delete(
      ApiConfig.messagingFriendById(friendId),
    );
    _checkSuccess(response);
  }

  // ==========================================================
  // CHANNELS - POSTS & COMMENTS
  // ==========================================================

  Future<List<ChatMessage>> getChannelPosts(String conversationId) async {
    final response = await _apiClient.get(
      ApiConfig.messagingChannelPosts(conversationId),
    );
    final data = _getData(response);
    if (data is List) {
      return data
          .map((p) => ChatMessage.fromJson(Map<String, dynamic>.from(p)))
          .toList();
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
        ...?mediaId == null ? null : {'mediaId': mediaId},
      },
    );
    final data = _getData(response);
    return ChatMessage.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<Map<String, dynamic>>> getChannelComments(
    String conversationId,
    String postId,
  ) async {
    final response = await _apiClient.get(
      ApiConfig.messagingChannelComments(conversationId, postId),
    );
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
      body: {'content': content, 'replyToCommentId': replyToCommentId},
    );
    final data = _getData(response);
    return Map<String, dynamic>.from(data);
  }

  Future<void> deleteChannelComment(
    String conversationId,
    String postId,
    String commentId,
  ) async {
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
      if (response.containsKey('success')) {
        if (response['success'] == true) {
          return response['data'];
        }
        throw ApiException(
          message: response['message'] ?? 'Request failed',
          data: response['data'],
        );
      }
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

  List<Conversation> _conversationList(
    dynamic data, {
    required String fallbackType,
  }) {
    // Accept the current array response and all list wrappers used by older
    // backend deployments. Some deployments return {data: {items: [...]}}
    // while others return {data: [...]} after the API client's unwrapping.
    for (var depth = 0; depth < 3 && data is Map; depth++) {
      final map = Map<String, dynamic>.from(data);
      final next =
          map['groups'] ??
          map['channels'] ??
          map['conversations'] ??
          map['items'] ??
          map['results'] ??
          map['data'];
      if (next == null || identical(next, data)) break;
      data = next;
    }
    if (data is! List) return [];
    return data.map((item) {
      final json = Map<String, dynamic>.from(item);
      // The endpoint itself is authoritative. This also protects the UI from
      // older values such as `group_chat`/`broadcast` being treated as DMs.
      final rawType = json['type']?.toString().trim().toLowerCase();
      final isExpectedType = fallbackType == 'group'
          ? rawType == 'group' || rawType == 'group_chat'
          : rawType == 'channel' || rawType == 'broadcast';
      if (!isExpectedType) json['type'] = fallbackType;
      json['title'] ??= json['name'];
      json['avatarUrl'] ??= json['image_url'] ?? json['imageUrl'];
      json['memberIds'] ??= <String>[];
      return Conversation.fromJson(json);
    }).toList();
  }
}
