class ReputationTier {
  final String name;
  final int minPoints;
  final int? maxPoints;
  final String badgeColor;

  ReputationTier({
    required this.name,
    required this.minPoints,
    this.maxPoints,
    required this.badgeColor,
  });

  factory ReputationTier.fromJson(Map<String, dynamic> json) {
    return ReputationTier(
      name: (json['name'] ?? json['tierName'] ?? json['tier_name'])?.toString() ?? '',
      minPoints: int.tryParse((json['minPoints'] ?? json['min_points'] ?? '0').toString()) ?? 0,
      maxPoints: (json['maxPoints'] ?? json['max_points']) == null
          ? null
          : int.tryParse((json['maxPoints'] ?? json['max_points']).toString()),
      badgeColor: (json['badgeColor'] ?? json['badge_color'] ?? json['color'])?.toString() ?? '#64748B',
    );
  }
}

class ReputationData {
  final int points;
  final ReputationTier tier;
  final ReputationTier? nextTier;

  ReputationData({
    required this.points,
    required this.tier,
    this.nextTier,
  });

  factory ReputationData.fromJson(Map<String, dynamic> json) {
    return ReputationData(
      points: int.tryParse(json['points']?.toString() ?? '0') ?? 0,
      tier: ReputationTier.fromJson(Map<String, dynamic>.from(json['tier'] ?? {})),
      nextTier: json['nextTier'] == null
          ? null
          : ReputationTier.fromJson(Map<String, dynamic>.from(json['nextTier'])),
    );
  }

  double get progress {
    final next = nextTier;
    if (next == null) return 1.0;

    final range = next.minPoints - tier.minPoints;
    if (range <= 0) return 1.0;

    return ((points - tier.minPoints) / range).clamp(0.0, 1.0);
  }
}
