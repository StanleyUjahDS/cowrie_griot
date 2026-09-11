import 'package:flutter/foundation.dart';
import '../services/user_api_service.dart';

class UserPreferenceProvider extends ChangeNotifier {
  final UserApiService _apiService;

  UserPreferenceProvider({required UserApiService apiService}) : _apiService = apiService;

  Map<String, bool> _preferences = {
    'chat_notifications': true,
    'message_preview': true,
    'read_receipts': true,
    'typing_indicators': true,
    'online_status_visibility': true,
    'profile_discoverability': true,
  };

  bool _isLoading = false;
  String? _error;

  Map<String, bool> get preferences => _preferences;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadPreferences() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final remote = await _apiService.getPreferences();
      if (remote.isNotEmpty) {
        _preferences = {..._preferences, ...remote};
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updatePreference(String key, bool value) async {
    final originalValue = _preferences[key];
    
    // Optimistic UI
    _preferences[key] = value;
    notifyListeners();

    try {
      final updated = await _apiService.updatePreferences({key: value});
      _preferences = {..._preferences, ...updated};
    } catch (e) {
      // Revert on failure
      if (originalValue != null) {
        _preferences[key] = originalValue;
      }
      _error = e.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }
}
