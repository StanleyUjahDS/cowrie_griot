import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class NotificationService {
  // ============================================================
  // SUCCESS
  // ============================================================

  static void showSuccess(BuildContext context, String message) {
    final colors = Theme.of(context).colorScheme;

    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.flatColored,
      primaryColor: colors.primary,
      title: Text(message, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 3),
      borderRadius: BorderRadius.circular(100),
      boxShadow: [
        BoxShadow(
          color: colors.primary.withValues(alpha: 0.1),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
      showProgressBar: false,
      animationDuration: const Duration(milliseconds: 300),
      icon: Icon(Icons.check_circle_rounded, color: colors.primary),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  static void showError(BuildContext context, String message) {
    final colors = Theme.of(context).colorScheme;
    final parsedMessage = _parseErrorMessage(message);

    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.flatColored,
      title: Text('Action Failed', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: colors.error)),
      description: Text(parsedMessage, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 5),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: colors.error.withValues(alpha: 0.15),
          blurRadius: 30,
          offset: const Offset(0, 10),
        ),
      ],
      showProgressBar: true,
      applyBlurEffect: true,
    );
  }

  // ============================================================
  // INFO
  // ============================================================

  static void showInfo(BuildContext context, String message) {
    final colors = Theme.of(context).colorScheme;

    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.flatColored,
      primaryColor: colors.secondary,
      title: Text(message, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 3),
      borderRadius: BorderRadius.circular(100),
      showProgressBar: false,
      icon: Icon(Icons.info_outline_rounded, color: colors.secondary),
    );
  }

  // ==========================================================
  // IN-APP NOTIFICATIONS (BRANDED)
  // ==========================================================

  static void showFriendRequest(BuildContext context, {required String name, String? avatarUrl, VoidCallback? onTap}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    toastification.showCustom(
      context: context,
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 6),
      builder: (context, holder) {
        return GestureDetector(
          onTap: () {
            toastification.dismiss(holder);
            onTap?.call();
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(color: colors.primary.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colors.primary.withValues(alpha: 0.1),
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null ? Icon(Icons.person_rounded, color: colors.primary) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('CHAT REQUEST', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 1)),
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      Text('Wants to connect on Griot', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant.withValues(alpha: 0.5)),
              ],
            ),
          ),
        );
      },
    );
  }

  static void showTipReceived(BuildContext context, {required String amount, required String symbol, required String fromName}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    toastification.showCustom(
      context: context,
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 5),
      builder: (context, holder) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(color: Colors.amber.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.volunteer_activism_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 12),
              Text(
                'Received ',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
              ),
              Text(
                '$amount $symbol ',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.amber),
              ),
              Text(
                'from $fromName!',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        );
      },
    );
  }

  static void showAnnouncement(BuildContext context, {required String title, required String message}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    toastification.showCustom(
      context: context,
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 8),
      builder: (context, holder) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colors.primary.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(color: colors.primary.withValues(alpha: 0.2), blurRadius: 25, offset: const Offset(0, 12)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Image.asset('assets/coins_logo/ic_launcher.png', width: 16, height: 16),
                  const SizedBox(width: 8),
                  Text(
                    'GRIOT OFFICIAL',
                    style: TextStyle(color: colors.primary, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 10),
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.close_rounded, size: 16, color: colors.onSurfaceVariant),
                    onPressed: () => toastification.dismiss(holder),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 2),
              Text(message, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12, height: 1.4)),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // ERROR PARSER (INTERNAL)
  // ============================================================

  static String _parseErrorMessage(String rawMessage) {
    var msg = rawMessage.trim();
    if (msg.startsWith('Exception: ')) msg = msg.substring(11);
    if (msg.startsWith('Transaction failed: ')) msg = msg.substring(20);
    if (msg.startsWith('Swap failed: ')) msg = msg.substring(13);

    final lower = msg.toLowerCase();
    if (lower.contains('insufficient funds')) return "Insufficient funds for gas fees.";
    if (lower.contains('insufficient balance')) return "Insufficient wallet balance.";
    if (lower.contains('user rejected') || lower.contains('canceled')) return "Transaction canceled.";

    if (lower.contains('transaction=') || lower.contains('code=') || lower.contains('version=')) {
      final regExp = RegExp(r'"message"\s*:\s*"([^"]+)"');
      final match = regExp.firstMatch(msg);
      if (match != null && match.groupCount >= 1) {
        return _parseErrorMessage(match.group(1)!);
      }
      return "Blockchain error. Check your gas balance.";
    }
    return msg;
  }
}
