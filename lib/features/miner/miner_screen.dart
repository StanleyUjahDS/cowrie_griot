import 'package:flutter/material.dart';

class MinerScreen extends StatelessWidget {
  const MinerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.memory, size: 64),
            const SizedBox(height: 16),
            Text('Miner', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Mining dashboard and rewards will appear here.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}