// lib/features/settings/screens/setting_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../auth/services/auth_session_service.dart';
import '../../users/providers/user_provider.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../../core/ui/widgets/banner_ad.dart';
import '../../../core/ui/widgets/griot_loader.dart';
import '../../../core/services/navigation_scroll_service.dart';
import '../../../core/services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
  });

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
    if (NavigationScrollService.instance.tappedIndex == 4) { // Index 4 is Settings
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _handleLogout(BuildContext context) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text(
          'Are you sure you want to log out of your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Log Out',
              style: TextStyle(
                color: colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!context.mounted) return;

    // Show loading indicator
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => const GriotOverlayLoader(
        message: 'Logging out...',
      ),
    );

    try {
      final authSessionService = context.read<AuthSessionService>();
      final userProvider = context.read<UserProvider>();
      final walletProvider = context.read<WalletProvider>();

      // 1. Perform backend logout & full local wipe
      await authSessionService.logout();

      // 2. Clear memory provider state
      userProvider.clearUser();
      walletProvider.reset();

      if (!context.mounted) return;

      // 3. Pop loading dialog and navigate to root
      // We use the root navigator to ensure the dialog is dismissed
      Navigator.of(context, rootNavigator: true).pop();
      
      // Navigate to / which will re-run the Splash logic
      // and take the user to Onboarding since the wallet is gone.
      context.go('/');
    } catch (e) {
      if (!context.mounted) return;
      
      // Ensure dialog is popped on error
      Navigator.of(context, rootNavigator: true).pop();

      NotificationService.showError(context, 'Logout failed: $e');
    }
  }

  // ============================================================
  // SECTION LABEL
  // ============================================================

  Widget _sectionLabel(
      BuildContext context,
      String title,
      ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(
        left: 4,
        top: 26,
        bottom: 9,
      ),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  // ============================================================
  // SETTING TILE
  // ============================================================

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
    final colorScheme = theme.colorScheme;

    final effectiveIconColor =
        iconColor ?? colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 9,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: effectiveIconColor.withValues(alpha: 0.085),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: effectiveIconColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                      theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                        theme.textTheme.bodySmall?.copyWith(
                          color:
                          colorScheme.onSurfaceVariant,
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
                    color: colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.75),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DIVIDER
  // ============================================================

  Widget _divider(
      BuildContext context,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(
        left: 66,
        right: 10,
      ),
      child: Divider(
        height: 1,
        thickness: 0.6,
        color: colorScheme.onSurface.withValues(alpha: 0.065),
      ),
    );
  }

  // ============================================================
  // SECTION CONTAINER
  // ============================================================

  Widget _sectionContainer({
    required BuildContext context,
    required List<Widget> children,
  }) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.065),
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  // ============================================================
  // PROFILE HEADER
  // ============================================================

  Widget _profileHeader(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.push(
            '/settings/user-details',
          );
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: colorScheme.primary.withValues(alpha: 0.055),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.12),
            ),
          ),
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
                      colorScheme.primary.withValues(alpha: 0.20),
                      colorScheme.primary.withValues(alpha: 0.08),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 29,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Griot Account',
                      style:
                      theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Manage your profile and identity',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                      theme.textTheme.bodySmall?.copyWith(
                        color:
                        colorScheme.onSurfaceVariant,
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
                  color: colorScheme.onSurface.withValues(alpha: 0.055),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color:
                  colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // GRIOT PLUS
  // ============================================================

  Widget _griotPlusCard(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.push(
            '/settings/griot-plus',
          );
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary.withValues(alpha: 0.19),
                colorScheme.primary.withValues(alpha: 0.055),
              ],
            ),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius:
                  BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Griot Plus',
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style: theme
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                              fontWeight:
                              FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                            colorScheme.primary,
                            borderRadius:
                            BorderRadius.circular(7),
                          ),
                          child: Text(
                            'PLUS',
                            style: theme
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                              color:
                              colorScheme.onPrimary,
                              fontWeight:
                              FontWeight.w800,
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
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      theme.textTheme.bodySmall?.copyWith(
                        color:
                        colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      child: SafeArea(
        child: ListView(
          controller: _scrollController,
          physics:
          const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            18,
            8,
            18,
            34,
          ),
          children: [
            // ==================================================
            // PROFILE
            // ==================================================

            _profileHeader(context),

            const SizedBox(height: 13),

            // ==================================================
            // GRIOT PLUS
            // ==================================================

            _griotPlusCard(context),

            // ==================================================
            // MESSAGING
            // ==================================================

            _sectionLabel(
              context,
              'Messaging',
            ),

            _sectionContainer(
              context: context,
              children: [
                _settingTile(
                  context: context,
                  icon:
                  Icons.chat_bubble_outline_rounded,
                  title: 'Chat Settings',
                  subtitle:
                  'Manage your messaging preferences',
                  onTap: () {
                    context.push(
                      '/settings/chat-settings',
                    );
                  },
                ),
                _divider(context),
                _settingTile(
                  context: context,
                  icon:
                  Icons.lock_outline_rounded,
                  title: 'Chat Privacy',
                  subtitle:
                  'Control privacy for your conversations',
                  onTap: () {
                    context.push(
                      '/settings/chat-privacy',
                    );
                  },
                ),
              ],
            ),

            // ==================================================
            // WALLET
            // ==================================================

            _sectionLabel(
              context,
              'Wallet',
            ),

            _sectionContainer(
              context: context,
              children: [
                _settingTile(
                  context: context,
                  icon: Icons
                      .account_balance_wallet_outlined,
                  title: 'Wallet Settings',
                  subtitle:
                  'Manage your wallet preferences',
                  onTap: () {
                    context.push(
                      '/settings/wallet-settings',
                    );
                  },
                ),
                _divider(context),
                _settingTile(
                  context: context,
                  icon:
                  Icons.currency_exchange_rounded,
                  title: 'Networks',
                  subtitle:
                  'Manage supported blockchain networks',
                  onTap: () {
                    context.push(
                      '/settings/networks',
                    );
                  },
                ),
              ],
            ),

            // ==================================================
            // SECURITY
            // ==================================================

            _sectionLabel(
              context,
              'Security',
            ),

            _sectionContainer(
              context: context,
              children: [
                _settingTile(
                  context: context,
                  icon:
                  Icons.fingerprint_rounded,
                  title: 'App Security',
                  subtitle:
                  'Biometrics, PIN and automatic app lock',
                  onTap: () {
                    context.push(
                      '/settings/app-security',
                    );
                  },
                ),
                _divider(context),
                _settingTile(
                  context: context,
                  icon:
                  Icons.backup_outlined,
                  title: 'Backup Wallet',
                  subtitle:
                  'Securely back up your recovery phrase',
                  onTap: () {
                    context.push(
                      '/settings/backup-wallet',
                    );
                  },
                ),
                _divider(context),
                _settingTile(
                  context: context,
                  icon:
                  Icons.verified_user_outlined,
                  title: 'Transaction Security',
                  subtitle:
                  'Protect sensitive wallet transactions',
                  onTap: () {
                    context.push(
                      '/settings/transaction-security',
                    );
                  },
                ),
              ],
            ),

            // ==================================================
            // MINER
            // ==================================================

            _sectionLabel(
              context,
              'Miner',
            ),

            _sectionContainer(
              context: context,
              children: [
                _settingTile(
                  context: context,
                  icon: Icons.bolt_rounded,
                  title: 'Mining',
                  subtitle:
                  'Manage your mining activity',
                  onTap: () {
                    context.push(
                      '/settings/mining',
                    );
                  },
                ),
                _divider(context),
                _settingTile(
                  context: context,
                  icon:
                  Icons.people_outline_rounded,
                  title: 'Referrals',
                  subtitle:
                  'Manage referrals and rewards',
                  onTap: () {
                    context.push(
                      '/settings/referrals',
                    );
                  },
                ),
              ],
            ),

            // ==================================================
            // P2P MARKET
            // ==================================================

            _sectionLabel(
              context,
              'P2P Market',
            ),

            _sectionContainer(
              context: context,
              children: [
                _settingTile(
                  context: context,
                  icon:
                  Icons.storefront_outlined,
                  title: 'P2P Preferences',
                  subtitle:
                  'Manage marketplace preferences',
                  onTap: () {
                    context.push(
                      '/settings/p2p-preferences',
                    );
                  },
                ),
                _divider(context),
                _settingTile(
                  context: context,
                  icon:
                  Icons.account_balance_outlined,
                  title: 'Payment Methods',
                  subtitle:
                  'Manage payment methods for P2P trades',
                  onTap: () {
                    context.push(
                      '/settings/payment-methods',
                    );
                  },
                ),
              ],
            ),

            // ==================================================
            // PRIVACY
            // ==================================================

            _sectionLabel(
              context,
              'Privacy',
            ),

            _sectionContainer(
              context: context,
              children: [
                _settingTile(
                  context: context,
                  icon:
                  Icons.visibility_off_outlined,
                  title: 'Privacy',
                  subtitle:
                  'Manage profile and discovery privacy',
                  onTap: () {
                    context.push(
                      '/settings/privacy',
                    );
                  },
                ),
              ],
            ),

            // ==================================================
            // APPEARANCE
            // ==================================================

            _sectionLabel(
              context,
              'Appearance',
            ),

            _sectionContainer(
              context: context,
              children: [
                _settingTile(
                  context: context,
                  icon:
                  Icons.dark_mode_outlined,
                  title: 'Theme',
                  subtitle:
                  'Light, dark or follow system',
                  onTap: () {
                    context.push(
                      '/settings/theme',
                    );
                  },
                ),
                _divider(context),
                _settingTile(
                  context: context,
                  icon:
                  Icons.palette_outlined,
                  title: 'Accent Color',
                  subtitle:
                  'Choose your app accent color',
                  onTap: () {
                    context.push(
                      '/settings/accent-color',
                    );
                  },
                ),
              ],
            ),

            // ==================================================
            // GENERAL
            // ==================================================

            _sectionLabel(
              context,
              'General',
            ),

            _sectionContainer(
              context: context,
              children: [
                _settingTile(
                  context: context,
                  icon:
                  Icons.notifications_none_rounded,
                  title: 'Notifications',
                  subtitle:
                  'Manage app notifications',
                  onTap: () {
                    context.push(
                      '/settings/notifications',
                    );
                  },
                ),
                _divider(context),
                _settingTile(
                  context: context,
                  icon:
                  Icons.info_outline_rounded,
                  title: 'About Griot',
                  subtitle:
                  'App information and policies',
                  onTap: () {
                    context.push(
                      '/settings/about',
                    );
                  },
                ),
              ],
            ),

            // ==================================================
            // ACCOUNT
            // ==================================================

            _sectionLabel(
              context,
              'Account',
            ),

            _sectionContainer(
              context: context,
              children: [
                _settingTile(
                  context: context,
                  icon:
                  Icons.security_outlined,
                  title: 'Account Security',
                  subtitle:
                  'Manage account access and authentication',
                  onTap: () {
                    context.push(
                      '/settings/account-security',
                    );
                  },
                ),
              ],
            ),

            // ==================================================
            // ACCOUNT ACTIONS
            // ==================================================

            _sectionLabel(
              context,
              'Account Actions',
            ),

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
                  icon:
                  Icons.delete_forever_outlined,
                  title: 'Delete Account',
                  subtitle:
                  'Permanently delete your account',
                  iconColor: colorScheme.error,
                  titleColor: colorScheme.error,
                  onTap: () {
                    // Connect to account deletion flow.
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ==================================================
            // AD
            // ==================================================

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: GriotBannerAd(),
            ),

            const SizedBox(height: 16),

            // ==================================================
            // FOOTER
            // ==================================================

            Center(
              child: Text(
                'Your wallet. Your identity. Your network.',
                textAlign: TextAlign.center,
                style:
                Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color:
                  colorScheme.onSurfaceVariant,
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