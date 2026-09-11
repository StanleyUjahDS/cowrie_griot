import 'package:flutter/material.dart';
import '../../../../core/ui/scaffolds/gradient_scaffold.dart';

class AboutGriotScreen extends StatelessWidget {
  const AboutGriotScreen({super.key});
  @override
  Widget build(BuildContext context) => GradientScaffold(
    appBar: AppBar(
      title: const Text('About Griot'),
      surfaceTintColor: Colors.transparent,
    ),
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(
          Icons.hub_rounded,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Griot',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'A community-owned social and wallet experience.',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),
        const ListTile(
          leading: Icon(Icons.verified_outlined),
          title: Text('Version'),
          subtitle: Text('1.0.0'),
        ),
        const ListTile(
          leading: Icon(Icons.security_outlined),
          title: Text('Your keys stay yours'),
          subtitle: Text('Griot never stores your wallet recovery phrase.'),
        ),
      ],
    ),
  );
}
