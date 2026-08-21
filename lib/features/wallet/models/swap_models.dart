class SwapTokenMetadata {
  final String? address;
  final String network;
  final int decimals;
  final bool isNative;

  const SwapTokenMetadata({
    this.address,
    required this.network,
    required this.decimals,
    required this.isNative,
  });

  factory SwapTokenMetadata.fromJson(Map<String, dynamic> json) {
    return SwapTokenMetadata(
      address: json['address']?.toString(),
      network: json['network']?.toString() ?? '',
      decimals: int.tryParse(json['decimals']?.toString() ?? '') ?? 18,
      isNative: json['isNative'] == true || json['is_native'] == true,
    );
  }
}

class SwapSlippage {
  final String mode;
  final double? requested;
  final double? recommended;
  final double? maximumRecommended;
  final bool auto;
  final String? reason;

  const SwapSlippage({
    required this.mode,
    this.requested,
    this.recommended,
    this.maximumRecommended,
    this.auto = false,
    this.reason,
  });

  factory SwapSlippage.fromJson(Map<String, dynamic> json) {
    return SwapSlippage(
      mode: json['mode']?.toString() ?? 'auto',
      requested: double.tryParse(json['requested']?.toString() ?? ''),
      recommended: double.tryParse(json['recommended']?.toString() ?? ''),
      maximumRecommended: double.tryParse(
        json['maximumRecommended']?.toString() ??
            json['maximum_recommended']?.toString() ??
            '',
      ),
      auto: json['auto'] == true,
      reason: json['reason']?.toString(),
    );
  }
}

class SwapTokenTax {
  final bool detected;
  final int? buyTaxBps;
  final int? sellTaxBps;
  final double? buyTaxPercent;
  final double? sellTaxPercent;
  final String? source;

  const SwapTokenTax({
    required this.detected,
    this.buyTaxBps,
    this.sellTaxBps,
    this.buyTaxPercent,
    this.sellTaxPercent,
    this.source,
  });

  factory SwapTokenTax.fromJson(Map<String, dynamic> json) {
    return SwapTokenTax(
      detected: json['detected'] == true,
      buyTaxBps: _nullableInt(json['buyTaxBps'] ?? json['buy_tax_bps']),
      sellTaxBps: _nullableInt(json['sellTaxBps'] ?? json['sell_tax_bps']),
      buyTaxPercent: _nullableDouble(
        json['buyTaxPercent'] ?? json['buy_tax_percent'],
      ),
      sellTaxPercent: _nullableDouble(
        json['sellTaxPercent'] ?? json['sell_tax_percent'],
      ),
      source: json['source']?.toString(),
    );
  }
}

class SwapRisk {
  final double? priceImpact;
  final String? priceImpactSource;
  final SwapTokenTax? tokenTaxes;
  final SwapSlippage? slippage;
  final List<String> warnings;

  const SwapRisk({
    this.priceImpact,
    this.priceImpactSource,
    this.tokenTaxes,
    this.slippage,
    required this.warnings,
  });

