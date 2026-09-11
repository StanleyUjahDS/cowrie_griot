import 'package:flutter/material.dart';
import '../models/referral_model.dart';
import '../services/referral_api_service.dart';

class ReferralProvider extends ChangeNotifier {
  final ReferralApiService _apiService;

  ReferralProvider({required ReferralApiService apiService})
      : _apiService = apiService;

  ReferralData? _data;
  bool _isLoading = false;
  bool _isClaiming = false;
  String? _error;
  DateTime? _lastLoadedAt;
  Future<void>? _loadFuture;

  ReferralData? get data => _data;
  bool get isLoading => _isLoading;
  bool get isClaiming => _isClaiming;
  String? get error => _error;

  Future<void> loadReferralStatus({bool force = false}) async {
    if (!force && _data != null && _lastLoadedAt != null &&
        DateTime.now().difference(_lastLoadedAt!) < const Duration(minutes: 2)) {
      return;
    }
    if (_loadFuture != null) return _loadFuture!;
    _loadFuture = _loadReferralStatus();
    try {
      await _loadFuture;
    } finally {
      _loadFuture = null;
    }
  }

  Future<void> _loadReferralStatus() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _data = await _apiService.getReferralStatus();
      _lastLoadedAt = DateTime.now();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> claimReferral(String referralCode) async {
    _isClaiming = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.claimReferral(referralCode);
      // Reload status after successful claim
      await loadReferralStatus(force: true);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isClaiming = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _data = null;
    _isLoading = false;
    _isClaiming = false;
    _error = null;
    _lastLoadedAt = null;
    _loadFuture = null;
    notifyListeners();
  }
}
