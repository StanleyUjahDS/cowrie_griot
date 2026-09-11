import '../utils/chain_assets.dart';

class TokenModel {
  final String name;
  final String symbol;
  final String balance; // formatted string
  final String rawBalance; // integer string
  final num? priceUsd;
  final num? valueUsd;
  final num? changePercent;
  final String chain;
  final String rawNetwork;
  final String contractAddress;
  final String imageUrl;
  final int? decimals;
  final bool hasMarketData;
  final bool isOfficial;
  final bool isEcosystem;
  final bool isFeatured;
  final bool alwaysDisplay;
  final int? displayOrder;
  final String marketDataSource;
  final Map<String, String> externalLinks;

  // Added Backend Fields
  final String? id;
  final String? type;
  final String? chainId;
  final num? marketCapUsd;
  final num? volume24hUsd;
  final num? liquidityUsd;
  final DateTime? priceUpdatedAt;

  const TokenModel({
    required this.name,
    required this.symbol,
    required this.balance,
    required this.rawBalance,
    this.priceUsd,
    this.valueUsd,
    this.changePercent,
    required this.chain,
    this.rawNetwork = '',
    required this.contractAddress,
    required this.imageUrl,
    this.decimals,
    this.hasMarketData = false,
    this.isOfficial = false,
    this.isEcosystem = false,
    this.isFeatured = false,
    this.alwaysDisplay = false,
    this.displayOrder,
    this.marketDataSource = '',
    this.externalLinks = const {},
    this.id,
    this.type,
    this.chainId,
    this.marketCapUsd,
    this.volume24hUsd,
    this.liquidityUsd,
    this.priceUpdatedAt,
  });

  String get identity {
    // CONTRACT: use network + tokenAddress as token identity
    final net = rawNetwork.isNotEmpty ? rawNetwork.toLowerCase() : ChainAssets.normalize(chain);
    if (isNative) return '$net:native';
    return '$net:${contractAddress.toLowerCase().trim()}';
  }

  bool get isNative {
    final address = contractAddress.trim().toLowerCase();
    return address.isEmpty ||
        address == '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee' ||
        address == '0x0000000000000000000000000000000000000000';
  }

  bool get isProfit => (changePercent ?? 0) >= 0;

  bool get isGriotAsset => isEcosystem;

  double get value => (valueUsd ?? 0).toDouble();

  factory TokenModel.fromJson(Map<String, dynamic> json) {
    final String balanceText = _string(json['balance'] ?? '0');

    // Robust rawBalance parsing: handle scientific notation or numeric JSON types
    String rawBalance = '0';
    final rawVal = json['rawBalance'] ?? json['balance'];
    if (rawVal != null) {
      if (rawVal is String) {
        rawBalance = rawVal;
      } else if (rawVal is num) {
        // If it's a number, convert to string without scientific notation if possible
        rawBalance = BigInt.from(rawVal).toString();
      } else {
        rawBalance = rawVal.toString();
      }
    }

    // Market Data Priority mapping
    final num? priceUsd = _numOrNull(json['priceUsd']);
    final num? valueUsd = _numOrNull(json['valueUsd'] ?? json['balanceUsd']);
    final num? changePercent = _numOrNull(json['changePercent24h'] ?? json['changePercent']);

    final bool hasMarketData = priceUsd != null || valueUsd != null;

    final linksRaw = json['externalLinks'];
    final externalLinks = linksRaw is Map
        ? Map<String, String>.from(linksRaw.map((k, v) => MapEntry(k.toString(), v.toString())))
        : <String, String>{};

    return TokenModel(
      name: _string(json['name']),
      symbol: _string(json['symbol']),
      balance: balanceText,
      rawBalance: rawBalance,
      priceUsd: priceUsd,
      valueUsd: valueUsd,
      changePercent: changePercent,
      chain: _string(json['chain'] ?? json['network']),
      rawNetwork: _string(json['network'] ?? json['chain']),
      contractAddress: _string(json['tokenAddress'] ?? json['contractAddress']),
      imageUrl: _string(json['logo'] ?? json['imageUrl']),
      decimals: _intOrNull(json['decimals']),
      hasMarketData: hasMarketData,
      isOfficial: json['isOfficial'] == true,
      isEcosystem: json['isEcosystem'] == true,
      isFeatured: json['isFeatured'] == true,
      alwaysDisplay: json['alwaysDisplay'] == true,
      displayOrder: _intOrNull(json['displayOrder']),
      marketDataSource: _string(json['marketDataSource']),
      externalLinks: externalLinks,
      id: json['id']?.toString(),
      type: json['type']?.toString(),
      chainId: json['chainId']?.toString(),
      marketCapUsd: _numOrNull(json['marketCapUsd'] ?? json['marketCap'] ?? json['market_cap_usd']),
      volume24hUsd: _numOrNull(json['volume24hUsd'] ?? json['volume24h'] ?? json['volume_24h_usd']),
      liquidityUsd: _numOrNull(json['liquidityUsd'] ?? json['liquidity'] ?? json['liquidity_usd']),
      priceUpdatedAt: json['priceUpdatedAt'] != null ? DateTime.tryParse(json['priceUpdatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'symbol': symbol,
      'balance': balance,
      'rawBalance': rawBalance,
      'priceUsd': priceUsd,
      'valueUsd': valueUsd,
      'changePercent': changePercent,
      'chain': chain,
      'network': rawNetwork,
      'contractAddress': contractAddress,
      'imageUrl': imageUrl,
      'decimals': decimals,
      'hasMarketData': hasMarketData,
      'isOfficial': isOfficial,
      'isEcosystem': isEcosystem,
      'isFeatured': isFeatured,
      'alwaysDisplay': alwaysDisplay,
      'displayOrder': displayOrder,
      'marketDataSource': marketDataSource,
      'externalLinks': externalLinks,
      'type': type,
      'chainId': chainId,
      'marketCapUsd': marketCapUsd,
      'volume24hUsd': volume24hUsd,
      'liquidityUsd': liquidityUsd,
      'priceUpdatedAt': priceUpdatedAt?.toIso8601String(),
    };
  }

  static String _string(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static num? _numOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }

  static int? _intOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
