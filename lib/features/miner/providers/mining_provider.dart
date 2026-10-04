import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_exception.dart';
import '../services/mining_api_service.dart';

double _parseDouble(dynamic v, [double defaultValue = 0.0]) {
  if (v == null) return defaultValue;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? defaultValue;
  return defaultValue;
}

double? _parseOptionalDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int _parseInt(dynamic v, [int defaultValue = 0]) {
  if (v == null) return defaultValue;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? defaultValue;
  return defaultValue;
}

bool _parseBool(dynamic v, [bool defaultValue = false]) {
  if (v == null) return defaultValue;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() == 'true' || v == '1';
  return defaultValue;
}

DateTime? _parseDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}

class MiningStatus {
  final String dayId;
  final DateTime dayStart;
  final DateTime dayEnd;
  final double? rewardPool;
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
    if (json.isEmpty) {
      throw const FormatException('Mining status response was empty');
    }
    final dayStart = _parseDateTime(json['dayStart'] ?? json['day_start']);
    final dayEnd = _parseDateTime(json['dayEnd'] ?? json['day_end']);
    return MiningStatus(
      dayId: (json['dayId'] ?? json['day_id'])?.toString() ?? 'today',
      dayStart:
          dayStart ?? (throw const FormatException('Mining day start missing')),
      dayEnd: dayEnd ?? (throw const FormatException('Mining day end missing')),
      rewardPool: _parseOptionalDouble(
        json['rewardPool'] ?? json['reward_pool'] ?? json['pool'],
      ),
      currency: (json['currency'])?.toString() ?? 'COWRIE',
      canMine: _parseBool(json['canMine'] ?? json['can_mine'], true),
      nextAvailableAt: _parseDateTime(
        json['nextAvailableAt'] ?? json['next_available_at'],
      ),
      pointsToday: _parseDouble(json['pointsToday'] ?? json['points_today']),
      totalPointsToday: _parseDouble(
        json['totalPointsToday'] ?? json['total_points_today'],
      ),
      currentSharePercent: _parseDouble(
        json['currentSharePercent'] ??
            json['current_share_percent'] ??
            json['share_percent'],
      ),
      estimatedReward: _parseDouble(
        json['estimatedReward'] ?? json['estimated_reward'],
      ),
      todayFinalReward: _parseDouble(
        json['todayFinalReward'] ??
            json['today_final_reward'] ??
            json['final_reward'],
      ),
      lifetimeEarned: _parseDouble(
        json['lifetimeEarned'] ??
            json['totalEarned'] ??
            json['lifetime_earned'] ??
            json['total_earned'],
      ),
      availableBalance: _parseDouble(
        json['availableBalance'] ??
            json['available_balance'] ??
            json['balance'],
      ),
      pendingBalance: _parseDouble(
        json['pendingBalance'] ?? json['pending_balance'],
      ),
      settled: _parseBool(json['settled']),
      multiplier: MiningMultiplier.fromJson(
        json['multiplier'] is Map
            ? Map<String, dynamic>.from(json['multiplier'])
            : {},
      ),
      reputation: json['reputation'] is Map
          ? MiningReputation.fromJson(
              Map<String, dynamic>.from(json['reputation']),
            )
          : MiningReputation(
              tier: 'Initiate Badger',
              points: 0,
              bonus: 0.0,
              badgeColor: '#64748B',
            ),
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
      base: _parseDouble(json['base'], 1.0),
      plusBonus: _parseDouble(json['plusBonus'] ?? json['plus_bonus']),
      referralBonus: _parseDouble(
        json['referralBonus'] ?? json['referral_bonus'],
      ),
      reputationBonus: _parseDouble(
        json['reputationBonus'] ?? json['reputation_bonus'],
      ),
      total: _parseDouble(json['total'], 1.0),
      maximum: _parseDouble(json['maximum'] ?? json['max'], 2.0),
      membershipStatus:
          (json['membershipStatus'] ?? json['membership_status'])?.toString() ??
          'basic',
      validReferralCount: _parseInt(
        json['validReferralCount'] ??
            json['valid_referral_count'] ??
            json['referrals'],
      ),
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
      tier:
          (json['tier'] ?? json['tierName'] ?? json['tier_name'])?.toString() ??
          'Initiate Badger',
      points: _parseInt(json['points']),
      bonus: _parseDouble(json['bonus']),
      badgeColor:
          (json['badgeColor'] ?? json['badge_color'] ?? json['color'])
              ?.toString() ??
          '#64748B',
    );
  }
}

class MiningProvider extends ChangeNotifier {
  final MiningApiService _apiService;

  MiningProvider({required MiningApiService apiService})
    : _apiService = apiService;

  MiningStatus? _status;
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = false;
  bool _isLoadingActivities = false;
  Future<void>? _activitiesLoadFuture;
  String? _error;
  Timer? _refreshTimer;
  DateTime? _lastLoadedAt;
  Future<void>? _loadFuture;

  MiningStatus? get status => _status;
  List<Map<String, dynamic>> get activities => _activities;
  bool get isLoading => _isLoading;
  bool get isLoadingActivities => _isLoadingActivities;
  String? get error => _error;

  Future<void> loadStatus({bool force = false}) async {
    if (!force &&
        _status != null &&
        _lastLoadedAt != null &&
        DateTime.now().difference(_lastLoadedAt!) <
            const Duration(minutes: 1)) {
      return;
    }
    if (_loadFuture != null) return _loadFuture!;
    _loadFuture = _loadStatus();
    try {
      await _loadFuture;
    } finally {
      _loadFuture = null;
    }
  }

  Future<void> _loadStatus() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // The status endpoint is the core screen data. Activities are
      // supplementary and may be unavailable on older backend revisions;
      // do not hide the whole Miner screen when that optional request fails.
      final statusData = await _apiService.getMiningStatus().timeout(
        const Duration(seconds: 15),
      );
      _status = MiningStatus.fromJson(statusData);
      try {
        _activities = await _apiService.getMiningActivities().timeout(
          const Duration(seconds: 10),
        );
      } catch (e) {
        _activities = [];
        debugPrint('Mining activities unavailable: $e');
      }

      _lastLoadedAt = DateTime.now();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e is ApiException ? e.message : e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadActivities() async {
    if (_activitiesLoadFuture != null) return _activitiesLoadFuture!;
    _activitiesLoadFuture = _loadActivities();
    try {
      await _activitiesLoadFuture!;
    } finally {
      _activitiesLoadFuture = null;
    }
  }

  Future<void> _loadActivities() async {
    if (_activities.isNotEmpty) return;
    _isLoadingActivities = true;
    notifyListeners();
    try {
      _activities = await _apiService.getMiningActivities();
    } catch (e) {
      debugPrint('Error loading mining activities: $e');
    } finally {
      _isLoadingActivities = false;
      notifyListeners();
    }
  }

  Future<bool> startMining() async {
    try {
      final res = await _apiService.startMining();
      if (res.isNotEmpty) {
        try {
          _status = MiningStatus.fromJson(res);
        } catch (_) {}
      }
      await loadStatus(force: true);
      return true;
    } catch (e) {
      _error = e is ApiException ? e.message : e.toString();
      notifyListeners();
      // Do not synthesize mining points or balances when the backend rejects
      // or cannot process the request. The backend is the source of truth.
      return false;
    }
  }

  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => loadStatus(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void reset() {
    _status = null;
    _isLoading = false;
    _error = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _lastLoadedAt = null;
    _loadFuture = null;
    notifyListeners();
  }
}
