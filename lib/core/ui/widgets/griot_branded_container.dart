import 'dart:ui';
import 'package:flutter/material.dart';

class GriotBrandedContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blurSigma;
  final bool showBorder;
  final double? width;
  final double? height;

  const GriotBrandedContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = 24,
    this.blurSigma = 15,
    this.showBorder = true,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.10 : 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: isDark ? 0.70 : 0.80),
              borderRadius: BorderRadius.circular(borderRadius),
              border: showBorder
                  ? Border(
                      top: BorderSide(
                        color: colorScheme.primary.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                      bottom: BorderSide(
                        color: colorScheme.primary.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                    )
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
