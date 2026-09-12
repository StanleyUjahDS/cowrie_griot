import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/messaging_provider.dart';
import '../models/chat_user.dart';
import '../../users/providers/user_provider.dart';
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
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CommentSheet(conversationId: conversationId, postId: postId),
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
      context.read<MessagingProvider>().loadPostComments(
        widget.conversationId,
        widget.postId,
      );
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
      height: MediaQuery.of(context).size.height * 0.80,
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
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
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
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No comments yet.',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final authorData = comment['author'] ?? comment['user'];
                    final authorId =
                        (authorData?['id'] ??
                                authorData?['user_id'] ??
                                comment['author_id'] ??
                                comment['authorId'])
                            ?.toString();
                    final currentUserId = context.read<UserProvider>().user?.id;

                    // Permission check for deletion
                    final provider = context.read<MessagingProvider>();
                    final matchingConversations = provider.conversations
                        .where((c) => c.id == widget.conversationId)
                        .toList();
                    final conv = matchingConversations.isNotEmpty
                        ? matchingConversations.first
                        : null;
                    final isOwner =
                        conv != null &&
                        (conv.ownerId == currentUserId || conv.role == 'owner');
                    final isAdmin = conv?.role == 'admin';
                    final canDelete =
                        isOwner || isAdmin || authorId == currentUserId;

                    return _CommentTile(
                      comment: comment,
                      canDelete: canDelete,
                      onDelete: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Comment?'),
                            content: const Text(
                              'This action cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: Theme.of(ctx).colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          try {
                            await provider.deleteChannelComment(
                              widget.conversationId,
                              widget.postId,
                              comment['id']?.toString() ?? '',
                            );
                          } catch (_) {
                            if (context.mounted) {
                              NotificationService.showError(
                                context,
                                'Failed to delete comment',
                              );
                            }
                          }
                        }
                      },
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
          Consumer2<MessagingProvider, UserProvider>(
            builder: (context, provider, userProvider, child) {
              final conv = provider.conversations.firstWhere(
                (c) => c.id == widget.conversationId,
                orElse: () => provider.conversations.first,
              );
              final isOwner =
                  conv.ownerId == userProvider.user?.id || conv.role == 'owner';
              final isAdmin = conv.role == 'admin';
              final isLocked = conv.commentsLocked && !isOwner && !isAdmin;

              if (isLocked) {
                return Container(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    20,
                    16,
                    MediaQuery.of(context).viewInsets.bottom + 40,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border(
                      top: BorderSide(
                        color: colors.outline.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: Text(
                    'Comments are locked for this post.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    MediaQuery.of(context).viewInsets.bottom + 8,
                  ),
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
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
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
                                fillColor: colors.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
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
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final bool canDelete;
  final VoidCallback onDelete;
  final Function(String id, String name) onReply;

  const _CommentTile({
    required this.comment,
    required this.canDelete,
    required this.onDelete,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // The channel comments API currently returns author data as flat fields
    // (author_id, author_username, author_display_name, author_avatar_url),
    // while socket/legacy responses may return a nested author or user.
    final authorData = _authorData(comment);
    final author = authorData != null
        ? ChatUser.fromJson(Map<String, dynamic>.from(authorData))
        : null;

    final createdAt = _parseDate(comment['createdAt'] ?? comment['created_at']);

    final role = comment['role']?.toString();
    final username = author?.username;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colors.primary.withValues(alpha: 0.1),
            backgroundImage: author?.profileUrl != null
                ? NetworkImage(author!.profileUrl!)
                : null,
            child: author?.profileUrl == null
                ? const Icon(Icons.person, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        author?.effectiveDisplayName ?? 'Griot User',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (username != null && username.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '@$username',
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    if (role == 'owner' || role == 'admin') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          role!.toUpperCase(),
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('HH:mm').format(createdAt),
                      style: textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Text(
                  comment['content'] ?? '',
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => onReply(
                        comment['id'] ?? '',
                        author?.effectiveDisplayName ?? 'User',
                      ),
                      child: Text(
                        'Reply',
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (canDelete) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: onDelete,
                        child: Text(
                          'Delete',
                          style: textTheme.labelSmall?.copyWith(
                            color: colors.error.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _authorData(Map<String, dynamic> comment) {
    final nested = comment['author'] ?? comment['user'];
    if (nested is Map) {
      return Map<String, dynamic>.from(nested);
    }

    final authorId = comment['author_id'] ?? comment['authorId'];
    final username = comment['author_username'] ?? comment['authorUsername'];
    final displayName =
        comment['author_display_name'] ?? comment['authorDisplayName'];
    final avatarUrl =
        comment['author_avatar_url'] ?? comment['authorAvatarUrl'];

    if (authorId == null &&
        username == null &&
        displayName == null &&
        avatarUrl == null) {
      return null;
    }

    return {
      'id': authorId,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
    };
  }

  DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed?.toLocal() ?? DateTime.now();
  }
}
