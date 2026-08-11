class ContactMatch {
  final String userId;
  final String? username;
  final String walletAddress;
  final String? profileUrl;

  const ContactMatch({
    required this.userId,
    this.username,
    required this.walletAddress,
    this.profileUrl,
  });

  String get displayName {
    if (username != null && username!.trim().isNotEmpty) {
      return username!.trim();
    }

    if (walletAddress.length > 10) {
      return '${walletAddress.substring(0, 6)}...'
          '${walletAddress.substring(walletAddress.length - 4)}';
    }

    return walletAddress;
  }

  factory ContactMatch.fromJson(Map<String, dynamic> json) {
    return ContactMatch(
      userId: json['userId'] as String,
      username: json['username'] as String?,
      walletAddress: json['walletAddress'] as String,
      profileUrl: json['profileUrl'] as String?,
    );
  }
}