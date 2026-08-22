import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/token_model.dart';
import '../services/wallet_api_service.dart';

class TokenSearchProvider extends ChangeNotifier {
  final WalletApiService _walletApiService;
  List<TokenModel> _holdings = [];
  bool _isWalletMode = false;

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

  void setHoldings(List<TokenModel> holdings) {
    _holdings = holdings;
  }

  void setWalletMode(bool value) {
    _isWalletMode = value;
  }

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

    // Perform local search immediately for holdings
    _performLocalSearch();

    // The backend requires at least three characters for discovery searches.
    if (_query.trim().length < 3) {
      // If it's a contract address, we still want to search even if short (unlikely but possible)
      if (!RegExp(r'^0x[a-fA-F0-9]{2,}$').hasMatch(_query.trim())) {
        return;
      }
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch();
    });
  }

  void _performLocalSearch() {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return;

    final matches = _holdings.where((t) {
      final name = t.name.toLowerCase();
      final symbol = t.symbol.toLowerCase();
      final address = t.contractAddress.toLowerCase();
      return name.contains(q) || symbol.contains(q) || address.contains(q);
    }).toList();

    if (matches.isNotEmpty) {
      _results = matches;
      notifyListeners();
    }
  }

  Future<void> _loadPopular() async {
    final requestId = ++_lastRequestId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    if (_isWalletMode && _holdings.isNotEmpty) {
      _results = _holdings.toList();
      _isLoading = false;
      notifyListeners();
      return;
    }

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
      final remoteResults = await _walletApiService.searchAssets(
        query: _query,
        network: _network,
      );

      // Ignore stale responses
      if (requestId != _lastRequestId) return;

      final q = _query.trim().toLowerCase();
      final localMatches = _holdings.where((t) {
        return t.name.toLowerCase().contains(q) || 
               t.symbol.toLowerCase().contains(q) || 
               t.contractAddress.toLowerCase().contains(q);
      }).toList();

      // Merge and deduplicate by identity
      final Map<String, TokenModel> merged = {};
      
      // Prioritize holdings (they have actual balances)
      for (final t in localMatches) {
        merged[t.identity] = t;
      }
      
      // Add remote results if not already present
      for (final t in remoteResults) {
        if (!merged.containsKey(t.identity)) {
          if (_isWalletMode) {
            // Wallet mode is strictly limited to locally loaded holdings.
            continue;
          } else {
            merged[t.identity] = t;
          }
        }
      }

      _results = merged.values.toList();
      
      // Sort backend-verified assets first, then by value.
      _results.sort((a, b) {
        final av = a.status == 'verified' && a.isTradeable;
        final bv = b.status == 'verified' && b.isTradeable;
        if (av != bv) return av ? -1 : 1;
        return b.valueUsd.compareTo(a.valueUsd);
      });

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
    return token.isTradeable && status == 'verified';
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
