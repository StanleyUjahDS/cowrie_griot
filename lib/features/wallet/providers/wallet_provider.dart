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
  List<TokenModel> _popularAssets = [];
  int _selectedTab = 0;
  bool _isLoading = false;
  String? _error;
  bool _hideUnverified = false;
  bool _hideLowBalance = false;
  bool _onlyProfit = false;
  bool _onlyLoss = false;
  final Set<String> _selectedChains = {};
  final Set<String> _hiddenTokenKeys = {};

  WalletModel? get wallet => _wallet;
  List<TokenModel> get tokens => List.unmodifiable(_tokens);
  List<TokenModel> get popularAssets => List.unmodifiable(_popularAssets);
  int get selectedTab => _selectedTab;
  bool get isLoading => _isLoading;
  String? get error => _error;
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
      if (status == 'blocked' || token.isSpam) return false;
      
      // Verified/Major Assets: status verified/official, native assets, or Griot ecosystem assets
      return status == 'verified' || status == 'official' || token.isNative || token.isGriotAsset;
    }).toList()..sort((a, b) => b.valueUsd.compareTo(a.valueUsd));
  }

  List<TokenModel> get unverifiedAssets {
    if (_hideUnverified) return [];

    return _tokens.where((token) {
      if (_hiddenTokenKeys.contains(_getTokenKey(token))) return false;
      if (_hideLowBalance && token.valueUsd < 1) return false;
      
      final status = token.status.toLowerCase();
      if (status == 'blocked' || token.isSpam) return false;
      
      // Unverified Assets: status unknown and NOT a major asset
      return status == 'unknown' && !token.isNative && !token.isGriotAsset;
    }).toList()..sort((a, b) => b.valueUsd.compareTo(a.valueUsd));
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
    if (token.isNative || token.isGriotAsset) return true;

    final status = token.status.toLowerCase();
    // AUTHORITATIVE: status == verified && isTradeable == true && !isSpam
    return status == 'verified' && token.isTradeable && !token.isSpam;
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

  void _recalculateWalletTotals() {
    if (_wallet == null) return;

    // The total balance mirrors exactly what is visible in the list.
    // If an asset is filtered out (manually hidden, low balance, or unverified filter), 
    // it no longer contributes to the total.
    final visibleTokens = _tokens.where((token) {
      // 1. Manual Hide (Long press action)
      if (_hiddenTokenKeys.contains(_getTokenKey(token))) return false;

      // 2. Blocked/Spam (Always excluded)
      if (isTokenBlocked(token)) return false;

      final status = token.status.toLowerCase();
      final isMajor =
          status == 'verified' || status == 'official' || token.isNative || token.isGriotAsset;

      // 3. Unverified Filter
      if (_hideUnverified && status == 'unknown' && !isMajor) return false;

      // 4. Low Balance Filter
      if (_hideLowBalance && token.valueUsd < 1) return false;

      // 5. Chain Filter
      if (_selectedChains.isNotEmpty && !_selectedChains.contains(token.chain)) {
        return false;
      }

      return true;
    }).toList();

    final totalBalanceUsd = visibleTokens.fold<num>(
      0,
      (total, token) => total + token.valueUsd,
    );

    // Calculate aggregate portfolio percentage change (24h) for visible assets
    num totalPreviousValueUsd = 0;
    for (final token in visibleTokens) {
      if (token.hasMarketData && token.valueUsd > 0) {
        final previousValue =
            token.valueUsd / (1 + (token.changePercent / 100));
        totalPreviousValueUsd += previousValue;
      } else {
        totalPreviousValueUsd += token.valueUsd;
      }
    }

    final aggregateChangePercent = totalPreviousValueUsd > 0
        ? ((totalBalanceUsd - totalPreviousValueUsd) / totalPreviousValueUsd) *
            100
        : 0.0;

    _wallet = _wallet!.copyWith(
      totalBalance: totalBalanceUsd,
      changePercent: aggregateChangePercent,
    );
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
      _hideUnverified = filterSettings['hideUnverified'] == true;
      _hideLowBalance = filterSettings['hideLowBalance'] == true;
      _onlyProfit = filterSettings['onlyProfit'] == true;
      _onlyLoss = filterSettings['onlyLoss'] == true;

      final savedChains = filterSettings['selectedChains'];
      if (savedChains is List) {
        _selectedChains.clear();
        _selectedChains.addAll(savedChains.map((e) => e.toString()));
      }

      // Load holdings and popular assets in parallel
      final results = await Future.wait([
        _walletApiService.getAssets(),
        _walletApiService.getPopularAssets(),
      ]);

      final responseData = results[0] as Map<String, dynamic>;
      final popularJson = results[1] as List<TokenModel>;

      final List assetsJson = responseData['assets'] ?? [];
      final parsedTokens = assetsJson
          .map((json) => TokenModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();

      _tokens = parsedTokens;
      _popularAssets = popularJson;

      _wallet = WalletModel(
        address: responseData['address'] ?? address,
        displayName: 'Your Griot Account',
        totalBalance: 0,
        changePercent: 0,
      );

      _recalculateWalletTotals();
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
    _recalculateWalletTotals();
    notifyListeners();
  }

  Future<void> showToken(TokenModel token) async {
    final key = _getTokenKey(token);
    _hiddenTokenKeys.remove(key);
    await _walletService.saveHiddenTokens(_hiddenTokenKeys.toList());
    _recalculateWalletTotals();
    notifyListeners();
  }

  void setTab(int index) {
    _selectedTab = index;
    notifyListeners();
  }

  Future<void> _saveFilters() async {
    await _walletService.saveWalletFilters({
      'hideUnverified': _hideUnverified,
      'hideLowBalance': _hideLowBalance,
      'onlyProfit': _onlyProfit,
      'onlyLoss': _onlyLoss,
      'selectedChains': _selectedChains.toList(),
    });
  }

  void setHideUnverified(bool value) {
    _hideUnverified = value;
    _saveFilters();
    _recalculateWalletTotals();
    notifyListeners();
  }

  void setHideLowBalance(bool value) {
    _hideLowBalance = value;
    _saveFilters();
    _recalculateWalletTotals();
    notifyListeners();
  }

  void setOnlyProfit(bool value) {
    _onlyProfit = value;
    if (value) _onlyLoss = false;
    _saveFilters();
    _recalculateWalletTotals();
    notifyListeners();
  }

  void setOnlyLoss(bool value) {
    _onlyLoss = value;
    if (value) _onlyProfit = false;
    _saveFilters();
    _recalculateWalletTotals();
    notifyListeners();
  }

  void toggleChain(String chain) {
    if (_selectedChains.contains(chain)) {
      _selectedChains.remove(chain);
    } else {
      _selectedChains.add(chain);
    }
    _saveFilters();
    _recalculateWalletTotals();
    notifyListeners();
  }

  void clearFilters() {
    _hideUnverified = false;
    _hideLowBalance = false;
    _onlyProfit = false;
    _onlyLoss = false;
    _selectedChains.clear();
    _saveFilters();
    _recalculateWalletTotals();
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
    _hideUnverified = false;
    _hideLowBalance = false;
    _onlyProfit = false;
    _onlyLoss = false;
    _selectedChains.clear();
    notifyListeners();
  }
}
