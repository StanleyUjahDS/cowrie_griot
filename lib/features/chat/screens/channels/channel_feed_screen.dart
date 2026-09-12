import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/messaging_provider.dart';
import '../../models/conversation_model.dart';
import '../../models/chat_user.dart';
import '../../models/chat_message.dart';
import '../../widgets/channel_comment_sheet.dart';
import '../../widgets/chatting/tip_sheet.dart';
import '../../widgets/chatting/attachment_sheet.dart';
import '../../widgets/chatting/media_preview_sheet.dart';
import '../../services/messaging_api_service.dart';
import 'package:griot_cowrie/features/users/providers/user_provider.dart';
import 'package:griot_cowrie/core/services/notification_service.dart';
import '../../../../core/ui/widgets/griot_loader.dart';
import '../../../../core/ui/scaffolds/gradient_scaffold.dart';

import 'channel_details_screen.dart';

class ChannelFeedScreen extends StatefulWidget {
  final Conversation conversation;

  const ChannelFeedScreen({super.key, required this.conversation});

  @override
  State<ChannelFeedScreen> createState() => _ChannelFeedScreenState();
}

class _ChannelFeedScreenState extends State<ChannelFeedScreen> {
  late Conversation _currentConversation;

  @override
  void initState() {
    super.initState();
    _currentConversation = widget.conversation;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MessagingProvider>();
      provider.joinConversation(_currentConversation.id);
      provider.loadChannelPosts(_currentConversation.id);

      // Fetch full details to get role and subscriber count
      _fetchDetails();
    });
  }

  Future<void> _fetchDetails() async {
    try {
      final details = await context.read<MessagingApiService>().getChannel(
        _currentConversation.id,
      );
      if (mounted) {
        setState(() => _currentConversation = details);
      }
    } catch (e) {
      debugPrint('Failed to fetch channel details: $e');
    }
  }

  @override
  void dispose() {
    context.read<MessagingProvider>().leaveConversation(
      _currentConversation.id,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<MessagingProvider, UserProvider>(
      builder: (context, provider, userProvider, child) {
        final userId = userProvider.user?.id;

        // Find the conversation in provider list to get latest status/role
        final Conversation providerConv = provider.conversations.firstWhere(
          (c) => c.id == _currentConversation.id,
          orElse: () => _currentConversation,
        );

        // Merge to ensure we have ownerId and latest counts from _currentConversation
        // while keeping role and status from provider.
        final conv = _currentConversation.copyWith(
          role: providerConv.role,
          status: providerConv.status,
          unreadCount: providerConv.unreadCount,
          memberIds: providerConv.memberIds.isNotEmpty
              ? providerConv.memberIds
              : _currentConversation.memberIds,
        );

        final role = conv.role;
        // Strictly follow owner/admin role for posting permissions,
        // with ownerId check as a reliable fallback.
        final isOwner =
            role == 'owner' ||
            (conv.ownerId != null && userId != null && conv.ownerId == userId);
        final isAdmin = role == 'admin';
        final canPost = isOwner || isAdmin;
        final isSubscribed =
            conv.status == 'active' || conv.memberIds.contains(userId);

        return GradientScaffold(
          appBar: AppBar(
            toolbarHeight: 64,
            title: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChannelDetailsScreen(conversation: conv),
                ),
              ),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      conv.title ?? 'Channel',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${conv.subscriberCount > 0 ? conv.subscriberCount : (conv.memberCount > 0 ? conv.memberCount : (conv.memberIds.isNotEmpty ? conv.memberIds.length : 1))} subscribers',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            centerTitle: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            actions: [
              if (!canPost && !isSubscribed)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton(
                    onPressed: () => provider.subscribeToChannel(conv.id),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Join',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              IconButton(
                onPressed: () async {
                  final ownerId = conv.ownerId;
                  if (ownerId == null) return;

                  final api = context.read<MessagingApiService>();

                  try {
                    // Try to find in already loaded members if possible
                    final member = await api.getChannelMember(conv.id, ownerId);
                    if (context.mounted) {
                      TipSheet.show(
                        context,
                        recipients: [ChatUser.fromJson(member)],
                        conversationId: conv.id,
                        conversationType: ConversationType.channel,
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      TipSheet.show(
                        context,
                        recipients: [],
                        conversationId: conv.id,
                        conversationType: ConversationType.channel,
                      );
                    }
                  }
                },
                icon: const Icon(Icons.volunteer_activism_outlined),
                color: Theme.of(context).colorScheme.primary,
              ),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChannelDetailsScreen(conversation: conv),
                  ),
                ),
                icon: const Icon(Icons.info_outline_rounded),
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
            ],
          ),
          child: _buildBody(context, provider, canPost, conv.id),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    MessagingProvider provider,
    bool canPost,
    String conversationId,
  ) {
    if (provider.isLoadingPosts(conversationId)) {
      return const Center(child: GriotLoader());
    }

    final posts = provider.getChannelPosts(conversationId);
    final content = posts.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.feed_rounded,
                  size: 64,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No posts yet.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: () => provider.loadChannelPosts(conversationId),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return _PostCard(post: post, conversationId: conversationId);
              },
            ),
          );

    return Stack(
      children: [
        Positioned.fill(child: content),
        if (canPost)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ChannelComposer(conversationId: conversationId),
          ),
      ],
    );
  }
}

