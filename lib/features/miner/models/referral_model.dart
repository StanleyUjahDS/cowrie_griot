class ReferralData {
  final String referralCode;
  final int totalReferrals;
  final String? referredBy;

  ReferralData({
    required this.referralCode,
    required this.totalReferrals,
    this.referredBy,
  });

  factory ReferralData.fromJson(Map<String, dynamic> json) {
    return ReferralData(
      referralCode: json['referralCode']?.toString() ?? '',
      totalReferrals: int.tryParse(json['totalReferrals']?.toString() ?? '0') ?? 0,
      referredBy: json['referredBy']?.toString(),
    );
  }
}
