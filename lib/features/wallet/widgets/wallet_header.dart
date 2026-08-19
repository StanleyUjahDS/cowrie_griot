import 'package:flutter/material.dart';

class WalletHeader extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final Widget addressCard;
  final VoidCallback onNotificationsTap;
  final VoidCallback onScanTap;

  const WalletHeader({
    super.key,
    required this.displayName,
    this.avatarUrl,
    required this.addressCard,
    required this.onNotificationsTap,
    required this.onScanTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 10, 0),
      child: Row(
        children: [
          _buildAvatar(colors),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                addressCard,
              ],
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            visualDensity: VisualDensity.compact,
            onPressed: onNotificationsTap,
            icon: Icon(
              Icons.notifications_none_rounded,
              color: colors.onSurfaceVariant,
            ),
          ),
          IconButton(
            tooltip: 'Scan QR code',
            visualDensity: VisualDensity.compact,
            onPressed: onScanTap,
            icon: Icon(
              Icons.qr_code_scanner_rounded,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(ColorScheme colors) {
    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 23,
        backgroundColor: colors.surfaceContainerHighest,
        backgroundImage: NetworkImage(avatarUrl!),
      );
    }

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.primary.withValues(alpha: 0.10),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Icon(
        Icons.person_outline_rounded,
        color: colors.primary,
        size: 23,
      ),
    );
  }
}
