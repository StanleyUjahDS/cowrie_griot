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

  ReferralData? get data => _data;
  bool get isLoading => _isLoading;
  bool get isClaiming => _isClaiming;
  String? get error => _error;

  Future<void> loadReferralStatus() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _data = await _apiService.getReferralStatus();
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
      await loadReferralStatus();
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
}
