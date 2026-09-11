import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small persistent JSON cache for non-sensitive UI snapshots.
///
/// Cached data is only used as an immediate rendering baseline. Every feature
/// still reconciles it with the API when its normal refresh runs.
class LocalJsonCache {
  const LocalJsonCache();

  Future<void> write(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }

  Future<dynamic> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;

    try {
      return jsonDecode(raw);
    } catch (_) {
      await prefs.remove(key);
      return null;
    }
  }

  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
