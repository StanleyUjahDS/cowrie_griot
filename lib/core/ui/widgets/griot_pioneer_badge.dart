import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Companion shield badge for members recognised as Griot pioneers.
class GriotPioneerBadge extends StatelessWidget {
  final bool compact;

  const GriotPioneerBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    // Keep Pioneer and Plus badges optically aligned everywhere they appear.
    // The shared compact size is used beside names; regular badges are used
    // in cards and feature screens.
    final size = compact ? 16.0 : 24.0;
    return Semantics(
      label: 'Griot Pioneer',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _PioneerBadgePainter()),
      ),
    );
  }
}

class _PioneerBadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
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
    canvas.drawPath(
      shield,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFDFF7EF), Color(0xFF62C9A4), Color(0xFF168267)],
        ).createShader(rect),
    );
    canvas.drawPath(
      shield,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * .045
        ..color = const Color(0xFFE9FFF7),
    );

    final center = rect.center;
    final outer = size.shortestSide * .27;
    final inner = outer * .42;
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? outer : inner;
      final angle = -3.1415926535 / 2 + i * 3.1415926535 / 5;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = const Color(0xFF126B57));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
