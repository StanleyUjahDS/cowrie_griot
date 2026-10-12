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
    return CustomPaint(
      size: const Size(15, 15),
      painter: _GriotSentReceiptPainter(color.withValues(alpha: 0.95)),
    );
  }
}

class _GriotDeliveredMark extends StatelessWidget {
  final Color color;
  const _GriotDeliveredMark({required this.color});

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(19, 15),
    painter: _GriotDeliveredReceiptPainter(color.withValues(alpha: 0.92)),
  );
}

class _GriotDeliveredReceiptPainter extends CustomPainter {
  final Color color;
  const _GriotDeliveredReceiptPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.45
      ..strokeCap = StrokeCap.round;
    for (final x in <double>[size.width * .35, size.width * .65]) {
      final center = Offset(x, size.height * .5);
      canvas.drawCircle(center, size.shortestSide * .23, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GriotDeliveredReceiptPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Compact target-style mark for a sent message.
class _GriotSentReceiptPainter extends CustomPainter {
  final Color color;

  const _GriotSentReceiptPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);
    // Sent is intentionally a single orbit. Delivery uses the paired mark
    // below, while read uses the larger seal/orbit treatment.
    canvas.drawCircle(center, size.shortestSide * .34, paint);
    canvas.drawLine(
      Offset(size.width * .5, size.height * .04),
      Offset(size.width * .5, size.height * .18),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * .5, size.height * .82),
      Offset(size.width * .5, size.height * .96),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GriotSentReceiptPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _GriotSeenMark extends StatelessWidget {
  final Color color;
  const _GriotSeenMark({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(19, 15),
      painter: _GriotReadReceiptPainter(color.withValues(alpha: 0.98)),
    );
  }
}

/// Griot's own read-receipt mark: a friendly orbit/seal symbol rather than
/// the conventional chat-app checkmarks.
class _GriotReadReceiptPainter extends CustomPainter {
  final Color color;

  const _GriotReadReceiptPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width * .5, size.height * .5);
    // Seen uses the same target language as sent, but with a solid centre.
    canvas.drawCircle(center, size.shortestSide * .38, paint);
    canvas.drawCircle(center, size.shortestSide * .20, paint);
    final rays = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .5, size.height * .04),
      Offset(size.width * .5, size.height * .18),
      rays,
    );
    canvas.drawLine(
      Offset(size.width * .5, size.height * .82),
      Offset(size.width * .5, size.height * .96),
      rays,
    );
    canvas.drawLine(
      Offset(size.width * .04, size.height * .5),
      Offset(size.width * .18, size.height * .5),
      rays,
    );
    canvas.drawLine(
      Offset(size.width * .82, size.height * .5),
      Offset(size.width * .96, size.height * .5),
      rays,
    );

    final pupil = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size.shortestSide * .13, pupil);
  }

  @override
  bool shouldRepaint(covariant _GriotReadReceiptPainter oldDelegate) =>
      oldDelegate.color != color;
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
