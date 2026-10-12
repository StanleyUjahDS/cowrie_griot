import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'conversation_campfire_button.dart';

/// Entry point for voice/video calling from direct and group conversations.
/// The call screen is deliberately a separate route so the provider/API
/// implementation can be wired in one place without changing chat headers.
class ConversationCallButton extends StatelessWidget {
  final String conversationId;
  final String conversationType;

  const ConversationCallButton({
    super.key,
    required this.conversationId,
    required this.conversationType,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Start a voice or video call',
      onPressed: () => _chooseCallType(context),
      icon: const Icon(Icons.phone_in_talk_outlined),
    );
  }

  Future<void> _chooseCallType(BuildContext context) async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;
        final textTheme = Theme.of(sheetContext).textTheme;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border(
                top: BorderSide(
                  color: colors.primary.withValues(alpha: 0.7),
                  width: 1.4,
                ),
                bottom: BorderSide(
                  color: colors.primary.withValues(alpha: 0.7),
                  width: 1.4,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Start a call',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose how you want to connect',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _CallOption(
                  icon: Icons.phone_rounded,
                  title: 'Voice call',
                  subtitle: 'Talk without video',
                  color: colors.primary,
                  onTap: () => Navigator.pop(sheetContext, 'voice'),
                ),
                const SizedBox(height: 10),
                _CallOption(
                  icon: Icons.videocam_rounded,
                  title: 'Video call',
                  subtitle: 'Talk face to face',
                  color: colors.secondary,
                  onTap: () => Navigator.pop(sheetContext, 'video'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!context.mounted || mode == null) return;
    await context.push(
      '/calls/$conversationId',
      extra: {'type': conversationType, 'mode': mode},
    );
  }
}

/// Group conversations support both the regular RTC call flow and the
/// conversation-scoped Campfire flow. Channels intentionally do not use this
/// widget: their only live audio entry point is the Campfire action.
class GroupConversationCallButton extends StatelessWidget {
  final String conversationId;
  final bool canCreateCampfire;

  const GroupConversationCallButton({
    super.key,
    required this.conversationId,
    required this.canCreateCampfire,
  });

  Future<void> open(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;
        final textTheme = Theme.of(sheetContext).textTheme;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: colors.primary.withValues(alpha: .65)),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: .28),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.onSurfaceVariant.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Start something together',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose a regular group call or a Campfire space.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _CallOption(
                  icon: Icons.groups_rounded,
                  title: 'Group call',
                  subtitle: 'Private voice or video call for group members',
                  color: colors.primary,
                  onTap: () => Navigator.pop(sheetContext, 'group_call'),
                ),
                const SizedBox(height: 10),
                _CallOption(
                  icon: Icons.local_fire_department_rounded,
                  title: 'Group Campfire',
                  subtitle: canCreateCampfire
                      ? 'A hosted live room with speakers and listeners'
                      : 'Available to group owners and admins',
                  color: Colors.deepOrange,
                  onTap: canCreateCampfire
                      ? () => Navigator.pop(sheetContext, 'campfire')
                      : () => Navigator.pop(sheetContext),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!context.mounted || action == null) return;
    if (action == 'campfire') {
      await ConversationCampfireButton(
        conversationId: conversationId,
        conversationType: 'group',
        canCreate: canCreateCampfire,
      ).open(context);
      return;
    }
    final mode = await _chooseGroupCallMode(context);
    if (!context.mounted || mode == null) return;
    await context.push(
      '/calls/$conversationId',
      extra: {'type': 'group', 'mode': mode},
    );
  }

  Future<String?> _chooseGroupCallMode(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: colors.primary.withValues(alpha: .65)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                _CallOption(
                  icon: Icons.phone_rounded,
                  title: 'Voice call',
                  subtitle: 'Talk without video',
                  color: colors.primary,
                  onTap: () => Navigator.pop(sheetContext, 'voice'),
                ),
                const SizedBox(height: 10),
                _CallOption(
                  icon: Icons.videocam_rounded,
                  title: 'Video call',
                  subtitle: 'Talk face to face',
                  color: colors.secondary,
                  onTap: () => Navigator.pop(sheetContext, 'video'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Start a group call or Campfire',
    onPressed: () => open(context),
    icon: const Icon(Icons.groups_rounded),
  );
}

class _CallOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _CallOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.14),
                foregroundColor: color,
                child: Icon(icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
