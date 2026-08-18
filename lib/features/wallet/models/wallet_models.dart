class WalletToken {
  final String? id;
  final String name;
  final String symbol;
  final num balance;
  final num? price;
  final num? valueUsd;
  final num? changePercent;
  final num? marketCap;
  final String chain;
  final String? contractAddress;
  final String? imageUrl;
  final bool isOfficial;
  final bool isFeatured;
  final bool alwaysDisplay;
  final int? displayOrder;

  const WalletToken({
    this.id,
    required this.name,
    required this.symbol,
    required this.balance,
    this.price,
    this.valueUsd,
    this.changePercent,
    this.marketCap,
    required this.chain,
    this.contractAddress,
    this.imageUrl,
    this.isOfficial = false,
    this.isFeatured = false,
    this.alwaysDisplay = false,
    this.displayOrder,
  });

  bool get isProfit => (changePercent ?? 0) >= 0;

  factory WalletToken.fromJson(
    Map<String, dynamic> json,
  ) {
    return WalletToken(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? 'Unknown asset',
      symbol: json['symbol']?.toString() ?? '',
      balance: _numValue(json['balance']) ?? 0,
      price: _numValue(json['price']),
      valueUsd: _numValue(json['valueUsd']),
      changePercent: _numValue(json['change24h']),
      marketCap: _numValue(json['marketCap']),
      chain: json['network']?.toString() ?? '',
      contractAddress: json['tokenAddress']?.toString(),
      imageUrl: json['logo']?.toString(),
      isOfficial: json['isOfficial'] == true,
      isFeatured: json['isFeatured'] == true,
      alwaysDisplay: json['alwaysDisplay'] == true,
      displayOrder: json['displayOrder'] is num
          ? (json['displayOrder'] as num).toInt()
          : null,
    );
  }

  static num? _numValue(dynamic value) {
    if (value is num) {
      return value;
    }

    if (value is String) {
      return num.tryParse(value);
    }

    return null;
  }
}

class WalletAssetsResponse {
  final String address;
  final List<WalletToken> assets;
  final num totalBalanceUsd;
  final DateTime? fetchedAt;

  const WalletAssetsResponse({
    required this.address,
    required this.assets,
    required this.totalBalanceUsd,
    this.fetchedAt,
  });

  factory WalletAssetsResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawAssets = json['assets'] as List<dynamic>? ?? [];

    return WalletAssetsResponse(
      address: json['address']?.toString() ?? '',
      assets: rawAssets
          .whereType<Map<String, dynamic>>()
          .map(WalletToken.fromJson)
          .toList(),
      totalBalanceUsd:
          WalletToken._numValue(json['totalBalanceUsd']) ?? 0,
      fetchedAt: DateTime.tryParse(
        json['fetchedAt']?.toString() ?? '',
      ),
    );
  }
}

class WalletNetwork {
  final String network;
  final String name;
  final String symbol;
  final String type;
  final String? alchemyNetwork;

  const WalletNetwork({
    required this.network,
    required this.name,
    required this.symbol,
    required this.type,
    this.alchemyNetwork,
  });

  factory WalletNetwork.fromJson(
    Map<String, dynamic> json,
  ) {
    return WalletNetwork(
      network: json['network']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      alchemyNetwork: json['alchemyNetwork']?.toString(),
    );
  }
}
