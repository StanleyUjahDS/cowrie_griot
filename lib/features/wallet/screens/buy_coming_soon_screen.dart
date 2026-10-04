import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BuyComingSoonScreen extends StatelessWidget {
  const BuyComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buy & sell crypto'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: 46,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Buy & sell crypto is coming soon',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'We are putting the finishing touches on our secure trading partners. You can still swap assets or receive crypto in your wallet.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => context.push('/wallet/swap'),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Swap assets instead'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
