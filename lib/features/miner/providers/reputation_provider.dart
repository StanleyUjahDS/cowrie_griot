import 'package:flutter/material.dart';
import '../../users/providers/user_provider.dart';
import '../models/reputation_model.dart';
import '../services/reputation_api_service.dart';

class ReputationProvider extends ChangeNotifier {
  final ReputationApiService _apiService;
  UserProvider? _userProvider;

  ReputationProvider({required ReputationApiService apiService})
    : _apiService = apiService;

  void updateUserProvider(UserProvider provider) {
    _userProvider = provider;
  }

  ReputationData? _data;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastLoadedAt;
  Future<void>? _loadFuture;

  ReputationData? get data => _data;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadReputation({bool force = false}) async {
    if (!force &&
        _data != null &&
        _lastLoadedAt != null &&
        DateTime.now().difference(_lastLoadedAt!) <
            const Duration(minutes: 2)) {
      return;
    }
    if (_loadFuture != null) return _loadFuture!;
    _loadFuture = _loadReputation();
    try {
      await _loadFuture;
    } finally {
      _loadFuture = null;
    }
  }

  Future<void> _loadReputation() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newData = await _apiService.getReputation();

      // If the tier has changed, refresh the main user profile
      // to update badges across the app (Settings, Chat, etc.)
      if (_data != null &&
          (newData.tier.name != _data!.tier.name ||
              newData.points != _data!.points)) {
        _userProvider?.refreshUser();
      }

      _data = newData;
      _lastLoadedAt = DateTime.now();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
