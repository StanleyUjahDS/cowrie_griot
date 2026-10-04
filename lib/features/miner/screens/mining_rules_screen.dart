import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../models/reputation_model.dart';
import '../providers/reputation_provider.dart';
import '../providers/mining_provider.dart';

class MiningRulesScreen extends StatelessWidget {
  const MiningRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reputation = context.watch<ReputationProvider>().data;
    final mining = context.watch<MiningProvider>();
    final tiers = reputation?.tiers.isNotEmpty == true
        ? reputation!.tiers
        : _defaultTiers();

    return GradientScaffold(
      appBar: AppBar(
        title: const Text(
          'COWRIE Activity Rules',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -80,
            bottom: 40,
            child: Opacity(
              opacity: 0.03,
              child: Image.asset(
                'assets/cowrie_images/Cowrie5.png',
                width: 300,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            left: -40,
            top: 200,
            child: Opacity(
              opacity: 0.02,
              child: Image.asset(
                'assets/cowrie_images/Cowrie9.png',
                width: 250,
                fit: BoxFit.contain,
              ),
            ),
          ),

          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.primary, colors.primaryContainer],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Cloud-Based COWRIE Activity',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Take part in the daily community activity cycle and build COWRIE reputation without using your device hardware or battery.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                _buildSectionHeader(context, 'HOW IT WORKS'),
                _buildRuleItem(
                  context,
                  icon: Icons.cloud_done_rounded,
                  title: 'Cloud-Based Activity',
                  description:
                      'Griot records activity through secure cloud infrastructure. Your device CPU, GPU, and battery are never used for this activity.',
                ),
                _buildRuleItem(
                  context,
                  icon: Icons.touch_app_rounded,
                  title: 'Active Participation',
                  description:
                      'Start an activity session every 3 hours to record your participation in the Griot community.',
                ),
                _buildRuleItem(
                  context,
                  icon: Icons.groups_rounded,
                  title: 'Daily Community Allocation',
                  description:
                      'The daily COWRIE allocation recognises participation across the community. Your share reflects your activity for that day.',
                ),

                const SizedBox(height: 40),

                _buildSectionHeader(context, 'MINING ACTIVITY RULES'),
                _buildRuleItem(
                  context,
                  icon: Icons.timer_rounded,
                  title: 'One session every 3 hours',
                  description:
                      'Complete an eligible cloud-mining session after the cooldown. Each accepted session adds weighted participation and reputation points.',
                ),
                _buildRuleItem(
                  context,
                  icon: Icons.play_circle_outline_rounded,
                  title: 'Rewarded activity confirmation',
                  description:
                      'When a reward ad is required, it must finish successfully before the session is recorded. Closing or failing the ad does not grant activity credit.',
                ),
                _buildRuleItem(
                  context,
                  icon: Icons.pie_chart_rounded,
                  title: 'Daily pool allocation',
                  description:
                      'Your final COWRIE share is based on your weighted activity compared with the whole community for that mining day. The displayed amount is an estimate until settlement.',
                ),
                if (mining.activities.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...mining.activities.map(
                    (activity) => _buildRuleItem(
                      context,
                      icon: Icons.auto_awesome_rounded,
                      title: activity['title']?.toString() ?? 'Community task',
                      description:
                          '${activity['description']?.toString() ?? 'Complete this administrator-managed task.'} Daily limit: ${activity['dailyLimit'] ?? 1}.',
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                _buildSectionHeader(context, 'MULTIPLIER BONUSES'),
                Container(
                  padding: const EdgeInsets.all(24),
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
                    children: [
                      _buildMultiplierRow(
                        context,
                        'Base Rate',
                        '1.0×',
                        'Everyone starts here',
                      ),
                      _buildDivider(context),
                      InkWell(
                        onTap: () => context.push('/settings/griot-plus'),
                        borderRadius: BorderRadius.circular(12),
                        child: _buildMultiplierRow(
                          context,
                          'Griot Plus',
                          '+0.4×',
                          'Members exclusive bonus',
                        ),
                      ),
                      _buildDivider(context),
                      _buildMultiplierRow(
                        context,
                        'Referral Bonus',
                        '+0.1×',
                        'Per active invite',
                      ),
                      _buildDivider(context),
                      _buildMultiplierRow(
                        context,
                        'Reputation Bonus',
                        'Up to +0.5×',
                        'Based on your Badger tier',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                _buildSectionHeader(context, 'EVERY REPUTATION TIER'),
                _buildTierRules(context, tiers),

                const SizedBox(height: 40),

                _buildInfoBox(
                  context,
                  icon: Icons.shield_rounded,
                  text:
                      'COWRIE is a community reputation score. It has no cash value and cannot be transferred, traded, redeemed, withdrawn, or converted to cryptocurrency.',
                ),

                const SizedBox(height: 80),
              ].animate(interval: 50.ms).fade(duration: 400.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad),
            ),
          ),
        ],
      ),
    );
  }

  List<ReputationTier> _defaultTiers() => const [
        ReputationTier(name: 'Starter Badger', minPoints: 0, maxPoints: 49, badgeColor: '#64748B', miningMultiplier: 1),
        ReputationTier(name: 'Rookie Badger', minPoints: 50, maxPoints: 149, badgeColor: '#22C55E', miningMultiplier: 1.056),
        ReputationTier(name: 'Rising Badger', minPoints: 150, maxPoints: 299, badgeColor: '#3B82F6', miningMultiplier: 1.111),
        ReputationTier(name: 'Active Badger', minPoints: 300, maxPoints: 599, badgeColor: '#A855F7', miningMultiplier: 1.167),
        ReputationTier(name: 'Guardian Badger', minPoints: 600, maxPoints: 999, badgeColor: '#14B8A6', miningMultiplier: 1.222),
        ReputationTier(name: 'Warden Badger', minPoints: 1000, maxPoints: 1499, badgeColor: '#F97316', miningMultiplier: 1.278),
        ReputationTier(name: 'Elder Badger', minPoints: 1500, maxPoints: 1999, badgeColor: '#EF4444', miningMultiplier: 1.333),
        ReputationTier(name: 'Ancient Badger', minPoints: 2000, maxPoints: 2399, badgeColor: '#4F46E5', miningMultiplier: 1.389),
        ReputationTier(name: 'Legendary Badger', minPoints: 2400, maxPoints: 2999, badgeColor: '#EAB308', miningMultiplier: 1.444),
        ReputationTier(name: 'Ultimate Badger', minPoints: 3000, maxPoints: null, badgeColor: '#67E8F9', miningMultiplier: 1.5),
      ];

  Widget _buildTierRules(BuildContext context, List<ReputationTier> tiers) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: tiers.map((tier) {
        final color = Color(int.parse(tier.badgeColor.replaceFirst('#', '0xff')));
        final range = tier.maxPoints == null
            ? '${tier.minPoints}+'
            : '${tier.minPoints}–${tier.maxPoints}';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tier.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text('$range points  •  ${tier.miningMultiplier.toStringAsFixed(3)}× mining weight', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                ]),
              ),
              Text(tier.reputationBonusLabel, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildRuleItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: colors.primary, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiplierRow(
    BuildContext context,
    String label,
    String value,
    String subtitle,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: colors.onSurface,
              fontSize: 16,
              fontFamily: 'Monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 24,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.05),
    );
  }

  Widget _buildInfoBox(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: 0.03),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: colors.onSurfaceVariant.withValues(alpha: 0.5),
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
