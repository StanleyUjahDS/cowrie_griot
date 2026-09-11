import 'package:flutter/material.dart';

/// Shared surface for modal bottom sheets so corners, borders, and drag
/// handles remain consistent across the app.
class GriotBottomSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const GriotBottomSheet({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
        border: Border(
          top: BorderSide(
            color: colors.primary.withValues(alpha: 0.38),
            width: 1,
          ),
        ),
      ),
      child: child,
    );
  }
}
