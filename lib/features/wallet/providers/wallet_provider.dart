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

  // ============================================================
  // STATE
  // ============================================================

  WalletModel? _wallet;
  List<TokenModel> _tokens = [];
  int _selectedTab = 0;
  bool _isLoading = false;
  String? _error;

  // Filters
  bool _hideZeroBalance = false;
  bool _onlyProfit = false;
  bool _onlyLoss = false;
  final Set<String> _selectedChains = {};

  // ============================================================
  // GETTERS
  // ============================================================

  WalletModel? get wallet => _wallet;
  List<TokenModel> get tokens => _tokens;
  int get selectedTab => _selectedTab;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get hideZeroBalance => _hideZeroBalance;
  bool get onlyProfit => _onlyProfit;
  bool get onlyLoss => _onlyLoss;
  Set<String> get selectedChains => _selectedChains;

  List<TokenModel> get filteredTokens {
    return _tokens.where((token) {
      if (_hideZeroBalance && token.balance <= 0) {
        return false;
      }

      if (_onlyProfit && token.changePercent < 0) {
        return false;
      }

      if (_onlyLoss && token.changePercent > 0) {
        return false;
      }

      if (_selectedChains.isNotEmpty && !_selectedChains.contains(token.chain)) {
        return false;
      }

      return true;
    }).toList();
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> loadWallet() async {
    _setLoading(true);
    try {
      final address = await _walletService.getAddress();
      if (address != null) {
        _wallet = WalletModel(
          address: address,
          displayName: 'Your Griot Account',
        );

        // Fetch tokens and native balances from API
        final tokenData = await _walletApiService.getTokens(address: address);
        
        _tokens = tokenData.map((json) => TokenModel(
          name: json['name']?.toString() ?? '',
          symbol: json['symbol']?.toString() ?? '',
          balance: json['balance'] ?? 0,
          changePercent: json['changePercent'] ?? 0,
          chain: json['chain']?.toString() ?? '',
          contractAddress: json['contractAddress']?.toString() ?? '',
          imageUrl: json['imageUrl']?.toString() ?? '',
        )).toList();
      }
      
      _error = null;
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

  // ============================================================
  // RESET
  // ============================================================

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
