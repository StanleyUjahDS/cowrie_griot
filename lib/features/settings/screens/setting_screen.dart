import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/ui/dialogs/griot_confirm_dialog.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../auth/services/auth_session_service.dart';
import '../../users/providers/user_provider.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../wallet/providers/display_currency_provider.dart';
import '../../chat/providers/messaging_provider.dart';
import '../../miner/providers/mining_provider.dart';
import '../../miner/providers/referral_provider.dart';
import '../../miner/providers/reputation_provider.dart';
import '../../local_auth/providers/app_lock_provider.dart';
import '../../../core/ui/widgets/banner_ad.dart';
import '../../../core/ui/widgets/griot_loader.dart';
import '../../../core/services/navigation_scroll_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/ad_service.dart';
import '../../../core/ui/widgets/griot_branded_container.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    NavigationScrollService.instance.addListener(_onNavTap);
  }

  @override
  void dispose() {
    NavigationScrollService.instance.removeListener(_onNavTap);
    _scrollController.dispose();
    super.dispose();
  }

  void _onNavTap() {
    if (NavigationScrollService.instance.tappedIndex == 4) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showGriotConfirmDialog(
      context,
      title: 'Log out',
      message: 'Are you sure you want to log out of your account?',
      confirmLabel: 'Log out',
      destructive: true,
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => const GriotOverlayLoader(message: 'Logging out...'),
    );

    try {
      final authSessionService = context.read<AuthSessionService>();
      final userProvider = context.read<UserProvider>();
      final walletProvider = context.read<WalletProvider>();
      final messagingProvider = context.read<MessagingProvider>();
      final miningProvider = context.read<MiningProvider>();
      final referralProvider = context.read<ReferralProvider>();
      final reputationProvider = context.read<ReputationProvider>();
      final appLockProvider = context.read<AppLockProvider>();

      // 1. Clear in-memory state and close database connections first
      await messagingProvider.clearState();
      userProvider.clearUser();
      walletProvider.reset();
      miningProvider.reset();
      referralProvider.reset();
      reputationProvider.reset();
      appLockProvider.reset();

      // 2. Full wipe of session and database files
      await authSessionService.signOut();

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      context.go('/login');
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      NotificationService.showError(context, 'Logout failed: $e');
    }
  }

  Widget _sectionLabel(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 26, bottom: 9),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _settingTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? iconColor,
    Color? titleColor,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final effectiveIconColor = iconColor ?? colors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: effectiveIconColor.withValues(alpha: 0.085),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 21, color: effectiveIconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 21,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 70, right: 14),
      child: Divider(
        height: 1,
        thickness: 0.6,
        color: colors.onSurface.withValues(alpha: 0.065),
      ),
    );
  }

  Widget _sectionContainer({
    required BuildContext context,
    required List<Widget> children,
  }) {
    return GriotBrandedContainer(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      child: Column(children: children),
    );
  }

  Widget _profileHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        final user = userProvider.user;
        final reputation = user?.reputation;

        return GriotBrandedContainer(
          padding: EdgeInsets.zero,
          borderRadius: 24,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/settings/user-details'),
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colors.primary.withValues(alpha: 0.20),
                            colors.primary.withValues(alpha: 0.08),
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 29,
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'Your Griot Account',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                          if (reputation != null) ...[
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Icon(
                                  Icons.workspace_premium_rounded,
                                  size: 16,
                                  color: AppColors.parseHexColor(
                                    reputation.badgeColor,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  reputation.tierName,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppColors.parseHexColor(
                                      reputation.badgeColor,
                                    ),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.3,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            'Manage your profile and identity',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colors.onSurface.withValues(alpha: 0.055),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 19,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _griotPlusCard(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return GriotBrandedContainer(
      padding: EdgeInsets.zero,
      borderRadius: 24,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/settings/griot-plus'),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: colors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Griot Plus',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              'PLUS',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.onPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 9,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enhanced mining and premium benefits',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: colors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final displayCurrency = context.watch<DisplayCurrencyProvider>();
    return GradientScaffold(
      useSafeArea: false,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 56,
        automaticallyImplyLeading: false,
      ),
      child: RefreshIndicator(
        onRefresh: () => context.read<UserProvider>().refreshUser(),
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
          children: [
            _profileHeader(context),
            const SizedBox(height: 13),
            _griotPlusCard(context),
            _sectionLabel(context, 'Wallet & currency'),
            _sectionContainer(
              context: context,
              children: [
                _settingTile(
                  context: context,
                  icon: Icons.currency_exchange_rounded,
                  title: 'Display currency',
                  subtitle:
                      '${displayCurrency.currency} · ${displayCurrency.label}',
                  onTap: () => context.push('/settings/currency'),
                ),
              ],
            ),
            _sectionLabel(context, 'Messaging'),
            _sectionContainer(
              context: context,
              children: [
                _settingTile(
                  context: context,
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Chat Settings',
                  subtitle: 'Manage your messaging preferences',
                  onTap: () => context.push('/settings/chat-settings'),
                ),
                _divider(context),
                _settingTile(
                  context: context,
                  icon: Icons.lock_outline_rounded,
                  title: 'Chat Privacy',
                  subtitle: 'Control privacy for your conversations',
                  onTap: () => context.push('/settings/chat-privacy'),
                ),
              ],
            ),
            _sectionLabel(context, 'Security'),
            _sectionContainer(
              context: context,
              children: [
                _settingTile(
                  context: context,
                  icon: Icons.fingerprint_rounded,
                  title: 'App Security',
                  subtitle: 'Biometrics, PIN and automatic app lock',
                  onTap: () => context.push('/settings/app-security'),
                ),
                _divider(context),
                _settingTile(
                  context: context,
                  icon: Icons.key_rounded,
                  title: 'Backup Seed Phrase',
                  subtitle: 'Securely back up your recovery phrase',
                  onTap: () {
                    context.push(
                      '/verify_pin',
                      extra: (BuildContext ctx) async {
                        if (ctx.mounted) {
                          ctx.pushReplacement('/settings/backup-wallet');
                        }
                      },
                    );
                  },
                ),
              ],
            ),
            _sectionLabel(context, 'Miner'),
            _sectionContainer(
              context: context,
              children: [
                _settingTile(
                  context: context,
                  icon: Icons.stars_rounded,
                  title: 'Reputation',
                  subtitle: 'View your network tier and points',
                  onTap: () => context.push('/settings/reputation'),
                ),
                _divider(context),
                _settingTile(
                  context: context,
                  icon: Icons.people_outline_rounded,
                  title: 'Referrals',
                  subtitle: 'Manage referrals and rewards',
                  onTap: () => context.push('/settings/referrals'),
                ),
              ],
            ),
            _sectionLabel(context, 'Privacy'),
            _sectionContainer(
              context: context,
              children: [
                _settingTile(
                  context: context,
                  icon: Icons.visibility_off_outlined,
                  title: 'Privacy',
                  subtitle: 'Manage profile and discovery privacy',
                  onTap: () => context.push('/settings/privacy'),
                ),
              ],
            ),
            _sectionLabel(context, 'Appearance'),
            _sectionContainer(
              context: context,
              children: [
                _settingTile(
                  context: context,
                  icon: Icons.dark_mode_outlined,
                  title: 'Theme',
                  subtitle: 'Light, dark or follow system',
                  onTap: () => context.push('/settings/theme'),
                ),
                _divider(context),
                _settingTile(
                  context: context,
                  icon: Icons.palette_outlined,
                  title: 'Accent Color',
                  subtitle: 'Choose your app accent color',
                  onTap: () => context.push('/settings/accent-color'),
                ),
              ],
            ),
            _sectionLabel(context, 'General'),
            _sectionContainer(
              context: context,
              children: [
                _settingTile(
                  context: context,
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  subtitle: 'Manage app notifications',
                  onTap: () => context.push('/settings/notifications'),
                ),
                _divider(context),
                _settingTile(
                  context: context,
                  icon: Icons.info_outline_rounded,
                  title: 'About Griot',
                  subtitle: 'App information and policies',
                  onTap: () => context.push('/settings/about'),
                ),
                if (kDebugMode || kProfileMode) ...[
                  _divider(context),
                  _settingTile(
                    context: context,
                    icon: Icons.analytics_outlined,
                    title: 'Open Ad Inspector',
                    subtitle: 'Inspect mediation adapters and ad fills',
                    onTap: AdService.instance.openAdInspector,
                  ),
                ],
              ],
            ),
            _sectionLabel(context, 'Account Actions'),
            _sectionContainer(
              context: context,
              children: [
                _settingTile(
                  context: context,
                  icon: Icons.logout_rounded,
                  title: 'Log Out',
                  subtitle: 'Sign out of your Griot account',
                  onTap: () => _handleLogout(context),
                ),
                _divider(context),
                _settingTile(
                  context: context,
                  icon: Icons.delete_forever_outlined,
                  title: 'Delete Griot Account',
                  subtitle:
                      'Permanently delete your cloud account and device data',
                  iconColor: Theme.of(context).colorScheme.error,
                  titleColor: Theme.of(context).colorScheme.error,
                  onTap: () => context.push('/settings/delete-account'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const GriotBannerAd(),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Your wallet. Your identity. Your network.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
