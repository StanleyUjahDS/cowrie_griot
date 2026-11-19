import 'package:flutter/material.dart';

import '../../../core/ui/widgets/griot_branded_container.dart';

/// Card-shaped loading state used anywhere a Tale or Campfire card will be
/// rendered. Keeping the same header, text, media and action proportions as
/// the real card prevents the feed from jumping when data arrives.
class CampCardShimmer extends StatefulWidget {
  const CampCardShimmer({super.key, required this.tale, this.count = 3});

  final bool tale;
  final int count;

  @override
  State<CampCardShimmer> createState() => _CampCardShimmerState();
}

class _CampCardShimmerState extends State<CampCardShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = (_controller.value * 2.4) - 1.2;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(progress - 1.2, 0),
            end: Alignment(progress + 1.2, 0),
            colors: [
              colors.surfaceContainerHighest.withValues(alpha: .45),
              colors.surfaceContainerHighest.withValues(alpha: .95),
              colors.surfaceContainerHighest.withValues(alpha: .45),
            ],
            stops: const [0, .5, 1],
          ).createShader(bounds),
          child: child,
        );
      },
      child: Column(
        children: List.generate(
          widget.count,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _card(context, colors),
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, ColorScheme colors) {
    return GriotBrandedContainer(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _block(44, 44, radius: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _block(widget.tale ? 132 : 155, 14),
                    const SizedBox(height: 7),
                    _block(widget.tale ? 112 : 178, 10),
                  ],
                ),
              ),
              _block(widget.tale ? 58 : 62, 22, radius: 11),
              const SizedBox(width: 8),
              _block(20, 24, radius: 10),
            ],
          ),
          const SizedBox(height: 13),
          if (widget.tale) ...[
            Row(
              children: [
                _block(108, 11, radius: 6),
                const SizedBox(width: 8),
                Expanded(child: _block(double.infinity, 1, radius: 1)),
              ],
            ),
            const SizedBox(height: 14),
          ],
          _block(double.infinity, 16),
          const SizedBox(height: 8),
          _block(double.infinity, 16),
          const SizedBox(height: 8),
          FractionallySizedBox(
            widthFactor: widget.tale ? .68 : .78,
            child: _block(double.infinity, 16),
          ),
          const SizedBox(height: 14),
          _block(double.infinity, widget.tale ? 208 : 82, radius: 18),
          const SizedBox(height: 13),
          Divider(height: 1, color: colors.outlineVariant.withValues(alpha: .35)),
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(widget.tale ? 5 : 4, (_) => _block(40, 20, radius: 10)),
          ),
          if (widget.tale) ...[
            const SizedBox(height: 10),
            _block(double.infinity, 30, radius: 12),
          ],
        ],
      ),
    );
  }

  Widget _block(double width, double height, {double radius = 7}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
