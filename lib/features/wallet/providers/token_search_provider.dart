import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/token_model.dart';
import '../services/wallet_api_service.dart';

class TokenSearchProvider extends ChangeNotifier {
  final WalletApiService _walletApiService;

  TokenSearchProvider({
    required WalletApiService walletApiService,
  }) : _walletApiService = walletApiService;

  String _query = '';
  String? _network;
  bool _isLoading = false;
  String? _error;
  List<TokenModel> _results = [];
  Timer? _debounceTimer;
  int _lastRequestId = 0;

  String get query => _query;
  String? get network => _network;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<TokenModel> get results => List.unmodifiable(_results);

  void updateQuery(String newQuery) {
    if (_query == newQuery) {
      if (newQuery.trim().isEmpty && _results.isEmpty && !_isLoading) _loadPopular();
      return;
    }
    _query = newQuery;
    
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    
    if (_query.trim().isEmpty) {
      _loadPopular();
      return;
    }

    // The backend requires at least three characters for discovery searches.
    if (_query.trim().length < 3) {
      _lastRequestId++;
      _results = [];
      _isLoading = false;
      _error = null;
      notifyListeners();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch();
    });
  }

  Future<void> _loadPopular() async {
    final requestId = ++_lastRequestId;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await _walletApiService.getPopularAssets(network: _network);
      if (requestId != _lastRequestId) return;
      _results = results;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (requestId != _lastRequestId) return;
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void setNetwork(String? network) {
    if (_network == network) return;
    _network = network;
    if (_query.trim().length >= 3) {
      _performSearch();
    } else {
      _loadPopular();
    }
  }

  Future<void> _performSearch() async {
    final requestId = ++_lastRequestId;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await _walletApiService.searchAssets(
        query: _query,
        network: _network,
      );

      // Ignore stale responses
      if (requestId != _lastRequestId) return;

      _results = results;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (requestId != _lastRequestId) return;
      
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  bool canSwap(TokenModel token) {
    final status = token.status.toLowerCase();
    return token.isTradeable && 
           status != 'unknown' && 
           status != 'blocked';
  }

  void clearSearch() {
    _query = '';
    _results = [];
    _isLoading = false;
    _error = null;
    _debounceTimer?.cancel();
    _lastRequestId++;
    notifyListeners();
    _loadPopular();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
