import '../models/wallet_models.dart';
import '../services/wallet_api_service.dart';
import '../state/wallet_state.dart';

class WalletController {
  final WalletState state;
  final WalletApiService apiService;

  List<WalletToken> _tokens = const [];
  num totalBalanceUsd = 0;
  bool isLoading = false;
  String? errorMessage;

  WalletController({
    WalletState? state,
    WalletApiService? apiService,
  })  : state = state ?? WalletState(),
        apiService = apiService ?? WalletApiService();

  List<WalletToken> get filteredTokens {
    return _tokens.where((token) {
      if (state.hideZeroBalance && token.balance <= 0) {
        return false;
      }

      if (state.onlyProfit && !token.isProfit) {
        return false;
      }

      if (state.onlyLoss && token.isProfit) {
        return false;
      }

      if (state.selectedChains.isNotEmpty &&
          !state.selectedChains.contains(token.chain)) {
        return false;
      }

      return true;
    }).toList();
  }

  List<WalletToken> get tokens => List.unmodifiable(_tokens);

  Future<void> loadAssets() async {
    isLoading = true;
    errorMessage = null;

    try {
      final response = await apiService.getAssets();

      _tokens = response.assets;
      totalBalanceUsd = response.totalBalanceUsd;
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
    }
  }

  Future<void> refresh() async {
    await loadAssets();
  }

  void setTab(int index) {
    state.selectedTab = index;
  }

  void setHideZeroBalance(bool value) {
    state.hideZeroBalance = value;
  }

  void setOnlyProfit(bool value) {
    state.onlyProfit = value;

    if (value) {
      state.onlyLoss = false;
    }
  }

  void setOnlyLoss(bool value) {
    state.onlyLoss = value;

    if (value) {
      state.onlyProfit = false;
    }
  }

  void toggleChain(String chain) {
    if (state.selectedChains.contains(chain)) {
      state.selectedChains.remove(chain);
    } else {
      state.selectedChains.add(chain);
    }
  }

  void clearFilters() {
    state.hideZeroBalance = false;
    state.onlyProfit = false;
    state.onlyLoss = false;
    state.selectedChains.clear();
  }

  void dispose() {
    apiService.dispose();
  }
}
