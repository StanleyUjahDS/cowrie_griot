import 'package:flutter/material.dart';
import '../models/reputation_model.dart';
import '../services/reputation_api_service.dart';

class ReputationProvider extends ChangeNotifier {
  final ReputationApiService _apiService;

  ReputationProvider({required ReputationApiService apiService})
      : _apiService = apiService;

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
      _data = await _apiService.getReputation();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
