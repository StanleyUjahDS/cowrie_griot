import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../../features/local_auth/providers/app_lock_provider.dart';
import '../../../../features/local_auth/services/local_auth_service.dart';
import '../account/widgets/section_label.dart';
import '../account/widgets/settings_container.dart';

class AppSecurityScreen extends StatelessWidget {
  const AppSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;
    final lockProvider = context.watch<AppLockProvider>();

    return GradientScaffold(
      appBar: AppBar(
        title: const Text(
          'App Security',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          const SectionLabel(title: 'Lock Settings'),
          SettingsContainer(
            children: [
              _SwitchTile(
                icon: Icons.lock_outline_rounded,
                title: 'App Lock',
                subtitle: 'Require PIN to open the app',
                value: lockProvider.isEnabled,
                onChanged: (value) async {
                  if (value) {
                    // Check if PIN exists first
                    final authService = context.read<LocalAuthService>();
                    final hasPin = await authService.hasPin();
                    if (!context.mounted) return;
                    
                    if (hasPin) {
                      await lockProvider.setEnabled(true);
                    } else {
                      // Navigate to set PIN
                      context.push('/set_password');
                    }
                  } else {
                    await lockProvider.setEnabled(false);
                  }
                },
              ),
              if (lockProvider.isEnabled) ...[
                const SettingsDivider(),
                _SwitchTile(
                  icon: Icons.fingerprint_rounded,
                  title: 'Biometric Unlock',
                  subtitle: 'Use Face ID or Fingerprint',
                  value: lockProvider.biometricEnabled,
                  onChanged: (value) async {
                    if (value) {
                      final authService = context.read<LocalAuthService>();
                      final available = await authService.biometricsAvailable();
                      if (!context.mounted) return;
                      
                      if (available) {
                        final success = await authService.authenticateWithBiometrics();
                        if (!context.mounted) return;
                        
                        if (success) {
                          await lockProvider.setBiometricEnabled(true);
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Biometrics not available on this device')),
                        );
                      }
                    } else {
                      await lockProvider.setBiometricEnabled(false);
                    }
                  },
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 24),
          const SectionLabel(title: 'Configuration'),
          SettingsContainer(
            children: [
              _ActionTile(
                icon: Icons.timer_outlined,
                title: 'Auto-lock Duration',
                value: _formatDuration(lockProvider.autoLockDuration),
                onTap: () => _showDurationPicker(context, lockProvider),
              ),
              const SettingsDivider(),
              _ActionTile(
                icon: Icons.password_rounded,
                title: 'Change PIN',
                onTap: () async {
                  final authService = context.read<LocalAuthService>();
                  final hasPin = await authService.hasPin();

                  if (!context.mounted) return;

                  if (hasPin) {
                    context.push('/verify_pin', extra: (BuildContext ctx) async {
                      if (ctx.mounted) {
                        ctx.pushReplacement('/set_password', extra: (BuildContext ctx2) async {
                          // After new PIN is confirmed, pop all the way back to security settings
                          if (ctx2.mounted) {
                            ctx2.pop(); 
                          }
                        });
                      }
                    });
                  } else {
                    context.push('/set_password');
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.primary.withValues(alpha: 0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: colors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'App lock protects your wallet and conversations when the app is in the background. Your PIN is stored securely on your device.',
                    style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ].animate(interval: 50.ms).fade(duration: 400.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutQuad),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes == 0) return 'Immediately';
    if (d.inMinutes < 60) return '${d.inMinutes} minutes';
    return '${d.inHours} hour${d.inHours > 1 ? 's' : ''}';
  }

  void _showDurationPicker(BuildContext context, AppLockProvider provider) {
    final options = [
      const Duration(minutes: 0),
      const Duration(minutes: 1),
      const Duration(minutes: 5),
      const Duration(minutes: 15),
      const Duration(minutes: 30),
      const Duration(hours: 1),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((d) => ListTile(
            title: Text(_formatDuration(d)),
            trailing: provider.autoLockDuration == d ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
            onTap: () {
              provider.setAutoLockDuration(d);
              Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: colors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: colors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Text(value!, style: TextStyle(color: colors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}
