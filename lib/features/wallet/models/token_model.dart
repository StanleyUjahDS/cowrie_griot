import '../utils/chain_assets.dart';

class TokenModel {
  final String name;
  final String symbol;
  final num balance;
  final num priceUsd;
  final num valueUsd;
  final num changePercent;
  final String chain;
  final String contractAddress;
  final String imageUrl;
  final int decimals;
  final bool hasMarketData;
  final bool isSpam;
  final bool isOfficial;
  final bool isTradeable;
  final bool isEcosystem;
  final String status;
  final List<String> reasons;
  final Map<String, String> externalLinks;
  final Map<String, dynamic>? security;

  const TokenModel({
    required this.name,
    required this.symbol,
    required this.balance,
    this.priceUsd = 0,
    required this.valueUsd,
    required this.changePercent,
    required this.chain,
    required this.contractAddress,
    required this.imageUrl,
    this.decimals = 18,
    this.hasMarketData = false,
    this.isSpam = false,
    this.isOfficial = false,
    this.isTradeable = false,
    this.isEcosystem = false,
    this.status = 'unknown',
    this.reasons = const [],
    this.externalLinks = const {},
    this.security,
  });

  String get identity {
    final net = ChainAssets.normalize(chain);
    if (isNative) return '$net:native';
    return '$net:${contractAddress.toLowerCase().trim()}';
  }

  bool get isNative {
    final address = contractAddress.trim().toLowerCase();
    return address.isEmpty ||
        address == '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee' ||
        address == '0x0000000000000000000000000000000000000000';
  }

  bool get isProfit => changePercent >= 0;

  bool get isGriotAsset => isEcosystem;

  double get value => valueUsd.toDouble();

  factory TokenModel.fromJson(Map<String, dynamic> json) {
    final hasPrice =
        json['priceUsd'] != null || json['price'] != null;
    final hasChange =
        json['changePercent24h'] != null ||
        json['changePercent'] != null ||
        json['priceChangePercent'] != null;

    final securityData = json['security'] is Map ? Map<String, dynamic>.from(json['security']) : null;
    final classification = json['classification'] is Map
        ? Map<String, dynamic>.from(json['classification'])
        : null;

    String status;
    bool isTradeable;
    bool isSpam;

    if (classification != null) {
      // Direct authoritative mapping from backend
      status = _string(classification['status'] ?? 'unknown');
      isTradeable = classification['isTradeable'] == true;
      isSpam = classification['isSpam'] == true;
    } else {
      // Safe fallback for missing classification
      status = 'unknown';
      isTradeable = false;
      isSpam = json['isSpam'] == true;
    }
    
    final reasonsRaw = classification?['reasons'] ?? securityData?['reasons'];
    final reasons = reasonsRaw is List ? reasonsRaw.map((e) => e.toString()).toList() : <String>[];

    final linksRaw = json['externalLinks'];
    final externalLinks = linksRaw is Map 
        ? Map<String, String>.from(linksRaw.map((k, v) => MapEntry(k.toString(), v.toString())))
        : <String, String>{};

    return TokenModel(
      name: _string(json['name']),
      symbol: _string(json['symbol']),
      balance: _num(json['balance']),
      priceUsd: _num(json['priceUsd'] ?? json['price']),
      valueUsd: _num(
        json['usdValue'] ??
            json['valueUsd'] ??
            json['balanceUsd'],
      ),
      changePercent: _num(
        json['changePercent24h'] ??
            json['changePercent'] ??
            json['priceChangePercent'],
      ),
      chain: _string(json['chain'] ?? json['network']),
      contractAddress: _string(
        json['tokenAddress'] ??
            json['contractAddress'],
      ),
      imageUrl: _string(
        json['logo'] ??
            json['imageUrl'] ??
            json['logoUrl'],
      ),
      decimals: _int(json['decimals'], fallback: 18),
      hasMarketData: hasPrice || hasChange || (json['usdValue'] != null || json['valueUsd'] != null),
      isSpam: isSpam,
      isOfficial: json['isOfficial'] == true,
      isTradeable: isTradeable,
      isEcosystem: json['isEcosystem'] == true,
      status: status,
      reasons: reasons,
      externalLinks: externalLinks,
      security: securityData,
    );
  }

  static String _string(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static num _num(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    return num.tryParse(value.toString()) ?? 0;
  }

  static int _int(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
