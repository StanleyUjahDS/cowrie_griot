import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/messaging_provider.dart';
import '../models/chat_user.dart';
import '../models/conversation_model.dart';
import '../../users/providers/user_provider.dart';
import '../../../core/ui/widgets/griot_loader.dart';
import '../../../core/services/notification_service.dart';
import 'chatting/tip_sheet.dart';

String _channelCommentId(Map<String, dynamic> comment) {
  return (comment['id'] ??
              comment['comment_id'] ??
              comment['commentId'] ??
              comment['_id'])
          ?.toString() ??
      '';
}

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
  final FocusNode _commentFocusNode = FocusNode();
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
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    final replyToId = _replyToId;

    try {
      await context.read<MessagingProvider>().submitChannelComment(
        conversationId: widget.conversationId,
        postId: widget.postId,
        content: content,
        replyToCommentId: replyToId,
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
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
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
                      conversationId: widget.conversationId,
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
                              _channelCommentId(comment),
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
                        if (id.trim().isEmpty) {
                          NotificationService.showError(
                            context,
                            'This comment cannot be replied to yet',
                          );
                          return;
                        }
                        setState(() {
                          _replyToId = id;
                          _replyToName = name;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _commentFocusNode.requestFocus();
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
              final matching = provider.conversations.where(
                (c) => c.id == widget.conversationId,
              );
              // The conversation list can briefly be empty during startup or
              // reconnect. Never call `.first` on that transient state.
              if (matching.isEmpty) {
                return const SizedBox.shrink();
              }
              final conv = matching.first;
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
                    MediaQuery.of(context).viewInsets.bottom +
                        MediaQuery.paddingOf(context).bottom +
                        52,
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
                padding: EdgeInsets.fromLTRB(
                  12,
                  8,
                  12,
                  MediaQuery.paddingOf(context).bottom + 12,
                ),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    MediaQuery.of(context).viewInsets.bottom +
                        MediaQuery.paddingOf(context).bottom +
                        12,
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
                              focusNode: _commentFocusNode,
                              onTapOutside: (_) =>
                                  FocusScope.of(context).unfocus(),
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
  final String conversationId;
  final bool canDelete;
  final VoidCallback onDelete;
  final Function(String id, String name) onReply;

  const _CommentTile({
    required this.comment,
    required this.conversationId,
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

    final replyToId =
        (comment['reply_to_comment_id'] ??
                comment['replyToCommentId'] ??
                comment['reply_to_id'])
            ?.toString();

    return Padding(
      padding: EdgeInsets.only(
        left: replyToId?.isNotEmpty == true ? 28 : 0,
        bottom: 20,
      ),
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
                if (replyToId?.isNotEmpty == true) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        size: 14,
                        color: colors.primary.withValues(alpha: 0.75),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Reply',
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.primary.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
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
                        _channelCommentId(comment),
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
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        final recipient = author;
                        TipSheet.show(
                          context,
                          recipients: recipient == null
                              ? const []
                              : [recipient],
                          conversationId: conversationId,
                          conversationType: ConversationType.channel,
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.volunteer_activism_outlined,
                            size: 14,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Tip',
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
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
