import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ShimmerList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final double padding;
  final double topPadding;

  const ShimmerList({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 72,
    this.padding = 16.0,
    this.topPadding = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        padding: EdgeInsets.only(top: topPadding, left: padding, right: padding),
        itemCount: itemCount,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return const _ShimmerListItem();
        },
      ),
    );
  }
}

class _ShimmerListItem extends StatelessWidget {
  const _ShimmerListItem();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const CircleAvatar(radius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 14,
                  margin: const EdgeInsets.only(right: 40),
                  color: Colors.grey,
                ),
                const SizedBox(height: 8),
                Container(
                  width: 120,
                  height: 10,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
