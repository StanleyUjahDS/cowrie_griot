import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../models/chat_user.dart';

class ChatListItem extends StatelessWidget {
  final ChatUser user;
  final String time;

  const ChatListItem({
    super.key,
    required this.user,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final profileUrl = user.profileUrl;
    final hasProfileImage =
        profileUrl != null && profileUrl.trim().isNotEmpty;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 5,
      ),

      // ==========================================================
      // PROFILE IMAGE + ONLINE STATUS
      // ==========================================================

      leading: SizedBox(
        width: 54,
        height: 54,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor:
              colorScheme.surfaceContainerHighest,
              backgroundImage: hasProfileImage
                  ? NetworkImage(profileUrl)
                  : null,
              child: !hasProfileImage
                  ? Icon(
                Icons.person_rounded,
                color: colorScheme.onSurfaceVariant,
              )
                  : null,
            ),

            // ======================================================
            // ONLINE INDICATOR
            // ======================================================

            if (user.isOnline)
              Positioned(
                right: 0,
                bottom: 1,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.surface,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),

      // ==========================================================
      // NAME + PHONE DISCOVERY
      // ==========================================================

      title: Row(
        children: [
          Expanded(
            child: Text(
              user.effectiveDisplayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          if (user.reputation != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.parseHexColor(user.reputation!.badgeColor).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.parseHexColor(user.reputation!.badgeColor).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.stars_rounded,
                      size: 10,
                      color: AppColors.parseHexColor(user.reputation!.badgeColor),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      user.reputation!.tierName.toUpperCase(),
                      style: TextStyle(
                        color: AppColors.parseHexColor(user.reputation!.badgeColor),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (user.isDiscoverableByPhone)
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Icon(
                Icons.contacts_rounded,
                size: 15,
                color: colorScheme.primary,
              ),
            ),
        ],
      ),

      // ==========================================================
      // LAST MESSAGE / USERNAME / WALLET
      // ==========================================================

      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          user.lastMessage.trim().isNotEmpty
              ? user.lastMessage
              : user.formattedUsername ??
              user.shortWalletAddress,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),

      // ==========================================================
      // TIME + UNREAD COUNT
      // ==========================================================

      trailing: SizedBox(
        width: 42,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: user.unreadCount > 0
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: user.unreadCount > 0
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),

            const SizedBox(height: 6),

            if (user.unreadCount > 0)
              Container(
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  user.unreadCount > 99
                      ? '99+'
                      : user.unreadCount.toString(),
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),

      // ==========================================================
      // OPEN CHAT
      // ==========================================================

      onTap: () {
        context.push('/chat/${user.id}');
      },
    );
  }
}