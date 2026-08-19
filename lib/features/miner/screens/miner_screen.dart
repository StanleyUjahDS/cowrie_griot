import 'dart:async';
import 'package:flutter/material.dart';

class MinerScreen extends StatefulWidget {
  const MinerScreen({
    super.key,
  });

  @override
  State<MinerScreen> createState() => _MinerScreenState();
}

class _MinerScreenState extends State<MinerScreen>
    with SingleTickerProviderStateMixin {
  static const Duration sessionDuration = Duration(hours: 2);

  bool isMining = false;
  DateTime? sessionStartedAt;
  Duration sessionElapsed = Duration.zero;

  Timer? _timer;
  Timer? _payoutTimer;

  late final AnimationController _pulseController;

  double todayPoints = 186;
  double dailyPointsAvailable = 250;

  // Points accumulated by the user during the current
  // three-month reward cycle.
  double cyclePoints = 12480;

  // Total points accumulated by everyone during the
  // current three-month cycle.
  double networkCyclePoints = 18425000;

  // Total reward pool available for the current cycle.
  double cycleRewardPool = 3750000;

  double baseMiningWeight = 1.0;
  double reputationMultiplier = 1.15;
  double plusMultiplier = 1.25;
  bool isPlusUser = true;

  Duration payoutCountdown = Duration.zero;
  DateTime nextPayoutDate = DateTime.now();

  double get totalMiningWeight {
    final plus = isPlusUser ? plusMultiplier : 1.0;

    return baseMiningWeight * reputationMultiplier * plus;
  }

  double get sessionProgress {
    if (sessionElapsed == Duration.zero) {
      return 0;
    }

    return (sessionElapsed.inSeconds / sessionDuration.inSeconds)
        .clamp(0.0, 1.0);
  }

  Duration get remainingSession {
    final remaining = sessionDuration - sessionElapsed;

    return remaining.isNegative ? Duration.zero : remaining;
  }

  double get activityProgress {
    if (dailyPointsAvailable <= 0) {
      return 0;
    }

    return (todayPoints / dailyPointsAvailable).clamp(0.0, 1.0);
  }

  double get estimatedCycleShare {
    if (networkCyclePoints <= 0) {
      return 0;
    }

    return cyclePoints / networkCyclePoints;
  }

  double get estimatedReward {
    return cycleRewardPool * estimatedCycleShare;
  }

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _setupPayoutCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _payoutTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ============================================================
  // QUARTERLY PAYOUT
  // ============================================================

  DateTime _calculateNextPayout(DateTime now) {
    final year = now.year;

    final payoutDates = [
      DateTime(year, 1, 1),
      DateTime(year, 4, 1),
      DateTime(year, 7, 1),
      DateTime(year, 10, 1),
      DateTime(year + 1, 1, 1),
    ];

    for (final date in payoutDates) {
      if (date.isAfter(now)) {
        return date;
      }
    }

    return DateTime(year + 1, 1, 1);
  }

  void _setupPayoutCountdown() {
    final now = DateTime.now();

    nextPayoutDate = _calculateNextPayout(now);

    payoutCountdown = nextPayoutDate.difference(now);

    _payoutTimer?.cancel();

    _payoutTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) {
          return;
        }

        final currentTime = DateTime.now();

        if (!nextPayoutDate.isAfter(currentTime)) {
          setState(() {
            nextPayoutDate = _calculateNextPayout(currentTime);

            payoutCountdown = nextPayoutDate.difference(
              currentTime,
            );
          });

          return;
        }

        setState(() {
          payoutCountdown = nextPayoutDate.difference(
            currentTime,
          );
        });
      },
    );
  }

  // ============================================================
  // MINING
  // ============================================================

  void _startMining() {
    if (isMining) {
      return;
    }

    setState(() {
      isMining = true;
      sessionStartedAt = DateTime.now();
      sessionElapsed = Duration.zero;
    });

    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) {
          return;
        }

        setState(() {
          sessionElapsed += const Duration(seconds: 1);
        });

        if (sessionElapsed >= sessionDuration) {
          _finishMiningSession();
        }
      },
    );
  }

  void _finishMiningSession() {
    _timer?.cancel();
    _timer = null;

    if (!mounted) {
      return;
    }

    setState(() {
      isMining = false;
      sessionElapsed = sessionDuration;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Mining session completed.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _addActivityPoints(double points) {
    setState(() {
      todayPoints = (todayPoints + points).clamp(
        0,
        dailyPointsAvailable,
      );

      cyclePoints += points;
    });
  }

  String _formatShortCountdown(
    Duration duration,
  ) {
    final days = duration.inDays;

    final hours = duration.inHours.remainder(24).toString().padLeft(2, '0');

    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');

    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '${days}d $hours:$minutes:$seconds';
  }

  String _formatPayoutDate(
    DateTime date,
  ) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} '
        '${date.day}, '
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: Text(
          'Miner',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.history_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                18,
                8,
                18,
                30,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    // ==================================================
                    // MINING HERO
                    // ==================================================

                    _MiningHero(
                      isMining: isMining,
                      progress: sessionProgress,
                      remaining: remainingSession,
                      totalWeight: totalMiningWeight,
                      pulse: _pulseController,
                      onStart: _startMining,
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    // ==================================================
                    // QUARTERLY PAYOUT
                    // ==================================================

                    _PayoutCountdownCard(
                      countdown: payoutCountdown,
                      payoutDate: nextPayoutDate,
                      cyclePoints: cyclePoints,
                      networkPoints: networkCyclePoints,
                      rewardPool: cycleRewardPool,
                      estimatedReward: estimatedReward,
                      share: estimatedCycleShare,
                      formatCountdown: _formatShortCountdown,
                      formatDate: _formatPayoutDate,
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    // ==================================================
                    // BALANCE
                    // ==================================================

                    _BalanceCard(
                      balance: 1248.42,
                      cycleReward: estimatedReward,
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ==================================================
                    // QUICK STATS
                    // ==================================================

                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.bolt_rounded,
                            label: 'Mining weight',
                            value: '${totalMiningWeight.toStringAsFixed(2)}×',
                          ),
                        ),
                        const SizedBox(
                          width: 12,
                        ),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.stars_rounded,
                            label: 'Today',
                            value: '${todayPoints.toStringAsFixed(0)} pts',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 22,
                    ),

                    // ==================================================
                    // DAILY PROGRESS
                    // ==================================================

                    _SectionTitle(
                      title: 'Today\'s progress',
                      trailing:
                          '${todayPoints.toStringAsFixed(0)} / ${dailyPointsAvailable.toStringAsFixed(0)}',
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    _DailyProgressCard(
                      progress: activityProgress,
                      points: todayPoints,
                      available: dailyPointsAvailable,
                    ),

                    const SizedBox(
                      height: 22,
                    ),

                    // ==================================================
                    // CURRENT CYCLE
                    // ==================================================

                    _SectionTitle(
                      title: 'Current reward cycle',
                      trailing: '3 months',
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    _CyclePointsCard(
                      cyclePoints: cyclePoints,
                      networkPoints: networkCyclePoints,
                      rewardPool: cycleRewardPool,
                      estimatedReward: estimatedReward,
                      share: estimatedCycleShare,
                    ),

                    const SizedBox(
                      height: 22,
                    ),

                    // ==================================================
                    // MINING POWER
                    // ==================================================

                    _SectionTitle(
                      title: 'Your mining power',
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    _MiningPowerCard(
                      base: baseMiningWeight,
                      reputation: reputationMultiplier,
                      plus: plusMultiplier,
                      isPlus: isPlusUser,
                      total: totalMiningWeight,
                    ),

                    const SizedBox(
                      height: 22,
                    ),

                    // ==================================================
                    // ACTIVITIES
                    // ==================================================

                    _SectionTitle(
                      title: 'Earn more points',
                      trailing: 'Daily activities',
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    _ActivityTile(
                      icon: Icons.play_circle_fill_rounded,
                      title: 'Follow Griot on YouTube',
                      subtitle: 'Follow the official Griot channel',
                      reward: '+20 pts',
                      onTap: () {
                        _addActivityPoints(
                          20,
                        );
                      },
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    _ActivityTile(
                      icon: Icons.alternate_email_rounded,
                      title: 'Follow Griot on X',
                      subtitle: 'Follow the official Griot account',
                      reward: '+15 pts',
                      onTap: () {
                        _addActivityPoints(
                          15,
                        );
                      },
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    _ActivityTile(
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'Invite a friend',
                      subtitle: 'Bring someone into Griot',
                      reward: '+50 pts',
                      completed: true,
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    _ActivityTile(
                      icon: Icons.account_circle_rounded,
                      title: 'Complete your profile',
                      subtitle: 'Finish setting up your account',
                      reward: '+10 pts',
                      onTap: () {
                        _addActivityPoints(
                          10,
                        );
                      },
                    ),

                    const SizedBox(
                      height: 22,
                    ),

                    // ==================================================
                    // HOW IT WORKS
                    // ==================================================

                    const _HowMiningWorksCard(),

                    const SizedBox(
                      height: 20,
                    ),

                    // ==================================================
                    // AD
                    // ==================================================

                    const _AdPlaceholder(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MINING HERO
// ============================================================================

class _MiningHero extends StatelessWidget {
  final bool isMining;
  final double progress;
  final Duration remaining;
  final double totalWeight;
  final Animation pulse;
  final VoidCallback onStart;

  const _MiningHero({
    required this.isMining,
    required this.progress,
    required this.remaining,
    required this.totalWeight,
    required this.pulse,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        20,
        24,
        20,
        20,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withValues(
              alpha: 0.18,
            ),
            colors.primaryContainer.withValues(
              alpha: 0.12,
            ),
            colors.surfaceContainerHighest.withValues(
              alpha: 0.55,
            ),
          ],
        ),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMining ? 'Mining is active' : 'Ready to mine',
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    isMining
                        ? 'Keep the session running'
                        : 'Start your daily mining session',
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isMining
                      ? Colors.green.withValues(
                          alpha: 0.12,
                        )
                      : colors.surface.withValues(
                          alpha: 0.55,
                        ),
                  borderRadius: BorderRadius.circular(
                    30,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isMining ? Colors.green : colors.onSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    Text(
                      isMining ? 'ACTIVE' : 'IDLE',
                      style: text.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 24,
          ),
          AnimatedBuilder(
            animation: pulse,
            builder: (context, child) {
              final scale = isMining ? 1.0 + (pulse.value * 0.045) : 1.0;

              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 178,
                  height: 178,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(
                          alpha: isMining ? 0.25 : 0.10,
                        ),
                        blurRadius: 45,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 164,
                  height: 164,
                  child: CircularProgressIndicator(
                    value: isMining ? progress : 0,
                    strokeWidth: 8,
                    backgroundColor: colors.surface.withValues(
                      alpha: 0.55,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colors.primary,
                    ),
                  ),
                ),
                Container(
                  width: 138,
                  height: 138,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors.primary.withValues(
                          alpha: 0.24,
                        ),
                        colors.primary.withValues(
                          alpha: 0.06,
                        ),
                      ],
                    ),
                    border: Border.all(
                      color: colors.primary.withValues(
                        alpha: 0.18,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        size: 32,
                        color: colors.primary,
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      Text(
                        isMining ? '${(progress * 100).toInt()}%' : '0%',
                        style: text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        isMining ? _formatRemaining(remaining) : '2 HOURS',
                        style: text.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.insights_rounded,
                size: 18,
                color: colors.primary,
              ),
              const SizedBox(
                width: 7,
              ),
              Text(
                'Mining power ',
                style: text.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              Text(
                '${totalWeight.toStringAsFixed(2)}×',
                style: text.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 18,
          ),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: isMining ? null : onStart,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    17,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isMining ? Icons.hourglass_top_rounded : Icons.play_arrow_rounded,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Text(
                    isMining ? 'Mining in progress' : 'Start mining',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatRemaining(
    Duration duration,
  ) {
    final hours = duration.inHours.toString().padLeft(2, '0');

    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');

    return '$hours:$minutes';
  }
}

// ============================================================================
// QUARTERLY PAYOUT COUNTDOWN
// ============================================================================

class _PayoutCountdownCard extends StatelessWidget {
  final Duration countdown;
  final DateTime payoutDate;
  final double cyclePoints;
  final double networkPoints;
  final double rewardPool;
  final double estimatedReward;
  final double share;

  final String Function(Duration) formatCountdown;

  final String Function(DateTime) formatDate;

  const _PayoutCountdownCard({
    required this.countdown,
    required this.payoutDate,
    required this.cyclePoints,
    required this.networkPoints,
    required this.rewardPool,
    required this.estimatedReward,
    required this.share,
    required this.formatCountdown,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withValues(
              alpha: 0.13,
            ),
            colors.surfaceContainerHighest.withValues(
              alpha: 0.50,
            ),
          ],
        ),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(
                    15,
                  ),
                ),
                child: Icon(
                  Icons.account_balance_rounded,
                  color: colors.primary,
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next payout',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      formatDate(
                        payoutDate,
                      ),
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(
                    12,
                  ),
                ),
                child: Text(
                  'QUARTERLY',
                  style: text.labelSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 20,
          ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 12,
            ),
            decoration: BoxDecoration(
              color: colors.surface.withValues(
                alpha: 0.48,
              ),
              borderRadius: BorderRadius.circular(
                17,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'PAYOUT IN',
                  style: text.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(
                  height: 7,
                ),
                FittedBox(
                  child: Text(
                    formatCountdown(
                      countdown,
                    ),
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          Row(
            children: [
              Expanded(
                child: _PayoutMetric(
                  label: 'Your points',
                  value: cyclePoints.toStringAsFixed(
                    0,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 38,
                color: colors.outline.withValues(
                  alpha: 0.12,
                ),
              ),
              Expanded(
                child: _PayoutMetric(
                  label: 'Your share',
                  value: '${(share * 100).toStringAsFixed(3)}%',
                ),
              ),
              Container(
                width: 1,
                height: 38,
                color: colors.outline.withValues(
                  alpha: 0.12,
                ),
              ),
              Expanded(
                child: _PayoutMetric(
                  label: 'Est. reward',
                  value: '${estimatedReward.toStringAsFixed(2)} GRT',
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 15,
          ),

          Text(
            'Your final reward is calculated from your '
            'share of all eligible points at the end '
            'of the three-month cycle.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutMetric extends StatelessWidget {
  final String label;
  final String value;

  const _PayoutMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 5,
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BALANCE
// ============================================================================

class _BalanceCard extends StatelessWidget {
  final double balance;
  final double cycleReward;

  const _BalanceCard({
    required this.balance,
    required this.cycleReward,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(
                    17,
                  ),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: colors.primary,
                ),
              ),
              const SizedBox(
                width: 14,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mining balance',
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      '${balance.toStringAsFixed(2)} GRT',
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 15,
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: colors.primary.withValues(
                alpha: 0.07,
              ),
              borderRadius: BorderRadius.circular(
                14,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: colors.primary,
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    'Estimated next payout',
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  '${cycleReward.toStringAsFixed(2)} GRT',
                  style: text.bodyMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STAT CARD
// ============================================================================

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outline.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: colors.primary,
            size: 21,
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  value,
                  style: text.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SECTION TITLE
// ============================================================================

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;

  const _SectionTitle({
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: text.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: text.bodySmall?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// DAILY PROGRESS
// ============================================================================

class _DailyProgressCard extends StatelessWidget {
  final double progress;
  final double points;
  final double available;

  const _DailyProgressCard({
    required this.progress,
    required this.points,
    required this.available,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outline.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${points.toStringAsFixed(0)} pts',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: text.bodySmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 12,
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(
              20,
            ),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: colors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(
                colors.primary,
              ),
            ),
          ),
          const SizedBox(
            height: 11,
          ),
          Row(
            children: [
              Text(
                'Daily activity',
                style: text.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '${available.toStringAsFixed(0)} max points',
                style: text.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CURRENT CYCLE
// ============================================================================

class _CyclePointsCard extends StatelessWidget {
  final double cyclePoints;
  final double networkPoints;
  final double rewardPool;
  final double estimatedReward;
  final double share;

  const _CyclePointsCard({
    required this.cyclePoints,
    required this.networkPoints,
    required this.rewardPool,
    required this.estimatedReward,
    required this.share,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final progress = (cyclePoints / networkPoints).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outline.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  Icons.donut_large_rounded,
                  color: colors.primary,
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your cycle points',
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      cyclePoints.toStringAsFixed(
                        0,
                      ),
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Reward pool',
                    style: text.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    '${rewardPool.toStringAsFixed(0)} GRT',
                    style: text.bodyMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(
            height: 17,
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(
              20,
            ),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: colors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(
                colors.primary,
              ),
            ),
          ),
          const SizedBox(
            height: 15,
          ),
          Row(
            children: [
              Expanded(
                child: _CycleMetric(
                  label: 'Network points',
                  value: networkPoints.toStringAsFixed(
                    0,
                  ),
                ),
              ),
              Expanded(
                child: _CycleMetric(
                  label: 'Your share',
                  value: '${(share * 100).toStringAsFixed(3)}%',
                ),
              ),
              Expanded(
                child: _CycleMetric(
                  label: 'Est. reward',
                  value: '${estimatedReward.toStringAsFixed(2)} GRT',
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 14,
          ),
          Text(
            'More points increase your share of the '
            'available reward pool.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CycleMetric extends StatelessWidget {
  final String label;
  final String value;

  const _CycleMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(
          height: 4,
        ),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// MINING POWER
// ============================================================================

class _MiningPowerCard extends StatelessWidget {
  final double base;
  final double reputation;
  final double plus;
  final bool isPlus;
  final double total;

  const _MiningPowerCard({
    required this.base,
    required this.reputation,
    required this.plus,
    required this.isPlus,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outline.withValues(alpha: 0.10),
        ),
      ),
      child: Column(
        children: [
          _PowerRow(
            icon: Icons.bolt_rounded,
            label: 'Base mining',
            value: '${base.toStringAsFixed(2)}×',
          ),
          const SizedBox(
            height: 14,
          ),
          _PowerRow(
            icon: Icons.workspace_premium_rounded,
            label: 'Reputation',
            value: '${reputation.toStringAsFixed(2)}×',
          ),
          const SizedBox(
            height: 14,
          ),
          _PowerRow(
            icon: Icons.auto_awesome_rounded,
            label: 'Griot Plus',
            value: isPlus ? '${plus.toStringAsFixed(2)}×' : '1.00×',
          ),
          const SizedBox(
            height: 16,
          ),
          Divider(
            color: colors.outline.withValues(alpha: 0.12),
            height: 1,
          ),
          const SizedBox(
            height: 15,
          ),
          Row(
            children: [
              Text(
                'Total mining weight',
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${total.toStringAsFixed(2)}×',
                style: text.titleMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PowerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PowerRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(
              11,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: colors.primary,
          ),
        ),
        const SizedBox(
          width: 11,
        ),
        Expanded(
          child: Text(
            label,
            style: text.bodyMedium,
          ),
        ),
        Text(
          value,
          style: text.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ACTIVITY
// ============================================================================

class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String reward;
  final VoidCallback? onTap;
  final bool completed;

  const _ActivityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.reward,
    this.onTap,
    this.completed = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: completed ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.outline.withValues(alpha: 0.10),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  icon,
                  color: colors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(
                width: 13,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      reward,
                      style: text.labelMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              if (completed)
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(
                      alpha: 0.10,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 19,
                    color: Colors.green,
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: colors.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// HOW IT WORKS
// ============================================================================

class _HowMiningWorksCard extends StatelessWidget {
  const _HowMiningWorksCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: colors.primary,
                ),
              ),
              const SizedBox(
                width: 11,
              ),
              Text(
                'How mining works',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 17,
          ),
          const _Step(
            number: '01',
            title: 'Start a session',
            description: 'Activate mining for up to two hours.',
          ),
          const SizedBox(
            height: 14,
          ),
          const _Step(
            number: '02',
            title: 'Earn points',
            description: 'Mining activity, reputation and eligible activities build your points.',
          ),
          const SizedBox(
            height: 14,
          ),
          const _Step(
            number: '03',
            title: 'Build your share',
            description: 'Your points determine your percentage of the available reward pool.',
          ),
          const SizedBox(
            height: 14,
          ),
          const _Step(
            number: '04',
            title: 'Receive quarterly payout',
            description: 'At the end of every three-month cycle, the reward pool is distributed to eligible users.',
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _Step({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: text.labelMedium?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(
          width: 13,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(
                height: 3,
              ),
              Text(
                description,
                style: text.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// AD
// ============================================================================

class _AdPlaceholder extends StatelessWidget {
  const _AdPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      height: 86,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.ads_click_rounded,
            size: 20,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(
            width: 8,
          ),
          Text(
            'Advertisement',
            style: text.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
