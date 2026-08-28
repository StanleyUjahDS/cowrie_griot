import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../models/nft_model.dart';
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
  List<NftModel> _nfts = [];
  List<TokenModel> _popularAssets = [];
  int _selectedTab = 0;
  bool _isLoading = false;
  bool _isLoadingNfts = false;
  String? _error;
  String? _nftError;
  DateTime? _lastFetchTime;
  DateTime? _lastNftFetchTime;
  static const Duration _fetchCooldown = Duration(seconds: 30);
  static const Duration _nftFetchCooldown = Duration(seconds: 30);
  bool _hideLowBalance = false;
  bool _onlyProfit = false;
  bool _onlyLoss = false;
  final Set<String> _selectedChains = {};
  final Set<String> _hiddenTokenKeys = {};

  WalletModel? get wallet => _wallet;
  List<TokenModel> get tokens => List.unmodifiable(_tokens);
  List<NftModel> get nfts => List.unmodifiable(_nfts);
  List<TokenModel> get popularAssets => List.unmodifiable(_popularAssets);
  int get selectedTab => _selectedTab;
  bool get isLoading => _isLoading;
  bool get isLoadingNfts => _isLoadingNfts;
  String? get error => _error;
  String? get nftError => _nftError;
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

  List<TokenModel> get visibleAssets {
    return _tokens.where((token) {
      if (_hiddenTokenKeys.contains(_getTokenKey(token))) return false;
      
      // CONTRACT: always show HBADG; always show native assets with a positive balance.
      if (token.isEcosystem) return true;
      final balance = num.tryParse(token.balance) ?? 0;
      if (token.isNative) return balance > 0;

      // Other assets require positive balance
      if (balance <= 0) return false;

      // Filter settings
      final isMajor = token.isNative || token.isEcosystem;
      // FIX: Ensure wallet filters work when market data is unavailable.
      // If we don't have market data, we don't hide the token even if hideLowBalance is ON.
      if (!isMajor && _hideLowBalance && token.hasMarketData && (token.valueUsd ?? 0) < 1) return false;
      
      return true;
    }).toList()..sort((a, b) => (b.valueUsd ?? 0).compareTo(a.valueUsd ?? 0));
  }

  List<TokenModel> get blockedAssets {
    return []; // No longer provided by backend in this format
  }

  bool isTokenBlocked(TokenModel token) {
    return false; // No longer provided by backend in this format
  }

  bool canSwap(TokenModel token) {
    // CONTRACT: Allow swap if asset is in wallet (has balance), is a popular/official asset, 
    // or is a Griot native asset.
    final hasBalance = (num.tryParse(token.balance) ?? 0) > 0;
    return hasBalance || token.isOfficial || token.isNative || token.isEcosystem || token.isFeatured;
  }

  List<TokenModel> get filteredTokens {
    // Note: We return all non-blocked tokens for the general list if not explicitly filtered.
    // The UI will handle categorization into sections.
    final result = _tokens.where((token) {
      if (isTokenBlocked(token)) {
        return false;
      }

      if (_hiddenTokenKeys.contains(_getTokenKey(token))) {
        return false;
      }

      // CONTRACT: always show HBADG; always show native assets with a positive balance.
      if (token.isEcosystem) {
        // Proceed
      } else {
        final balance = num.tryParse(token.balance) ?? 0;
        if (token.isNative && balance > 0) {
          // Proceed
        } else if (balance <= 0) {
          return false;
        }
      }

      final isMajor = token.isNative || token.isEcosystem;

      // CONTRACT: Native/Ecosystem exempt from low balance filter.
      // FIX: Ensure wallet filters work when market data is unavailable.
      if (!isMajor && _hideLowBalance && token.hasMarketData && (token.valueUsd ?? 0) < 1) {
        return false;
      }

      if (_onlyProfit && (token.changePercent ?? 0) < 0) {
        return false;
      }

      if (_onlyLoss && (token.changePercent ?? 0) > 0) {
        return false;
      }

      if (_selectedChains.isNotEmpty &&
          !_selectedChains.contains(token.chain)) {
        return false;
      }

      return true;
    }).toList();

    result.sort((a, b) => (b.valueUsd ?? 0).compareTo(a.valueUsd ?? 0));
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

      // 3. Zero/Negative balances
      // CONTRACT: always show HBADG; always show native assets with a positive balance.
      if (token.isEcosystem) {
        // Proceed
      } else {
        final balance = num.tryParse(token.balance) ?? 0;
        if (token.isNative && balance > 0) {
          // Proceed
        } else if (balance <= 0) {
          return false;
        }
      }

      final isMajor = token.isNative || token.isEcosystem;

      // 4. Low Balance Filter
      // CONTRACT: Native/Ecosystem exempt from low balance filter.
      // FIX: Ensure wallet filters work when market data is unavailable.
      if (!isMajor && _hideLowBalance && token.hasMarketData && (token.valueUsd ?? 0) < 1) return false;

      // 6. Chain Filter
      if (_selectedChains.isNotEmpty && !_selectedChains.contains(token.chain)) {
        return false;
      }

      return true;
    }).toList();

    final totalBalanceUsd = visibleTokens.fold<num>(
      0,
      (total, token) => total + (token.valueUsd ?? 0),
    );

    // Calculate aggregate portfolio percentage change (24h) for visible assets
    num totalPreviousValueUsd = 0;
    for (final token in visibleTokens) {
      final valUsd = token.valueUsd ?? 0;
      final change = token.changePercent ?? 0;
      if (token.hasMarketData && valUsd > 0) {
        final previousValue = valUsd / (1 + (change / 100));
        totalPreviousValueUsd += previousValue;
      } else {
        totalPreviousValueUsd += valUsd;
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

  Future<void> loadWallet({bool force = false}) async {
    if (_isLoading) return;

    final now = DateTime.now();
    if (!force && _lastFetchTime != null && now.difference(_lastFetchTime!) < _fetchCooldown) {
      debugPrint('WalletProvider: Skipping token fetch, cooldown active.');
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

      final hiddenList = await _walletService.getHiddenTokens();
      _hiddenTokenKeys.clear();
      _hiddenTokenKeys.addAll(hiddenList);

      final filterSettings = await _walletService.getWalletFilters();
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
      _lastFetchTime = DateTime.now();
      
      // If we are on the NFT tab, try to load NFTs too
      if (_selectedTab == 1) {
        loadNfts(force: force);
      }
    } catch (e) {
      debugPrint('WalletProvider: Error loading wallet: $e');
      
      if (e is ApiException && e.statusCode == 401) {
        _error = 'Session expired. Please log in again.';
      } else if (_tokens.isNotEmpty) {
        _error = 'Rate limit reached. Showing cached data.';
      } else {
        _error = e.toString();
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadNfts({bool force = false}) async {
    if (_isLoadingNfts) return;

    final now = DateTime.now();
    if (!force && _lastNftFetchTime != null && now.difference(_lastNftFetchTime!) < _nftFetchCooldown) {
      debugPrint('WalletProvider: Skipping NFT fetch, cooldown active.');
      return;
    }

    _isLoadingNfts = true;
    _nftError = null;
    notifyListeners();

    try {
      final nftResponse = await _walletApiService.getNfts();
      final List nftsJson = nftResponse['nfts'] ?? [];
      
      final parsedNfts = nftsJson
          .map((json) => NftModel.fromJson(Map<String, dynamic>.from(json)))
          .where((nft) => !nft.classification.isSpam) // Hide spam NFTs
          .toList();

      _nfts = parsedNfts;
      _lastNftFetchTime = DateTime.now();
    } catch (e) {
      debugPrint('WalletProvider: Error loading NFTs: $e');
      
      if (e is ApiException && e.statusCode == 429) {
        _nftError = 'NFTs temporarily unavailable (Rate limit)';
      } else {
        _nftError = 'Failed to load NFTs';
      }
      
      // We keep existing NFTs on error if we have them
    } finally {
      _isLoadingNfts = false;
      notifyListeners();
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
    
    // CONTRACT: Load NFTs only when the NFT tab is opened
    if (index == 1 && _nfts.isEmpty) {
      loadNfts();
    }
  }

  Future<void> _saveFilters() async {
    await _walletService.saveWalletFilters({
      'hideLowBalance': _hideLowBalance,
      'onlyProfit': _onlyProfit,
      'onlyLoss': _onlyLoss,
      'selectedChains': _selectedChains.toList(),
    });
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
    _hideLowBalance = false;
    _onlyProfit = false;
    _onlyLoss = false;
    _selectedChains.clear();
    notifyListeners();
  }
}
