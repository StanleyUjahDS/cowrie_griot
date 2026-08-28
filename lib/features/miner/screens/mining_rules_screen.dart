import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';

class MiningRulesScreen extends StatelessWidget {
  const MiningRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Mining Rules'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: Stack(
        children: [
          // Background Decorative Elements
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
                // Hero Intro
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
                      const Icon(Icons.bolt_rounded, color: Colors.white, size: 40),
                      const SizedBox(height: 20),
                      const Text(
                        'Cloud-Based Rewards',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Secure your share of the daily decentralized reward pool using our eco-friendly cloud infrastructure.',
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
                  title: '100% Cloud-Based',
                  description: 'Griot uses a cloud-based distribution system. We do NOT use your device hardware (CPU, GPU) or battery to mine. All rewards are managed on our secure servers.',
                ),
                _buildRuleItem(
                  context,
                  icon: Icons.touch_app_rounded,
                  title: 'Active Engagement',
                  description: 'Activate your cloud-miner every 3 hours to collect share points. This proves you are an active member of the community.',
                ),
                _buildRuleItem(
                  context,
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Fair Distribution',
                  description: 'The COWRIE pool is distributed every 24 hours based on total engagement points collected by all active users in the cloud.',
                ),

                const SizedBox(height: 40),

                _buildSectionHeader(context, 'MULTIPLIER BONUSES'),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: colors.outline.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                      _buildMultiplierRow(context, 'Base Rate', '1.0×', 'Everyone starts here'),
                      _buildDivider(context),
                      InkWell(
                        onTap: () => context.push('/settings/griot-plus'),
                        borderRadius: BorderRadius.circular(12),
                        child: _buildMultiplierRow(context, 'Griot Plus', '+0.4×', 'Members exclusive bonus'),
                      ),
                      _buildDivider(context),
                      _buildMultiplierRow(context, 'Referral Bonus', '+0.1×', 'Per active invite'),
                      _buildDivider(context),
                      _buildMultiplierRow(context, 'Reputation Bonus', 'Up to +0.5×', 'Based on your Badger tier'),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                _buildInfoBox(
                  context,
                  icon: Icons.shield_rounded,
                  text: 'Mining activity awards share points only. Your Reputation points and Badge Tier are earned separately through social contribution and ecosystem engagement.',
                ),
                
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildRuleItem(BuildContext context, {required IconData icon, required String title, required String description}) {
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiplierRow(BuildContext context, String label, String value, String subtitle) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Text(subtitle, style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 11)),
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
    return Divider(height: 24, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.05));
  }

  Widget _buildInfoBox(BuildContext context, {required IconData icon, required String text}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outline.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.onSurfaceVariant.withValues(alpha: 0.5), size: 20),
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
