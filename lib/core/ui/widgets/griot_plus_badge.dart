import 'package:flutter/material.dart';

/// A small, consistent indicator for users with an active Griot Plus plan.
class GriotPlusBadge extends StatelessWidget {
  final bool isPlus;
  final bool compact;

  const GriotPlusBadge({super.key, required this.isPlus, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (!isPlus) return const SizedBox.shrink();
    // Compact badges sit beside names in chat/home rows; keep them subtle so
    // they identify Plus without competing with the avatar or name.
    final size = compact ? 16.0 : 24.0;
    return Semantics(
      label: 'Griot Plus',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          key: const ValueKey('griot-plus-shield-v1'),
          painter: _GriotPlusBadgePainter(),
        ),
      ),
    );
  }
}

/// Gold premium shield badge with a transparent Plus cut-out.
class _GriotPlusBadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.saveLayer(rect, Paint());
    final badgePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF0A8), Color(0xFFFFC247), Color(0xFFB66C16)],
      ).createShader(rect);

    final inset = size.shortestSide * .06;
    final w = size.width;
    final h = size.height;
    final shield = Path()
      ..moveTo(w / 2, inset)
      ..lineTo(w - inset, h * .25)
      ..lineTo(w - inset * 1.3, h * .58)
      ..cubicTo(w * .9, h * .78, w * .68, h * .91, w / 2, h - inset)
      ..cubicTo(w * .32, h * .91, w * .1, h * .78, inset * 1.3, h * .58)
      ..lineTo(inset, h * .25)
      ..close();
    canvas.drawPath(shield, badgePaint);

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * .045
      ..color = const Color(0xFFFFF1AE);
    canvas.drawPath(shield, outline);

    final center = rect.center;
    final plusArm = size.shortestSide * .12;

    final transparentPlus = Paint()
      ..blendMode = BlendMode.clear
      ..strokeWidth = size.shortestSide * .085
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx - plusArm, center.dy),
      Offset(center.dx + plusArm, center.dy),
      transparentPlus,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - plusArm),
      Offset(center.dx, center.dy + plusArm),
      transparentPlus,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
