import 'package:flutter/material.dart';

class AnimatedProgressBar extends StatelessWidget {
  final double value;
  final Color backgroundColor;
  final Color valueColor;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    required this.backgroundColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return LinearProgressIndicator(
          value: animatedValue,
          backgroundColor: backgroundColor,
          valueColor: AlwaysStoppedAnimation(valueColor),
          minHeight: 6,
          borderRadius: BorderRadius.circular(16),
        );
      },
    );
  }
}