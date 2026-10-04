import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../../core/ui/widgets/griot_branded_container.dart';

class AboutGriotScreen extends StatelessWidget {
  const AboutGriotScreen({super.key});

  Future<void> _openExternal(BuildContext context, String value) async {
    final opened = await launchUrl(
      Uri.parse(value),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this page.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => GradientScaffold(
    appBar: AppBar(
      title: const Text('About Griot'),
      surfaceTintColor: Colors.transparent,
    ),
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: Image.asset(
            'assets/coins_logo/ic_launcher.png',
            width: 88,
            height: 88,
            fit: BoxFit.contain,
          ),
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
        GriotBrandedContainer(
          padding: EdgeInsets.zero,
          borderRadius: 20,
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.verified_outlined),
                title: Text('Version'),
                subtitle: Text('1.0.5'),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.security_outlined),
                title: Text('Your keys stay yours'),
                subtitle: Text(
                  'Griot never stores your wallet recovery phrase.',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                subtitle: const Text(
                  'How Griot handles information and choices',
                ),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () => _openExternal(
                  context,
                  'https://griot.network/privacy-policy',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms and Conditions'),
                subtitle: const Text('The terms that apply to using Griot'),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () =>
                    _openExternal(context, 'https://griot.network/terms'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Community Guidelines'),
                subtitle: const Text(
                  'Rules for safe and respectful participation',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/settings/community-guidelines'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
