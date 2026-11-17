import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
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
        'Chat notifications',
        'Receive notifications for new messages',
        'chat_notifications',
      ),
      _PreferenceItem(
        'Message requests',
        'Notify me about new connection and message requests',
        'message_requests',
        section: 'Messages',
      ),
      _PreferenceItem(
        'Message reactions',
        'Notify me when someone reacts to a message I sent',
        'message_reactions',
        section: 'Messages',
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
      _PreferenceItem(
        'Profile discoverability',
        'Allow your profile to appear in discovery',
        'profile_discoverability',
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

  static const categories = <NotificationCategory>[
    NotificationCategory(
      slug: 'general',
      title: 'General',
      subtitle: 'Push permission and notification previews',
      icon: Icons.tune_rounded,
      items: [
        _PreferenceItem(
          'Allow push notifications',
          'Enable or silence all Griot push notifications on this account',
          'push_notifications',
        ),
        _PreferenceItem(
          'Social activity',
          'Receive connection and interaction updates',
          'social_notifications',
        ),
      ],
    ),
    NotificationCategory(
      slug: 'messages',
      title: 'Messages and calls',
      subtitle: 'Chats, requests, reactions and calls',
      icon: Icons.chat_bubble_outline_rounded,
      items: [
        _PreferenceItem(
          'Chat notifications',
          'Receive notifications for new messages',
          'chat_notifications',
        ),
        _PreferenceItem(
          'Call notifications',
          'Receive incoming and missed call alerts',
          'call_notifications',
        ),
        _PreferenceItem(
          'Message previews',
          'Include a short preview in notifications',
          'message_preview',
        ),
      ],
    ),
    NotificationCategory(
      slug: 'tales',
      title: 'Camp Tales',
      subtitle: 'Reactions, comments, retells and mentions',
      icon: Icons.menu_book_outlined,
      items: [
        _PreferenceItem(
          'Tale likes',
          'Notify me when someone likes (upvotes) my Tale',
          'tale_upvotes',
        ),
        _PreferenceItem(
          'Tale downvotes',
          'Notify me when someone downvotes my Tale',
          'tale_downvotes',
        ),
        _PreferenceItem(
          'Tale comments and replies',
          'Notify me when someone comments on or replies to my Tale',
          'tale_comments',
        ),
        _PreferenceItem(
          'Tale retells',
          'Notify me when someone retells my Tale',
          'tale_retells',
        ),
        _PreferenceItem(
          'Tale co-tells',
          'Notify me when someone co-tells or continues my Tale',
          'tale_cotells',
        ),
        _PreferenceItem(
          'Tale mentions and tags',
          'Notify me when I am mentioned or tagged in a Tale or comment',
          'tale_mentions',
        ),
      ],
    ),
    NotificationCategory(
      slug: 'campfires',
      title: 'Campfires',
      subtitle: 'Invitations, speakers, reminders and live activity',
      icon: Icons.local_fire_department_outlined,
      items: [
        _PreferenceItem(
          'Campfire notifications',
          'Receive Campfire invites, speaker requests and reminders',
          'campfire_notifications',
        ),
        _PreferenceItem(
          'Invitations',
          'Notify me about Campfire invitations',
          'campfire_invites',
        ),
        _PreferenceItem(
          'Speaker requests',
          'Notify me when a host invites or requests me to speak',
          'campfire_speaker_requests',
        ),
        _PreferenceItem(
          'Scheduled reminders',
          'Notify me before a Campfire I follow is due to start',
          'campfire_reminders',
        ),
        _PreferenceItem(
          'Live Campfire activity',
          'Notify me when a followed Campfire goes live or ends',
          'campfire_live_activity',
        ),
      ],
    ),
    NotificationCategory(
      slug: 'wallet',
      title: 'Wallet and rewards',
      subtitle: 'Wallet, mining, tips and reward activity',
      icon: Icons.account_balance_wallet_outlined,
      items: [
        _PreferenceItem(
          'Wallet and rewards',
          'Receive wallet, mining and reward updates',
          'crypto_notifications',
        ),
        _PreferenceItem(
          'Tips and gifts',
          'Notify me when someone tips me with crypto or Griot Golds',
          'camp_tips',
        ),
      ],
    ),
    NotificationCategory(
      slug: 'profiles',
      title: 'Camp profiles',
      subtitle: 'Followers and profile activity',
      icon: Icons.person_outline_rounded,
      items: [
        _PreferenceItem(
          'Camp profile follows',
          'Notify me when someone follows my Camp profile',
          'camp_profile_follows',
        ),
      ],
    ),
    NotificationCategory(
      slug: 'statuses',
      title: 'Statuses',
      subtitle: 'Replies and reactions to your statuses',
      icon: Icons.bolt_outlined,
      items: [
        _PreferenceItem(
          'Status replies',
          'Notify me when someone replies to my status',
          'status_replies',
        ),
        _PreferenceItem(
          'Status reactions',
          'Notify me when someone reacts to my status',
          'status_reactions',
        ),
      ],
    ),
  ];

  static NotificationCategory? categoryFor(String slug) {
    for (final category in categories) {
      if (category.slug == slug) return category;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) =>
      _NotificationCategoryIndex(categories: categories);
}

class NotificationCategorySettingsScreen extends StatelessWidget {
  final NotificationCategory category;
  const NotificationCategorySettingsScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) =>
      _PreferencePage(title: category.title, items: category.items);
}

class NotificationCategory {
  final String slug, title, subtitle;
  final IconData icon;
  final List<PreferenceItem> items;
  const NotificationCategory({
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.items,
  });
}

class _NotificationCategoryIndex extends StatelessWidget {
  final List<NotificationCategory> categories;
  const _NotificationCategoryIndex({required this.categories});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), centerTitle: true),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final category = categories[index];
          return Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () =>
                  context.push('/settings/notifications/${category.slug}'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(category.icon, color: colors.primary, size: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            category.subtitle,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class PreferenceItem {
  final String title, subtitle, keyName;
  final String? section;
  const PreferenceItem(this.title, this.subtitle, this.keyName, {this.section});
}

typedef _PreferenceItem = PreferenceItem;

class _PreferencePage extends StatefulWidget {
  final String title;
  final List<PreferenceItem> items;
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

          final rows = <Widget>[];
          String? previousSection;
          for (final item in widget.items) {
            if (item.section != null && item.section != previousSection) {
              rows.add(
                Padding(
                  padding: EdgeInsets.only(
                    top: rows.isEmpty ? 14 : 18,
                    bottom: 8,
                    left: 4,
                  ),
                  child: Text(
                    item.section!,
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              );
              previousSection = item.section;
            }

            final value = provider.preferences[item.keyName] ?? true;
            rows.add(
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border(
                    top: BorderSide(
                      color: colors.primary.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                    bottom: BorderSide(
                      color: colors.primary.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
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
              ),
            );
            rows.add(const SizedBox(height: 12));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: rows,
          );
        },
      ),
    );
  }
}
