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
      json['walletAddress']?.toString() ?? '',
      nonce:
      json['nonce']?.toString() ?? '',
      message:
      json['message']?.toString() ?? '',
      expiresAt:
      DateTime.parse(
        json['expiresAt'].toString(),
      ),
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