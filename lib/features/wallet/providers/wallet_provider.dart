import 'package:flutter/material.dart';

import '../models/token_model.dart';
import '../models/wallet_model.dart';
import '../services/wallet_service.dart';
import '../services/wallet_api_service.dart';

class WalletProvider extends ChangeNotifier {
  final WalletService _walletService;
  final WalletApiService _walletApiService;

  WalletProvider({
    required WalletService walletService,
    required WalletApiService walletApiService,
  })  : _walletService = walletService,
        _walletApiService = walletApiService;

  static const Set<String> _prioritySymbols = {
    'HBADG',
    'BNB',
  };

  WalletModel? _wallet;
  List<TokenModel> _tokens = [];
  int _selectedTab = 0;
  bool _isLoading = false;
  String? _error;
  bool _hideZeroBalance = false;
  bool _hideUnverified = false;
  bool _hideLowBalance = false;
  bool _onlyProfit = false;
  bool _onlyLoss = false;
  final Set<String> _selectedChains = {};
  final Set<String> _hiddenTokenKeys = {};

  WalletModel? get wallet => _wallet;
  List<TokenModel> get tokens => List.unmodifiable(_tokens);
  int get selectedTab => _selectedTab;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hideZeroBalance => _hideZeroBalance;
  bool get hideUnverified => _hideUnverified;
  bool get hideLowBalance => _hideLowBalance;
  bool get onlyProfit => _onlyProfit;
  bool get onlyLoss => _onlyLoss;
  Set<String> get hiddenTokenKeys => Set.unmodifiable(_hiddenTokenKeys);
  Set<String> get selectedChains => Set.unmodifiable(_selectedChains);

  bool isPriorityToken(TokenModel token) {
    return _prioritySymbols.contains(token.symbol.trim().toUpperCase());
  }

  String _getTokenKey(TokenModel token) {
    return token.identity;
  }

  bool isTokenHidden(TokenModel token) {
    return _hiddenTokenKeys.contains(_getTokenKey(token));
  }

  List<TokenModel> get verifiedAssets {
    return _tokens.where((token) {
      if (_hiddenTokenKeys.contains(_getTokenKey(token))) return false;
      if (_hideLowBalance && token.valueUsd < 1) return false;
      
      final status = token.status.toLowerCase();
      // General wallet list includes verified, official, and unknown tokens.
      // It EXCLUDES blocked and spam tokens.
      return status != 'blocked' && !token.isSpam;
    }).toList()..sort((a, b) => b.valueUsd.compareTo(a.valueUsd));
  }

  List<TokenModel> get unverifiedAssets {
    // This category is now merged into verifiedAssets (General List)
    // as per updated authoritative backend rules.
    return [];
  }

  List<TokenModel> get blockedAssets {
    return _tokens.where((token) {
      final status = token.status.toLowerCase();
      // AUTHORITATIVE: status == blocked || isSpam == true
      return status == 'blocked' || token.isSpam;
    }).toList()..sort((a, b) => b.valueUsd.compareTo(a.valueUsd));
  }

  bool isTokenBlocked(TokenModel token) {
    final status = token.status.toLowerCase();
    return status == 'blocked' || token.isSpam;
  }

  bool canSwap(TokenModel token) {
    final status = token.status.toLowerCase();
    // AUTHORITATIVE: status == verified && isTradeable == true
    return status == 'verified' && token.isTradeable;
  }

  List<TokenModel> get filteredTokens {
    // Note: We return all non-blocked tokens for the general list if not explicitly filtered.
    // The UI will handle categorization into sections.
    final result = _tokens.where((token) {
      if (isTokenBlocked(token)) {
        return false;
      }

      // Negative balances are never valid wallet holdings for presentation.
      // They must stay hidden regardless of the user's filter settings.
      if (token.balance < 0) {
        return false;
      }

      if (_hiddenTokenKeys.contains(_getTokenKey(token))) {
        return false;
      }

      if (_hideZeroBalance && token.balance <= 0) {
        return false;
      }

      if (_hideUnverified && token.status.toLowerCase() == 'unknown') {
        return false;
      }

      if (_hideLowBalance && token.valueUsd < 1) {
        return false;
      }

      if (_onlyProfit && token.changePercent < 0) {
        return false;
      }

      if (_onlyLoss && token.changePercent > 0) {
        return false;
      }

      if (_selectedChains.isNotEmpty &&
          !_selectedChains.contains(token.chain)) {
        return false;
      }

      return true;
    }).toList();

    result.sort((a, b) => b.valueUsd.compareTo(a.valueUsd));
    return result;
  }

