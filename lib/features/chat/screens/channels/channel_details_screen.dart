import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../providers/messaging_provider.dart';
import '../../models/conversation_model.dart';
import '../../../users/providers/user_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../../core/ui/widgets/griot_loader.dart';

class ChannelDetailsScreen extends StatefulWidget {
  final Conversation conversation;
  const ChannelDetailsScreen({super.key, required this.conversation});

  @override
  State<ChannelDetailsScreen> createState() => _ChannelDetailsScreenState();
}

class _ChannelDetailsScreenState extends State<ChannelDetailsScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoadingMembers = false;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoadingMembers = true);
    try {
      final provider = context.read<MessagingProvider>();
      final members = await provider.getChannelMembers(widget.conversation.id);
      if (mounted) setState(() => _members = members);
    } catch (e) {
      debugPrint('Error loading channel members: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _handleUnsubscribe() async {
    setState(() => _isActionLoading = true);
    try {
      await context.read<MessagingProvider>().unsubscribeFromChannel(widget.conversation.id);
      if (mounted) {
        NotificationService.showSuccess(context, 'Unsubscribed from channel');
        context.pop(); // Go back to feed or chat home
      }
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Failed to unsubscribe');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleDeleteChannel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Channel?'),
        content: const Text('This action is permanent and cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isActionLoading = true);
    try {
      await context.read<MessagingProvider>().deleteChannel(widget.conversation.id);
      if (mounted) {
        NotificationService.showSuccess(context, 'Channel deleted');
        context.go('/chat');
      }
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Failed to delete channel');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final userProvider = context.watch<UserProvider>();
    final currentUserId = userProvider.user?.id;
    
    final myMember = _members.firstWhere((m) => m['user_id'] == currentUserId, orElse: () => {});
    final myRole = myMember['role'] ?? widget.conversation.role;
    final isOwner = myRole == 'owner';
    final isAdmin = myRole == 'admin';

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Channel Info', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        actions: [
          if (widget.conversation.username != null)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: () async {
                final link = 'https://griot.network/channel/@${widget.conversation.username}';
                await Clipboard.setData(ClipboardData(text: link));
                if (mounted) {
                  NotificationService.showSuccess(context, 'Link copied to clipboard');
                }
                await Share.share(link);
              },
            ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                shape: BoxShape.circle,
                border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
              ),
              child: ClipOval(
                child: widget.conversation.avatarUrl != null
                    ? Image.network(widget.conversation.avatarUrl!, fit: BoxFit.cover)
                    : Icon(Icons.campaign_rounded, size: 50, color: colors.primary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              widget.conversation.title ?? 'Unknown Channel',
              style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          if (widget.conversation.username != null)
            Center(
              child: Text(
                '@${widget.conversation.username}',
                style: TextStyle(color: colors.primary, fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${widget.conversation.visibility.toUpperCase()} CHANNEL',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          if (widget.conversation.description != null && widget.conversation.description!.isNotEmpty) ...[
            _buildSectionLabel('ABOUT'),
            const SizedBox(height: 8),
            Text(widget.conversation.description!, style: textTheme.bodyLarge),
            const SizedBox(height: 32),
          ],

          _buildSectionLabel('SUBSCRIBERS (${_members.length})'),
          const SizedBox(height: 12),
          if (_isLoadingMembers)
            const Center(child: GriotLoader(size: 32))
          else
            ..._members.take(10).map((member) {
              final role = member['role']?.toString() ?? 'member';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundImage: member['avatar_url'] != null ? NetworkImage(member['avatar_url']) : null,
                  child: member['avatar_url'] == null ? const Icon(Icons.person) : null,
                ),
                title: Text(
                  member['display_name'] ?? member['username'] ?? 'Griot User',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: role != 'member' ? Text(role.toUpperCase(), style: TextStyle(fontSize: 10, color: colors.primary, fontWeight: FontWeight.w800)) : null,
              );
            }),
          if (_members.length > 10)
            TextButton(onPressed: () {}, child: const Text('View all subscribers')),
          
          const SizedBox(height: 40),
          
          if (isOwner)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isActionLoading ? null : _handleDeleteChannel,
                icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                label: const Text('Delete Channel', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            )
          else if (!isOwner)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isActionLoading ? null : _handleUnsubscribe,
                icon: const Icon(Icons.notifications_off_rounded, color: Colors.red),
                label: const Text('Unsubscribe', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      ),
    );
  }
}
