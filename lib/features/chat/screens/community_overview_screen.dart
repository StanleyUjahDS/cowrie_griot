import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/services/share_link_service.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../models/conversation_model.dart';
import '../providers/messaging_provider.dart';
import '../../users/providers/user_provider.dart';

/// The public-facing destination for group and channel links.
///
/// This intentionally does not load members or expose admin controls. Those
/// belong to the authenticated details screens after the user has joined.
class CommunityOverviewScreen extends StatefulWidget {
  final Conversation conversation;

  const CommunityOverviewScreen({super.key, required this.conversation});

  @override
  State<CommunityOverviewScreen> createState() =>
      _CommunityOverviewScreenState();
}

class _CommunityOverviewScreenState extends State<CommunityOverviewScreen> {
  bool _isWorking = false;
  late bool _requestSent;

  @override
  void initState() {
    super.initState();
    _requestSent = widget.conversation.joinRequestPending;
  }

  bool get _isChannel => widget.conversation.type == ConversationType.channel;

  String get _kind => _isChannel ? 'channel' : 'group';

  bool _isMember(MessagingProvider provider, String? userId) {
    if (userId == null || userId.isEmpty) return false;
    if (widget.conversation.ownerId == userId) return true;
    // A public deep-link response may include a descriptive role (for
    // example, `subscriber` or `viewer`) even when the current user has not
    // joined. Membership is authoritative only when the API marks it active.
    if (widget.conversation.status == 'active') {
      return true;
    }

    final loaded = provider.conversations.where(
      (conversation) => conversation.id == widget.conversation.id,
    );
    if (loaded.isEmpty) return false;
    final conversation = loaded.first;
    return conversation.status == 'active' ||
        conversation.memberIds.contains(userId);
  }

  Future<void> _share() async {
    final link = ShareLinkService.conversation(widget.conversation);
    if (link == null) {
      if (mounted) {
        NotificationService.showError(
          context,
          'This community does not have a shareable username yet.',
        );
      }
      return;
    }
    await SharePlus.instance.share(ShareParams(text: link));
  }

  Future<void> _handlePrimaryAction() async {
    if (_isWorking) return;

    final provider = context.read<MessagingProvider>();
    final userId = context.read<UserProvider>().user?.id;
    if (_isMember(provider, userId)) {
      _openConversation();
      return;
    }

    setState(() => _isWorking = true);
    try {
      if (_isChannel && widget.conversation.visibility == 'public') {
        await provider.subscribeToChannel(widget.conversation.id);
        if (mounted) {
          _openConversation();
        }
        return;
      }

      if (!_isChannel && widget.conversation.visibility == 'public') {
        await provider.joinPublicGroup(widget.conversation.id);
        if (mounted) {
          _openConversation();
        }
        return;
      }

      final ownerId = widget.conversation.ownerId;
      if (ownerId == null || ownerId.isEmpty) {
        throw StateError('This community has no owner available for requests.');
      }

      await provider.requestToJoinConversation(
        ownerId: ownerId,
        conversationId: widget.conversation.id,
        requestType: _kind,
      );
      if (mounted) {
        setState(() => _requestSent = true);
        NotificationService.showSuccess(
          context,
          'Request sent to the $_kind owner',
        );
      }
    } catch (error) {
      if (mounted) {
        NotificationService.showError(context, _friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  void _openConversation() {
    final conversation = widget.conversation.copyWith(
      status: 'active',
      role: widget.conversation.role ?? 'member',
    );
    context.replace('/conversation/${conversation.id}', extra: conversation);
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    final marker = text.indexOf(': ');
    return marker >= 0 && marker + 2 < text.length
        ? text.substring(marker + 2)
        : 'Unable to complete this action. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final provider = context.watch<MessagingProvider>();
    final userId = context.watch<UserProvider>().user?.id;
    final isMember = _isMember(provider, userId);
    final isPrivate = widget.conversation.visibility != 'public';
    final title = widget.conversation.name?.trim().isNotEmpty == true
        ? widget.conversation.name!.trim()
        : (_isChannel ? 'Channel' : 'Group');
    final count = _isChannel
        ? widget.conversation.subscriberCount
        : widget.conversation.memberCount;
    final primaryLabel = isMember
        ? 'Open ${_isChannel ? 'channel' : 'group'}'
        : _requestSent
        ? 'Request sent'
        : _isChannel
        ? (isPrivate ? 'Request to join' : 'Subscribe')
        : (isPrivate ? 'Request to join' : 'Join group');

    return GradientScaffold(
      appBar: AppBar(
        title: Text(_isChannel ? 'Channel overview' : 'Group overview'),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => context.go(
            _isChannel ? '/chat?tab=channels' : '/chat?tab=groups',
          ),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        actions: [
          IconButton(
            onPressed: _share,
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: colors.primary.withValues(alpha: .35)),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: .08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: colors.primary.withValues(alpha: .12),
                  child: ClipOval(
                    child:
                        widget.conversation.imageUrl != null &&
                            widget.conversation.imageUrl!.trim().isNotEmpty
                        ? Image.network(
                            widget.conversation.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Icon(
                              _isChannel
                                  ? Icons.campaign_rounded
                                  : Icons.groups_rounded,
                              size: 42,
                              color: colors.primary,
                            ),
                          )
                        : Icon(
                            _isChannel
                                ? Icons.campaign_rounded
                                : Icons.groups_rounded,
                            size: 42,
                            color: colors.primary,
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (widget.conversation.username?.trim().isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      '@${widget.conversation.username!.replaceFirst(RegExp(r'^@'), '')}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _OverviewBadge(
                      icon: isPrivate
                          ? Icons.lock_outline_rounded
                          : Icons.public_rounded,
                      label: isPrivate ? 'Private' : 'Public',
                      color: isPrivate ? colors.secondary : colors.primary,
                    ),
                    _OverviewBadge(
                      icon: _isChannel
                          ? Icons.people_alt_outlined
                          : Icons.group_outlined,
                      label: '$count ${_isChannel ? 'subscribers' : 'members'}',
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
                if (widget.conversation.description?.trim().isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      widget.conversation.description!.trim(),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _requestSent || _isWorking
                        ? null
                        : _handlePrimaryAction,
                    icon: _isWorking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            isMember
                                ? Icons.arrow_forward_rounded
                                : isPrivate
                                ? Icons.lock_open_rounded
                                : Icons.login_rounded,
                          ),
                    label: Text(primaryLabel),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _share,
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share this overview'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isPrivate
                ? 'This is a private $_kind. A request will be sent to the owner for approval.'
                : 'This $_kind is public. Join to see the conversation and participate.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _OverviewBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
