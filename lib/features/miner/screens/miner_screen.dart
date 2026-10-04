import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/mining_provider.dart';
import '../providers/reputation_provider.dart';
import '../../../core/services/navigation_scroll_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/ad_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';

class MinerScreen extends StatefulWidget {
  const MinerScreen({super.key});

  @override
  State<MinerScreen> createState() => _MinerScreenState();
}

class _MinerScreenState extends State<MinerScreen> {
  final ScrollController _scrollController = ScrollController();
  Timer? _countdownTimer;
  String _timeRemaining = '';
  bool _isWatchingAd = false;

  @override
  void initState() {
    super.initState();
    NavigationScrollService.instance.addListener(_onNavTap);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MiningProvider>().loadStatus(force: true);
      _startCountdown();
    });
  }

  @override
  void dispose() {
    NavigationScrollService.instance.removeListener(_onNavTap);
    _scrollController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _onNavTap() {
    if (NavigationScrollService.instance.tappedIndex == 2) {
      // Index 2 is Miner
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutQuart,
        );
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _updateRemainingTime();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemainingTime();
    });
  }

  void _updateRemainingTime() {
    final status = context.read<MiningProvider>().status;
    if (status != null && !status.canMine) {
      if (status.nextAvailableAt != null) {
        final now = DateTime.now();
        final diff = status.nextAvailableAt!.difference(now);
        if (diff.isNegative) {
          context.read<MiningProvider>().loadStatus(force: true);
          return;
        }
        if (mounted) {
          setState(() {
            _timeRemaining = _formatDuration(diff);
          });
        }
      } else {
        if (mounted &&
            (_timeRemaining.isEmpty || _timeRemaining == '00:00:00')) {
          setState(() {
            _timeRemaining = 'ACTIVE';
          });
        }
      }
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<void> _startMining(BuildContext context) async {
    final adService = AdService.instance;

    // Mining is ad-supported in this build. Never call the backend unless the
    // user actually earns the rewarded-ad reward; an unavailable or failed ad
    // must not silently grant a mining session.
    if (!adService.isRewardedAdAvailable) {
      adService.loadRewardedAd();
      NotificationService.showInfo(
        context,
        'The reward ad is still loading. Please try again in a moment.',
      );
      return;
    }

    setState(() => _isWatchingAd = true);
    final adResult = await adService.showRewardedAd();
    if (!context.mounted) return;

    if (adResult != RewardedAdResult.rewarded) {
      setState(() => _isWatchingAd = false);
      NotificationService.showInfo(
        context,
        adResult == RewardedAdResult.dismissed
            ? 'Watch the full ad to begin mining.'
            : 'The reward ad could not be completed. Please try again.',
      );
      return;
    }

    final provider = context.read<MiningProvider>();
    final success = await provider.startMining();

    if (!context.mounted) return;
    setState(() => _isWatchingAd = false);
    if (success) {
      await context.read<ReputationProvider>().loadReputation(force: true);
      if (!context.mounted) return;
      NotificationService.showSuccess(
        context,
        'Cloud-miner activated! Session started.',
      );
    } else {
      NotificationService.showError(
        context,
        provider.error ?? 'Activation failed. Try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final provider = context.watch<MiningProvider>();

    return GradientScaffold(
      useSafeArea: false,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text('Cloud Miner'),
        centerTitle: true,
        backgroundColor: colors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 56,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => context.push('/miner/rules'),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.help_outline_rounded, size: 20),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeOutQuart,
        child: _buildBody(context, provider, theme, colors),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    MiningProvider provider,
    ThemeData theme,
    ColorScheme colors,
  ) {
    final status = provider.status;

    // Priority 1: Loading state
    if (status == null && provider.isLoading) {
      return Center(
        key: const ValueKey('loading'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading Miner…',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    // Priority 2: Error state or initial uninitialized state
    if (status == null) {
      if (!provider.isLoading && provider.error == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          provider.loadStatus(force: true);
        });
      }
      return Center(
        key: const ValueKey('error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Unable to load Miner'),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                provider.error ?? 'Connecting to cloud miner...',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.loadStatus(force: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      key: const ValueKey('content'),
      onRefresh: provider.loadStatus,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
        child: Column(
          children:
              [
                    const SizedBox(height: 10),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'AVAILABLE BALANCE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.primary.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                'assets/cowrie_images/cowriesvg.svg',
                                width: 44,
                                height: 44,
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${status.availableBalance.toStringAsFixed(2)} ${status.currency}',
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colors.primary.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 14,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Daily Pool: ${status.rewardPool == null ? '—' : NumberFormat.decimalPattern().format(status.rewardPool)} ${status.currency}',
                              style: TextStyle(
                                color: colors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Main activity area
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                                width: 260,
                                height: 260,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colors.primary.withValues(alpha: 0.03),
                                ),
                              )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .scale(
                                begin: const Offset(1, 1),
                                end: const Offset(1.1, 1.1),
                                duration: 2.seconds,
                              ),

                          GestureDetector(
                            onTap: (status.canMine && !_isWatchingAd)
                                ? () => _startMining(context)
                                : null,
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: status.canMine
                                    ? colors.primary
                                    : colors.surfaceContainerHighest,
                                boxShadow: [
                                  if (status.canMine && !_isWatchingAd)
                                    BoxShadow(
                                      color: colors.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 30,
                                      offset: const Offset(0, 10),
                                    ),
                                ],
                              ),
                              child: _isWatchingAd
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          status.canMine
                                              ? Icons.bolt_rounded
                                              : Icons.timer_outlined,
                                          size: 48,
                                          color: status.canMine
                                              ? Colors.white
                                              : colors.onSurfaceVariant,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          status.canMine
                                              ? 'ACTIVATE'
                                              : _timeRemaining,
                                          style: TextStyle(
                                            color: status.canMine
                                                ? Colors.white
                                                : colors.onSurfaceVariant,
                                            fontWeight: FontWeight.w900,
                                            fontSize: status.canMine ? 18 : 22,
                                            letterSpacing: status.canMine
                                                ? 2
                                                : 1,
                                            fontFamily: 'Monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),

                    // 3. Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Mining Weight',
                            value: status.pointsToday.toStringAsFixed(0),
                            icon: Icons.auto_awesome_rounded,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            label: 'Pool Share',
                            value:
                                '${status.currentSharePercent.toStringAsFixed(2)}%',
                            icon: Icons.pie_chart_rounded,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(28),
                        border: Border(
                          top: BorderSide(
                            color: colors.primary.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                          bottom: BorderSide(
                            color: colors.primary.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            status.settled
                                ? 'FINAL REWARD'
                                : 'ESTIMATED REWARD',
                            style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                'assets/cowrie_images/cowriesvg.svg',
                                width: 64,
                                height: 64,
                              ),
                              const SizedBox(width: 16),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '${status.estimatedReward.toStringAsFixed(2)} ${status.currency}',
                                    style: theme.textTheme.displaySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: colors.onSurface,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    _BalanceOverview(status: status),

                    const SizedBox(height: 32),

                    // 5. Reputation Section
                    if (status.reputation != null)
                      _ReputationSection(reputation: status.reputation!),

                    const SizedBox(height: 24),

                    // 5.5 Referral Section
                    _ReferralSection(multiplier: status.multiplier),

                    const SizedBox(height: 32),

                    _MiningActivities(activities: provider.activities),

                    const SizedBox(height: 32),

                    // 6. Multiplier Breakdown
                    _MultiplierBreakdown(multiplier: status.multiplier),

                    const SizedBox(height: 40),
                  ]
                  .animate(interval: 40.ms)
                  .fade(duration: 400.ms)
                  .slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border(
          top: BorderSide(
            color: colors.primary.withValues(alpha: 0.6),
            width: 1.5,
          ),
          bottom: BorderSide(
            color: colors.primary.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.primary.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceOverview extends StatelessWidget {
  const _BalanceOverview({required this.status});

  final MiningStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.outline.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WALLET OVERVIEW',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: colors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          _balanceRow(
            context,
            'Lifetime Earned',
            status.lifetimeEarned,
            currency: status.currency,
          ),
          const Divider(height: 32),
          _balanceRow(
            context,
            'Available Balance',
            status.availableBalance,
            currency: status.currency,
            highlight: true,
          ),
          const SizedBox(height: 12),
          _balanceRow(
            context,
            'Pending Settlement',
            status.pendingBalance,
            currency: status.currency,
            isDim: true,
          ),
        ],
      ),
    );
  }

  Widget _balanceRow(
    BuildContext context,
    String label,
    double amount, {
    required String currency,
    bool highlight = false,
    bool isDim = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDim
                ? colors.onSurfaceVariant.withValues(alpha: 0.6)
                : colors.onSurfaceVariant,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          '${amount.toStringAsFixed(2)} $currency',
          style: TextStyle(
            fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
            color: highlight
                ? colors.primary
                : (isDim
                      ? colors.onSurface.withValues(alpha: 0.5)
                      : colors.onSurface),
            fontFamily: 'Monospace',
          ),
        ),
      ],
    );
  }
}

class _ReputationSection extends StatelessWidget {
  final MiningReputation reputation;
  const _ReputationSection({required this.reputation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = AppColors.parseHexColor(reputation.badgeColor);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border(
          top: BorderSide(color: color.withValues(alpha: 0.6), width: 1.5),
          bottom: BorderSide(color: color.withValues(alpha: 0.6), width: 1.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SvgPicture.asset(
                'assets/coins_logo/hbadger_logo.svg',
                width: 32,
                height: 32,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reputation.tier,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    Text(
                      '${reputation.points} points',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+${reputation.bonus.toStringAsFixed(3)}×',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      fontFamily: 'Monospace',
                    ),
                  ),
                  const Text(
                    'BONUS',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReferralSection extends StatelessWidget {
  final MiningMultiplier multiplier;
  const _ReferralSection({required this.multiplier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isUnlocked = multiplier.referralBonus > 0;
    final needed = 10 - multiplier.validReferralCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(28),
        border: Border(
          top: BorderSide(
            color: colors.primary.withValues(alpha: 0.6),
            width: 1.5,
          ),
          bottom: BorderSide(
            color: colors.primary.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_alt_rounded, color: colors.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REFERRALS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: colors.primary.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${multiplier.validReferralCount} valid referrals',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isUnlocked)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Text(
                        'UNLOCKED',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => context.push('/settings/referrals'),
                    icon: const Icon(Icons.share_rounded, size: 14),
                    label: const Text(
                      'REFER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: colors.primary.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (!isUnlocked && needed > 0) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: multiplier.validReferralCount / 10,
                backgroundColor: colors.primary.withValues(alpha: 0.1),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$needed more valid referrals needed for +0.100× bonus',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiningActivities extends StatelessWidget {
  const _MiningActivities({required this.activities});

  final List<Map<String, dynamic>> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text(
            'ECOSYSTEM TASKS',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: colors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        ...activities.map((activity) => _ActivityTile(activity: activity)),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity});

  final Map<String, dynamic> activity;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final actionUrl = activity['actionUrl']?.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border(
          top: BorderSide(
            color: colors.primary.withValues(alpha: 0.6),
            width: 1.5,
          ),
          bottom: BorderSide(
            color: colors.primary.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _iconFor(activity['activityType']?.toString()),
            color: colors.primary,
            size: 20,
          ),
        ),
        title: Text(
          activity['title']?.toString() ?? 'Community activity',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        subtitle: Text(
          activity['description']?.toString() ?? '',
          style: TextStyle(
            color: colors.onSurfaceVariant.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: colors.onSurfaceVariant.withValues(alpha: 0.3),
          size: 20,
        ),
        onTap: actionUrl == null || actionUrl.isEmpty
            ? null
            : () async {
                final uri = Uri.tryParse(actionUrl);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
      ),
    );
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'follow_page':
        return Icons.person_add_rounded;
      case 'youtube':
      case 'watch_video':
        return Icons.play_circle_fill_rounded;
      case 'visit_link':
      case 'visit_site':
        return Icons.public_rounded;
      case 'share_post':
        return Icons.share_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }
}

class _MultiplierBreakdown extends StatelessWidget {
  final MiningMultiplier multiplier;

  const _MultiplierBreakdown({required this.multiplier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(28),
        border: Border(
          top: BorderSide(
            color: colors.primary.withValues(alpha: 0.6),
            width: 1.5,
          ),
          bottom: BorderSide(
            color: colors.primary.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up_rounded, size: 20),
              const SizedBox(width: 12),
              Text(
                'YOUR MULTIPLIER',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                '${multiplier.total.toStringAsFixed(3)}×',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  fontFamily: 'Monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _row(context, 'Base', '${multiplier.base.toStringAsFixed(3)}×'),
          _row(
            context,
            'Plus Membership',
            '+${multiplier.plusBonus.toStringAsFixed(3)}×',
            isBonus: true,
          ),
          _row(
            context,
            'Referrals',
            '+${multiplier.referralBonus.toStringAsFixed(3)}×',
            isBonus: true,
          ),
          _row(
            context,
            'Reputation',
            '+${multiplier.reputationBonus.toStringAsFixed(3)}×',
            isBonus: true,
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Maximum potential',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${multiplier.maximum.toStringAsFixed(1)}×',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool isBonus = false,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: isBonus && value != '+0.0×' && value != '+0.000×'
                  ? AppColors.success
                  : null,
              fontFamily: 'Monospace',
            ),
          ),
        ],
      ),
    );
  }
}
