import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

class P2PLoading extends StatelessWidget {
  const P2PLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const _DummyOfferCard(),
          childCount: 5,
        ),
      ),
    );
  }
}

class _DummyOfferCard extends StatelessWidget {
  const _DummyOfferCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(radius: 23),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 120, height: 14, color: Colors.grey),
                      const SizedBox(height: 6),
                      Container(width: 80, height: 10, color: Colors.grey),
                    ],
                  ),
                ),
                const Icon(Icons.star, size: 16),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    Container(width: 40, height: 10, color: Colors.grey),
                    const SizedBox(height: 6),
                    Container(width: 70, height: 18, color: Colors.grey),
                  ],
                ),
                Column(
                  children: [
                    Container(width: 40, height: 10, color: Colors.grey),
                    const SizedBox(height: 6),
                    Container(width: 90, height: 14, color: Colors.grey),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(width: double.infinity, height: 40, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
