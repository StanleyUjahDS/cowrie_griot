import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:griot_cowrie/core/theme/app_theme_extension.dart';
import 'package:flutter/services.dart';

/// contractAddress = UNIQUE KEY (chain + contractAddress = full uniqueness)
final List<Map<String, dynamic>> mockTokens = [
  {
    "name": "Ethereum",
    "symbol": "ETH",
    "balance": 1.25,
    "changePercent": 3.2,
    "chain": "Ethereum",
    "contractAddress": "0x0000000000000000000000000000000000000000",
    "imageUrl":
    "https://assets.coingecko.com/coins/images/279/small/ethereum.png",
  },
  {
    "name": "USD Coin",
    "symbol": "USDC",
    "balance": 2500,
    "changePercent": -0.3,
    "chain": "Ethereum",
    "contractAddress":
    "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
    "imageUrl":
    "https://assets.coingecko.com/coins/images/6319/small/usdc.png",
  },
  {
    "name": "Solana",
    "symbol": "SOL",
    "balance": 12,
    "changePercent": 5.1,
    "chain": "Solana",
    "contractAddress":
    "So11111111111111111111111111111111111111112",
    "imageUrl":
    "https://assets.coingecko.com/coins/images/4128/small/solana.png",
  },
];

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int selectedTab = 0;
  final TextEditingController easyBuyController =
  TextEditingController();

  // ================= FILTER STATE =================
  bool hideZeroBalance = false;
  bool onlyProfit = false;
  bool onlyLoss = false;

  final Set<String> selectedChains = {};

  final List<dynamic> tabs = [
    "Tokens",
    "NFTs",
    "Activity",
    Icons.filter_list,
  ];

  // ================= FILTER ENGINE =================
  List<Map<String, dynamic>> get filteredTokens {
    return mockTokens.where((t) {
      final balance = t["balance"] as num;
      final change = t["changePercent"] as num;
      final chain = t["chain"] as String;

      if (hideZeroBalance && balance <= 0) return false;
      if (onlyProfit && change < 0) return false;
      if (onlyLoss && change > 0) return false;

      if (selectedChains.isNotEmpty &&
          !selectedChains.contains(chain)) {
        return false;
      }

      return true;
    }).toList();
  }
  // ================= EASY BUY MODAL =================
  void _openEasyBuySheet(
      BuildContext context,
      AppThemeExtension appTheme,
      ) {
    final TextEditingController easyBuyController =
    TextEditingController();

    final TextEditingController amountController =
    TextEditingController();

    String detectedAddress = "";
    String detectedChain = "Ethereum";
    String detectedSymbol = "ETH";
    String detectedName = "Ethereum";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return DraggableScrollableSheet(
              initialChildSize: 0.82,
              maxChildSize: 0.95,
              minChildSize: 0.65,
              builder: (_, controller) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: ListView(
                    controller: controller,
                    children: [

                      // ================= HANDLE =================
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color:
                            Colors.grey.withValues(alpha: 0.3),
                            borderRadius:
                            BorderRadius.circular(20),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ================= TITLE =================
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: appTheme.primaryButton
                                  .withValues(alpha: 0.1),
                            ),
                            child: Icon(
                              Icons.flash_on_rounded,
                              color: appTheme.primaryButton,
                            ),
                          ),

                          const SizedBox(width: 12),

                          const Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Easy Buy",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),

                              SizedBox(height: 2),

                              Text(
                                "Paste any contract or wallet",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 26),

                      // ================= PASTE INPUT =================
                      const Text(
                        "Paste Address",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 10),

                      TextField(
                        controller: easyBuyController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText:
                          "Paste CA, wallet, URL, tweet, or text...",

                          filled: true,

                          fillColor:
                          Colors.grey.withValues(alpha: 0.05),

                          border: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(16),
                          ),

                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.grey
                                  .withValues(alpha: 0.15),
                            ),
                          ),

                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: appTheme.primaryButton,
                            ),
                          ),

                          suffixIcon: IconButton(
                            icon: const Icon(Icons.paste),
                            onPressed: () async {

                              // use clipboard later
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ================= DETECT BUTTON =================
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            appTheme.primaryButton,

                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {

                            final raw =
                            easyBuyController.text.trim();

                            // ================= ETH REGEX =================
                            final ethRegex = RegExp(
                              r'0x[a-fA-F0-9]{40}',
                            );

                            final match =
                            ethRegex.firstMatch(raw);

                            if (match != null) {
                              detectedAddress =
                              match.group(0)!;

                              detectedChain = "Ethereum";
                              detectedSymbol = "ETH";
                              detectedName = "Ethereum";
                            }

                            setModal(() {});
                          },
                          icon: const Icon(
                            Icons.search,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "Detect Token",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 26),

                      // ================= DETECTED TOKEN =================
                      if (detectedAddress.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius:
                            BorderRadius.circular(18),

                            border: Border.all(
                              color: Colors.grey
                                  .withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [

                              // TOKEN IMAGE
                              const CircleAvatar(
                                radius: 24,
                                backgroundImage: NetworkImage(
                                  "https://assets.coingecko.com/coins/images/279/small/ethereum.png",
                                ),
                              ),

                              const SizedBox(width: 14),

                              // TOKEN INFO
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      detectedName,
                                      style: const TextStyle(
                                        fontWeight:
                                        FontWeight.w700,
                                      ),
                                    ),

                                    const SizedBox(height: 4),

                                    Text(
                                      detectedAddress,
                                      maxLines: 1,
                                      overflow:
                                      TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                        Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // CHAIN BADGE
                              Container(
                                padding:
                                const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius:
                                  BorderRadius.circular(30),

                                  color: Colors.green
                                      .withValues(alpha: 0.12),
                                ),
                                child: Text(
                                  detectedChain,
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight:
                                    FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 28),

                      // ================= BUY AMOUNT =================
                      Text(
                        "Buy Amount ($detectedSymbol)",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ================= PRESET BUTTONS =================
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          "0.01",
                          "0.05",
                          "0.1",
                          "0.5",
                        ].map((amount) {
                          return InkWell(
                            borderRadius:
                            BorderRadius.circular(14),
                            onTap: () {
                              amountController.text = amount;
                              setModal(() {});
                            },
                            child: Container(
                              padding:
                              const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                borderRadius:
                                BorderRadius.circular(14),

                                border: Border.all(
                                  color: Colors.grey
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                "$amount $detectedSymbol",
                                style: const TextStyle(
                                  fontWeight:
                                  FontWeight.w700,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 18),

                      // ================= CUSTOM INPUT =================
                      TextField(
                        controller: amountController,
                        keyboardType:
                        const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText:
                          "Custom $detectedSymbol amount",

                          prefixIcon: const Icon(
                            Icons.currency_exchange,
                          ),

                          filled: true,

                          fillColor:
                          Colors.grey.withValues(alpha: 0.05),

                          border: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(16),
                          ),

                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.grey
                                  .withValues(alpha: 0.15),
                            ),
                          ),

                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: appTheme.primaryButton,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // ================= BUY BUTTON =================
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            appTheme.primaryButton,

                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () {

                            debugPrint(
                              "BUY ${amountController.text} "
                                  "$detectedSymbol "
                                  "OF $detectedAddress",
                            );
                          },
                          child: const Text(
                            "Buy Token",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
    Theme.of(context).extension<AppThemeExtension>()!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,

      // ================= APP BAR =================
      appBar: AppBar(
        title: const Text("Wallet"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      body: Column(
        children: [

          // ===== HEADER =====
          ListTile(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12),
            leading: const CircleAvatar(
              radius: 22,
              backgroundImage: AssetImage(
                  "assets/cowrie_images/wolrd_cowrie.png"),
            ),
            title: const Text("John Doe",
                style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.notifications_none),
                SizedBox(width: 10),
                Icon(Icons.qr_code_scanner),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ===== BALANCE =====
          Column(
            children: const [
              Text("Total Balance"),
              SizedBox(height: 6),
              Text(
                "\$12,450.00",
                style:
                TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text("+3.5%",
                  style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600)),
            ],
          ),

          const SizedBox(height: 20),

          // ===== ACTIONS =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                _ActionBox(icon: Icons.send, label: "Send"),
                _ActionBox(icon: Icons.call_received, label: "Receive"),
                _ActionBox(icon: Icons.swap_horiz, label: "Swap"),
                _ActionBox(icon: Icons.qr_code_scanner, label: "Scan"),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ================= TABS =================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: List.generate(tabs.length, (index) {
                final isSelected = selectedTab == index;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (tabs[index] is IconData) {
                        _openFilterSheet();
                        return;
                      }

                      setState(() => selectedTab = index);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? appTheme.primaryButton
                              : Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      child: tabs[index] is IconData
                          ? Icon(tabs[index],
                          color: isSelected
                              ? appTheme.primaryButton
                              : null)
                          : Text(
                        tabs[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? appTheme.primaryButton
                              : null,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 10),

          // ================= TOKENS =================
          Expanded(
            child: ListView.builder(
              itemCount: filteredTokens.length,
              itemBuilder: (context, index) {
                final token = filteredTokens[index];
                final isPositive = token["changePercent"] >= 0;

                return Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundImage:
                        NetworkImage(token["imageUrl"]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(token["name"],
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(token["symbol"],
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("${token["balance"]}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          Text(
                            "${isPositive ? '+' : ''}${token["changePercent"]}%",
                            style: TextStyle(
                              color: isPositive
                                  ? Colors.green
                                  : Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // ================= FILTER SHEET =================
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60),

        child: FloatingActionButton(
          heroTag: "easy_buy_fab",

          backgroundColor:
          appTheme.primaryButton.withValues(alpha: 0.9),

          onPressed: () {
            _openEasyBuySheet(context, appTheme);
          },

          child: const Icon(
            Icons.flash_on_rounded,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ================= FILTER SHEET =================
  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (_, controller) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .primaryColor
                        .withValues(alpha: 0.95),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24)),
                  ),
                  child: ListView(
                    controller: controller,
                    children: [
                      const Text("Filters",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),

                      SwitchListTile(
                        title: const Text("Hide Zero Balance"),
                        value: hideZeroBalance,
                        onChanged: (v) {
                          setModal(() => hideZeroBalance = v);
                          setState(() {});
                        },
                      ),

                      SwitchListTile(
                        title: const Text("Only Profit"),
                        value: onlyProfit,
                        onChanged: (v) {
                          setModal(() => onlyProfit = v);
                          setState(() {});
                        },
                      ),

                      SwitchListTile(
                        title: const Text("Only Loss"),
                        value: onlyLoss,
                        onChanged: (v) {
                          setModal(() => onlyLoss = v);
                          setState(() {});
                        },
                      ),

                      const Divider(),

                      Wrap(
                        spacing: 8,
                        children: [
                          _chip("Ethereum", setModal),
                          _chip("Solana", setModal),
                          _chip("Polygon", setModal),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _chip(String chain, Function setModal) {
    final selected = selectedChains.contains(chain);

    return FilterChip(
      label: Text(chain),
      selected: selected,
      onSelected: (v) {
        setModal(() {
          if (v) {
            selectedChains.add(chain);
          } else {
            selectedChains.remove(chain);
          }
        });
        setState(() {});
      },
    );
  }
}


// ================= ACTION BOX (LIGHT UI OPTIMIZED) =================
class _ActionBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionBox({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 78,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.primaryColor.withValues(alpha: 0.08),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: theme.primaryColor,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.primaryColor.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ================= BUY CHIP =================
Widget _buyChip(String amount) {
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 18,
      vertical: 12,
    ),

    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Colors.grey.withValues(alpha: 0.2),
      ),
    ),

    child: Text(
      amount,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

// ================= EASY BUY TOKEN =================
Widget _easyBuyToken({
  required String image,
  required String name,
  required String symbol,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),

    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Colors.grey.withValues(alpha: 0.2),
      ),
    ),

    child: Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: NetworkImage(image),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),

              Text(
                symbol,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      ],
    ),
  );
}
