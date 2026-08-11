import '../data/wallet_data.dart';
import '../models/wallet_models.dart';
import '../state/wallet_state.dart';

class WalletController {
  final WalletState state;

  WalletController({
    WalletState? state,
  }) : state = state ?? WalletState();

  List<WalletToken> get filteredTokens {
    return mockTokens.where((token) {
      if (state.hideZeroBalance &&
          token.balance <= 0) {
        return false;
      }

      if (state.onlyProfit &&
          token.changePercent < 0) {
        return false;
      }

      if (state.onlyLoss &&
          token.changePercent > 0) {
        return false;
      }

      if (state.selectedChains.isNotEmpty &&
          !state.selectedChains.contains(token.chain)) {
        return false;
      }

      return true;
    }).toList();
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
}