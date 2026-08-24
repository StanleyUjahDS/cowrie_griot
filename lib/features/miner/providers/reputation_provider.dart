import 'package:flutter/material.dart';
import '../../users/providers/user_provider.dart';
import '../models/reputation_model.dart';
import '../services/reputation_api_service.dart';

class ReputationProvider extends ChangeNotifier {
  final ReputationApiService _apiService;
  UserProvider? _userProvider;

  ReputationProvider({
    required ReputationApiService apiService,
  }) : _apiService = apiService;

  void updateUserProvider(UserProvider provider) {
    _userProvider = provider;
  }

  ReputationData? _data;
  bool _isLoading = false;
  String? _error;

  ReputationData? get data => _data;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadReputation() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newData = await _apiService.getReputation();
      
      // If the tier has changed, refresh the main user profile
      // to update badges across the app (Settings, Chat, etc.)
      if (_data != null && newData.tier.name != _data!.tier.name) {
        _userProvider?.refreshUser();
      }
      
      _data = newData;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
