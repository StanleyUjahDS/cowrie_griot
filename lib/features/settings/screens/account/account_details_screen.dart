import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../users/providers/user_provider.dart';
import '../../../users/models/user_model.dart';

import 'username_edit_sheet.dart';
import 'display_name_edit_sheet.dart';
import 'bio_edit_sheet.dart';

import 'widgets/identity_card.dart';
import 'widgets/profile_avatar.dart';
import 'widgets/profile_field.dart';
import 'widgets/section_label.dart';
import 'widgets/settings_container.dart';

class AccountDetailsScreen extends StatelessWidget {
  const AccountDetailsScreen({
    super.key,
  });

  // ============================================================
  // EDIT USERNAME
  // ============================================================

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

  // ============================================================
  // EDIT DISPLAY NAME
  // ============================================================

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

  // ============================================================
  // EDIT BIO
  // ============================================================

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

  // ============================================================
  // VALUE
  // ============================================================

  String _valueOrFallback(
      String? value,
      String fallback,
      ) {
    if (value == null || value.trim().isEmpty) {
      return fallback;
    }

    return value.trim();
  }

  // ============================================================
  // USERNAME
  // ============================================================

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

  // ============================================================
  // REFERRAL
  // ============================================================

  String _referralIdentifier(
      String? username,
      ) {
    final value = _valueOrFallback(
      username,
      'username',
    ).trim();

    if (value.startsWith('@')) {
      return value.substring(1);
    }

    return value;
  }

  // ============================================================
  // WALLET DISPLAY
  // ============================================================

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

  // ============================================================
  // BUILD
  // ============================================================

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
    final referralIdentifier = _referralIdentifier(user?.username);
    final avatarUrl = user?.avatarUrl;

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Your Griot Account'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      child: RefreshIndicator(
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
              bio: rawBio,
              reputation: user?.reputation,
              onEditBio: () => _editBio(context, rawBio),
            ),
            const SizedBox(height: 28),
            const SectionLabel(title: 'Profile'),
            SettingsContainer(
              children: [
                ProfileField(
                  icon: Icons.badge_outlined,
                  title: 'Display Name',
                  value: displayName,
                  onTap: () => _editDisplayName(context, displayName == 'Your name' ? '' : displayName),
                ),
                const SettingsDivider(),
                ProfileField(
                  icon: Icons.alternate_email_rounded,
                  title: 'Griot Username',
                  value: username,
                  onTap: () => _editUsername(context, username == '@username' ? '' : username),
                ),
                const SettingsDivider(),
                ProfileField(
                  icon: Icons.link_rounded,
                  title: 'Referral Code',
                  value: referralIdentifier,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionLabel(title: 'Identity'),
            const IdentityCard(),
            const SizedBox(height: 12),
            SettingsContainer(
              children: [
                ProfileField(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Wallet Address',
                  value: _walletDisplay(walletAddress),
                  onTap: () {},
                ),
                const SettingsDivider(),
                ProfileField(
                  icon: Icons.qr_code_2_rounded,
                  title: 'My QR Code',
                  value: 'Share your Griot identity',
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionLabel(title: 'Discovery'),
            SettingsContainer(
              children: [
                ProfileField(
                  icon: Icons.share_outlined,
                  title: 'Share Profile',
                  value: 'Share your Griot profile',
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 28),
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
          ],
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final String username;
  final String bio;
  final UserReputationBadge? reputation;
  final VoidCallback onEditBio;

  const _ProfileHero({
    required this.avatarUrl,
    required this.displayName,
    required this.username,
    required this.bio,
    this.reputation,
    required this.onEditBio,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    final hasBio = bio.trim().isNotEmpty;

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
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.4),
        ),
        const SizedBox(height: 4),
        Text(
          username,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: colors.primary, fontWeight: FontWeight.w600),
        ),
        if (reputation != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.parseHexColor(reputation!.badgeColor).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppColors.parseHexColor(reputation!.badgeColor).withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.parseHexColor(reputation!.badgeColor).withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  size: 20,
                  color: AppColors.parseHexColor(reputation!.badgeColor),
                ),
                const SizedBox(width: 8),
                Text(
                  reputation!.tierName.toUpperCase(),
                  style: text.labelLarge?.copyWith(
                    color: AppColors.parseHexColor(reputation!.badgeColor),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onEditBio,
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 17, 15, 17),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.outline.withValues(alpha: 0.10)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(Icons.info_outline_rounded, size: 21, color: colors.primary),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bio',
                          style: text.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          hasBio ? bio : 'Tell people a little about yourself',
                          style: text.bodyMedium?.copyWith(
                            color: hasBio ? colors.onSurface : colors.onSurfaceVariant,
                            height: 1.5,
                            fontStyle: hasBio ? FontStyle.normal : FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined, size: 15, color: colors.primary),
                            const SizedBox(width: 5),
                            Text(
                              'Edit bio',
                              style: text.labelMedium?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
