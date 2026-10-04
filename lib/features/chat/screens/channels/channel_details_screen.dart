import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/messaging_provider.dart';
import '../../models/conversation_model.dart';
import '../../models/chat_user.dart';
import '../../services/media_api_service.dart';
import '../../widgets/chatting/tip_sheet.dart';
import '../../../users/providers/user_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/share_link_service.dart';
import '../../../../core/ui/widgets/griot_loader.dart';
import '../../../../core/ui/widgets/griot_plus_badge.dart';

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

  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _usernameController = TextEditingController();
    _bioController = TextEditingController();
    _loadMembers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    if (!mounted) return;
    setState(() => _isLoadingMembers = true);
    try {
      final provider = context.read<MessagingProvider>();
      final members = await provider.getChannelMembers(widget.conversation.id);
      if (mounted) {
        setState(() {
          _members = members;
          _isLoadingMembers = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading channel members: $e');
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _shareChannelLink() async {
    final link = ShareLinkService.conversation(widget.conversation);
    if (link == null) {
      if (mounted) {
        NotificationService.showError(
          context,
          'This channel does not have a username yet. Set one before sharing.',
        );
      }
      return;
    }

    await SharePlus.instance.share(ShareParams(text: link));
  }

  Future<void> _handleRemoveSubscriber(String userId) async {
    setState(() => _isActionLoading = true);
    try {
      await context.read<MessagingProvider>().removeChannelMember(
        widget.conversation.id,
        userId,
      );
      await _loadMembers();
      if (mounted) {
        NotificationService.showSuccess(context, 'Subscriber removed');
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to remove subscriber');
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleUnsubscribe() async {
    final confirm = await _showConfirmationSheet(
      title: 'Unsubscribe?',
      message:
          'Are you sure you want to stop receiving updates from this channel?',
      confirmLabel: 'Unsubscribe',
      isDestructive: true,
    );

    if (confirm != true || !mounted) return;

    setState(() => _isActionLoading = true);
    try {
      await context.read<MessagingProvider>().unsubscribeFromChannel(
        widget.conversation.id,
      );
      if (mounted) {
        NotificationService.showSuccess(context, 'Unsubscribed from channel');
        context.go('/chat');
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to unsubscribe');
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleDeleteChannel() async {
    final confirm = await _showConfirmationSheet(
      title: 'Delete Channel?',
      message:
          'This action is permanent and will delete the channel for all subscribers.',
      confirmLabel: 'Delete Permanently',
      isDestructive: true,
    );

    if (confirm != true || !mounted) return;

    setState(() => _isActionLoading = true);
    try {
      await context.read<MessagingProvider>().deleteChannel(
        widget.conversation.id,
      );
      if (mounted) {
        NotificationService.showSuccess(context, 'Channel deleted');
        context.go('/chat');
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to delete channel');
      }
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
        child: Material(
          type: MaterialType.transparency,
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
                        backgroundColor: isDestructive
                            ? colorScheme.error
                            : colorScheme.primary,
                        foregroundColor: isDestructive
                            ? colorScheme.onError
                            : colorScheme.onPrimary,
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
      ),
    );
  }

  void _showSubscriberOptions(
    Map<String, dynamic> member,
    bool iAmOwner,
    bool iAmAdmin,
    String? currentUserId,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final userId = member['user_id'];
    final memberRole = member['role'] ?? 'member';
    final isOwner = memberRole == 'owner';
    final isAdmin = memberRole == 'admin';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) => Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
        decoration: BoxDecoration(
          color: colorScheme.surface,
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                (member['display_name'] ??
                                        member['username'] ??
                                        'Griot User') +
                                    (userId == currentUserId ? ' (You)' : ''),
                                style: textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            if (member['is_plus'] == true ||
                                member['isPlus'] == true) ...[
                              const SizedBox(width: 6),
                              const GriotPlusBadge(isPlus: true, compact: true),
                            ],
                          ],
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
              if (!isOwner)
                ListTile(
                  leading: Icon(
                    Icons.notifications_off_rounded,
                    color: colors.error,
                  ),
                  title: Text(
                    'Unsubscribe',
                    style: TextStyle(
                      color: colors.error,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(modalContext);
                    _handleUnsubscribe();
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
                      _handleRemoveAdmin(userId);
                    },
                  )
                else
                  ListTile(
                    leading: Icon(
                      Icons.admin_panel_settings_rounded,
                      color: colors.primary,
                    ),
                    title: const Text(
                      'Make Channel Admin',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onTap: () {
                      Navigator.pop(modalContext);
                      _handleAddAdmin(userId);
                    },
                  ),
              ],
              if ((iAmOwner || iAmAdmin) && !isOwner && !(iAmAdmin && isAdmin))
                ListTile(
                  leading: Icon(
                    Icons.person_remove_rounded,
                    color: colors.error,
                  ),
                  title: Text(
                    'Remove Subscriber',
                    style: TextStyle(
                      color: colors.error,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(modalContext);
                    _handleRemoveSubscriber(userId);
                  },
                ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAddAdmin(String userId) async {
    setState(() => _isActionLoading = true);
    try {
      await context.read<MessagingProvider>().addChannelAdmin(
        widget.conversation.id,
        userId,
      );
      await _loadMembers();
      if (mounted) NotificationService.showSuccess(context, 'Admin added');
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to add admin');
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleRemoveAdmin(String userId) async {
    setState(() => _isActionLoading = true);
    try {
      await context.read<MessagingProvider>().removeChannelAdmin(
        widget.conversation.id,
        userId,
      );
      await _loadMembers();
      if (mounted) NotificationService.showSuccess(context, 'Admin removed');
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to remove admin');
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _editChannelSettings() async {
    _nameController.text = widget.conversation.name ?? '';
    _usernameController.text = widget.conversation.username ?? '';
    _bioController.text = widget.conversation.description ?? '';
    var visibility = widget.conversation.visibility;
    var commentsLocked = widget.conversation.commentsLocked;
    File? selectedImage;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (innerContext, setSheetState) {
          final theme = Theme.of(innerContext);
          final colorScheme = theme.colorScheme;
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
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
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.2,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Channel Settings',
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
                          setSheetState(
                            () => selectedImage = File(picked.path),
                          );
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
                                color: colorScheme.primary.withValues(
                                  alpha: 0.2,
                                ),
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: selectedImage != null
                                  ? Image.file(
                                      selectedImage!,
                                      fit: BoxFit.cover,
                                    )
                                  : (widget.conversation.avatarUrl != null
                                        ? Image.network(
                                            widget.conversation.avatarUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => Icon(
                                              Icons.campaign_rounded,
                                              size: 40,
                                              color: colorScheme.primary,
                                            ),
                                          )
                                        : Icon(
                                            Icons.campaign_rounded,
                                            size: 40,
                                            color: colorScheme.primary,
                                          )),
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
                                border: Border.all(
                                  color: colorScheme.surface,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
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
                      labelText: 'Channel Name',
                      hintText: 'e.g. My Amazing News',
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
                      labelText: 'Channel Username',
                      hintText: 'e.g. amazing-news',
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
                    controller: _bioController,
                    maxLines: 3,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'What is this channel about?',
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
                            'description': _bioController.text.trim(),
                            'visibility': visibility,
                            'commentsLocked': commentsLocked,
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
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Lock Comments',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Prevent subscribers from commenting on posts.',
                    ),
                    value: commentsLocked,
                    onChanged: (value) =>
                        setSheetState(() => commentsLocked = value),
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
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isActionLoading
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              _handleDeleteChannel();
                            },
                      icon: const Icon(Icons.delete_forever_rounded, size: 20),
                      label: const Text(
                        'Delete Channel Permanently',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: colorScheme.error.withValues(alpha: 0.35),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result == null || !mounted) return;

    if (result['action'] == 'delete') {
      _handleDeleteChannel();
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
      await context.read<MessagingProvider>().updateChannel(
        widget.conversation.id,
        name: result['name'],
        username: result['username'],
        description: result['description'],
        visibility: result['visibility'],
        commentsLocked: result['commentsLocked'] as bool?,
        imageUrl: imageUrl,
      );
      if (mounted) {
        NotificationService.showSuccess(context, 'Channel updated');
      }
    } catch (_) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to update channel');
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Consumer<MessagingProvider>(
      builder: (context, provider, child) {
        final currentUserId = context.watch<UserProvider>().user?.id;

        // Find the latest version from provider if available
        final providerConv = provider.conversations.firstWhere(
          (c) => c.id == widget.conversation.id,
          orElse: () => widget.conversation,
        );

        // Merge to ensure we have the most complete data
        final conversation = widget.conversation.copyWith(
          role: providerConv.role,
          status: providerConv.status,
          unreadCount: providerConv.unreadCount,
          subscriberCount: providerConv.subscriberCount > 0
              ? providerConv.subscriberCount
              : widget.conversation.subscriberCount,
        );

        final isOwner = conversation.role == 'owner';
        final isAdmin = conversation.role == 'admin';

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 232,
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
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                actions: [
                  if (isOwner)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Center(
                        child: GestureDetector(
                          onTap: _isActionLoading ? null : _editChannelSettings,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: Icon(
                              Icons.settings_rounded,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  background: SafeArea(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                        child: Padding(
                        padding: const EdgeInsets.only(bottom: 82),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.surface,
                            border: Border.all(
                              color: colorScheme.primary.withValues(
                                alpha: 0.45,
                              ),
                              width: 2,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child:
                              widget.conversation.avatarUrl != null &&
                                  widget.conversation.avatarUrl!.isNotEmpty
                              ? Image.network(
                                  widget.conversation.avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.campaign_rounded,
                                    size: 34,
                                    color: colorScheme.primary,
                                  ),
                                )
                              : Icon(
                                  Icons.campaign_rounded,
                                  size: 34,
                                  color: colorScheme.primary,
                                ),
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    widget.conversation.name ?? 'Channel',
                    style: TextStyle(
                      color: colorScheme.onSurface,
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
                      // Channel Identity
                      _buildSectionLabel('CHANNEL IDENTITY'),
                      const SizedBox(height: 12),
                      _ChannelInfoCard(
                        conversation: conversation,
                        colors: colorScheme,
                        actualSubscriberCount: _members.length,
                      ),
                      const SizedBox(height: 32),

                      if (widget.conversation.description != null &&
                          widget.conversation.description!.isNotEmpty) ...[
                        _buildSectionLabel('BROADCAST DESCRIPTION'),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(24),
                            border: Border(
                              top: BorderSide(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.6,
                                ),
                                width: 1.5,
                              ),
                              bottom: BorderSide(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.6,
                                ),
                                width: 1.5,
                              ),
                            ),
                          ),
                          child: Text(
                            widget.conversation.description!,
                            style: textTheme.bodyLarge?.copyWith(
                              height: 1.6,
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Channel Actions
                      _buildSectionLabel('CHANNEL ACTIONS'),
                      const SizedBox(height: 12),
                      _ChannelActionsCard(
                        conversation: widget.conversation,
                        onTip: () => TipSheet.show(
                          context,
                          recipients: [],
                          conversationId: widget.conversation.id,
                          conversationType: ConversationType.channel,
                        ),
                        onShare: _shareChannelLink,
                        colors: colorScheme,
                      ),
                      const SizedBox(height: 32),

                      _buildSectionLabel('SUBSCRIBER COMMUNITY'),
                      const SizedBox(height: 12),
                      if (_isLoadingMembers)
                        const Center(child: GriotLoader(size: 32))
                      else if (_members.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'No subscribers yet.',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _members.take(5).length,
                          itemBuilder: (context, index) {
                            final member = _members[index];
                            final isMe = member['user_id'] == currentUserId;
                            final role = member['role']?.toString() ?? 'member';
                            final isMemberOwner = role == 'owner';
                            final isMemberAdmin = role == 'admin';

                            return InkWell(
                              onTap: () => _showSubscriberOptions(
                                member,
                                isOwner,
                                isAdmin,
                                currentUserId,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundImage:
                                          member['avatar_url'] != null
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
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  (member['display_name'] ??
                                                          member['username'] ??
                                                          'Griot User') +
                                                      (isMe ? ' (You)' : ''),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ),
                                              if (member['is_plus'] == true ||
                                                  member['isPlus'] == true) ...[
                                                const SizedBox(width: 6),
                                                const GriotPlusBadge(
                                                  isPlus: true,
                                                  compact: true,
                                                ),
                                              ],
                                            ],
                                          ),
                                          if (isMemberOwner || isMemberAdmin)
                                            Text(
                                              role.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: colorScheme.primary,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (isOwner ||
                                        isAdmin ||
                                        (isMe && !isMemberOwner))
                                      Icon(
                                        Icons.more_vert_rounded,
                                        color: colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.4),
                                        size: 20,
                                      )
                                    else
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.4),
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                      if (_members.length > 5)
                        Center(
                          child: TextButton(
                            onPressed: () {},
                            child: Text(
                              'View all ${_members.length} subscribers',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 48),

                      if (!isOwner)
                        _buildDangerButton(
                          label: 'Unsubscribe',
                          icon: Icons.notifications_off_rounded,
                          onTap: _handleUnsubscribe,
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
    final colorScheme = Theme.of(context).colorScheme;
    final colors = colorScheme;
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

class _ChannelInfoCard extends StatelessWidget {
  final Conversation conversation;
  final ColorScheme colors;
  final int? actualSubscriberCount;

  const _ChannelInfoCard({
    required this.conversation,
    required this.colors,
    this.actualSubscriberCount,
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
          _infoRow(
            Icons.alternate_email_rounded,
            'Handle',
            conversation.username != null
                ? '@${conversation.username}'
                : 'NO HANDLE',
          ),
          _divider(),
          _infoRow(
            Icons.sensors_rounded,
            'Broadcasts',
            '${conversation.postCount} posts',
          ),
          _divider(),
          _infoRow(
            Icons.groups_3_outlined,
            'Followers',
            '${(actualSubscriberCount != null && actualSubscriberCount! > 0) ? actualSubscriberCount : conversation.subscriberCount} subscribers',
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.primary.withValues(alpha: 0.6)),
        const SizedBox(width: 16),
        Text(
          label,
          style: TextStyle(
            color: colors.onSurfaceVariant.withValues(alpha: 0.7),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        ),
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

class _ChannelActionsCard extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTip;
  final VoidCallback onShare;
  final ColorScheme colors;

  const _ChannelActionsCard({
    required this.conversation,
    required this.onTip,
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
              label: 'Share Channel',
              onTap: onShare,
              colors: colors,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionButton(
              icon: Icons.volunteer_activism_outlined,
              label: 'Tip Author',
              onTap: onTip,
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
            border: isPrimary
                ? null
                : Border.all(color: colors.outline.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isPrimary ? colors.onPrimary : colors.primary,
                size: 20,
              ),
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
