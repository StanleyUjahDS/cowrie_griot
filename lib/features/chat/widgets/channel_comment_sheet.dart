import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/messaging_provider.dart';
import '../models/chat_user.dart';
import '../../../core/ui/widgets/griot_loader.dart';
import '../../../core/services/notification_service.dart';

class CommentSheet extends StatefulWidget {
  final String conversationId;
  final String postId;

  const CommentSheet({
    super.key,
    required this.conversationId,
    required this.postId,
  });

  static void show(BuildContext context, String conversationId, String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentSheet(
        conversationId: conversationId,
        postId: postId,
      ),
    );
  }

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final TextEditingController _commentController = TextEditingController();
  String? _replyToId;
  String? _replyToName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MessagingProvider>().loadPostComments(widget.conversationId, widget.postId);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    try {
      await context.read<MessagingProvider>().submitChannelComment(
        conversationId: widget.conversationId,
        postId: widget.postId,
        content: content,
        replyToCommentId: _replyToId,
      );
      _commentController.clear();
      setState(() {
        _replyToId = null;
        _replyToName = null;
      });
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Failed to post comment');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.onSurfaceVariant.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Comments',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: Consumer<MessagingProvider>(
              builder: (context, provider, child) {
                if (provider.isLoadingComments(widget.postId)) {
                  return const Center(child: GriotLoader());
                }

                final comments = provider.getPostComments(widget.postId);
                if (comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 48, color: colors.onSurfaceVariant.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text('No comments yet.', style: TextStyle(color: colors.onSurfaceVariant)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return _CommentTile(
                      comment: comment,
                      onReply: (id, name) {
                        setState(() {
                          _replyToId = id;
                          _replyToName = name;
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
          
          // Input Area
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.outline.withValues(alpha: 0.1))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyToId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Replying to $_replyToName',
                            style: textTheme.labelSmall?.copyWith(color: colors.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () => setState(() {
                            _replyToId = null;
                            _replyToName = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          filled: true,
                          fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _submitComment,
                      icon: const Icon(Icons.send_rounded),
                      color: colors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final Function(String id, String name) onReply;

  const _CommentTile({required this.comment, required this.onReply});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    // Support multiple naming conventions from backend
    final authorData = comment['author'] ?? comment['user'];
    final author = authorData != null ? ChatUser.fromJson(Map<String, dynamic>.from(authorData)) : null;
    
    final String? createdAtStr = comment['createdAt'] ?? comment['created_at'];
    final createdAt = createdAtStr != null ? DateTime.parse(createdAtStr) : DateTime.now();

    final role = comment['role']; // Some backends might include the role of the commenter in the context of the channel

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colors.primary.withValues(alpha: 0.1),
            backgroundImage: author?.profileUrl != null ? NetworkImage(author!.profileUrl!) : null,
            child: author?.profileUrl == null ? const Icon(Icons.person, size: 20) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      author?.effectiveDisplayName ?? 'User',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                    if (role == 'owner' || role == 'admin') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          role!.toUpperCase(),
                          style: TextStyle(color: colors.primary, fontSize: 7, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('HH:mm').format(createdAt),
                      style: textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant.withValues(alpha: 0.5), fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment['content'] ?? '', style: const TextStyle(fontSize: 14, height: 1.4)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => onReply(comment['id'] ?? '', author?.effectiveDisplayName ?? 'User'),
                  child: Text(
                    'Reply',
                    style: textTheme.labelSmall?.copyWith(color: colors.primary, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
