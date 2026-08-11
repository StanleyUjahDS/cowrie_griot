class WalletState {
  int selectedTab;

  bool hideZeroBalance;
  bool onlyProfit;
  bool onlyLoss;

  final Set<String> selectedChains;

  WalletState({
    this.selectedTab = 0,
    this.hideZeroBalance = false,
    this.onlyProfit = false,
    this.onlyLoss = false,
    Set<String>? selectedChains,
  }) : selectedChains = selectedChains ?? {};
}