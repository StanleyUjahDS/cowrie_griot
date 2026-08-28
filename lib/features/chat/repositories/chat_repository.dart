import '../models/chat_user.dart';
import '../services/messaging_api_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import 'package:flutter/foundation.dart';

class ChatOperations {
  final MessagingApiService _apiService;
  final ApiClient _apiClient;

  ChatOperations({MessagingApiService? apiService, ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(),
        _apiService = apiService ?? MessagingApiService(apiClient: apiClient ?? ApiClient());

  // ==========================================================
  // GET CHATS
  // ==========================================================

  Future<List<ChatUser>> getChats() async {
    final conversations = await _apiService.getConversations();
    // Map Conversation to ChatUser for compatibility with existing UI
    return conversations.map((conv) {
      final otherMember = conv.otherUser;
      
      return ChatUser(
        id: otherMember?.id ?? conv.id,
        walletAddress: otherMember?.walletAddress ?? '',
        username: otherMember?.username,
        displayName: otherMember?.displayName,
        profileUrl: otherMember?.profileUrl,
        lastMessage: conv.lastMessage?.text ?? '',
        timestamp: conv.lastMessage?.createdAt ?? conv.updatedAt,
        unreadCount: conv.unreadCount,
        isOnline: otherMember?.isOnline ?? false,
      );
    }).toList();
  }

  // ==========================================================
  // SEARCH USERS
  // ==========================================================

  Future<List<ChatUser>> searchUsers(String query) async {
    final response = await _apiClient.get(ApiConfig.usersSearch(query));
    final data = response['data'] as List;
    return data.map((u) {
      return ChatUser.fromJson(Map<String, dynamic>.from(u));
    }).toList();
  }

  // ==========================================================
  // FIND USER BY WALLET
  // ==========================================================

  Future<ChatUser?> findUserByWallet(String walletAddress) async {
    try {
      final response = await _apiClient.get(ApiConfig.usersSearch(walletAddress));
      final data = response['data'] as List;
      if (data.isNotEmpty) {
        return ChatUser.fromJson(Map<String, dynamic>.from(data.first));
      }
      return null;
    } catch (e) {
      debugPrint('Error finding user by wallet: $e');
      return null;
    }
  }

  // ==========================================================
  // PHONE DISCOVERY
  // ==========================================================

  Future<List<ChatUser>> findUsersByPhoneNumbers(List<String> phoneNumbers) async {
    // This requires a new endpoint or mapping to an existing one.
    // For now, return empty or implement if backend supports it.
    return [];
  }

  Future<void> updatePhoneDiscovery({
    required String walletAddress,
    required bool enabled,
  }) async {
    // This would call usersUpdate or similar
    await _apiClient.put(ApiConfig.usersUpdate, body: {
      'phoneDiscoveryEnabled': enabled,
    });
  }

  // ==========================================================
  // FRIENDS & BLOCKING
  // ==========================================================

  Future<List<ChatUser>> getFriends() async {
    final friends = await _apiService.getFriends();
    return friends.map((f) => ChatUser(
      id: f.id,
      walletAddress: f.walletAddress,
      username: f.username,
      displayName: f.displayName,
      profileUrl: f.avatarUrl,
      timestamp: DateTime.now(),
    )).toList();
  }

  Future<void> blockUser(String userId) async {
    await _apiService.blockUser(userId);
  }

  Future<void> unblockUser(String userId) async {
    await _apiService.unblockUser(userId);
  }

  Future<List<String>> getBlockedUserIds() async {
    return _apiService.getBlockedUserIds();
  }
}
