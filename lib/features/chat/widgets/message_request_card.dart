import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/message_request.dart';
import '../../users/models/user_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/griot_plus_badge.dart';
import '../../../../core/ui/widgets/griot_pioneer_badge.dart';
import '../../../../core/ui/widgets/griot_avatar.dart';

class MessageRequestCard extends StatelessWidget {
  final MessageRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const MessageRequestCard({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;

    final profileUrl = request.senderProfileUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final user = UserModel(
              id: request.senderId ?? '',
              walletAddress: request.senderWalletAddress,
              username: request.senderUsername,
              displayName: request.senderDisplayName,
              avatarUrl: request.senderProfileUrl,
              relationshipStatus: 'request_received',
              isPlus: request.senderIsPlus,
              isPioneer: request.senderIsPioneer,
            );
            context.push('/user/profile', extra: user);
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GriotAvatar(
                      avatarUrl: profileUrl,
                      radius: 26,
                      backgroundColor: colors.surfaceContainerHighest,
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
                                  request.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (request.senderIsPlus) ...[
                                const SizedBox(width: 6),
                                const GriotPlusBadge(
                                  isPlus: true,
                                  compact: true,
                                ),
                              ],
                              if (request.senderIsPioneer) ...[
                                const SizedBox(width: 4),
                                const GriotPioneerBadge(compact: true),
                              ],
                            ],
                          ),
                          Text(
                            request.formattedUsername ?? 'Griot User',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.primary.computeLuminance() > 0.6
                                  ? colors.onSurfaceVariant
                                  : colors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (request.senderIsOnline)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (request.message.trim().isNotEmpty) ...[
                  Text(
                    request.message,
                    style: text.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'Decline',
                        onTap: onDecline,
                        color: colors.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        label: 'Accept',
                        onTap: onAccept,
                        color: colors.primary,
                        foregroundColor: colors.onPrimary,
                        isFilled: true,
                      ),
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

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color? foregroundColor;
  final bool isFilled;

  const _ActionButton({
    required this.label,
    required this.onTap,
    required this.color,
    this.foregroundColor,
    this.isFilled = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isFilled ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isFilled ? (foregroundColor ?? color) : color,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
