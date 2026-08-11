// lib/features/settings/setting_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/core/ui/scaffolds/gradient_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
  });

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(
      BuildContext context,
      String title,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        4,
        8,
        4,
        9,
      ),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  // ============================================================
  // SETTING CONTAINER
  // ============================================================

  Widget _settingContainer({
    required BuildContext context,
    required Widget child,
  }) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(
          alpha: 0.035,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onSurface.withValues(
            alpha: 0.08,
          ),
        ),
      ),
      child: child,
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

    return Divider(
      height: 1,
      indent: 60,
      endIndent: 16,
      color: colorScheme.onSurface.withValues(
        alpha: 0.07,
      ),
    );
  }

  // ============================================================
  // NAVIGATION TILE
  // ============================================================

  Widget _navigationTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final textTheme =
        Theme.of(context).textTheme;

    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: colorScheme.onSurface,
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
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
    final theme =
    Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
        ),
        centerTitle: true,
        backgroundColor:
        Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor:
        Colors.transparent,
      ),

      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            18,
            8,
            18,
            30,
          ),
          children: [

            // ==================================================
            // ACCOUNT
            // ==================================================

            _sectionTitle(
              context,
              'Account',
            ),

            _settingContainer(
              context: context,
              child: Column(
                children: [

                  _navigationTile(
                    context: context,
                    icon: Icons
                        .person_outline_rounded,
                    title: 'User Details',
                    subtitle:
                    'Profile, personal information and account details',
                  ),

                  _divider(context),

                  _navigationTile(
                    context: context,
                    icon: Icons
                        .verified_user_outlined,
                    title:
                    'Account Verification',
                    subtitle:
                    'Manage account verification and identity',
                  ),

                  _divider(context),

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.security_outlined,
                    title:
                    'Account Security',
                    subtitle:
                    'Security, authentication and account protection',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // CHATS
            // ==================================================

            _sectionTitle(
              context,
              'Chats',
            ),

            _settingContainer(
              context: context,
              child: Column(
                children: [

                  _navigationTile(
                    context: context,
                    icon: Icons
                        .chat_bubble_outline_rounded,
                    title:
                    'Chat Settings',
                    subtitle:
                    'Manage conversations and messaging preferences',
                  ),

                  _divider(context),

                  _navigationTile(
                    context: context,
                    icon: Icons
                        .notifications_none_rounded,
                    title:
                    'Chat Notifications',
                    subtitle:
                    'Messages, sounds and notification preferences',
                  ),

                  _divider(context),

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.lock_outline_rounded,
                    title:
                    'Chat Privacy',
                    subtitle:
                    'Privacy and message security settings',
                  ),

                  _divider(context),

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.storage_outlined,
                    title:
                    'Media & Storage',
                    subtitle:
                    'Manage media, storage and downloads',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // MINER
            // ==================================================

            _sectionTitle(
              context,
              'Miner',
            ),

            _settingContainer(
              context: context,
              child: Column(
                children: [

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.bolt_rounded,
                    title: 'Mining',
                    subtitle:
                    'Manage mining activity and mining preferences',
                  ),

                  _divider(context),

                  _navigationTile(
                    context: context,
                    icon: Icons
                        .people_outline_rounded,
                    title: 'Referrals',
                    subtitle:
                    'Referral code, referrals and rewards',
                  ),

                  _divider(context),

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.card_giftcard_outlined,
                    title: 'Rewards',
                    subtitle:
                    'Mining rewards, bonuses and achievements',
                  ),

                  _divider(context),

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.leaderboard_outlined,
                    title:
                    'Mining Statistics',
                    subtitle:
                    'View your mining activity and progress',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // P2P MARKET
            // ==================================================

            _sectionTitle(
              context,
              'P2P Market',
            ),

            _settingContainer(
              context: context,
              child: Column(
                children: [

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.storefront_outlined,
                    title:
                    'P2P Preferences',
                    subtitle:
                    'Manage your buying and selling preferences',
                  ),

                  _divider(context),

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.account_balance_outlined,
                    title:
                    'Payment Methods',
                    subtitle:
                    'Manage payment methods used for P2P trades',
                  ),

                  _divider(context),

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.swap_horiz_rounded,
                    title:
                    'Trading Settings',
                    subtitle:
                    'Manage trade preferences and limits',
                  ),

                  _divider(context),

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.history_rounded,
                    title:
                    'P2P History',
                    subtitle:
                    'View your previous P2P transactions',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // WALLET
            // ==================================================

            _sectionTitle(
              context,
              'Wallet',
            ),

            _settingContainer(
              context: context,
              child: Column(
                children: [

                  _navigationTile(
                    context: context,
                    icon: Icons
                        .account_balance_wallet_outlined,
                    title:
                    'Wallet Settings',
                    subtitle:
                    'Manage your wallet and wallet preferences',
                  ),

                  _divider(context),

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.currency_exchange_rounded,
                    title: 'Networks',
                    subtitle:
                    'Manage supported blockchain networks',
                  ),

                  _divider(context),

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.tune_rounded,
                    title:
                    'Token Preferences',
                    subtitle:
                    'Manage tokens displayed in your wallet',
                  ),

                  _divider(context),

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.history_rounded,
                    title:
                    'Transaction History',
                    subtitle:
                    'View your wallet transaction history',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // WALLET SECURITY
            // ==================================================

            _sectionTitle(
              context,
              'Wallet Security',
            ),

            _settingContainer(
              context: context,
              child: Column(
                children: [

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.lock_outline_rounded,
                    title: 'App Lock',
                    subtitle:
                    'Manage app lock, biometrics and auto-lock',
                  ),

                  _divider(context),

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.password_outlined,
                    title: 'Change PIN',
                    subtitle:
                    'Change your wallet security PIN',
                  ),

                  _divider(context),

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.verified_user_outlined,
                    title:
                    'Transaction Security',
                    subtitle:
                    'Protect sensitive wallet actions',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // PRIVACY
            // ==================================================

            _sectionTitle(
              context,
              'Privacy',
            ),

            _settingContainer(
              context: context,
              child: Column(
                children: [

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.visibility_off_outlined,
                    title: 'Privacy',
                    subtitle:
                    'Manage privacy and visibility preferences',
                  ),

                  _divider(context),

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.block_outlined,
                    title:
                    'Blocked Users',
                    subtitle:
                    'Manage blocked accounts',
                  ),

                  _divider(context),

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.data_usage_outlined,
                    title:
                    'Data & Permissions',
                    subtitle:
                    'Manage app permissions and data preferences',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // APPEARANCE
            // ==================================================

            _sectionTitle(
              context,
              'Appearance',
            ),

            _settingContainer(
              context: context,
              child: Column(
                children: [

                  _navigationTile(
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

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.palette_outlined,
                    title:
                    'Accent Color',
                    subtitle:
                    'Choose your app accent color',
                  ),

                  _divider(context),

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.format_size_rounded,
                    title:
                    'Text & Display',
                    subtitle:
                    'Manage text size and display preferences',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // GENERAL
            // ==================================================

            _sectionTitle(
              context,
              'General',
            ),

            _settingContainer(
              context: context,
              child: Column(
                children: [

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.notifications_none_rounded,
                    title:
                    'Notifications',
                    subtitle:
                    'Manage app notifications',
                  ),

                  _divider(context),

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.language_rounded,
                    title: 'Language',
                    subtitle: 'English',
                  ),

                  _divider(context),

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.help_outline_rounded,
                    title:
                    'Help & Support',
                    subtitle:
                    'Get help and contact support',
                  ),

                  _divider(context),

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.info_outline_rounded,
                    title:
                    'About Griot',
                    subtitle:
                    'App information, terms and policies',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // ACCOUNT ACTIONS
            // ==================================================

            _sectionTitle(
              context,
              'Account Actions',
            ),

            _settingContainer(
              context: context,
              child: Column(
                children: [

                  _navigationTile(
                    context: context,
                    icon:
                    Icons.logout_rounded,
                    title: 'Log Out',
                    subtitle:
                    'Sign out of your Griot account',
                  ),

                  _divider(context),

                  ListTile(
                    leading: Icon(
                      Icons
                          .delete_forever_outlined,
                      color:
                      colorScheme.error,
                    ),
                    title: Text(
                      'Delete Account',
                      style: TextStyle(
                        color:
                        colorScheme.error,
                      ),
                    ),
                    subtitle: Text(
                      'Permanently delete your account and associated data',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(
                      Icons
                          .chevron_right_rounded,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}