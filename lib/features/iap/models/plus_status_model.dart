
enum PlusSubscriptionStatus {
  none,
  pending,
  active,
  paused,
  cancelled,
  expired,
  refunded;

  static PlusSubscriptionStatus fromString(String? value) {
    if (value == null) return PlusSubscriptionStatus.none;
    return PlusSubscriptionStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => PlusSubscriptionStatus.none,
    );
  }
}

class PlusStatus {
  final bool isPlus;
  final PlusSubscriptionStatus status;
  final String? provider;
  final String? productId;
  final DateTime? startedAt;
  final DateTime? expiresAt;

  PlusStatus({
    required this.isPlus,
    required this.status,
    this.provider,
    this.productId,
    this.startedAt,
    this.expiresAt,
  });

  factory PlusStatus.fromJson(Map<String, dynamic> json) {
    return PlusStatus(
      isPlus: json['isPlus'] ?? false,
      status: PlusSubscriptionStatus.fromString(json['status']),
      provider: json['provider'],
      productId: json['productId'],
      startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt']) : null,
      expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
    );
  }

  factory PlusStatus.none() => PlusStatus(
    isPlus: false,
    status: PlusSubscriptionStatus.none,
  );

  @override
  String toString() {
    return 'PlusStatus(isPlus: $isPlus, status: $status, productId: $productId, expiresAt: $expiresAt)';
  }
}
