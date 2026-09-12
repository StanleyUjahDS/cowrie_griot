import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/widgets/griot_plus_badge.dart';
import '../models/chat_user.dart';
import '../providers/messaging_provider.dart';

class ChatListItem extends StatelessWidget {
  final ChatUser user;
  final String time;
  final VoidCallback? onTap;
  final VoidCallback? onAvatarTap;

  const ChatListItem({
    super.key,
    required this.user,
    required this.time,
    this.onTap,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final profileUrl = user.profileUrl;
    final hasProfileImage = profileUrl != null && profileUrl.trim().isNotEmpty;

    final bool isOnline =
        context.watch<MessagingProvider>().presenceMap[user.id] == true ||
        user.isOnline;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border(
          top: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.6),
            width: 1.2,
          ),
          bottom: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap:
              onTap ??
              () {
                context.push('/chat/user/${user.id}', extra: user);
              },
          onLongPress: onAvatarTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // ==========================================================
                // PROFILE IMAGE + ONLINE STATUS
                // ==========================================================
                Hero(
                  tag: 'user_avatar_${user.id}',
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          backgroundImage: hasProfileImage
                              ? NetworkImage(profileUrl)
                              : null,
                          child: !hasProfileImage
                              ? SvgPicture.asset(
                                  'assets/coins_logo/hbadger_logo.svg',
                                )
                              : null,
                        ),
                        if (isOnline)
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colorScheme.surface,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // ==========================================================
                // INFO CONTENT
                // ==========================================================
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.effectiveDisplayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (user.reputation != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.parseHexColor(
                                    user.reputation!.badgeColor,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border(
                                    top: BorderSide(
                                      color: AppColors.parseHexColor(
                                        user.reputation!.badgeColor,
                                      ).withValues(alpha: 0.3),
                                      width: 1.0,
                                    ),
                                    bottom: BorderSide(
                                      color: AppColors.parseHexColor(
                                        user.reputation!.badgeColor,
                                      ).withValues(alpha: 0.3),
                                      width: 1.0,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.stars_rounded,
                                      size: 10,
                                      color: AppColors.parseHexColor(
                                        user.reputation!.badgeColor,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      user.reputation!.tierName.toUpperCase(),
                                      style: TextStyle(
                                        color: AppColors.parseHexColor(
                                          user.reputation!.badgeColor,
                                        ),
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (user.isPlus) ...[
                            const SizedBox(width: 6),
                            const GriotPlusBadge(isPlus: true, compact: true),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.lastMessage.trim().isNotEmpty
                            ? user.lastMessage
                            : user.formattedUsername ?? user.shortWalletAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                          fontWeight: user.unreadCount > 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // ==========================================================
                // TIME + UNREAD COUNT
                // ==========================================================
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: textTheme.labelSmall?.copyWith(
                        color: user.unreadCount > 0
                            ? (colorScheme.primary.computeLuminance() > 0.6
                                  ? colorScheme.onSurface
                                  : colorScheme.primary)
                            : colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.4,
                              ),
                        fontWeight: user.unreadCount > 0
                            ? FontWeight.w900
                            : FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (user.unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          user.unreadCount > 99
                              ? '99+'
                              : user.unreadCount.toString(),
                          style: TextStyle(
                            color: colorScheme.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.done_all_rounded,
                        size: 16,
                        color: colorScheme.primary.withValues(alpha: 0.3),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
