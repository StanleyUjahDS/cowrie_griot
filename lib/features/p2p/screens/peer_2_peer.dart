import 'package:flutter/material.dart';

class P2PScreen extends StatelessWidget {
  const P2PScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_alt, size: 64),
            const SizedBox(height: 16),
            Text('P2P Transfer', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Send and receive money from other users.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}