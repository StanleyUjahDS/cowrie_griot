// lib/features/users/services/user_api_service.dart

import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';

import '../models/user_model.dart';

class UserApiService {
  final ApiClient _apiClient;

  UserApiService({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  // ============================================================
  // GET CURRENT USER
  // GET /api/users/me
  // ============================================================

  Future<UserModel> getCurrentUser() async {
    final response = await _apiClient.get(ApiConfig.usersMe);
    final data = _getData(response);
    return UserModel.fromJson(Map<String, dynamic>.from(data));
  }

  // ============================================================
  // CHECK USERNAME AVAILABILITY
  // GET /api/users/username/availability?username=
  // ============================================================

  Future<bool> checkUsernameAvailability(String username) async {
    final value = username.trim().toLowerCase();
    if (value.isEmpty) return false;

    final response = await _apiClient.get(ApiConfig.usernameAvailability(value));
    final data = _getData(response);

    final available = data['available'];
    if (available is! bool) {
      throw Exception('Invalid username availability value.');
    }

    return available;
  }

  // ============================================================
  // UPDATE CURRENT USER
  // PATCH /api/users/me
  // ============================================================

  Future<UserModel> updateCurrentUser({
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
  }) async {
    final Map<String, dynamic> body = {};

    if (username != null) body['username'] = username;
    if (displayName != null) body['displayName'] = displayName;
    if (avatarUrl != null) body['avatarUrl'] = avatarUrl;
    if (bio != null) body['bio'] = bio;

    if (body.isEmpty) throw Exception('No profile changes provided.');

    final response = await _apiClient.patch(ApiConfig.usersUpdate, body: body);
    final data = _getData(response);

    return UserModel.fromJson(Map<String, dynamic>.from(data));
  }

  // ============================================================
  // SEARCH USERS
  // GET /api/users/search?q=
  // ============================================================

  Future<List<UserModel>> searchUsers(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];

    final response = await _apiClient.get(ApiConfig.usersSearch(trimmedQuery));
    final data = _getData(response);

    if (data is! List) {
      return [];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map((json) => UserModel.fromJson(json))
        .toList();
  }

  // ============================================================
  // GET FRIENDS
  // GET /api/messaging/friends
  // ============================================================

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
}
