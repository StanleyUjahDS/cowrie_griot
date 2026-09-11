enum TipStatus {
  preparing,
  networkSwitchRequired,
  awaitingApproval,
  signing,
  broadcasting,
  pending,
  confirmed,
  failed,
  cancelled,
  unknown
}

class TipEvent {
  final String? transactionHash;
  final String network;
  final int chainId;
  final String assetType; // 'native' or 'token'
  final String? tokenAddress;
  final String senderAddress;
  final List<String> recipientAddresses;
  final String amountRaw;
  final bool isBatch;
  final TipStatus status;
  final String? transactionId;
  final DateTime timestamp;

  TipEvent({
    this.transactionHash,
    required this.network,
    required this.chainId,
    required this.assetType,
    this.tokenAddress,
    required this.senderAddress,
    required this.recipientAddresses,
    required this.amountRaw,
    this.isBatch = false,
    this.status = TipStatus.pending,
    this.transactionId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'transactionHash': transactionHash,
      'network': network,
      'chainId': chainId,
      'assetType': assetType,
      'tokenAddress': tokenAddress,
      'senderAddress': senderAddress,
      'recipientAddresses': recipientAddresses,
      'amountRaw': amountRaw,
      'isBatch': isBatch,
      'status': status.name,
      'transactionId': transactionId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory TipEvent.fromJson(Map<String, dynamic> json) {
    return TipEvent(
      transactionHash: json['transactionHash']?.toString(),
      network: json['network']?.toString() ?? '',
      chainId: int.parse(json['chainId']?.toString() ?? '0'),
      assetType: json['assetType']?.toString() ?? 'native',
      tokenAddress: json['tokenAddress']?.toString(),
      senderAddress: json['senderAddress']?.toString() ?? '',
      recipientAddresses: (json['recipientAddresses'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      amountRaw: json['amountRaw']?.toString() ?? '0',
      isBatch: json['isBatch'] == true,
      status: TipStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TipStatus.unknown,
      ),
      transactionId: json['transactionId']?.toString(),
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
