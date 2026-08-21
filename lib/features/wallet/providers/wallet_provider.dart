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
  bool get onlyProfit => _onlyProfit;
  bool get onlyLoss => _onlyLoss;
  Set<String> get hiddenTokenKeys => Set.unmodifiable(_hiddenTokenKeys);
  Set<String> get selectedChains => Set.unmodifiable(_selectedChains);

  bool isPriorityToken(TokenModel token) {
    return _prioritySymbols.contains(token.symbol.trim().toUpperCase());
  }

  String _getTokenKey(TokenModel token) {
    return '${token.chain}:${token.contractAddress.toLowerCase().trim()}';
  }

  bool isTokenHidden(TokenModel token) {
    return _hiddenTokenKeys.contains(_getTokenKey(token));
  }

  List<TokenModel> get filteredTokens {
    final result = _tokens.where((token) {
      // Contract: Only show tokens that are not spam and are tradeable.
      if (token.isSpam) {
        return false;
      }
      if (!token.isTradeable) {
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

      final responseData = await _walletApiService.getAssets();
      final List assetsJson = responseData['assets'] ?? [];
      final parsedTokens = assetsJson
          .map((json) => TokenModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();

      final totalBalanceUsd = responseData['totalValueUsd'] ?? 
        parsedTokens.fold<num>(0, (total, token) => total + token.valueUsd);

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

  void setHideZeroBalance(bool value) {
    _hideZeroBalance = value;
    notifyListeners();
  }

  void setOnlyProfit(bool value) {
    _onlyProfit = value;
    if (value) _onlyLoss = false;
    notifyListeners();
  }

  void setOnlyLoss(bool value) {
    _onlyLoss = value;
    if (value) _onlyProfit = false;
    notifyListeners();
  }

  void toggleChain(String chain) {
    if (_selectedChains.contains(chain)) {
      _selectedChains.remove(chain);
    } else {
      _selectedChains.add(chain);
    }
    notifyListeners();
  }

  void clearFilters() {
    _hideZeroBalance = false;
    _onlyProfit = false;
    _onlyLoss = false;
    _selectedChains.clear();
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
    _onlyProfit = false;
    _onlyLoss = false;
    _selectedChains.clear();
    notifyListeners();
  }
}
