import 'package:flutter/material.dart';
import '../../models/chat_message.dart';

class GriotMessageStatus extends StatelessWidget {
  final MessageStatus status;
  final Color color;

  const GriotMessageStatus({
    super.key,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      MessageStatus.sending => Icons.schedule_rounded,
      MessageStatus.sent => Icons.check_rounded,
      MessageStatus.delivered => Icons.done_all_rounded,
      MessageStatus.read => Icons.done_all_rounded,
      MessageStatus.failed => Icons.error_outline_rounded,
    };
    final iconColor = status == MessageStatus.failed
        ? Theme.of(context).colorScheme.error
        : color;
    return Icon(
      icon,
      size: status == MessageStatus.sent ? 15 : 17,
      color: iconColor,
      semanticLabel: _label(status),
    );
  }

  static String _label(MessageStatus status) => switch (status) {
    MessageStatus.sending => 'Sending',
    MessageStatus.sent => 'Sent',
    MessageStatus.delivered => 'Delivered',
    MessageStatus.read => 'Seen',
    MessageStatus.failed => 'Failed',
  };
}
