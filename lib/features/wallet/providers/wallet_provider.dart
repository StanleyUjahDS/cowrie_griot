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

  bool _hideZeroBalance = false;

  bool _onlyProfit = false;

  bool _onlyLoss = false;

  final Set<String> _selectedChains = {};

  // ============================================================
  // GETTERS
  // ============================================================

  WalletModel? get wallet =>
      _wallet;

  List<TokenModel> get tokens =>
      List.unmodifiable(_tokens);

  int get selectedTab =>
      _selectedTab;

  bool get isLoading =>
      _isLoading;

  String? get error =>
      _error;

  bool get hideZeroBalance =>
      _hideZeroBalance;

  bool get onlyProfit =>
      _onlyProfit;

  bool get onlyLoss =>
      _onlyLoss;

  Set<String> get selectedChains =>
      Set.unmodifiable(
        _selectedChains,
      );

  // ============================================================
  // FILTERED TOKENS
  // ============================================================

  List<TokenModel> get filteredTokens {
    return _tokens.where((token) {
      if (_hideZeroBalance &&
          token.balance <= 0) {
        return false;
      }

      if (_onlyProfit &&
          token.changePercent < 0) {
        return false;
      }

      if (_onlyLoss &&
          token.changePercent > 0) {
        return false;
      }

      if (_selectedChains.isNotEmpty &&
          !_selectedChains.contains(
            token.chain,
          )) {
        return false;
      }

      return true;
    }).toList();
  }

  // ============================================================
  // LOAD WALLET
  // ============================================================

  Future<void> loadWallet() async {
    if (_isLoading) {
      return;
    }

    _setLoading(true);

    try {
      _error = null;

      // --------------------------------------------------------
      // GET LOCAL WALLET ADDRESS
      // --------------------------------------------------------

      final address =
          await _walletService.getAddress();

      if (address == null ||
          address.isEmpty) {
        _wallet = null;
        _tokens = [];

        return;
      }

      // --------------------------------------------------------
      // FETCH NATIVE BALANCES
      // --------------------------------------------------------

      final nativeBalances =
          await _walletApiService
              .getNativeBalances(
        address: address,
      );

      // --------------------------------------------------------
      // FETCH TOKEN BALANCES
      // --------------------------------------------------------

      final tokenData =
          await _walletApiService.getTokens(
        address: address,
      );

      // --------------------------------------------------------
      // CONVERT TOKEN RESPONSES
      // --------------------------------------------------------

      final parsedTokens =
          tokenData
              .map(
                TokenModel.fromJson,
              )
              .toList();

      // --------------------------------------------------------
      // CALCULATE NATIVE USD VALUE
      // --------------------------------------------------------

      num totalNativeBalanceUsd = 0;

      for (final native in nativeBalances) {
        totalNativeBalanceUsd +=
            _readNumber(
          native,
          [
            'balanceUsd',
            'valueUsd',
            'usdValue',
          ],
        );
      }

      // --------------------------------------------------------
      // CALCULATE TOKEN USD VALUE
      // --------------------------------------------------------

      num totalTokenBalanceUsd = 0;

      for (final token in parsedTokens) {
        totalTokenBalanceUsd +=
            token.valueUsd;
      }

      // --------------------------------------------------------
      // TOTAL PORTFOLIO VALUE
      // --------------------------------------------------------

      final totalBalanceUsd =
          totalNativeBalanceUsd +
          totalTokenBalanceUsd;

      // --------------------------------------------------------
      // DEBUGGING
      // --------------------------------------------------------

      debugPrint(
        '================================================',
      );

      debugPrint(
        'WALLET ADDRESS: $address',
      );

      debugPrint(
        'NATIVE BALANCES: $nativeBalances',
      );

      debugPrint(
        'TOKEN DATA: $tokenData',
      );

      debugPrint(
        'PARSED TOKENS: $parsedTokens',
      );

      debugPrint(
        'TOTAL NATIVE USD: $totalNativeBalanceUsd',
      );

      debugPrint(
        'TOTAL TOKEN USD: $totalTokenBalanceUsd',
      );

      debugPrint(
        'TOTAL WALLET USD: $totalBalanceUsd',
      );

      debugPrint(
        '================================================',
      );

      // --------------------------------------------------------
      // PORTFOLIO CHANGE
      // --------------------------------------------------------
      //
      // Do NOT leave the old mock 3.5%.
      //
      // Until the backend provides an actual portfolio change,
      // use 0.
      //
      // --------------------------------------------------------

      final changePercent =
          _calculatePortfolioChange(
        nativeBalances,
        parsedTokens,
      );

      // --------------------------------------------------------
      // BUILD WALLET MODEL
      // --------------------------------------------------------

      _wallet = WalletModel(
        address: address,
        displayName:
            'Your Griot Account',
        totalBalance:
            totalBalanceUsd,
        changePercent:
            changePercent,
      );

      _tokens = parsedTokens;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // NUMBER READER
  // ============================================================

  num _readNumber(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];

      if (value is num) {
        return value;
      }

      if (value != null) {
        final parsed =
            num.tryParse(
          value.toString(),
        );

        if (parsed != null) {
          return parsed;
        }
      }
    }

    return 0;
  }

  // ============================================================
  // PORTFOLIO CHANGE
  // ============================================================
  //
  // Until backend supplies historical portfolio data,
  // we do not invent a percentage.
  //
  // ============================================================

  num _calculatePortfolioChange(
    List<Map<String, dynamic>>
        nativeBalances,
    List<TokenModel> tokens,
  ) {
    num weightedValue = 0;

    num weightedChange = 0;

    for (final native in nativeBalances) {
      final value = _readNumber(
        native,
        [
          'balanceUsd',
          'valueUsd',
          'usdValue',
        ],
      );

      final change = _readNumber(
        native,
        [
          'changePercent',
          'priceChangePercent',
        ],
      );

      weightedValue += value;

      weightedChange +=
          value * change;
    }

    for (final token in tokens) {
      weightedValue += token.valueUsd;

      weightedChange +=
          token.valueUsd *
          token.changePercent;
    }

    if (weightedValue <= 0) {
      return 0;
    }

    return weightedChange /
        weightedValue;
  }

  // ============================================================
  // TAB
  // ============================================================

  void setTab(int index) {
    _selectedTab = index;

    notifyListeners();
  }

  // ============================================================
  // FILTERS
  // ============================================================

  void setHideZeroBalance(
    bool value,
  ) {
    _hideZeroBalance = value;

    notifyListeners();
  }

  void setOnlyProfit(
    bool value,
  ) {
    _onlyProfit = value;

    if (value) {
      _onlyLoss = false;
    }

    notifyListeners();
  }

  void setOnlyLoss(
    bool value,
  ) {
    _onlyLoss = value;

    if (value) {
      _onlyProfit = false;
    }

    notifyListeners();
  }

  void toggleChain(
    String chain,
  ) {
    if (_selectedChains.contains(
      chain,
    )) {
      _selectedChains.remove(
        chain,
      );
    } else {
      _selectedChains.add(
        chain,
      );
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

  // ============================================================
  // LOADING
  // ============================================================

  void _setLoading(
    bool value,
  ) {
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