class _ChannelComposer extends StatefulWidget {
  final String conversationId;
  const _ChannelComposer({required this.conversationId});

  @override
  State<_ChannelComposer> createState() => _ChannelComposerState();
}

class _ChannelComposerState extends State<_ChannelComposer> {
  final _controller = TextEditingController();
  bool _isPosting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);
    try {
      await context.read<MessagingProvider>().createChannelPost(
        widget.conversationId,
        text,
      );
      _controller.clear();
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to broadcast post');
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AttachmentSheet(
        onImage: () => _pickImage(ImageSource.gallery),
        onCamera: () => _pickImage(ImageSource.camera),
        onVideo: () => _pickVideo(),
        onFile: () => _pickFile(),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source);
    if (file != null) {
      if (!mounted) return;
      await MediaPreviewSheet.show(
        context,
        filePath: file.path,
        type: MessageType.image,
        onSend: (caption) =>
            context.read<MessagingProvider>().sendChannelMediaPost(
              conversationId: widget.conversationId,
              filePath: file.path,
              type: MessageType.image,
              content: caption,
            ),
      );
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      if (!mounted) return;
      await MediaPreviewSheet.show(
        context,
        filePath: file.path,
        type: MessageType.video,
        onSend: (caption) =>
            context.read<MessagingProvider>().sendChannelMediaPost(
              conversationId: widget.conversationId,
              filePath: file.path,
              type: MessageType.video,
              content: caption,
            ),
      );
    }
  }

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile();
    if (file != null && file.path != null) {
      if (!mounted) return;
      await MediaPreviewSheet.show(
        context,
        filePath: file.path!,
        type: MessageType.file,
        onSend: (caption) =>
            context.read<MessagingProvider>().sendChannelMediaPost(
              conversationId: widget.conversationId,
              filePath: file.path!,
              type: MessageType.file,
              content: caption,
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colors.outline.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: _showAttachmentSheet,
              icon: Icon(
                Icons.add_circle_outline_rounded,
                color: colors.primary,
              ),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Broadcast a story...',
                  hintStyle: TextStyle(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: colors.onSurface.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
              ),
            ),
            const SizedBox(width: 10),
            _FloatingComposerButton(
              icon: Icons.arrow_upward_rounded,
              background: colors.primary,
              foreground: colors.onPrimary,
              onTap: _isPosting ? () {} : _submit,
              isLoading: _isPosting,
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingComposerButton extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final bool isLoading;

  const _FloatingComposerButton({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: isLoading
              ? Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                )
              : Icon(icon, color: foreground, size: 24),
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final ChatMessage post;
  final String conversationId;

  const _PostCard({required this.post, required this.conversationId});

  Widget _buildAuthorInfo(
    BuildContext context,
    ColorScheme colors,
    TextTheme textTheme,
  ) {
    final provider = context.read<MessagingProvider>();
    final conversations = provider.conversations
        .where((c) => c.id == conversationId)
        .toList();
    final conv = conversations.isNotEmpty ? conversations.first : null;

    final name = conv?.title ?? 'Channel Post';
    final avatarUrl = conv?.avatarUrl;
    final role = conv?.role;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.primary.withValues(alpha: 0.1)),
          ),
          child: ClipOval(
            child: avatarUrl != null
                ? Image.network(avatarUrl, fit: BoxFit.cover)
                : Icon(Icons.sensors_rounded, size: 20, color: colors.primary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  if (role == 'owner' || role == 'admin') ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        role!.toUpperCase(),
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                DateFormat('d MMM yyyy, HH:mm').format(post.createdAt),
                style: textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<MessagingProvider>();
    final comments = provider.getPostComments(post.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAuthorInfo(context, colors, textTheme),
                const SizedBox(height: 20),
                Text(
                  post.text,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (post.mediaUrl != null) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      post.mediaUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(
                          child: Icon(Icons.broken_image_outlined, size: 32),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () =>
                      CommentSheet.show(context, conversationId, post.id),
                  icon: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 18,
                    color: colors.primary,
                  ),
                  label: Text(
                    '${comments.length} comments',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: colors.primary,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(
                      text: '${post.text}\n\nJoin this channel on Griot.',
                    ),
                  ),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
