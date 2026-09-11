import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import '../../providers/messaging_provider.dart';
import '../../models/conversation_model.dart';
import '../../models/chat_user.dart';
import '../../widgets/friend_selector_sheet.dart';
import '../../widgets/chatting/tip_sheet.dart';
import '../../services/media_api_service.dart';
import '../../../users/providers/user_provider.dart';
import '../../../../core/services/notification_service.dart';
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

  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _usernameController = TextEditingController();
    _descriptionController = TextEditingController();
    _loadMembers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    if (!mounted) return;
    setState(() => _isLoadingMembers = true);
    try {
      final provider = context.read<MessagingProvider>();
      final members = await provider.getGroupMembers(widget.conversation.id);
      if (mounted) {
        setState(() {
          _members = members;
          _isLoadingMembers = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading group members: $e');
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _handleLeaveGroup() async {
    final confirm = await _showConfirmationSheet(
      title: 'Leave Circle?',
      message: 'Are you sure you want to leave this circle conversation?',
      confirmLabel: 'Leave Circle',
      isDestructive: true,
    );

    if (confirm != true || !mounted) return;

    setState(() => _isActionLoading = true);
    try {
      await context.read<MessagingProvider>().leaveGroup(
        widget.conversation.id,
      );
      if (mounted) {
        NotificationService.showSuccess(context, 'You left the group');
        context.go('/chat');
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to leave group');
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleDeleteGroup() async {
    final confirm = await _showConfirmationSheet(
      title: 'Delete Circle?',
      message: 'This will permanently delete the circle for everyone. This action is irreversible.',
      confirmLabel: 'Delete Permanently',
      isDestructive: true,
    );

    if (confirm != true || !mounted) return;
    setState(() => _isActionLoading = true);
    try {
      await context.read<MessagingProvider>().deleteConversation(
        widget.conversation.id,
      );
      if (mounted) {
        NotificationService.showSuccess(context, 'Group deleted');
        context.go('/chat');
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to delete group');
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleClearMessages() async {
    final confirm = await _showConfirmationSheet(
      title: 'Clear Chat?',
      message: 'Are you sure you want to clear all messages in this circle? This action is permanent.',
      confirmLabel: 'Clear Chat',
      isDestructive: true,
    );

    if (confirm != true || !mounted) return;

    setState(() => _isActionLoading = true);
    try {
      await context.read<MessagingProvider>().clearGroupMessages(
        widget.conversation.id,
      );
      if (mounted) NotificationService.showSuccess(context, 'Chat cleared');
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Failed to clear chat');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleRemoveMember(String userId) async {
    setState(() => _isActionLoading = true);
    try {
      await context.read<MessagingProvider>().removeGroupMember(
        widget.conversation.id,
        userId,
      );
      await _loadMembers();
      if (mounted) NotificationService.showSuccess(context, 'Member removed');
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Failed to remove member');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleUpdateRole(String userId, String newRole) async {
    setState(() => _isActionLoading = true);
    try {
      await context.read<MessagingProvider>().updateGroupMemberRole(
        widget.conversation.id,
        userId,
        newRole,
      );
      await _loadMembers();
      if (mounted) NotificationService.showSuccess(context, 'Role updated to $newRole');
    } catch (e) {
      if (mounted) NotificationService.showError(context, 'Failed to update role');
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<bool?> _showConfirmationSheet({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: isDestructive ? colorScheme.error : colorScheme.primary,
                      foregroundColor: isDestructive ? colorScheme.onError : colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editGroupSettings() async {
    final theme = Theme.of(context);
    _nameController.text = widget.conversation.title ?? '';
    _usernameController.text = widget.conversation.username ?? '';
    _descriptionController.text = widget.conversation.description ?? '';
    var visibility = widget.conversation.visibility;
    var messagesLocked = widget.conversation.messagesLocked;
    File? selectedImage;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (innerContext, setSheetState) {
          final colorScheme = Theme.of(innerContext).colorScheme;
          return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            MediaQuery.of(context).viewInsets.bottom + 40,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Circle Settings',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Avatar Picker
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 70,
                      );
                      if (picked != null) {
                        setSheetState(() => selectedImage = File(picked.path));
                      }
                    },
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            border: Border.all(
                              color: colorScheme.primary.withValues(alpha: 0.2),
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: selectedImage != null
                                ? Image.file(selectedImage!, fit: BoxFit.cover)
                                : (widget.conversation.avatarUrl != null
                                    ? Image.network(
                                        widget.conversation.avatarUrl!,
                                        fit: BoxFit.cover)
                                    : Icon(Icons.groups_rounded,
                                        size: 40, color: colorScheme.primary)),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: colorScheme.surface, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                TextField(
                  controller: _nameController,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: 'Circle Name',
                    hintText: 'Enter a name for your circle',
                    filled: true,
                    fillColor: colorScheme.onSurface.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _usernameController,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: 'Circle Username',
                    hintText: 'e.g. my-awesome-circle',
                    prefixText: '@',
                    filled: true,
                    fillColor: colorScheme.onSurface.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'What is this circle about?',
                    filled: true,
                    fillColor: colorScheme.onSurface.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _VisibilityToggleButton(
                          label: 'Public',
                          icon: Icons.public_rounded,
                          selected: visibility == 'public',
                          onTap: () =>
                              setSheetState(() => visibility = 'public'),
                        ),
                      ),
                      Expanded(
                        child: _VisibilityToggleButton(
                          label: 'Private',
                          icon: Icons.lock_outline_rounded,
                          selected: visibility == 'private',
                          onTap: () =>
                              setSheetState(() => visibility = 'private'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Admins only can send',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text(
                      'Owners and admins can still post when enabled.'),
                  value: messagesLocked,
                  onChanged: (value) =>
                      setSheetState(() => messagesLocked = value),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, {
                          'action': 'save',
                          'name': _nameController.text.trim(),
                          'username': _usernameController.text.trim(),
                          'description': _descriptionController.text.trim(),
                          'visibility': visibility,
                          'messagesLocked': messagesLocked,
                          'imageFile': selectedImage,
                        }),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'DANGER ZONE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.error.withValues(alpha: 0.7),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.pop(sheetContext, {'action': 'clear'}),
                        icon: const Icon(Icons.cleaning_services_rounded,
                            size: 18),
                        label: const Text(
                          'Clear Chat',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: colorScheme.error.withValues(alpha: 0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.pop(sheetContext, {'action': 'delete'}),
                        icon:
                            const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text(
                          'Delete Circle',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: colorScheme.error.withValues(alpha: 0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result == null || !mounted) return;

    if (result['action'] == 'clear') {
      _handleClearMessages();
      return;
    }

    if (result['action'] == 'delete') {
      _handleDeleteGroup();
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      String? imageUrl;
      if (result['imageFile'] != null) {
        if (!mounted) return;
        final mediaApi = context.read<MediaApiService>();
        final uploadResult = await mediaApi.uploadMedia(
          (result['imageFile'] as File).path,
          conversationId: widget.conversation.id,
        );
        imageUrl = uploadResult['mediaUrl'];
      }

      if (!mounted) return;
      await context.read<MessagingProvider>().updateGroup(
            widget.conversation.id,
            name: result['name'],
            username: result['username'],
            description: result['description'],
            visibility: result['visibility'],
            messagesLocked: result['messagesLocked'] as bool?,
            imageUrl: imageUrl,
          );
      if (mounted) {
        NotificationService.showSuccess(context, 'Group updated');
      }
    } catch (_) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to update group');
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _handleAddMember() async {
    final results = await FriendSelectorSheet.show(
      context,
      title: 'Add to Group',
      disabledIds: _members.map((m) => m['user_id'].toString()).toList(),
    );
    if (results != null && results.isNotEmpty) {
      if (!mounted) return;
      final provider = context.read<MessagingProvider>();
      setState(() => _isActionLoading = true);
      try {
        for (final user in results) {
          await provider.addGroupMember(widget.conversation.id, user.id);
        }
        await _loadMembers();
        if (mounted) NotificationService.showSuccess(context, 'Members added!');
      } catch (e) {
        if (mounted) {
          NotificationService.showError(context, 'Failed to add members');
        }
      } finally {
        if (mounted) setState(() => _isActionLoading = false);
      }
    }
  }

  void _showMemberOptions(
    Map<String, dynamic> member,
    String myRole,
    String? currentUserId,
  ) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final userId = member['user_id'];
    final memberRole = member['role'] ?? 'member';
    final isOwner = memberRole == 'owner';
    final isAdmin = memberRole == 'admin';
    final iAmOwner = myRole == 'owner';
    final iAmAdmin = myRole == 'admin';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) => Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(
              color: colors.primary.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundImage: member['avatar_url'] != null
                          ? NetworkImage(member['avatar_url'])
                          : null,
                      child: member['avatar_url'] == null
                          ? Icon(Icons.person_rounded, color: colors.primary)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (member['display_name'] ??
                              member['username'] ??
                              'Griot User') + (userId == currentUserId ? ' (You)' : ''),
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            memberRole.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              color: colors.primary,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.person_outline_rounded,
                color: colors.primary,
              ),
              title: const Text(
                'View Profile',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onTap: () {
                Navigator.pop(modalContext);
                context.push(
                  '/user/profile',
                  extra: ChatUser.fromJson(member).toUserModel(),
                );
              },
            ),
            if (userId == currentUserId) ...[
              if (memberRole != 'owner')
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: colors.error),
                  title: Text(
                    'Leave Group',
                    style: TextStyle(
                      color: colors.error,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(modalContext);
                    _handleLeaveGroup();
                  },
                ),
            ] else ...[
              if (iAmOwner && !isOwner) ...[
                if (isAdmin)
                  ListTile(
                    leading: Icon(
                      Icons.admin_panel_settings_outlined,
                      color: colors.primary,
                    ),
                    title: const Text(
                      'Dismiss as Admin',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onTap: () {
                      Navigator.pop(modalContext);
                      _handleUpdateRole(userId, 'member');
                    },
                  )
                else
                  ListTile(
                    leading: Icon(
                      Icons.admin_panel_settings_rounded,
                      color: colors.primary,
                    ),
                    title: const Text(
                      'Make Group Admin',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onTap: () {
                      Navigator.pop(modalContext);
                      _handleUpdateRole(userId, 'admin');
                    },
                  ),
              ],
              if ((iAmOwner || iAmAdmin) && !isOwner && !(iAmAdmin && isAdmin))
                ListTile(
                  leading: Icon(Icons.person_remove_rounded, color: colors.error),
                  title: Text(
                    'Remove from Group',
                    style: TextStyle(
                      color: colors.error,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(modalContext);
                    _handleRemoveMember(userId);
                  },
                ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Consumer<MessagingProvider>(
      builder: (context, provider, child) {
        final currentUserId = context.watch<UserProvider>().user?.id;

        // Get latest from provider
        final providerConv = provider.conversations.firstWhere(
          (c) => c.id == widget.conversation.id,
          orElse: () => widget.conversation,
        );

        // Merge data
        final conversation = widget.conversation.copyWith(
          role: providerConv.role,
          status: providerConv.status,
          memberCount: providerConv.memberCount > 0 ? providerConv.memberCount : widget.conversation.memberCount,
          memberIds: providerConv.memberIds.isNotEmpty ? providerConv.memberIds : widget.conversation.memberIds,
        );

        final myMember = _members.firstWhere(
          (m) => m['user_id'] == currentUserId,
          orElse: () => {},
        );
        final myRole = myMember['role'] ?? conversation.role;
        final iAmOwner = myRole == 'owner' || conversation.ownerId == currentUserId;
        final iAmAdmin = myRole == 'admin';
        final canManage = iAmOwner || iAmAdmin;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                stretch: false,
                backgroundColor: theme.scaffoldBackgroundColor,
                elevation: 0,
                leading: Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
            actions: [
              if (canManage)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Center(
                    child: GestureDetector(
                      onTap: _isActionLoading ? null : _editGroupSettings,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Icon(
                          Icons.settings_rounded,
                          size: 20,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Center(
                  child: GestureDetector(
                    onTap: () async {
                      final link =
                          'https://griot.network/circle/@${conversation.username ?? conversation.id}';
                      await Clipboard.setData(ClipboardData(text: link));
                      if (!context.mounted) return;
                      NotificationService.showSuccess(context, 'Link copied');
                      await SharePlus.instance.share(ShareParams(text: link));
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        Icons.share_rounded,
                        size: 20,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                widget.conversation.title ?? 'Circle',
                style: TextStyle(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Circle Identity Section
                  _buildSectionLabel('CIRCLE IDENTITY'),
                  const SizedBox(height: 12),
                  _CircleInfoCard(
                    conversation: conversation,
                    colors: colors,
                    actualMemberCount: _members.length,
                  ),
                  const SizedBox(height: 32),

                  if (widget.conversation.description != null &&
                      widget.conversation.description!.isNotEmpty) ...[
                    _buildSectionLabel('ABOUT THIS CIRCLE'),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border(
                          top: BorderSide(
                            color: colors.primary.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                          bottom: BorderSide(
                            color: colors.primary.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                      ),
                      child: Text(
                        widget.conversation.description!,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colors.onSurface,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Circle Actions
                  _buildSectionLabel('CIRCLE ACTIONS'),
                  const SizedBox(height: 12),
                  _CircleActionsCard(
                    canManage: canManage,
                    onAddMember: _handleAddMember,
                    onTipMembers: () => TipSheet.show(
                      context,
                      recipients: [],
                      conversationId: widget.conversation.id,
                      conversationType: ConversationType.group,
                    ),
                    onShare: () async {
                      final link = 'https://griot.network/circle/@${conversation.username ?? conversation.id}';
                      await SharePlus.instance.share(ShareParams(text: link));
                    },
                    colors: colors,
                  ),
                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionLabel('COMMUNITY MEMBERS'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingMembers)
                    const Center(child: GriotLoader(size: 32))
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        final isMe = member['user_id'] == currentUserId;
                        final role = member['role']?.toString() ?? 'member';
                        final isOwner = role == 'owner';
                        final isAdmin = role == 'admin';

                        return InkWell(
                          onTap: () => _showMemberOptions(
                            member,
                            iAmOwner ? 'owner' : (iAmAdmin ? 'admin' : 'member'),
                            currentUserId,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundImage: member['avatar_url'] != null
                                      ? NetworkImage(member['avatar_url'])
                                      : null,
                                  child: member['avatar_url'] == null
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (member['display_name'] ??
                                                member['username'] ??
                                                'Griot User') +
                                            (isMe ? ' (You)' : ''),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      if (isOwner || isAdmin)
                                        Text(
                                          role.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: colors.primary,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (!isMe && canManage && !isOwner)
                                  Icon(
                                    Icons.more_vert_rounded,
                                    color: colors.onSurfaceVariant.withValues(
                                      alpha: 0.4,
                                    ),
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 48),

                  if (myRole != 'owner')
                    _buildDangerButton(
                      label: 'Leave Group',
                      icon: Icons.logout_rounded,
                      onTap: _handleLeaveGroup,
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildSectionLabel(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
        color: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _buildDangerButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: _isActionLoading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: colors.error.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.error.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: colors.error, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: colors.error,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleInfoCard extends StatelessWidget {
  final Conversation conversation;
  final ColorScheme colors;
  final int? actualMemberCount;

  const _CircleInfoCard({
    required this.conversation,
    required this.colors,
    this.actualMemberCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(28),
        border: Border(
          top: BorderSide(
            color: colors.primary.withValues(alpha: 0.6),
            width: 1.5,
          ),
          bottom: BorderSide(
            color: colors.primary.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        children: [
          _infoRow(Icons.tag_rounded, 'Handle',
            conversation.username != null ? '@${conversation.username}' : 'NO HANDLE'),
          _divider(),
          _infoRow(Icons.people_outline_rounded, 'Members',
            '${(actualMemberCount != null && actualMemberCount! > 0) ? actualMemberCount : conversation.memberCount} members'),
          _divider(),
          _infoRow(Icons.calendar_today_rounded, 'Created',
            DateFormat('MMMM yyyy').format(conversation.createdAt)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.primary.withValues(alpha: 0.6)),
        const SizedBox(width: 16),
        Text(label, style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.7), fontWeight: FontWeight.w600, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
      ],
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Divider(height: 1, color: colors.outline.withValues(alpha: 0.05)),
    );
  }
}

class _CircleActionsCard extends StatelessWidget {
  final bool canManage;
  final VoidCallback onAddMember;
  final VoidCallback onTipMembers;
  final VoidCallback onShare;
  final ColorScheme colors;

  const _CircleActionsCard({
    required this.canManage,
    required this.onAddMember,
    required this.onTipMembers,
    required this.onShare,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.share_rounded,
              label: 'Share Circle',
              onTap: onShare,
              colors: colors,
            ),
          ),
          const SizedBox(width: 8),
          if (canManage) ...[
            Expanded(
              child: _ActionButton(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Add Member',
                onTap: onAddMember,
                colors: colors,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: _ActionButton(
              icon: Icons.volunteer_activism_outlined,
              label: 'Tip Members',
              onTap: onTipMembers,
              colors: colors,
              isPrimary: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme colors;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colors,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isPrimary ? colors.primary : colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: isPrimary ? null : Border.all(color: colors.outline.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: isPrimary ? colors.onPrimary : colors.primary, size: 20),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? colors.onPrimary : colors.onSurface,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisibilityToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _VisibilityToggleButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? colors.onSurface : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
