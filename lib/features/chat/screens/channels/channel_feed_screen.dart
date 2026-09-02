import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/messaging_provider.dart';
import '../../models/conversation_model.dart';
import '../../models/chat_message.dart';
import '../../widgets/channel_comment_sheet.dart';
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
      provider.loadChannelPosts(_currentConversation.id);

      // Fetch full details to get role and subscriber count
      _fetchDetails();
    });
  }

  Future<void> _fetchDetails() async {
    try {
      final details = await context.read<MessagingApiService>().getConversation(
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
  Widget build(BuildContext context) {
    return Consumer2<MessagingProvider, UserProvider>(
      builder: (context, provider, userProvider, child) {
        final userId = userProvider.user?.id;
        
        // Find the conversation in provider list to get latest status/role
        final Conversation conv = provider.conversations.firstWhere(
          (c) => c.id == _currentConversation.id,
          orElse: () => _currentConversation,
        );

        final role = conv.role;
        final canPost = role == 'owner' || role == 'admin';
        final isSubscribed = conv.status == 'active' || conv.memberIds.contains(userId);

        return GradientScaffold(
          appBar: AppBar(
            title: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChannelDetailsScreen(conversation: conv)),
              ),
              child: Column(
                children: [
                  Text(
                    conv.title ?? 'Channel',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${conv.subscriberCount > 0 ? conv.subscriberCount : conv.memberIds.length} subscribers',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            actions: [
              if (!canPost && !isSubscribed)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: TextButton(
                    onPressed: () =>
                        provider.subscribeToChannel(conv.id),
                    child: const Text(
                      'Subscribe',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChannelDetailsScreen(conversation: conv)),
                ),
                icon: const Icon(Icons.info_outline_rounded),
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
    if (posts.isEmpty) {
      return Center(
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
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => provider.loadChannelPosts(conversationId),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return _PostCard(
                post: post,
                conversationId: conversationId,
              );
            },
          ),
        ),
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
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outline.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Broadcast a post...',
                filled: true,
                fillColor: colors.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isPosting ? null : _submit,
            icon: _isPosting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            color: colors.primary,
          ),
        ],
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final provider = context.watch<MessagingProvider>();
    final comments = provider.getPostComments(post.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAuthorInfo(context, colors, textTheme),
                const SizedBox(height: 16),
                Text(
                  post.text,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
                if (post.mediaUrl != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      post.mediaUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 100,
                        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                        child: const Center(child: Icon(Icons.error_outline_rounded)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () =>
                      CommentSheet.show(context, conversationId, post.id),
                  icon: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: colors.onSurfaceVariant),
                  label: Text(
                    '${comments.length} comments',
                    style: TextStyle(
                      fontWeight: FontWeight.w800, 
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => provider.toggleReaction(post.id, '❤️'),
                  icon: Icon(
                    post.reactions.containsKey('❤️')
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 18,
                    color: post.reactions.containsKey('❤️') ? Colors.red : null,
                  ),
                ),
                IconButton(
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(
                      text: '${post.text}\n\nJoin this channel on Griot.',
                    ),
                  ),
                  icon: const Icon(Icons.share_rounded, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
