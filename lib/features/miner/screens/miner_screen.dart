import 'dart:async';

import 'package:flutter/material.dart';

class MinerScreen extends StatefulWidget {
  const MinerScreen({
    super.key,
  });

  @override
  State<MinerScreen> createState() => _MinerScreenState();
}

class _MinerScreenState extends State<MinerScreen> {
  // ============================================================
  // MINING CONFIGURATION
  // ============================================================

  static const Duration sessionDuration =
  Duration(hours: 2);

  // ============================================================
  // USER MINING STATE
  // ============================================================

  bool isMining = false;

  DateTime? sessionStartedAt;

  Duration sessionElapsed = Duration.zero;

  Timer? _timer;

  // ============================================================
  // DAILY POINTS
  // ============================================================

  double todayPoints = 186.0;

  double dailyPointsAvailable = 250.0;

  // ============================================================
  // DAILY POOL
  // ============================================================

  double todayRewardPool = 125000.0;

  // ============================================================
  // USER MULTIPLIERS
  // ============================================================

  double baseMiningWeight = 1.0;

  double reputationMultiplier = 1.15;

  double plusMultiplier = 1.25;

  bool isPlusUser = true;

  // ============================================================
  // CALCULATED WEIGHT
  // ============================================================

  double get totalMiningWeight {
    final plus = isPlusUser ? plusMultiplier : 1.0;

    return baseMiningWeight *
        reputationMultiplier *
        plus;
  }

  // ============================================================
  // SESSION PROGRESS
  // ============================================================

  double get sessionProgress {
    if (!isMining &&
        sessionElapsed == Duration.zero) {
      return 0;
    }

    final value =
        sessionElapsed.inSeconds /
            sessionDuration.inSeconds;

    return value.clamp(0.0, 1.0);
  }

  // ============================================================
  // REMAINING SESSION TIME
  // ============================================================

  Duration get remainingSession {
    final remaining =
        sessionDuration - sessionElapsed;

    if (remaining.isNegative) {
      return Duration.zero;
    }

    return remaining;
  }

