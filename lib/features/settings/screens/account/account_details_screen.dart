import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../users/providers/user_provider.dart';
import '../../../users/models/user_model.dart';

import 'username_edit_sheet.dart';
import 'display_name_edit_sheet.dart';
import 'bio_edit_sheet.dart';

import 'widgets/profile_avatar.dart';
import 'widgets/profile_field.dart';
import 'widgets/section_label.dart';
import 'widgets/settings_container.dart';
import '../../../../core/ui/widgets/griot_loader.dart';

class AccountDetailsScreen extends StatefulWidget {
  const AccountDetailsScreen({
    super.key,
  });

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<UserProvider>().refreshUser();
      }
    });
  }

  Future<void> _editUsername(
      BuildContext context,
      String currentUsername,
      ) async {
    final userProvider = context.read<UserProvider>();

    await UsernameEditSheet.show(
      context: context,
      initialValue: currentUsername.replaceFirst('@', ''),
      onCheckAvailability: (username) async {
        return await userProvider.checkUsernameAvailability(
          username.trim().toLowerCase(),
        );
      },
      onSave: (value) async {
        await userProvider.updateUsername(
          value.trim().toLowerCase(),
        );
      },
    );
  }

  Future<void> _editDisplayName(
      BuildContext context,
      String currentDisplayName,
      ) async {
    final provider = context.read<UserProvider>();

    await DisplayNameEditSheet.show(
      context: context,
      initialValue: currentDisplayName,
      onSave: (value) async {
        await provider.updateDisplayName(
          value.trim(),
        );
      },
    );
  }

  Future<void> _editBio(
      BuildContext context,
      String currentBio,
      ) async {
    final provider = context.read<UserProvider>();

    await BioEditSheet.show(
      context: context,
      initialValue: currentBio,
      onSave: (value) async {
        await provider.updateBio(
          value.trim(),
        );
      },
    );
  }

  String _valueOrFallback(
      String? value,
      String fallback,
      ) {
    if (value == null || value.trim().isEmpty) {
      return fallback;
    }

    return value.trim();
  }

  String _usernameDisplay(
      String? username,
      ) {
    final value = _valueOrFallback(
      username,
      'username',
    );

    if (value.startsWith('@')) {
      return value;
    }

    return '@$value';
  }

  String _walletDisplay(
      String? walletAddress,
      ) {
    if (walletAddress == null ||
        walletAddress.trim().isEmpty) {
      return 'Wallet address unavailable';
    }

    final value = walletAddress.trim();

    if (value.length <= 18) {
      return value;
    }

    return '${value.substring(0, 10)}'
        '••••••'
        '${value.substring(value.length - 8)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;

    final displayName = _valueOrFallback(user?.displayName, 'Your name');
    final username = _usernameDisplay(user?.username);
    final rawBio = user?.bio?.trim() ?? '';
    final walletAddress = user?.walletAddress;
    final avatarUrl = user?.avatarUrl;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text(
          'Your Griot Account',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeOutQuart,
        child: _buildBody(context, userProvider, user, displayName, username, rawBio, walletAddress, avatarUrl, colors, text),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, 
    UserProvider userProvider, 
    UserModel? user,
    String displayName,
    String username,
    String rawBio,
    String? walletAddress,
    String? avatarUrl,
    ColorScheme colors,
    TextTheme text,
  ) {
    if (user == null && userProvider.isLoading) {
      return Center(
        key: const ValueKey('loading'),
        child: const GriotLoader(),
      );
    }

    return RefreshIndicator(
      key: const ValueKey('content'),
      onRefresh: () => userProvider.refreshUser(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
        children: [
          _ProfileHero(
            avatarUrl: avatarUrl,
            displayName: displayName,
            username: username,
            reputation: user?.reputation,
          ),
          const SizedBox(height: 8),
          const SectionLabel(title: 'Public Profile'),
          SettingsContainer(
            children: [
              ProfileField(
                icon: Icons.badge_outlined,
                title: 'Display Name',
                value: displayName,
                trailingIcon: Icons.edit_rounded,
                onTap: () => _editDisplayName(context, displayName == 'Your name' ? '' : displayName),
              ),
              const SettingsDivider(),
              ProfileField(
                icon: Icons.alternate_email_rounded,
                title: 'Username',
                value: username,
                trailingIcon: Icons.edit_rounded,
                onTap: () => _editUsername(context, username == '@username' ? '' : username),
              ),
              const SettingsDivider(),
              ProfileField(
                icon: Icons.info_outline_rounded,
                title: 'Bio',
                value: rawBio.isEmpty ? 'Tell people about yourself' : rawBio,
                trailingIcon: Icons.edit_rounded,
                onTap: () => _editBio(context, rawBio),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SectionLabel(title: 'Account Identity'),
          SettingsContainer(
            children: [
              ProfileField(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Wallet Address',
                value: _walletDisplay(walletAddress),
                onTap: () {
                  // TODO: Copy to clipboard
                },
              ),
              const SettingsDivider(),
              ProfileField(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Share Your Identity',
                value: 'Referral link & QR code',
                onTap: () => context.push('/settings/referrals'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user_outlined, size: 15, color: colors.onSurfaceVariant),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Your wallet is your permanent Griot identity.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ].animate(interval: 50.ms).fade(duration: 400.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final String username;
  final UserReputationBadge? reputation;

  const _ProfileHero({
    required this.avatarUrl,
    required this.displayName,
    required this.username,
    this.reputation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    return Column(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.primary, colors.primaryContainer],
              ),
            ),
            child: ProfileAvatar(avatarUrl: avatarUrl),
          ),
        ),
        const SizedBox(height: 15),
        Text(
          displayName,
          textAlign: TextAlign.center,
          style: text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),

        if (reputation != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => context.push('/settings/reputation'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.parseHexColor(reputation!.badgeColor),
                    AppColors.parseHexColor(reputation!.badgeColor).withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    reputation!.tierName.toUpperCase(),
                    style: text.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 4),

        Text(
          username,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
