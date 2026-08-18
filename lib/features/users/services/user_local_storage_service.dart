import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class UserLocalStorageService {
  static const String _userKey = 'cached_user_profile';

  // ============================================================
  // SAVE USER
  // ============================================================

  Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(user.toJson());
    await prefs.setString(_userKey, json);
  }

  // ============================================================
  // LOAD USER
  // ============================================================

  Future<UserModel?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_userKey);

    if (json == null || json.isEmpty) {
      return null;
    }

    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // CLEAR USER
  // ============================================================

  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}