  // ============================================================
  // START MINING
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
          sessionElapsed +=
          const Duration(seconds: 1);
        });

        if (sessionElapsed >=
            sessionDuration) {
          _finishMiningSession();
        }
      },
    );
  }

  // ============================================================
  // FINISH SESSION
  // ============================================================

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

  // ============================================================
  // ADD POINTS
  // ============================================================

  void _addActivityPoints(double points) {
    setState(() {
      todayPoints += points;

      if (todayPoints >
          dailyPointsAvailable) {
        todayPoints =
            dailyPointsAvailable;
      }
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    final textTheme = theme.textTheme;

    // ==========================================================
    // THEME RESPONSIVE COLORS
    // ==========================================================

    final Color cardColor =
    colorScheme.surface.withValues(
      alpha: theme.brightness ==
          Brightness.dark
          ? 0.35
          : 0.75,
    );

    final Color subtleColor =
    colorScheme.surfaceContainerHighest
        .withValues(
      alpha: theme.brightness ==
          Brightness.dark
          ? 0.45
          : 0.65,
    );

    final Color borderColor =
    colorScheme.outline.withValues(
      alpha: theme.brightness ==
          Brightness.dark
          ? 0.22
          : 0.35,
    );

    final Color mutedColor =
        colorScheme.onSurfaceVariant;

    final Color primaryColor =
        colorScheme.primary;

    return Scaffold(
      backgroundColor:
      theme.scaffoldBackgroundColor,

      appBar: AppBar(
        title: Text(
          'Miner',
          style:
          textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor:
        theme.scaffoldBackgroundColor,
        foregroundColor:
        colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor:
        Colors.transparent,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            32,
          ),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.stretch,
            children: [
              // ==================================================
              // DAILY REWARD POOL
              // ==================================================

              _DailyPoolCard(
                rewardPool:
                todayRewardPool,
                todayPoints:
                todayPoints,
                availablePoints:
                dailyPointsAvailable,
                cardColor:
                cardColor,
                borderColor:
                borderColor,
                colorScheme:
                colorScheme,
                textTheme:
                textTheme,
              ),

              const SizedBox(height: 14),

              // ==================================================
              // MINING BALANCE
              // ==================================================

              _BalanceCard(
                balance: 1248.42,
                cardColor:
                cardColor,
                borderColor:
                borderColor,
                colorScheme:
                colorScheme,
                textTheme:
                textTheme,
              ),

              const SizedBox(height: 14),

              // ==================================================
              // MINING SESSION
              // ==================================================

              _MiningSessionCard(
                isMining:
                isMining,
                progress:
                sessionProgress,
                remaining:
                remainingSession,
                totalWeight:
                totalMiningWeight,
                cardColor:
                cardColor,
                borderColor:
                borderColor,
                colorScheme:
                colorScheme,
                textTheme:
                textTheme,
              ),

              const SizedBox(height: 14),

              // ==================================================
              // START MINING
              // ==================================================

              SizedBox(
                height: 56,
                child:
                ElevatedButton.icon(
                  onPressed:
                  isMining
                      ? null
                      : _startMining,
                  icon: Icon(
                    isMining
                        ? Icons
                        .hourglass_top_rounded
                        : Icons
                        .play_arrow_rounded,
                  ),
                  label: Text(
                    isMining
                        ? 'Mining in progress'
                        : 'Start 2-Hour Session',
                  ),
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    primaryColor,
                    foregroundColor:
                    colorScheme
                        .onPrimary,
                    disabledBackgroundColor:
                    primaryColor
                        .withValues(
                      alpha: 0.55,
                    ),
                    disabledForegroundColor:
                    colorScheme
                        .onPrimary
                        .withValues(
                      alpha: 0.55,
                    ),
                    elevation: 0,
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        16,
                      ),
                    ),
                    textStyle:
                    const TextStyle(
                      fontSize: 15,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'Each mining session lasts up to 2 hours. '
                    'Start another session when the current one ends.',
                textAlign:
                TextAlign.center,
                style:
                textTheme.bodySmall?.copyWith(
                  color: mutedColor,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 22),

              // ==================================================
              // MINING POWER
              // ==================================================

              _MiningPowerCard(
                reputationMultiplier:
                reputationMultiplier,
                plusMultiplier:
                plusMultiplier,
                isPlusUser:
                isPlusUser,
                totalWeight:
                totalMiningWeight,
                cardColor:
                cardColor,
                borderColor:
                borderColor,
                colorScheme:
                colorScheme,
                textTheme:
                textTheme,
              ),

              const SizedBox(height: 22),

              // ==================================================
              // BANNER
              // ==================================================

              _BannerAdPlaceholder(
                cardColor:
                subtleColor,
                borderColor:
                borderColor,
                colorScheme:
                colorScheme,
                textTheme:
                textTheme,
              ),

              const SizedBox(height: 24),

              // ==================================================
              // ACTIVITY
              // ==================================================

              Row(
                mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
                children: [
                  Text(
                    'Activity',
                    style:
                    textTheme.titleLarge
                        ?.copyWith(
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${todayPoints.toStringAsFixed(0)} / '
                        '${dailyPointsAvailable.toStringAsFixed(0)} pts',
                    style:
                    textTheme.bodySmall
                        ?.copyWith(
                      color:
                      primaryColor,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              Text(
                'Complete activities to increase your share of today’s reward pool.',
                style:
                textTheme.bodyMedium?.copyWith(
                  color: mutedColor,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 14),

              // ==================================================
              // POINT PROGRESS
              // ==================================================

              Container(
                padding:
                const EdgeInsets.all(15),
                decoration:
                BoxDecoration(
                  color: cardColor,
                  borderRadius:
                  BorderRadius.circular(
                    16,
                  ),
                  border:
                  Border.all(
                    color: borderColor,
                  ),
                ),
                child:
                Column(
                  children: [
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,
                      children: [
                        Text(
                          'Daily activity',
                          style:
                          textTheme
                              .bodyMedium
                              ?.copyWith(
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${((todayPoints / dailyPointsAvailable) * 100).clamp(0, 100).toStringAsFixed(0)}%',
                          style:
                          textTheme
                              .bodySmall
                              ?.copyWith(
                            color:
                            primaryColor,
                            fontWeight:
                            FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    ClipRRect(
                      borderRadius:
                      BorderRadius
                          .circular(
                        10,
                      ),
                      child:
                      LinearProgressIndicator(
                        value:
                        (todayPoints /
                            dailyPointsAvailable)
                            .clamp(
                          0.0,
                          1.0,
                        ),
                        minHeight: 8,
                        backgroundColor:
                        colorScheme
                            .surfaceContainerHighest,
                        valueColor:
                        AlwaysStoppedAnimation<
                            Color>(
                          primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ==================================================
              // CAMPAIGNS
              // ==================================================

              _CampaignCard(
                icon: Icons
                    .play_circle_outline_rounded,
                title:
                'Follow Griot on YouTube',
                description:
                'Follow the official Griot channel.',
                points: '+20 pts',
                completed: false,
                onPressed: () {
                  _addActivityPoints(20);
                },
                cardColor:
                cardColor,
                borderColor:
                borderColor,
                colorScheme:
                colorScheme,
                textTheme:
                textTheme,
              ),

              const SizedBox(height: 10),

              _CampaignCard(
                icon: Icons
                    .alternate_email_rounded,
                title:
                'Follow Griot on X',
                description:
                'Follow the official Griot account.',
                points: '+15 pts',
                completed: false,
                onPressed: () {
                  _addActivityPoints(15);
                },
                cardColor:
                cardColor,
                borderColor:
                borderColor,
                colorScheme:
                colorScheme,
                textTheme:
                textTheme,
              ),

              const SizedBox(height: 10),

              _CampaignCard(
                icon: Icons
                    .person_add_alt_1_rounded,
                title:
                'Invite a friend',
                description:
                'Invite someone to join Griot.',
                points: '+50 pts',
                completed: true,
                onPressed: null,
                cardColor:
                cardColor,
                borderColor:
                borderColor,
                colorScheme:
                colorScheme,
                textTheme:
                textTheme,
              ),

              const SizedBox(height: 10),

              _CampaignCard(
                icon: Icons
                    .account_circle_outlined,
                title:
                'Complete your profile',
                description:
                'Finish setting up your Griot profile.',
                points: '+10 pts',
                completed: false,
                onPressed: () {
                  _addActivityPoints(10);
                },
                cardColor:
                cardColor,
                borderColor:
                borderColor,
                colorScheme:
                colorScheme,
                textTheme:
                textTheme,
              ),

              const SizedBox(height: 24),

              // ==================================================
              // DISTRIBUTION
              // ==================================================

              _DistributionInfoCard(
                cardColor:
                cardColor,
                borderColor:
                borderColor,
                colorScheme:
                colorScheme,
                textTheme:
                textTheme,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// DAILY POOL CARD
// ================================================================

class _DailyPoolCard extends StatelessWidget {
  final double rewardPool;
  final double todayPoints;
  final double availablePoints;

  final Color cardColor;
  final Color borderColor;

  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _DailyPoolCard({
    required this.rewardPool,
    required this.todayPoints,
    required this.availablePoints,
    required this.cardColor,
    required this.borderColor,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.all(18),
      decoration:
      BoxDecoration(
        color: cardColor,
        borderRadius:
        BorderRadius.circular(20),
        border:
        Border.all(
          color: borderColor,
        ),
      ),
      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                BoxDecoration(
                  color:
                  colorScheme.primary
                      .withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  Icons
                      .account_balance_rounded,
                  color:
                  colorScheme.primary,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child:
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today’s reward pool',
                      style:
                      textTheme
                          .bodyLarge
                          ?.copyWith(
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      'Shared according to daily mining weight',
                      style:
                      textTheme
                          .bodySmall
                          ?.copyWith(
                        color:
                        colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            crossAxisAlignment:
            CrossAxisAlignment.end,
            children: [
              Text(
                rewardPool
                    .toStringAsFixed(0),
                style:
                textTheme.headlineMedium
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
              const SizedBox(width: 7),
              Padding(
                padding:
                const EdgeInsets.only(
                  bottom: 4,
                ),
                child: Text(
                  'GRT',
                  style:
                  textTheme.titleMedium
                      ?.copyWith(
                    color:
                    colorScheme.primary,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'Your points determine your share of this pool.',
            style:
            textTheme.bodySmall?.copyWith(
              color:
              colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// BALANCE CARD
// ================================================================

class _BalanceCard extends StatelessWidget {
  final double balance;

  final Color cardColor;
  final Color borderColor;

  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _BalanceCard({
    required this.balance,
    required this.cardColor,
    required this.borderColor,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.all(20),
      decoration:
      BoxDecoration(
        color: cardColor,
        borderRadius:
        BorderRadius.circular(20),
        border:
        Border.all(
          color: borderColor,
        ),
      ),
      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            'Mining balance',
            style:
            textTheme.bodyMedium?.copyWith(
              color:
              colorScheme
                  .onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 7),

          Row(
            crossAxisAlignment:
            CrossAxisAlignment.end,
            children: [
              Text(
                balance.toStringAsFixed(2),
                style:
                textTheme.displaySmall
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w800,
                ),
              ),

              const SizedBox(width: 8),

              Padding(
                padding:
                const EdgeInsets.only(
                  bottom: 5,
                ),
                child: Text(
                  'GRT',
                  style:
                  textTheme.titleMedium
                      ?.copyWith(
                    color:
                    colorScheme.primary,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'Accumulated rewards from previous distributions',
            style:
            textTheme.bodySmall?.copyWith(
              color:
              colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// MINING SESSION CARD
// ================================================================

class _MiningSessionCard
    extends StatelessWidget {
  final bool isMining;
  final double progress;
  final Duration remaining;
  final double totalWeight;

  final Color cardColor;
  final Color borderColor;

  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _MiningSessionCard({
    required this.isMining,
    required this.progress,
    required this.remaining,
    required this.totalWeight,
    required this.cardColor,
    required this.borderColor,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.all(18),
      decoration:
      BoxDecoration(
        color: cardColor,
        borderRadius:
        BorderRadius.circular(18),
        border:
        Border.all(
          color: borderColor,
        ),
      ),
      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
            MainAxisAlignment
                .spaceBetween,
            children: [
              Text(
                'Mining session',
                style:
                textTheme.titleMedium
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
              Container(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration:
                BoxDecoration(
                  color: colorScheme
                      .surfaceContainerHighest,
                  borderRadius:
                  BorderRadius.circular(
                    8,
                  ),
                ),
                child:
                Text(
                  'MAX 2 HOURS',
                  style:
                  textTheme.labelSmall
                      ?.copyWith(
                    color:
                    colorScheme
                        .onSurfaceVariant,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          ClipRRect(
            borderRadius:
            BorderRadius.circular(10),
            child:
            LinearProgressIndicator(
              value:
              isMining
                  ? progress
                  : 0,
              minHeight: 9,
              backgroundColor:
              colorScheme
                  .surfaceContainerHighest,
              valueColor:
              AlwaysStoppedAnimation<
                  Color>(
                colorScheme.primary,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment:
            MainAxisAlignment
                .spaceBetween,
            children: [
              Text(
                isMining
                    ? 'Remaining ${_formatRemaining(remaining)}'
                    : 'Ready to start',
                style:
                textTheme.bodySmall
                    ?.copyWith(
                  color:
                  colorScheme
                      .onSurfaceVariant,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style:
                textTheme.bodySmall
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Container(
            padding:
            const EdgeInsets.all(12),
            decoration:
            BoxDecoration(
              color: colorScheme
                  .surfaceContainerHighest
                  .withValues(
                alpha: 0.45,
              ),
              borderRadius:
              BorderRadius.circular(
                12,
              ),
            ),
            child:
            Row(
              children: [
                Icon(
                  Icons.insights_rounded,
                  size: 18,
                  color:
                  colorScheme.primary,
                ),

                const SizedBox(width: 9),

                Expanded(
                  child:
                  Text(
                    'Current mining weight: '
                        '${totalWeight.toStringAsFixed(2)}×',
                    style:
                    textTheme
                        .bodySmall
                        ?.copyWith(
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatRemaining(
      Duration duration,
      ) {
    final hours =
        duration.inHours;

    final minutes =
    duration.inMinutes.remainder(60);

    return '${hours}h '
        '${minutes.toString().padLeft(2, '0')}m';
  }
}

// ================================================================
// MINING POWER
// ================================================================

class _MiningPowerCard
    extends StatelessWidget {
  final double reputationMultiplier;
  final double plusMultiplier;
  final bool isPlusUser;
  final double totalWeight;

  final Color cardColor;
  final Color borderColor;

  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _MiningPowerCard({
    required this.reputationMultiplier,
    required this.plusMultiplier,
    required this.isPlusUser,
    required this.totalWeight,
    required this.cardColor,
    required this.borderColor,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.all(17),
      decoration:
      BoxDecoration(
        color: cardColor,
        borderRadius:
        BorderRadius.circular(18),
        border:
        Border.all(
          color: borderColor,
        ),
      ),
      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            'Mining power',
            style:
            textTheme.titleMedium?.copyWith(
              fontWeight:
              FontWeight.w700,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Your daily share weight is influenced by your account activity and status.',
            style:
            textTheme.bodySmall?.copyWith(
              color:
              colorScheme
                  .onSurfaceVariant,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 16),

          _MultiplierRow(
            label: 'Base weight',
            value: '1.00×',
            colorScheme:
            colorScheme,
            textTheme:
            textTheme,
          ),

          const SizedBox(height: 10),

          _MultiplierRow(
            label: 'Reputation',
            value:
            '${reputationMultiplier.toStringAsFixed(2)}×',
            colorScheme:
            colorScheme,
            textTheme:
            textTheme,
          ),

          const SizedBox(height: 10),

          _MultiplierRow(
            label: 'Griot Plus',
            value:
            isPlusUser
                ? '${plusMultiplier.toStringAsFixed(2)}×'
                : '1.00×',
            colorScheme:
            colorScheme,
            textTheme:
            textTheme,
          ),

          const SizedBox(height: 14),

          Divider(
            color: borderColor,
            height: 1,
          ),

          const SizedBox(height: 14),

          Row(
            mainAxisAlignment:
            MainAxisAlignment
                .spaceBetween,
            children: [
              Text(
                'Total weight',
                style:
                textTheme.bodyMedium
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
              Text(
                '${totalWeight.toStringAsFixed(2)}×',
                style:
                textTheme.titleMedium
                    ?.copyWith(
                  color:
                  colorScheme.primary,
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ================================================================
// MULTIPLIER ROW
// ================================================================

class _MultiplierRow
    extends StatelessWidget {
  final String label;
  final String value;

  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _MultiplierRow({
    required this.label,
    required this.value,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
      MainAxisAlignment
          .spaceBetween,
      children: [
        Text(
          label,
          style:
          textTheme.bodyMedium,
        ),
        Text(
          value,
          style:
          textTheme.bodyMedium
              ?.copyWith(
            fontWeight:
            FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ================================================================
// BANNER AD PLACEHOLDER
// ================================================================

class _BannerAdPlaceholder
    extends StatelessWidget {
  final Color cardColor;
  final Color borderColor;

  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _BannerAdPlaceholder({
    required this.cardColor,
    required this.borderColor,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 90,
      decoration:
      BoxDecoration(
        color: cardColor,
        borderRadius:
        BorderRadius.circular(16),
        border:
        Border.all(
          color: borderColor,
        ),
      ),
      child:
      Center(
        child:
        Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 24,
              color:
              colorScheme
                  .onSurfaceVariant,
            ),
            const SizedBox(height: 5),
            Text(
              'Banner advertisement',
              style:
              textTheme.bodySmall
                  ?.copyWith(
                color:
                colorScheme
                    .onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Reserved ad space',
              style:
              textTheme.labelSmall
                  ?.copyWith(
                color:
                colorScheme
                    .onSurfaceVariant
                    .withValues(
                  alpha: 0.65,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// CAMPAIGN CARD
// ================================================================

class _CampaignCard
    extends StatelessWidget {
  final IconData icon;

  final String title;
  final String description;
  final String points;

  final bool completed;

  final VoidCallback? onPressed;

  final Color cardColor;
  final Color borderColor;

  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _CampaignCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.points,
    required this.completed,
    required this.onPressed,
    required this.cardColor,
    required this.borderColor,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius:
      BorderRadius.circular(16),
      onTap:
      completed
          ? null
          : onPressed,
      child:
      Container(
        padding:
        const EdgeInsets.all(15),
        decoration:
        BoxDecoration(
          color: cardColor,
          borderRadius:
          BorderRadius.circular(16),
          border:
          Border.all(
            color: borderColor,
          ),
        ),
        child:
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration:
              BoxDecoration(
                color: colorScheme
                    .surfaceContainerHighest,
                borderRadius:
                BorderRadius.circular(
                  13,
                ),
              ),
              child:
              Icon(
                icon,
                size: 22,
                color:
                colorScheme.onSurface,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child:
              Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style:
                    textTheme.bodyLarge
                        ?.copyWith(
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    description,
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style:
                    textTheme.bodySmall
                        ?.copyWith(
                      color:
                      colorScheme
                          .onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    points,
                    style:
                    textTheme.bodySmall
                        ?.copyWith(
                      color:
                      colorScheme.primary,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            completed
                ? Container(
              width: 34,
              height: 34,
              decoration:
              BoxDecoration(
                color: colorScheme
                    .primary
                    .withValues(
                  alpha: 0.12,
                ),
                shape:
                BoxShape.circle,
              ),
              child:
              Icon(
                Icons.check_rounded,
                size: 19,
                color:
                colorScheme.primary,
              ),
            )
                : Icon(
              Icons
                  .chevron_right_rounded,
              color:
              colorScheme
                  .onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// DISTRIBUTION INFO
// ================================================================

class _DistributionInfoCard
    extends StatelessWidget {
  final Color cardColor;
  final Color borderColor;

  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _DistributionInfoCard({
    required this.cardColor,
    required this.borderColor,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.all(17),
      decoration:
      BoxDecoration(
        color: cardColor,
        borderRadius:
        BorderRadius.circular(18),
        border:
        Border.all(
          color: borderColor,
        ),
      ),
      child:
      Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons
                    .pie_chart_outline_rounded,
                color:
                colorScheme.primary,
                size: 21,
              ),
              const SizedBox(width: 9),
              Text(
                'How daily rewards work',
                style:
                textTheme.titleMedium
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            'Griot sets a reward pool for the day. '
                'Users compete for a share of that pool using their eligible activity points and mining weight. '
                'The pool is distributed according to each participant’s relative weight.',
            style:
            textTheme.bodySmall?.copyWith(
              color:
              colorScheme
                  .onSurfaceVariant,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 12),

          _InfoRow(
            number: '1',
            text:
            'Complete eligible activities and build daily points.',
            colorScheme:
            colorScheme,
            textTheme:
            textTheme,
          ),

          const SizedBox(height: 9),

          _InfoRow(
            number: '2',
            text:
            'Keep your 2-hour mining sessions active.',
            colorScheme:
            colorScheme,
            textTheme:
            textTheme,
          ),

          const SizedBox(height: 9),

          _InfoRow(
            number: '3',
            text:
            'Your points and account multipliers determine your daily weight.',
            colorScheme:
            colorScheme,
            textTheme:
            textTheme,
          ),

          const SizedBox(height: 9),

          _InfoRow(
            number: '4',
            text:
            'The available daily pool is shared between eligible participants.',
            colorScheme:
            colorScheme,
            textTheme:
            textTheme,
          ),
        ],
      ),
    );
  }
}

// ================================================================
// INFO ROW
// ================================================================

class _InfoRow
    extends StatelessWidget {
  final String number;
  final String text;

  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _InfoRow({
    required this.number,
    required this.text,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment:
          Alignment.center,
          decoration:
          BoxDecoration(
            color: colorScheme
                .primary
                .withValues(
              alpha: 0.10,
            ),
            shape:
            BoxShape.circle,
          ),
          child:
          Text(
            number,
            style:
            textTheme.labelSmall
                ?.copyWith(
              color:
              colorScheme.primary,
              fontWeight:
              FontWeight.w800,
            ),
          ),
        ),

        const SizedBox(width: 9),

        Expanded(
          child:
          Text(
            text,
            style:
            textTheme.bodySmall
                ?.copyWith(
              color:
              colorScheme
                  .onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}