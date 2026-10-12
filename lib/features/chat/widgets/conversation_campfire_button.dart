import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/messaging_api_service.dart';
import '../../iap/providers/iap_provider.dart';
import '../../iap/widgets/plus_required_dialog.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/ui/widgets/griot_branded_container.dart';
import '../../../core/ui/widgets/griot_avatar.dart';
import '../services/active_call_controller.dart';
import '../providers/messaging_provider.dart';

/// Inline status for a conversation-scoped Campfire. Conversation Campfires
/// intentionally do not appear in the public Campfires discovery feed.
class ConversationCampfireStatusCard extends StatefulWidget {
  final String conversationId;
  final String conversationType;
  final bool canCreate;

  const ConversationCampfireStatusCard({
    super.key,
    required this.conversationId,
    required this.conversationType,
    this.canCreate = false,
  });

  @override
  State<ConversationCampfireStatusCard> createState() =>
      _ConversationCampfireStatusCardState();
}

class _ConversationCampfireStatusCardState
    extends State<ConversationCampfireStatusCard> {
  late Future<List<Map<String, dynamic>>> _rooms;
  MessagingProvider? _messagingProvider;
  int _campfireRevision = 0;

  @override
  void initState() {
    super.initState();
    _rooms = _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _messagingProvider = context.read<MessagingProvider>();
      _campfireRevision = _messagingProvider!.campfireRevision;
      _messagingProvider!.addListener(_refreshWhenCampfireChanges);
    });
  }

  void _refreshWhenCampfireChanges() {
    final provider = _messagingProvider;
    if (!mounted ||
        provider == null ||
        provider.campfireRevision == _campfireRevision) {
      return;
    }
    _campfireRevision = provider.campfireRevision;
    setState(() => _rooms = _load());
  }

  @override
  void dispose() {
    _messagingProvider?.removeListener(_refreshWhenCampfireChanges);
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rooms = await context
        .read<MessagingApiService>()
        .getConversationCampfires(widget.conversationId);
    return rooms
        .map((room) => Map<String, dynamic>.from(room))
        .where((room) => room['id'] != null)
        .toList(growable: false);
  }

  DateTime? _scheduledAt(Map<String, dynamic> room) {
    final raw = room['scheduled_at'] ?? room['scheduledAt'];
    return raw == null ? null : DateTime.tryParse(raw.toString())?.toLocal();
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _rooms,
    builder: (context, snapshot) {
      final rooms = snapshot.data ?? const <Map<String, dynamic>>[];
      if (rooms.isEmpty) return const SizedBox.shrink();
      final now = DateTime.now();
      final room = rooms.firstWhere((candidate) {
        final starts = _scheduledAt(candidate);
        return starts == null || !starts.isAfter(now);
      }, orElse: () => rooms.first);
      final scheduled = _scheduledAt(room);
      final isLive = scheduled == null || !scheduled.isAfter(now);
      final colors = Theme.of(context).colorScheme;
      final title = room['title']?.toString().trim();
      final host = room['host_name'] ?? room['hostName'];
      final hostAvatar =
          room['host_avatar_url'] ??
          room['hostAvatarUrl'] ??
          room['host_avatar'] ??
          room['hostAvatar'];
      final time = scheduled == null
          ? null
          : MaterialLocalizations.of(
              context,
            ).formatTimeOfDay(TimeOfDay.fromDateTime(scheduled));
      final conversationLabel =
          widget.conversationType.toLowerCase() == 'channel'
          ? 'channel'
          : 'group';
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: GriotBrandedContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: Row(
            children: [
              GriotAvatar(
                avatarUrl: hostAvatar?.toString(),
                radius: 22,
                backgroundColor: colors.primary.withValues(alpha: .14),
                iconColor: colors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLive
                          ? 'Live Campfire in this $conversationLabel'
                          : 'Campfire scheduled',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    if (title != null && title.isNotEmpty)
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      isLive
                          ? (host == null
                                ? 'A live call is happening now'
                                : 'A live call is happening now · Hosted by $host')
                          : 'Hosted by ${host == null || host.toString().trim().isEmpty ? 'Griot user' : host} · Starts $time',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () async {
                  await ConversationCampfireButton(
                    conversationId: widget.conversationId,
                    conversationType: widget.conversationType,
                    canCreate: widget.canCreate,
                  ).open(context);
                  if (mounted) setState(() => _rooms = _load());
                },
                child: Text(isLive ? 'Open' : 'Details'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Starts or joins the private Campfire belonging to a group/channel.
/// These rooms use the Campfire UI but are never part of public discovery.
class ConversationCampfireButton extends StatelessWidget {
  final String conversationId;
  final String conversationType;
  final bool canCreate;

  const ConversationCampfireButton({
    super.key,
    required this.conversationId,
    required this.conversationType,
    this.canCreate = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!canCreate) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Start private Campfire',
      onPressed: () => open(context),
      icon: const Icon(Icons.local_fire_department_outlined),
    );
  }

  /// Opens the conversation-scoped Campfire flow from any overview action.
  /// Keeping this entry point here prevents overview buttons from accidentally
  /// falling back to public Campfire discovery.
  Future<void> open(BuildContext context) async {
    final activeCall = ActiveCallController.instance.request;
    if (activeCall != null &&
        !ActiveCallController.instance.closing &&
        activeCall.conversationType == 'space' &&
        activeCall.conversationId == conversationId) {
      ActiveCallController.instance.expand();
      return;
    }
    final iap = context.read<IapProvider>();
    if (!iap.status.isPlus) {
      final openPlus = await showPlusRequiredDialog(context);
      if (openPlus && context.mounted) context.push('/settings/griot-plus');
      return;
    }

    final api = context.read<MessagingApiService>();
    try {
      final rooms = await api.getConversationCampfires(conversationId);
      final now = DateTime.now();
      DateTime? scheduledTime(Map<String, dynamic>? room) {
        final raw = room?['scheduled_at'] ?? room?['scheduledAt'];
        if (raw == null) return null;
        return DateTime.tryParse(raw.toString())?.toLocal();
      }

      // Prefer a live room when a live room and a future reservation coexist.
      // A scheduled room is only a future reservation and cannot be joined
      // before its start time.
      final active = rooms.cast<Map<String, dynamic>?>().firstWhere((room) {
        final starts = scheduledTime(room);
        return starts == null || !starts.isAfter(now);
      }, orElse: () => null);
      if (active != null && context.mounted) {
        final id = active['id']?.toString();
        if (id != null && id.isNotEmpty) {
          await api.joinCampfire(id);
          if (!context.mounted) return;
          await context.push(
            '/calls/$id',
            extra: {
              'type': 'space',
              'mode': active['mode']?.toString() ?? 'voice',
              'title': active['title']?.toString(),
            },
          );
          return;
        }
      }

      final upcoming = rooms.cast<Map<String, dynamic>?>().firstWhere((room) {
        final starts = scheduledTime(room);
        return starts != null && starts.isAfter(now);
      }, orElse: () => null);
      if (upcoming != null && context.mounted) {
        final starts = scheduledTime(upcoming);
        final title = upcoming['title']?.toString().trim();
        final timeLabel = starts == null
            ? 'later'
            : '${MaterialLocalizations.of(context).formatMediumDate(starts)} at '
                  '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(starts))}';
        NotificationService.showInfo(
          context,
          '${title == null || title.isEmpty ? 'Campfire' : title} is scheduled for $timeLabel.',
        );
        return;
      }

      if (!context.mounted) return;
      if (!canCreate) {
        NotificationService.showInfo(
          context,
          'Only channel owners and admins can start a Campfire.',
        );
        return;
      }
      final created = await context.push<Map<String, dynamic>>(
        '/campfires/create',
        extra: {
          'conversationId': conversationId,
          'conversationType': conversationType,
        },
      );
      if (!context.mounted || created == null) return;
      final id = created['id']?.toString();
      if (id == null || id.isEmpty) return;

      final scheduledRaw = created['scheduled_at'] ?? created['scheduledAt'];
      final scheduledAt = scheduledRaw == null
          ? null
          : DateTime.tryParse(scheduledRaw.toString())?.toLocal();
      if (scheduledAt != null && scheduledAt.isAfter(DateTime.now())) {
        NotificationService.showCampfireScheduled(
          context,
          campfireId: id,
          scheduledAt: scheduledAt,
          title: created['title']?.toString(),
        );
        return;
      }

      await api.joinCampfire(id);
      if (!context.mounted) return;
      await context.push(
        '/calls/$id',
        extra: {
          'type': 'space',
          'mode': created['mode']?.toString() ?? 'voice',
          'title': created['title']?.toString(),
        },
      );
    } catch (error) {
      if (!context.mounted) return;
      NotificationService.showError(
        context,
        'Could not open private Campfire: $error',
      );
    }
  }
}
