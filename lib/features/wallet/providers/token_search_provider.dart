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

    // Debounce remote discovery search
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
      final popular = await _walletApiService.getPopularAssets(network: _network);
      if (requestId != _lastRequestId) return;

      if (!_isWalletMode) {
        // Selection Mode: Merge holdings and popular assets
        final Map<String, TokenModel> merged = {};
        
        // Prioritize holdings
        for (final t in _holdings) {
          if (_network == null || t.chain.toLowerCase() == _network!.toLowerCase()) {
            merged[t.identity] = t;
          }
        }
        
        // Add popular assets
        for (final t in popular) {
          if (!merged.containsKey(t.identity)) {
            merged[t.identity] = t;
          }
        }
        
        _results = merged.values.toList();
        
        // Sort: Priority/Verified/Major first, then by value/balance
        _results.sort((a, b) {
          // 1. Always Display (Top Priority)
          if (a.alwaysDisplay != b.alwaysDisplay) return a.alwaysDisplay ? -1 : 1;
          
          // 2. Featured
          if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
          
          // 3. Official / Native / Griot Asset
          final av = a.isOfficial || a.isNative || a.isGriotAsset;
          final bv = b.isOfficial || b.isNative || b.isGriotAsset;
          if (av != bv) return av ? -1 : 1;

          // 4. Wallet Holdings (Positive Balance)
          final ab = (num.tryParse(a.balance) ?? 0) > 0;
          final bb = (num.tryParse(b.balance) ?? 0) > 0;
          if (ab != bb) return ab ? -1 : 1;
          
          // 5. Explicit Display Order
          if (a.displayOrder != null && b.displayOrder != null) {
            if (a.displayOrder != b.displayOrder) return a.displayOrder!.compareTo(b.displayOrder!);
          }

          // 6. Value/Market Cap/Price
          return (b.valueUsd ?? 0).compareTo(a.valueUsd ?? 0);
        });
      } else {
        _results = popular;
      }

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
      
        // Sort: Priority/Verified/Major first, then by value/balance
      _results.sort((a, b) {
        // 1. Always Display (Top Priority)
        if (a.alwaysDisplay != b.alwaysDisplay) return a.alwaysDisplay ? -1 : 1;
        
        // 2. Featured
        if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
        
        // 3. Official / Native / Griot Asset
        final av = a.isOfficial || a.isNative || a.isGriotAsset;
        final bv = b.isOfficial || b.isNative || b.isGriotAsset;
        if (av != bv) return av ? -1 : 1;

        // 4. Wallet Holdings (Positive Balance)
        final ab = (num.tryParse(a.balance) ?? 0) > 0;
        final bb = (num.tryParse(b.balance) ?? 0) > 0;
        if (ab != bb) return ab ? -1 : 1;

        // 5. Explicit Display Order
        if (a.displayOrder != null && b.displayOrder != null) {
          if (a.displayOrder != b.displayOrder) return a.displayOrder!.compareTo(b.displayOrder!);
        }

        // 6. Value/Market Cap/Price
        return (b.valueUsd ?? 0).compareTo(a.valueUsd ?? 0);
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
    // CONTRACT: Allow swap if asset is in wallet (has balance), is a popular/official asset, 
    // or is a Griot native asset.
    final hasBalance = (num.tryParse(token.balance) ?? 0) > 0;
    return hasBalance || token.isOfficial || token.isNative || token.isGriotAsset || token.isFeatured;
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
