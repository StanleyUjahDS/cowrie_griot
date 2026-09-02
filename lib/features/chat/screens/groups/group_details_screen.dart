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

class GroupDetailsScreen extends StatefulWidget {
  final Conversation conversation;
  const GroupDetailsScreen({super.key, required this.conversation});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
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
      final members = await provider.getGroupMembers(widget.conversation.id);
      if (mounted) setState(() => _members = members);
    } catch (e) {
      debugPrint('Error loading group members: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _handleLeaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group?'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isActionLoading = true);
    try {
      await context.read<MessagingProvider>().leaveGroup(widget.conversation.id);
      if (mounted) {
        NotificationService.showSuccess(context, 'You left the group');
        context.go('/chat');
      }
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Failed to leave group');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleRemoveMember(String userId) async {
    setState(() => _isActionLoading = true);
    try {
      await context.read<MessagingProvider>().removeGroupMember(widget.conversation.id, userId);
      await _loadMembers();
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Failed to remove member');
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
    final canManage = myRole == 'owner' || myRole == 'admin';

    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Group Info', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        actions: [
          if (widget.conversation.username != null)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: () async {
                final link = 'https://griot.network/group/@${widget.conversation.username}';
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
                    : Icon(Icons.groups_rounded, size: 50, color: colors.primary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              widget.conversation.title ?? 'Unknown Group',
              style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          Center(
            child: Text(
              '${widget.conversation.visibility.toUpperCase()} GROUP',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionLabel('MEMBERS (${_members.length})'),
          const SizedBox(height: 12),
          if (_isLoadingMembers)
            const Center(child: GriotLoader(size: 32))
          else
            ..._members.map((member) {
              final isMe = member['user_id'] == currentUserId;
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
                subtitle: Text(role.toUpperCase(), style: TextStyle(fontSize: 10, color: colors.primary, fontWeight: FontWeight.w800)),
                trailing: isMe 
                  ? null 
                  : (canManage && role != 'owner' ? IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red),
                      onPressed: () => _handleRemoveMember(member['user_id']),
                    ) : null),
              );
            }),
          const SizedBox(height: 40),
          if (myRole != 'owner')
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isActionLoading ? null : _handleLeaveGroup,
                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                label: const Text('Leave Group', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
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
