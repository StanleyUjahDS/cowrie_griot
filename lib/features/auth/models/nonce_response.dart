class NonceResponse {
  final String walletAddress;
  final String nonce;
  final String message;
  final DateTime expiresAt;

  const NonceResponse({
    required this.walletAddress,
    required this.nonce,
    required this.message,
    required this.expiresAt,
  });

  factory NonceResponse.fromJson(
      Map<String, dynamic> json,
      ) {
    return NonceResponse(
      walletAddress:
      (json['walletAddress'] ?? json['wallet_address'])?.toString() ?? '',
      nonce:
      json['nonce']?.toString() ?? '',
      message:
      json['message']?.toString() ?? '',
      expiresAt:
      DateTime.tryParse(
        (json['expiresAt'] ?? json['expires_at'])?.toString() ?? '',
      ) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'walletAddress': walletAddress,
      'nonce': nonce,
      'message': message,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }
}