  factory SwapRisk.fromJson(Map<String, dynamic> json) {
    final taxJson = json['tokenTaxes'] ?? json['token_taxes'];
    final slippageJson = json['slippage'];

    return SwapRisk(
      priceImpact: _nullableDouble(
        json['priceImpact'] ?? json['price_impact'],
      ),
      priceImpactSource: json['priceImpactSource']?.toString() ??
          json['price_impact_source']?.toString(),
      tokenTaxes: taxJson is Map
          ? SwapTokenTax.fromJson(Map<String, dynamic>.from(taxJson))
          : null,
      slippage: slippageJson is Map
          ? SwapSlippage.fromJson(Map<String, dynamic>.from(slippageJson))
          : null,
      warnings: (json['warnings'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class SwapTransactionRequest {
  final String? from;
  final String? to;
  final String? data;
  final String value;
  final String? gas;
  final String? gasLimit;
  final String? gasPrice;
  final int? chainId;

  const SwapTransactionRequest({
    this.from,
    this.to,
    this.data,
    required this.value,
    this.gas,
    this.gasLimit,
    this.gasPrice,
    this.chainId,
  });

  factory SwapTransactionRequest.fromJson(Map<String, dynamic> json) {
    return SwapTransactionRequest(
      from: json['from']?.toString(),
      to: json['to']?.toString(),
      data: json['data']?.toString(),
      value: json['value']?.toString() ?? '0',
      gas: json['gas']?.toString(),
      gasLimit: json['gasLimit']?.toString() ?? json['gas_limit']?.toString(),
      gasPrice: json['gasPrice']?.toString() ?? json['gas_price']?.toString(),
      chainId: int.tryParse(json['chainId']?.toString() ?? ''),
    );
  }
}

class SwapStatusLookup {
  final String provider;
  final String type;
  final String transactionIdField;
  final String? quoteIdField;

  const SwapStatusLookup({
    required this.provider,
    required this.type,
    required this.transactionIdField,
    this.quoteIdField,
  });

  factory SwapStatusLookup.fromJson(Map<String, dynamic> json) {
    return SwapStatusLookup(
      provider: json['provider']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      transactionIdField: json['transactionIdField']?.toString() ??
          json['transaction_id_field']?.toString() ??
          'transactionId',
      quoteIdField: json['quoteIdField']?.toString() ??
          json['quote_id_field']?.toString(),
    );
  }
}

class SwapQuote {
  final String provider;
  final String type;
  final String fromChain;
  final String toChain;
  final String fromToken;
  final String toToken;
  final String fromAmount;
  final String? toAmount;
  final String? toAmountMin;
  final String? approvalAddress;
  final String? transactionId;
  final String? quoteId;
  final String? bridge;
  final SwapTransactionRequest? transactionRequest;
  final SwapStatusLookup? statusLookup;
  final SwapRisk? risk;
  final Map<String, dynamic>? fee;
  final List<dynamic>? gasCosts;
  final List<dynamic>? feeCosts;
  final List<dynamic>? route;
  final dynamic gas;
  final dynamic gasPrice;
  final dynamic fees;

  const SwapQuote({
    required this.provider,
    required this.type,
    required this.fromChain,
    required this.toChain,
    required this.fromToken,
    required this.toToken,
    required this.fromAmount,
    this.toAmount,
    this.toAmountMin,
    this.approvalAddress,
    this.transactionId,
    this.quoteId,
    this.bridge,
    this.transactionRequest,
    this.statusLookup,
    this.risk,
    this.fee,
    this.gasCosts,
    this.feeCosts,
    this.route,
    this.gas,
    this.gasPrice,
    this.fees,
  });

  factory SwapQuote.fromJson(Map<String, dynamic> json) {
    final txJson = json['transactionRequest'] ?? json['transaction_request'];
    final statusJson = json['statusLookup'] ?? json['status_lookup'];

    return SwapQuote(
      provider: json['provider']?.toString() ?? '',
      type: json['type']?.toString() ?? 'same-chain',
      fromChain: (json['fromChain'] ?? json['from_chain'])?.toString() ?? '',
      toChain: (json['toChain'] ?? json['to_chain'])?.toString() ?? '',
      fromToken: (json['fromToken'] ?? json['from_token'])?.toString() ?? '',
      toToken: (json['toToken'] ?? json['to_token'])?.toString() ?? '',
      fromAmount: (json['fromAmount'] ?? json['from_amount'])?.toString() ?? '0',
      toAmount: (json['toAmount'] ?? json['to_amount'])?.toString(),
      toAmountMin:
          (json['toAmountMin'] ?? json['to_amount_min'])?.toString(),
      approvalAddress:
          (json['approvalAddress'] ?? json['approval_address'])?.toString(),
      transactionId: json['transactionId']?.toString(),
      quoteId: json['quoteId']?.toString(),
      bridge: json['bridge']?.toString(),
      transactionRequest: txJson is Map
          ? SwapTransactionRequest.fromJson(Map<String, dynamic>.from(txJson))
          : null,
      statusLookup: statusJson is Map
          ? SwapStatusLookup.fromJson(Map<String, dynamic>.from(statusJson))
          : null,
      risk: json['risk'] is Map
          ? SwapRisk.fromJson(Map<String, dynamic>.from(json['risk']))
          : null,
      fee: json['fee'] is Map
          ? Map<String, dynamic>.from(json['fee'])
          : null,
      gasCosts: json['gasCosts'] is List ? List<dynamic>.from(json['gasCosts']) : null,
      feeCosts: json['feeCosts'] is List ? List<dynamic>.from(json['feeCosts']) : null,
      route: json['route'] is List ? List<dynamic>.from(json['route']) : null,
      gas: json['gas'],
      gasPrice: json['gasPrice'],
      fees: json['fees'],
    );
  }
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  return int.tryParse(value.toString());
}

double? _nullableDouble(dynamic value) {
  if (value == null) return null;
  return double.tryParse(value.toString());
}
