import 'package:flutter/material.dart';
import '../../../core/ui/widgets/griot_avatar.dart';

class WalletHeader extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final Widget addressCard;
  final VoidCallback onNotificationsTap;
  final VoidCallback onScanTap;
  final VoidCallback? onProfileTap;

  const WalletHeader({
    super.key,
    required this.displayName,
    this.avatarUrl,
    required this.addressCard,
    required this.onNotificationsTap,
    required this.onScanTap,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 10, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: onProfileTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.primary,
                        colors.primary.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: GriotAvatar(
                      avatarUrl: avatarUrl,
                      radius: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onProfileTap,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
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
}
