// lib/features/users/providers/user_provider.dart

import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/user_api_service.dart';
import '../services/user_local_storage_service.dart';

class UserProvider extends ChangeNotifier {
  final UserApiService _userApiService;
  final UserLocalStorageService _userLocalStorageService;

  UserProvider({
    required UserApiService userApiService,
    UserLocalStorageService? userLocalStorageService,
  })  : _userApiService = userApiService,
        _userLocalStorageService =
            userLocalStorageService ?? UserLocalStorageService();

  // ============================================================
  // STATE
  // ============================================================

  UserModel? _user;

  bool _isLoading = false;
  bool _isUpdating = false;

  String? _errorMessage;

  // ============================================================
  // GETTERS
  // ============================================================

  UserModel? get user => _user;

  bool get isLoading => _isLoading;

  bool get isUpdating => _isUpdating;

  String? get errorMessage => _errorMessage;

  bool get hasUser => _user != null;

  // ============================================================
  // LOAD LOCAL USER
  // ============================================================

  Future<void> loadLocalUser() async {
    final cached = await _userLocalStorageService.loadUser();

    if (cached != null) {
      _user = cached;
      notifyListeners();
    }
  }

  // ============================================================
  // LOAD CURRENT USER
  // GET /api/users/me
  // ============================================================

  Future<void> loadUser() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      _user = await _userApiService.getCurrentUser();

      // Update cache
      if (_user != null) {
        await _userLocalStorageService.saveUser(_user!);
      }
    } catch (error) {
      _errorMessage = _cleanError(error);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================
  // REFRESH CURRENT USER
  // GET /api/users/me
  // ============================================================

  Future<void> refreshUser() async {
    _errorMessage = null;

    try {
      _user = await _userApiService.getCurrentUser();

      // Update cache
      if (_user != null) {
        await _userLocalStorageService.saveUser(_user!);
      }

      notifyListeners();
    } catch (error) {
      _errorMessage = _cleanError(error);

      notifyListeners();

      rethrow;
    }
  }

  // ============================================================
  // CHECK USERNAME AVAILABILITY
  // GET /api/users/username/availability
  // ============================================================
  //
  // This is called while the user is typing.
  //
  // Wallet address:
  //   Permanent Griot identity.
  //
  // Username:
  //   Changeable unique handle.
  //
  // The provider is responsible for:
  //
  // 1. Local validation
  // 2. Checking whether the username belongs to
  //    the current user
  // 3. Asking the API service to check PostgreSQL
  //
  // ============================================================

  Future<bool> checkUsernameAvailability(
      String username,
      ) async {
    final value = username.trim().toLowerCase();

    // ----------------------------------------------------------
    // LOCAL VALIDATION
    // ----------------------------------------------------------

    if (value.length < 3) {
      return false;
    }

    if (value.length > 30) {
      return false;
    }

    if (!RegExp(
      r'^[a-zA-Z0-9_]+$',
    ).hasMatch(value)) {
      return false;
    }

    // ----------------------------------------------------------
    // CURRENT USERNAME
    // ----------------------------------------------------------
    //
    // If the username already belongs to this user,
    // consider it available.
    //
    // The backend also excludes the current user's profile
    // when performing the database availability check.
    // ----------------------------------------------------------

    final currentUsername =
    _user?.username?.trim().toLowerCase();

    if (currentUsername != null &&
        currentUsername.isNotEmpty &&
        value == currentUsername) {
      return true;
    }

    // ----------------------------------------------------------
    // BACKEND CHECK
    // ----------------------------------------------------------

    try {
      return await _userApiService.checkUsernameAvailability(
        value,
      );
    } catch (error) {
      _errorMessage = _cleanError(error);

      rethrow;
    }
  }

  // ============================================================
  // UPDATE CURRENT USER
  // PATCH /api/users/me
  // ============================================================

  Future<void> updateUser({
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
  }) async {
    if (_isUpdating) {
      return;
    }

    if (username == null &&
        displayName == null &&
        avatarUrl == null &&
        bio == null) {
      throw Exception(
        'No profile changes provided.',
      );
    }

    _isUpdating = true;
    _errorMessage = null;

    notifyListeners();

    try {
      _user = await _userApiService.updateCurrentUser(
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        bio: bio,
      );

      // Update cache
      if (_user != null) {
        await _userLocalStorageService.saveUser(_user!);
      }
    } catch (error) {
      _errorMessage = _cleanError(error);

      rethrow;
    } finally {
      _isUpdating = false;

      notifyListeners();
    }
  }

  // ============================================================
  // UPDATE USERNAME
  // ============================================================

  Future<void> updateUsername(
      String username,
      ) async {
    final value = username.trim().toLowerCase();

    if (value.isEmpty) {
      throw Exception(
        'Username cannot be empty.',
      );
    }

    if (value.length < 3) {
      throw Exception(
        'Username must be at least 3 characters.',
      );
    }

    if (value.length > 30) {
      throw Exception(
        'Username must be 30 characters or less.',
      );
    }

    if (!RegExp(
      r'^[a-zA-Z0-9_]+$',
    ).hasMatch(value)) {
      throw Exception(
        'Username can only contain letters, numbers and underscores.',
      );
    }

    await updateUser(
      username: value,
    );
  }

  // ============================================================
  // UPDATE DISPLAY NAME
  // ============================================================

  Future<void> updateDisplayName(
      String displayName,
      ) async {
    final value = displayName.trim();

    if (value.isEmpty) {
      throw Exception(
        'Display name cannot be empty.',
      );
    }

    await updateUser(
      displayName: value,
    );
  }

  // ============================================================
  // UPDATE BIO
  // ============================================================

  Future<void> updateBio(
      String bio,
      ) async {
    final value = bio.trim();

    await updateUser(
      bio: value,
    );
  }

  // ============================================================
  // UPDATE AVATAR URL
  // ============================================================

  Future<void> updateAvatarUrl(
      String avatarUrl,
      ) async {
    final value = avatarUrl.trim();

    if (value.isEmpty) {
      throw Exception(
        'Avatar URL cannot be empty.',
      );
    }

    await updateUser(
      avatarUrl: value,
    );
  }

  // ============================================================
  // CLEAR USER
  // ============================================================

  void clearUser() {
    _user = null;
    _errorMessage = null;

    _userLocalStorageService.clearUser();

    notifyListeners();
  }

  // ============================================================
  // CLEAR ERROR
  // ============================================================

  void clearError() {
    _errorMessage = null;

    notifyListeners();
  }

  // ============================================================
  // ERROR
  // ============================================================

  String _cleanError(
      Object error,
      ) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(11);
    }

    return message;
  }
}
