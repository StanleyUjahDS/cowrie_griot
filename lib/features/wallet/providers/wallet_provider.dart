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

  /// Canonical Griot priority assets.
  ///
  /// This is metadata/recognition only. It does not affect wallet ordering
  /// and does not add zero-balance assets to the user's holdings.
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

  WalletModel? get wallet => _wallet;
  List<TokenModel> get tokens => List.unmodifiable(_tokens);
  int get selectedTab => _selectedTab;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hideZeroBalance => _hideZeroBalance;
  bool get onlyProfit => _onlyProfit;
  bool get onlyLoss => _onlyLoss;

  Set<String> get selectedChains => Set.unmodifiable(_selectedChains);

  bool isPriorityToken(TokenModel token) {
    return _prioritySymbols.contains(token.symbol.trim().toUpperCase());
  }

  List<TokenModel> get filteredTokens {
    final result = _tokens.where((token) {
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

    // Priority assets do not control ordering.
    // Wallet holdings are shown by current holding value.
    result.sort((a, b) => b.valueUsd.compareTo(a.valueUsd));

    return result;
  }

  Future<void> loadWallet() async {
    if (_isLoading) {
      return;
    }

    _setLoading(true);

    try {
      _error = null;

      final address = await _walletService.getAddress();

      if (address == null || address.isEmpty) {
        _wallet = null;
        _tokens = [];
        return;
      }

      final assetData = await _walletApiService.getAssets();

      final parsedTokens = assetData
          .map(TokenModel.fromJson)
          .toList();

      final totalBalanceUsd = parsedTokens.fold<num>(
        0,
        (total, token) => total + token.valueUsd,
      );

      const changePercent = 0;

      _wallet = WalletModel(
        address: address,
        displayName: 'Your Griot Account',
        totalBalance: totalBalanceUsd,
        changePercent: changePercent,
      );

      _tokens = parsedTokens;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
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
    if (value) {
      _onlyLoss = false;
    }
    notifyListeners();
  }

  void setOnlyLoss(bool value) {
    _onlyLoss = value;
    if (value) {
      _onlyProfit = false;
    }
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
