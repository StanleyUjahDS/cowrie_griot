import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/ui/widgets/griot_branded_container.dart';

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
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Start a call',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Choose how you want to connect',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _CallOption(
                icon: Icons.phone_rounded,
                title: 'Voice call',
                subtitle: 'Talk without video',
                onTap: () => Navigator.pop(sheetContext, 'voice'),
              ),
              const SizedBox(height: 10),
              _CallOption(
                icon: Icons.videocam_rounded,
                title: 'Video call',
                subtitle: 'Talk face to face',
                onTap: () => Navigator.pop(sheetContext, 'video'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || mode == null) return;
    await context.push(
      '/calls/$conversationId',
      extra: {'type': conversationType, 'mode': mode},
    );
  }
}

class _CallOption extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const _CallOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: GriotBrandedContainer(
        padding: const EdgeInsets.all(14),
        borderRadius: 18,
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colors.primary.withValues(alpha: .14),
              foregroundColor: colors.primary,
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
