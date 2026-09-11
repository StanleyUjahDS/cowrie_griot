import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../users/providers/user_preference_provider.dart';
import '../../../../core/ui/widgets/griot_loader.dart';
import '../../../../core/services/notification_service.dart';

class ChatSettingsScreen extends StatelessWidget {
  const ChatSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PreferencePage(
    title: 'Chat Settings',
    items: [
      _PreferenceItem(
        'Message previews',
        'Show message text in notifications',
        'message_preview',
      ),
      _PreferenceItem(
        'Read receipts',
        'Let contacts know when messages are read',
        'read_receipts',
      ),
      _PreferenceItem(
        'Typing indicators',
        'Show when you are typing',
        'typing_indicators',
      ),
    ],
  );
}

class ChatPrivacyScreen extends StatelessWidget {
  const ChatPrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PreferencePage(
    title: 'Chat Privacy',
    items: [
      _PreferenceItem(
        'Online status',
        'Allow friends to see when you are online',
        'online_status_visibility',
      ),
      _PreferenceItem(
        'Read receipts',
        'Share message read status',
        'read_receipts',
      ),
    ],
  );
}

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PreferencePage(
    title: 'Privacy',
    items: [
      _PreferenceItem(
        'Profile discoverability',
        'Allow your profile to appear in discovery',
        'profile_discoverability',
      ),
      _PreferenceItem(
        'Online status',
        'Show your online status to friends',
        'online_status_visibility',
      ),
    ],
  );
}

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PreferencePage(
    title: 'Notifications',
    items: [
      _PreferenceItem(
        'Chat notifications',
        'Receive notifications for new messages',
        'chat_notifications',
      ),
      _PreferenceItem(
        'Message previews',
        'Include a short preview in notifications',
        'message_preview',
      ),
    ],
  );
}

class _PreferenceItem {
  final String title, subtitle, keyName;
  const _PreferenceItem(this.title, this.subtitle, this.keyName);
}

class _PreferencePage extends StatefulWidget {
  final String title;
  final List<_PreferenceItem> items;
  const _PreferencePage({required this.title, required this.items});
  @override
  State<_PreferencePage> createState() => _PreferencePageState();
}

class _PreferencePageState extends State<_PreferencePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserPreferenceProvider>().loadPreferences();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Consumer<UserPreferenceProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.preferences.isEmpty) {
            return const Center(child: GriotLoader());
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: widget.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final item = widget.items[i];
              final value = provider.preferences[item.keyName] ?? true;

              return Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.outline.withValues(alpha: 0.1),
                  ),
                ),
                child: SwitchListTile.adaptive(
                  value: value,
                  onChanged: (v) async {
                    try {
                      await provider.updatePreference(item.keyName, v);
                    } catch (e) {
                      if (context.mounted) {
                        NotificationService.showError(
                          context,
                          'Failed to save setting',
                        );
                      }
                    }
                  },
                  activeThumbColor: colors.primary,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  title: Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    item.subtitle,
                    style: TextStyle(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
