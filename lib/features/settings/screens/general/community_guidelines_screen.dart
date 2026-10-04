import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../../core/ui/widgets/griot_branded_container.dart';
import '../../../users/services/user_api_service.dart';

class CommunityGuidelinesScreen extends StatefulWidget {
  const CommunityGuidelinesScreen({super.key});

  @override
  State<CommunityGuidelinesScreen> createState() =>
      _CommunityGuidelinesScreenState();
}

class _CommunityGuidelinesScreenState extends State<CommunityGuidelinesScreen> {
  bool _accepting = false;

  Future<void> _acceptPolicies() async {
    setState(() => _accepting = true);
    try {
      await context.read<UserApiService>().acceptCurrentPolicies();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terms and Community Guidelines accepted.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not record your acceptance. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Community Guidelines'),
        surfaceTintColor: Colors.transparent,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
        children: [
          GriotBrandedContainer(
            padding: const EdgeInsets.all(22),
            borderRadius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.favorite_outline_rounded,
                  color: colors.primary,
                  size: 30,
                ),
                const SizedBox(height: 14),
                Text(
                  'Help keep Griot welcoming and safe.',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use Griot to connect, share, and participate respectfully. Report content or block a user whenever something feels unsafe.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _Guideline(
            icon: Icons.people_outline_rounded,
            title: 'Treat people with respect',
            body:
                'Do not harass, threaten, bully, impersonate, or target people or groups with hateful or abusive content.',
          ),
          const _Guideline(
            icon: Icons.gpp_bad_outlined,
            title: 'Keep others safe',
            body:
                'Do not share illegal sexual content, exploit minors, encourage self-harm, promote violence, or publish private information without permission.',
          ),
          const _Guideline(
            icon: Icons.report_gmailerrorred_outlined,
            title: 'No scams or spam',
            body:
                'Do not use Griot for fraud, deceptive schemes, phishing, fake offers, unsolicited promotions, or artificial engagement.',
          ),
          const _Guideline(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Take care with wallet activity',
            body:
                'Never share your recovery phrase or private keys. Verify addresses and third-party DApps yourself before approving a transaction.',
          ),
          const _Guideline(
            icon: Icons.flag_outlined,
            title: 'Report and block',
            body:
                'Use the Report option for harmful content and Block to stop another user from contacting you. Serious or repeated violations may lead to content removal or account restrictions.',
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _accepting ? null : _acceptPolicies,
            child: Text(_accepting ? 'Saving…' : 'Accept Terms and Guidelines'),
          ),
        ],
      ),
    );
  }
}

class _Guideline extends StatelessWidget {
  const _Guideline({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GriotBrandedContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: 20,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    body,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
