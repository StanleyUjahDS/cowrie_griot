import 'package:flutter/material.dart';
import '../../../../core/ui/widgets/griot_loader.dart';
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
    switch (status) {
      case MessageStatus.sending:
        return GriotPulseIndicator(color: color, size: 14);
      case MessageStatus.sent:
        return _GriotSentMark(color: color);
      case MessageStatus.delivered:
        return _GriotDeliveredMark(color: color);
      case MessageStatus.read:
        return _GriotSeenMark(color: color);
      case MessageStatus.failed:
        return _GriotFailedMark(color: color);
    }
  }
}

// Remove the private _GriotSendingMark since we are using GriotPulseIndicator now

class _GriotSentMark extends StatelessWidget {
  final Color color;
  const _GriotSentMark({required this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.check_rounded,
      size: 15,
      color: color.withValues(alpha: 0.45),
    );
  }
}

class _GriotDeliveredMark extends StatelessWidget {
  final Color color;
  const _GriotDeliveredMark({required this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.done_all_rounded,
      size: 15,
      color: color.withValues(alpha: 0.45),
    );
  }
}

class _GriotSeenMark extends StatelessWidget {
  final Color color;
  const _GriotSeenMark({required this.color});

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.done_all_rounded,
      size: 15,
      color: Color(0xFF34B7F1), // WhatsApp blue ticks color
    );
  }
}

class _GriotFailedMark extends StatelessWidget {
  final Color color;
  const _GriotFailedMark({required this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.warning_amber_rounded,
      size: 14,
      color: Theme.of(context).colorScheme.error,
    );
  }
}
