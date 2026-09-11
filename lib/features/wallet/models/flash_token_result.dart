import 'token_model.dart';

class FlashTokenResult {
  final String addressType;
  final TokenModel? token;
  final TokenSecurity? security;
  final TradingAvailability trading;
  final List<String> sources;
  final DateTime retrievedAt;

  FlashTokenResult({
    required this.addressType,
    this.token,
    this.security,
    required this.trading,
    this.sources = const [],
    required this.retrievedAt,
  });

  factory FlashTokenResult.fromJson(Map<String, dynamic> json) {
    return FlashTokenResult(
      addressType: json['addressType']?.toString() ?? 'unknown',
      token: json['token'] != null ? TokenModel.fromJson(Map<String, dynamic>.from(json['token'])) : null,
      security: json['security'] != null ? TokenSecurity.fromJson(Map<String, dynamic>.from(json['security'])) : null,
      trading: TradingAvailability.fromJson(Map<String, dynamic>.from(json['trading'] ?? {})),
      sources: (json['sources'] as List?)?.map((e) => e.toString()).toList() ?? [],
      retrievedAt: json['retrievedAt'] != null
          ? DateTime.tryParse(json['retrievedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class TokenSecurity {
  final String status;
  final bool isTradeable;
  final bool isSpam;
  final num buyTaxPercent;
  final num sellTaxPercent;

  TokenSecurity({
    required this.status,
    required this.isTradeable,
    required this.isSpam,
    required this.buyTaxPercent,
    required this.sellTaxPercent,
  });

  factory TokenSecurity.fromJson(Map<String, dynamic> json) {
    num parseNumber(dynamic value) {
      if (value is num) return value;
      return num.tryParse(value?.toString() ?? '') ?? 0;
    }
    return TokenSecurity(
      status: json['status']?.toString() ?? 'unknown',
      isTradeable: json['isTradeable'] == true,
      isSpam: json['isSpam'] == true,
      buyTaxPercent: parseNumber(json['buyTaxPercent']),
      sellTaxPercent: parseNumber(json['sellTaxPercent']),
    );
  }
}

class TradingAvailability {
  final bool canBuy;
  final bool canSell;
  final String? reason;

  TradingAvailability({
    required this.canBuy,
    required this.canSell,
    this.reason,
  });

  factory TradingAvailability.fromJson(Map<String, dynamic> json) {
    return TradingAvailability(
      canBuy: json['canBuy'] == true,
      canSell: json['canSell'] == true,
      reason: json['reason']?.toString(),
    );
  }
}
