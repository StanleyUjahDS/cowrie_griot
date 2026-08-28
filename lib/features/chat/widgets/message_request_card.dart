import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../models/message_request.dart';
import '../../users/models/user_model.dart';

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
    final hasProfileImage = profileUrl != null && profileUrl.trim().isNotEmpty;

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
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: colors.surfaceContainerHighest,
                      backgroundImage: hasProfileImage ? NetworkImage(profileUrl) : null,
                      child: !hasProfileImage 
                        ? SvgPicture.asset('assets/coins_logo/hbadger_logo.svg', width: 32, height: 32)
                        : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                          Text(
                            request.formattedUsername ?? 'Griot User',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.primary,
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
                        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (request.message.trim().isNotEmpty) ...[
                  Text(
                    request.message,
                    style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant, height: 1.5),
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
  final bool isFilled;

  const _ActionButton({
    required this.label,
    required this.onTap,
    required this.color,
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
            color: isFilled ? Colors.white : color,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
