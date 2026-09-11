// lib/features/users/services/user_api_service.dart

import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';

import '../models/user_model.dart';

class UserApiService {
  final ApiClient _apiClient;

  UserApiService({required ApiClient apiClient}) : _apiClient = apiClient;

  // ============================================================
  // GET CURRENT USER
  // GET /api/users/me
  // ============================================================

  Future<UserModel> getCurrentUser() async {
    final response = await _apiClient.get(ApiConfig.usersMe);
    final data = _getData(response);
    return UserModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<UserModel> getUserById(String userId) async {
    final response = await _apiClient.get(ApiConfig.userById(userId));
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

    final response = await _apiClient.get(
      ApiConfig.usernameAvailability(value),
    );
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
    final Map<String, dynamic> body = {
      'username': ?username,
      ...?displayName == null
          ? null
          : {'displayName': displayName, 'display_name': displayName},
      ...?avatarUrl == null
          ? null
          : {'avatarUrl': avatarUrl, 'avatar_url': avatarUrl},
      'bio': ?bio,
    };

    if (body.isEmpty) throw Exception('No profile changes provided.');

    final response = await _apiClient.patch(ApiConfig.usersUpdate, body: body);
    final data = _getData(response);

    return UserModel.fromJson(Map<String, dynamic>.from(data));
  }

  // ============================================================
  // SEARCH USERS
  // GET /api/users/search?q=
  // ============================================================

  Future<Map<String, dynamic>> searchUsers(
    String query, {
    int limit = 20,
    int offset = 0,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return {'users': <UserModel>[], 'total': 0};

    final response = await _apiClient.get(
      ApiConfig.usersSearch(trimmedQuery, limit: limit, offset: offset),
    );
    final data = _getData(response);

    final List usersJson = data is List ? data : (data['users'] ?? []);
    final total = (data is Map ? data['total'] : null) ?? usersJson.length;

    final users = usersJson
        .map((e) => UserModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return {'users': users, 'total': total};
  }

  // ============================================================
  // GET FRIENDS
  // GET /api/messaging/friends
  // ============================================================

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

  // ============================================================
  // PREFERENCES
  // GET /api/users/preferences
  // PATCH /api/users/preferences
  // ============================================================

  Future<Map<String, bool>> getPreferences() async {
    final response = await _apiClient.get(ApiConfig.userPreferences);
    final data = _getData(response);
    if (data is Map) {
      return Map<String, bool>.from(
        data.map((key, value) => MapEntry(key.toString(), value == true)),
      );
    }
    return {};
  }

  Future<Map<String, bool>> updatePreferences(
    Map<String, bool> preferences,
  ) async {
    final response = await _apiClient.patch(
      ApiConfig.userPreferences,
      body: preferences,
    );
    final data = _getData(response);
    if (data is Map) {
      return Map<String, bool>.from(
        data.map((key, value) => MapEntry(key.toString(), value == true)),
      );
    }
    return {};
  }

  // ==========================================================
  // HELPERS
  // ==========================================================

  dynamic _getData(dynamic response) {
    if (response is Map<String, dynamic>) {
      // Handle the { success: true, data: ... } wrapper
      if (response.containsKey('success')) {
        if (response['success'] == true) {
          return response['data'];
        }
        throw Exception(response['message'] ?? 'Request failed');
      }
    }
    // Return flat response as is
    return response;
  }
}
