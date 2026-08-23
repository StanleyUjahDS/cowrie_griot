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
    final response = await _apiClient.get(
      ApiConfig.usersMe,
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid response from server.',
      );
    }

    // Support both wrapped and unwrapped response
    final data = (response.containsKey('data') ? response['data'] : response);

    if (data is! Map<String, dynamic>) {
      throw Exception(
        'Invalid user data from server.',
      );
    }

    return UserModel.fromJson(data);
  }

  // ============================================================
  // CHECK USERNAME AVAILABILITY
  // GET /api/users/username/availability?username=
  // ============================================================
  //
  // Called while the user is typing.
  //
  // Returns:
  // true  = username is available
  // false = username is already taken
  //
  // ============================================================

  Future<bool> checkUsernameAvailability(
      String username,
      ) async {
    final value = username.trim().toLowerCase();

    if (value.isEmpty) {
      return false;
    }

    final response = await _apiClient.get(
      ApiConfig.usernameAvailability(value),
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid response from server.',
      );
    }

    if (response['success'] != true) {
      throw Exception(
        response['message'] ??
            'Unable to check username availability.',
      );
    }

    final data = response['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception(
        'Invalid username availability response.',
      );
    }

    final available = data['available'];

    if (available is! bool) {
      throw Exception(
        'Invalid username availability value.',
      );
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

    if (username != null) {
      body['username'] = username;
    }

    if (displayName != null) {
      body['displayName'] = displayName;
    }

    if (avatarUrl != null) {
      body['avatarUrl'] = avatarUrl;
    }

    if (bio != null) {
      body['bio'] = bio;
    }

    if (body.isEmpty) {
      throw Exception(
        'No profile changes provided.',
      );
    }

    final response = await _apiClient.patch(
      ApiConfig.usersUpdate,
      body: body,
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid response from server.',
      );
    }

    final data = response['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception(
        'Invalid user data from server.',
      );
    }

    return UserModel.fromJson(data);
  }

  // ============================================================
  // SEARCH USERS
  // GET /api/users/search?q=
  // ============================================================

  Future<List<UserModel>> searchUsers(
      String query,
      ) async {
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      return [];
    }

    final response = await _apiClient.get(
      ApiConfig.usersSearch(trimmedQuery),
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Invalid response from server.',
      );
    }

    final data = response['data'];

    if (data is! List) {
      throw Exception(
        'Invalid users data from server.',
      );
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => UserModel.fromJson(json),
    )
        .toList();
  }
}