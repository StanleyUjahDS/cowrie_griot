import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reputation_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_loader.dart';

class ReputationScreen extends StatelessWidget {
  const ReputationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    return Consumer<ReputationProvider>(
      builder: (context, provider, child) {
        final reputation = provider.data;

        return GradientScaffold(
          appBar: AppBar(
            title: const Text('Account Reputation'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                onPressed: provider.loadReputation,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          child: RefreshIndicator(
            onRefresh: provider.loadReputation,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                if (provider.isLoading && reputation == null)
                  SizedBox(
                    height: 400,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const GriotLoader(),
                          const SizedBox(height: 16),
                          const Text('Loading reputation...'),
                        ],
                      ),
                    ),
                  )
                else if (provider.error != null && reputation == null)
                  SizedBox(
                    height: 400,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 48, color: colors.error),
                          const SizedBox(height: 16),
                          Text('Unable to load reputation', style: text.titleMedium),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: provider.loadReputation,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (reputation != null) ...[
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: AppColors.parseHexColor(reputation.tier.badgeColor).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.parseHexColor(reputation.tier.badgeColor).withValues(alpha: 0.3),
                              width: 3,
                            ),
                          ),
                          child: Icon(
                            Icons.workspace_premium_rounded,
                            size: 42,
                            color: AppColors.parseHexColor(reputation.tier.badgeColor),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          reputation.tier.name,
                          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${reputation.points} points',
                          style: text.bodyLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Current',
                              style: text.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            if (reputation.nextTier != null)
                              Text(
                                'Next Goal',
                                style: text.labelSmall?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              reputation.tier.name,
                              style: text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.parseHexColor(reputation.tier.badgeColor),
                              ),
                            ),
                            if (reputation.nextTier != null)
                              Text(
                                reputation.nextTier!.name,
                                style: text.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.parseHexColor(reputation.nextTier!.badgeColor),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: reputation.progress,
                            minHeight: 12,
                            backgroundColor: colors.surface,
                            color: AppColors.parseHexColor(reputation.tier.badgeColor),
                          ),
                        ),
                        if (reputation.nextTier != null) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              '${reputation.nextTier!.minPoints - reputation.points} more points to reach ${reputation.nextTier!.name}',
                              style: text.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.primary.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: colors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your reputation is calculated based on your activity within the Griot network. Higher tiers unlock exclusive benefits and mining boosts.',
                            style: text.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (!provider.isLoading) ...[
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 120),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.workspace_premium_rounded,
                            size: 48,
                            color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Starter Badger',
                          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '0 points earned',
                          style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 32),
                        FilledButton.icon(
                          onPressed: provider.loadReputation,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Refresh Status'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
