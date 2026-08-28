import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/mining_api_service.dart';

class MiningStatus {
  final String dayId;
  final DateTime dayStart;
  final DateTime dayEnd;
  final double rewardPool;
  final String currency;
  final bool canMine;
  final DateTime? nextAvailableAt;
  final double pointsToday;
  final double totalPointsToday;
  final double currentSharePercent;
  final double estimatedReward;
  final double todayFinalReward;
  final double lifetimeEarned;
  final double availableBalance;
  final double pendingBalance;
  final bool settled;
  final MiningMultiplier multiplier;
  final MiningReputation? reputation;

  MiningStatus({
    required this.dayId,
    required this.dayStart,
    required this.dayEnd,
    required this.rewardPool,
    required this.currency,
    required this.canMine,
    this.nextAvailableAt,
    required this.pointsToday,
    required this.totalPointsToday,
    required this.currentSharePercent,
    required this.estimatedReward,
    required this.todayFinalReward,
    required this.lifetimeEarned,
    required this.availableBalance,
    required this.pendingBalance,
    required this.settled,
    required this.multiplier,
    this.reputation,
  });

  factory MiningStatus.fromJson(Map<String, dynamic> json) {
    return MiningStatus(
      dayId: json['dayId'] ?? '',
      dayStart: DateTime.parse(json['dayStart'] ?? DateTime.now().toIso8601String()),
      dayEnd: DateTime.parse(json['dayEnd'] ?? DateTime.now().toIso8601String()),
      rewardPool: (json['rewardPool'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'COWRIE',
      canMine: json['canMine'] ?? false,
      nextAvailableAt: json['nextAvailableAt'] != null ? DateTime.parse(json['nextAvailableAt']) : null,
      pointsToday: (json['pointsToday'] ?? 0).toDouble(),
      totalPointsToday: (json['totalPointsToday'] ?? 0).toDouble(),
      currentSharePercent: (json['currentSharePercent'] ?? 0).toDouble(),
      estimatedReward: (json['estimatedReward'] ?? 0).toDouble(),
      todayFinalReward: (json['todayFinalReward'] ?? 0).toDouble(),
      lifetimeEarned: (json['lifetimeEarned'] ?? json['totalEarned'] ?? 0).toDouble(),
      availableBalance: (json['availableBalance'] ?? 0).toDouble(),
      pendingBalance: (json['pendingBalance'] ?? 0).toDouble(),
      settled: json['settled'] ?? false,
      multiplier: MiningMultiplier.fromJson(json['multiplier'] ?? {}),
      reputation: json['reputation'] != null ? MiningReputation.fromJson(json['reputation']) : null,
    );
  }
}

class MiningMultiplier {
  final double base;
  final double plusBonus;
  final double referralBonus;
  final double reputationBonus;
  final double total;
  final double maximum;
  final String membershipStatus;
  final int validReferralCount;

  MiningMultiplier({
    required this.base,
    required this.plusBonus,
    required this.referralBonus,
    required this.reputationBonus,
    required this.total,
    required this.maximum,
    required this.membershipStatus,
    required this.validReferralCount,
  });

  factory MiningMultiplier.fromJson(Map<String, dynamic> json) {
    return MiningMultiplier(
      base: (json['base'] ?? 1.0).toDouble(),
      plusBonus: (json['plusBonus'] ?? 0.0).toDouble(),
      referralBonus: (json['referralBonus'] ?? 0.0).toDouble(),
      reputationBonus: (json['reputationBonus'] ?? 0.0).toDouble(),
      total: (json['total'] ?? 1.0).toDouble(),
      maximum: (json['maximum'] ?? 2.0).toDouble(),
      membershipStatus: json['membershipStatus'] ?? 'basic',
      validReferralCount: json['validReferralCount'] ?? 0,
    );
  }
}

class MiningReputation {
  final String tier;
  final int points;
  final double bonus;
  final String badgeColor;

  MiningReputation({
    required this.tier,
    required this.points,
    required this.bonus,
    required this.badgeColor,
  });

  factory MiningReputation.fromJson(Map<String, dynamic> json) {
    return MiningReputation(
      tier: json['tier'] ?? 'Initiate Badger',
      points: json['points'] ?? 0,
      bonus: (json['bonus'] ?? 0.0).toDouble(),
      badgeColor: json['badgeColor'] ?? '#64748B',
    );
  }
}

class MiningProvider extends ChangeNotifier {
  final MiningApiService _apiService;

  MiningProvider({required MiningApiService apiService}) : _apiService = apiService;

  MiningStatus? _status;
  bool _isLoading = false;
  String? _error;
  Timer? _refreshTimer;

  MiningStatus? get status => _status;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadStatus() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.getMiningStatus();
      _status = MiningStatus.fromJson(data);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> startMining() async {
    try {
      await _apiService.startMining();
      await loadStatus();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => loadStatus());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
