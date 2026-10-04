import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/notification_service.dart';
import '../../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../../core/ui/widgets/griot_branded_container.dart';
import '../../../../core/ui/widgets/griot_loader.dart';
import '../../../auth/services/auth_session_service.dart';
import '../../../chat/providers/messaging_provider.dart';
import '../../../local_auth/providers/app_lock_provider.dart';
import '../../../miner/providers/mining_provider.dart';
import '../../../miner/providers/referral_provider.dart';
import '../../../miner/providers/reputation_provider.dart';
import '../../../users/providers/user_provider.dart';
import '../../../wallet/providers/wallet_provider.dart';
import 'widgets/section_label.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _confirmationController = TextEditingController();
  bool _understandsConsequences = false;
  bool _isDeleting = false;

  bool get _canDelete =>
      _understandsConsequences &&
      _confirmationController.text.trim().toUpperCase() == 'DELETE' &&
      !_isDeleting;

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (!_canDelete) return;

    setState(() => _isDeleting = true);
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => const GriotOverlayLoader(message: 'Deleting account...'),
    );

    final userProvider = context.read<UserProvider>();
    final messagingProvider = context.read<MessagingProvider>();
    final authSessionService = context.read<AuthSessionService>();
    final walletProvider = context.read<WalletProvider>();
    final miningProvider = context.read<MiningProvider>();
    final referralProvider = context.read<ReferralProvider>();
    final reputationProvider = context.read<ReputationProvider>();
    final appLockProvider = context.read<AppLockProvider>();

    try {
      await userProvider.userApiService.deleteCurrentAccount();
      await messagingProvider.clearState();
      await authSessionService.wipeData();
      userProvider.clearUser();
      walletProvider.reset();
      miningProvider.reset();
      referralProvider.reset();
      reputationProvider.reset();
      appLockProvider.reset();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      context.go('/welcome_one');
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _isDeleting = false);
      NotificationService.showError(context, 'Account deletion failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text(
          'Delete Griot Account',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          GriotBrandedContainer(
            padding: const EdgeInsets.all(24),
            borderRadius: 28,
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_forever_outlined,
                    size: 30,
                    color: colors.error,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'This action is permanent',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Delete your Griot account and remove its data from this device. Your account cannot be recovered afterwards.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SectionLabel(title: 'Before you continue'),
          _DetailCard(
            icon: Icons.delete_outline_rounded,
            title: 'What will be deleted',
            description:
                'Your profile, account access, sessions, device data, contact-discovery information, and messages you sent will be removed or anonymised.',
          ),
          const SizedBox(height: 12),
          _DetailCard(
            icon: Icons.info_outline_rounded,
            title: 'What may remain',
            description:
                'Blockchain records and legally required payment or tax records cannot be erased. These records will no longer identify you in the Griot app.',
          ),
          const SizedBox(height: 12),
          _DetailCard(
            icon: Icons.subscriptions_outlined,
            title: 'Active subscriptions',
            description:
                'Deleting your account does not cancel an active membership. Cancel it separately through Google Play or the App Store where you bought it.',
          ),
          const SectionLabel(title: 'Confirm deletion'),
          GriotBrandedContainer(
            padding: const EdgeInsets.all(18),
            borderRadius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CheckboxListTile(
                  value: _understandsConsequences,
                  onChanged: _isDeleting
                      ? null
                      : (value) => setState(
                          () => _understandsConsequences = value ?? false,
                        ),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'I understand this cannot be undone.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Type DELETE to continue',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmationController,
                  enabled: !_isDeleting,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'DELETE',
                    filled: true,
                    fillColor: colors.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: colors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _canDelete ? _deleteAccount : null,
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('Permanently Delete Account'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isDeleting ? null : () => context.pop(),
            child: const Text('Cancel and keep my account'),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GriotBrandedContainer(
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
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
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
