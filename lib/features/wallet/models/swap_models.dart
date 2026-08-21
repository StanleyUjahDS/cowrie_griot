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

class SwapAmount {
  final String raw;
  final String formatted;
  final int decimals;

  const SwapAmount({
    required this.raw,
    required this.formatted,
    required this.decimals,
  });

  factory SwapAmount.fromJson(Map<String, dynamic> json) {
    return SwapAmount(
      raw: json['raw']?.toString() ?? '',
      formatted: json['formatted']?.toString() ?? '0.00',
      decimals: int.tryParse(json['decimals']?.toString() ?? '') ?? 18,
    );
  }
}

class SwapAmounts {
  final SwapAmount from;
  final SwapAmount to;
  final SwapAmount toMin;

  const SwapAmounts({
    required this.from,
    required this.to,
    required this.toMin,
  });

  factory SwapAmounts.fromJson(Map<String, dynamic> json) {
    return SwapAmounts(
      from: SwapAmount.fromJson(Map<String, dynamic>.from(json['from'] ?? {})),
      to: SwapAmount.fromJson(Map<String, dynamic>.from(json['to'] ?? {})),
      toMin: SwapAmount.fromJson(Map<String, dynamic>.from(json['toMin'] ?? json['to_min'] ?? {})),
    );
  }
}

class SwapSlippage {
  final String mode;
  final double? requested;
  final double? recommended;
  final double? maximumRecommended;
  final double? auto;

  const SwapSlippage({
    required this.mode,
    this.requested,
    this.recommended,
    this.maximumRecommended,
    this.auto,
  });

  factory SwapSlippage.fromJson(Map<String, dynamic> json) {
    return SwapSlippage(
      mode: json['mode']?.toString() ?? 'auto',
      requested: double.tryParse(json['requested']?.toString() ?? ''),
      recommended: double.tryParse(json['recommended']?.toString() ?? ''),
      maximumRecommended: double.tryParse(json['maximumRecommended'] ?? json['maximum_recommended']?.toString() ?? ''),
      auto: double.tryParse(json['auto']?.toString() ?? ''),
    );
  }
}

class SwapTokenTax {
  final bool detected;
  final int buyTaxBps;
  final int sellTaxBps;
  final double buyTaxPercent;
  final double sellTaxPercent;
  final String? source;

  const SwapTokenTax({
    required this.detected,
    required this.buyTaxBps,
    required this.sellTaxBps,
    required this.buyTaxPercent,
    required this.sellTaxPercent,
    this.source,
  });

  factory SwapTokenTax.fromJson(Map<String, dynamic> json) {
    return SwapTokenTax(
      detected: json['detected'] == true,
      buyTaxBps: int.tryParse(json['buyTaxBps'] ?? json['buy_tax_bps']?.toString() ?? '') ?? 0,
      sellTaxBps: int.tryParse(json['sellTaxBps'] ?? json['sell_tax_bps']?.toString() ?? '') ?? 0,
      buyTaxPercent: double.tryParse(json['buyTaxPercent'] ?? json['buy_tax_percent']?.toString() ?? '') ?? 0.0,
      sellTaxPercent: double.tryParse(json['sellTaxPercent'] ?? json['sell_tax_percent']?.toString() ?? '') ?? 0.0,
      source: json['source']?.toString(),
    );
  }
}

class SwapRisk {
  final double? priceImpact;
  final SwapTokenTax? tokenTaxes;
  final SwapSlippage? slippage;
  final List<String> warnings;

  const SwapRisk({
    this.priceImpact,
    this.tokenTaxes,
    this.slippage,
    required this.warnings,
  });

  factory SwapRisk.fromJson(Map<String, dynamic> json) {
    return SwapRisk(
      priceImpact: double.tryParse(json['priceImpact'] ?? json['price_impact']?.toString() ?? ''),
      tokenTaxes: json['tokenTaxes'] != null || json['token_taxes'] != null
          ? SwapTokenTax.fromJson(Map<String, dynamic>.from(json['tokenTaxes'] ?? json['token_taxes']))
          : null,
      slippage: json['slippage'] != null
          ? SwapSlippage.fromJson(Map<String, dynamic>.from(json['slippage']))
          : null,
      warnings: (json['warnings'] as List?)?.map((e) => e.toString()).toList() ?? [],
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
  final String toAmount;
  final String toAmountMin;
  final Map<String, SwapTokenMetadata> tokenMetadata;
  final SwapAmounts amounts;
  final Map<String, dynamic> transactionRequest;
  final SwapRisk? risk;

  const SwapQuote({
    required this.provider,
    required this.type,
    required this.fromChain,
    required this.toChain,
    required this.fromToken,
    required this.toToken,
    required this.fromAmount,
    required this.toAmount,
    required this.toAmountMin,
    required this.tokenMetadata,
    required this.amounts,
    required this.transactionRequest,
    this.risk,
  });

  factory SwapQuote.fromJson(Map<String, dynamic> json) {
    final metadataJson = Map<String, dynamic>.from(json['tokenMetadata'] ?? json['token_metadata'] ?? {});
    final metadata = <String, SwapTokenMetadata>{};
    metadataJson.forEach((key, val) {
      metadata[key] = SwapTokenMetadata.fromJson(Map<String, dynamic>.from(val ?? {}));
    });

    return SwapQuote(
      provider: json['provider']?.toString() ?? '',
      type: json['type']?.toString() ?? 'same-chain',
      fromChain: json['fromChain'] ?? json['from_chain']?.toString() ?? '',
      toChain: json['toChain'] ?? json['to_chain']?.toString() ?? '',
      fromToken: json['fromToken'] ?? json['from_token']?.toString() ?? '',
      toToken: json['toToken'] ?? json['to_token']?.toString() ?? '',
      fromAmount: json['fromAmount'] ?? json['from_amount']?.toString() ?? '0',
      toAmount: json['toAmount'] ?? json['to_amount']?.toString() ?? '0',
      toAmountMin: json['toAmountMin'] ?? json['to_amount_min']?.toString() ?? '0',
      tokenMetadata: metadata,
      amounts: SwapAmounts.fromJson(Map<String, dynamic>.from(json['amounts'] ?? {})),
      transactionRequest: Map<String, dynamic>.from(json['transactionRequest'] ?? json['transaction_request'] ?? {}),
      risk: json['risk'] != null ? SwapRisk.fromJson(Map<String, dynamic>.from(json['risk'])) : null,
    );
  }
}