  Future<void> loadWallet() async {
    if (_isLoading) return;

    _setLoading(true);

    try {
      _error = null;

      final address = await _walletService.getAddress();

      if (address == null || address.isEmpty) {
        _wallet = null;
        _tokens = [];
        return;
      }

      final hiddenList = await _walletService.getHiddenTokens();
      _hiddenTokenKeys.clear();
      _hiddenTokenKeys.addAll(hiddenList);

      final filterSettings = await _walletService.getWalletFilters();
      _hideZeroBalance = filterSettings['hideZeroBalance'] == true;
      _hideUnverified = filterSettings['hideUnverified'] == true;
      _hideLowBalance = filterSettings['hideLowBalance'] == true;
      _onlyProfit = filterSettings['onlyProfit'] == true;
      _onlyLoss = filterSettings['onlyLoss'] == true;
      
      final savedChains = filterSettings['selectedChains'];
      if (savedChains is List) {
        _selectedChains.clear();
        _selectedChains.addAll(savedChains.map((e) => e.toString()));
      }

      final responseData = await _walletApiService.getAssets();
      final List assetsJson = responseData['assets'] ?? [];
      final parsedTokens = assetsJson
          .map((json) => TokenModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();

      final totalBalanceUsd = parsedTokens
          .where((token) {
            // Unknown assets remain in the general wallet list and totals.
            // Only hidden, blocked, and spam assets are excluded.
            if (_hiddenTokenKeys.contains(_getTokenKey(token))) return false;
            return !isTokenBlocked(token);
          })
          .fold<num>(0, (total, token) => total + token.valueUsd);

      _wallet = WalletModel(
        address: responseData['address'] ?? address,
        displayName: 'Your Griot Account',
        totalBalance: totalBalanceUsd,
        changePercent: 0,
      );

      _tokens = parsedTokens;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> hideToken(TokenModel token) async {
    final key = _getTokenKey(token);
    _hiddenTokenKeys.add(key);
    await _walletService.saveHiddenTokens(_hiddenTokenKeys.toList());
    notifyListeners();
  }

  Future<void> showToken(TokenModel token) async {
    final key = _getTokenKey(token);
    _hiddenTokenKeys.remove(key);
    await _walletService.saveHiddenTokens(_hiddenTokenKeys.toList());
    notifyListeners();
  }

  void setTab(int index) {
    _selectedTab = index;
    notifyListeners();
  }

  Future<void> _saveFilters() async {
    await _walletService.saveWalletFilters({
      'hideZeroBalance': _hideZeroBalance,
      'hideUnverified': _hideUnverified,
      'hideLowBalance': _hideLowBalance,
      'onlyProfit': _onlyProfit,
      'onlyLoss': _onlyLoss,
      'selectedChains': _selectedChains.toList(),
    });
  }

  void setHideZeroBalance(bool value) {
    _hideZeroBalance = value;
    _saveFilters();
    notifyListeners();
  }

  void setHideUnverified(bool value) {
    _hideUnverified = value;
    _saveFilters();
    notifyListeners();
  }

  void setHideLowBalance(bool value) {
    _hideLowBalance = value;
    _saveFilters();
    notifyListeners();
  }

  void setOnlyProfit(bool value) {
    _onlyProfit = value;
    if (value) _onlyLoss = false;
    _saveFilters();
    notifyListeners();
  }

  void setOnlyLoss(bool value) {
    _onlyLoss = value;
    if (value) _onlyProfit = false;
    _saveFilters();
    notifyListeners();
  }

  void toggleChain(String chain) {
    if (_selectedChains.contains(chain)) {
      _selectedChains.remove(chain);
    } else {
      _selectedChains.add(chain);
    }
    _saveFilters();
    notifyListeners();
  }

  void clearFilters() {
    _hideZeroBalance = false;
    _hideUnverified = false;
    _hideLowBalance = false;
    _onlyProfit = false;
    _onlyLoss = false;
    _selectedChains.clear();
    _saveFilters();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void reset() {
    _wallet = null;
    _tokens = [];
    _selectedTab = 0;
    _isLoading = false;
    _error = null;
    _hideZeroBalance = false;
    _hideUnverified = false;
    _hideLowBalance = false;
    _onlyProfit = false;
    _onlyLoss = false;
    _selectedChains.clear();
    notifyListeners();
  }
}
