import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_branded_container.dart';
import '../../../core/ui/widgets/griot_feed_media.dart';
import '../../../core/network/api_config.dart';
import '../services/messaging_api_service.dart';
import '../models/chat_user.dart';
import '../widgets/camp_tip_sheet.dart';
import '../widgets/camp_tale_components.dart';
import '../widgets/camp_tale_media_gallery.dart';
import '../widgets/chatting/link_preview_widget.dart';
import '../widgets/chatting/report_content_sheet.dart';
import '../../../core/services/notification_service.dart';
import '../../users/providers/user_provider.dart';
import '../../auth/auth_controller.dart';

class TalePublicScreen extends StatefulWidget {
  final String taleId;
  final Map<String, dynamic>? initialTale;

  const TalePublicScreen({super.key, required this.taleId, this.initialTale});

  @override
  State<TalePublicScreen> createState() => _TalePublicScreenState();
}

class _TalePublicScreenState extends State<TalePublicScreen>
    with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _taleFuture;
  late Future<List<Map<String, dynamic>>> _commentsFuture;
  Future<Map<String, dynamic>>? _threadFuture;
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  final _commentComposerKey = GlobalKey();
  final _primaryTaleKey = GlobalKey();
  final Map<String, GlobalKey> _threadPartKeys = {};
  String? _replyToCommentId;
  String? _replyToAuthor;
  final Set<String> _expandedCommentThreads = <String>{};
  int _visibleCommentLimit = 20;
  late String _commentTargetTaleId;
  String? _commentTargetThreadId;
  String _commentTargetLabel = 'this Tale';
  bool _postingComment = false;
  bool _threadExpanded = false;
  int? _viewerVote;
  bool? _viewerUpvoted;
  bool? _viewerDownvoted;
  int? _upvotes;
  int? _downvotes;
  bool _voting = false;
  bool _savingToCampList = false;
  bool? _bookmarked;
  final _readerScrollController = ScrollController();
  bool _readerChromeVisible = true;
  late final AnimationController _readerChromeAnimation;
  final Map<String, Map<String, int>> _commentVotes = {};

  GlobalKey _threadPartKey(String taleId) {
    return _threadPartKeys.putIfAbsent(taleId, GlobalKey.new);
  }

  @override
  void initState() {
    super.initState();
    _readerChromeAnimation =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 280),
          value: 1,
        )..addListener(() {
          if (mounted) setState(() {});
        });
    // Feed cards intentionally carry a lightweight snapshot. Always hydrate
    // the dedicated reader from the canonical endpoint so linked parts,
    // media, counts and author data are not stale or missing when a card is
    // opened from Camp.
    final api = context.read<MessagingApiService>();
    _taleFuture = api
        .getTale(widget.taleId)
        .then((remote) {
          if (remote.isNotEmpty) return remote;
          return widget.initialTale ?? <String, dynamic>{};
        })
        .catchError((_) => widget.initialTale ?? <String, dynamic>{});
    _commentsFuture = context.read<MessagingApiService>().getTaleComments(
      widget.taleId,
    );
    // Count a reader once when the dedicated Tale screen opens. The backend
    // endpoint is idempotent for the current viewer, so retries are safe.
    unawaited(
      context.read<MessagingApiService>().markTaleViewed(widget.taleId),
    );
    _commentTargetTaleId = widget.taleId;
    _commentTargetThreadId = widget.initialTale == null
        ? null
        : _threadId(widget.initialTale!);
    final initial = widget.initialTale;
    final initialThreadCount = int.tryParse(
      '${initial?['threadCount'] ?? initial?['thread_count'] ?? 1}',
    );
    if (initial != null &&
        _threadId(initial) != null &&
        (initialThreadCount ?? 1) > 1) {
      // A dedicated reader is the full continuity view. Open multi-part
      // Tales with the linked section visible so Part 1 is never hidden when
      // the reader was opened from a later part.
      _threadExpanded = true;
      _threadFuture = context.read<MessagingApiService>().getTaleThread(
        widget.taleId,
      );
    }
  }

  Widget _threadSection(
    BuildContext context,
    Map<String, dynamic> tale,
    int threadPosition,
    int threadCount,
  ) {
    final colors = Theme.of(context).colorScheme;
    if (!_threadExpanded) {
      return TextButton.icon(
        onPressed: () => setState(() => _threadExpanded = true),
        icon: const Icon(Icons.account_tree_outlined, size: 18),
        label: Text('View all $threadCount parts'),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }
    if (_threadFuture == null) {
      return OutlinedButton.icon(
        onPressed: () => _openThread(tale),
        icon: const Icon(Icons.account_tree_rounded, size: 18),
        label: Text('Part $threadPosition of $threadCount · View continuity'),
      );
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: _threadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: () => _openThread(tale),
              icon: const Icon(Icons.account_tree_outlined, size: 17),
              label: const Text('Show linked parts'),
            ),
          );
        }
        final raw = snapshot.data!['items'] ?? snapshot.data!['parts'];
        final allItems = raw is List
            ? raw.whereType<Map>().map(Map<String, dynamic>.from).toList()
            : <Map<String, dynamic>>[];
        allItems.sort((a, b) {
          final aPosition =
              int.tryParse(
                '${a['threadPosition'] ?? a['thread_position'] ?? 1}',
              ) ??
              1;
          final bPosition =
              int.tryParse(
                '${b['threadPosition'] ?? b['thread_position'] ?? 1}',
              ) ??
              1;
          return aPosition.compareTo(bPosition);
        });
        // The reader already renders the selected part in the primary Tale
        // surface. Do not render that same part again in the continuity list.
        final currentId = tale['id']?.toString();
        final currentPosition = threadPosition;
        final items = allItems.where((item) {
          final itemId = item['id']?.toString();
          if (currentId != null && currentId.isNotEmpty && itemId != null) {
            return itemId != currentId;
          }
          final itemPosition = int.tryParse(
            '${item['threadPosition'] ?? item['thread_position'] ?? 1}',
          );
          return itemPosition != currentPosition;
        }).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        final firstPart = allItems.cast<Map<String, dynamic>?>().firstWhere(
          (item) =>
              int.tryParse(
                '${item?['threadPosition'] ?? item?['thread_position'] ?? 1}',
              ) ==
              1,
          orElse: () => null,
        );
        // Keep the continuation visually attached to the primary Tale card.
        // The parts are one reading surface, not a list of unrelated cards.
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (currentPosition > 1 && firstPart != null) ...[
                CampTaleReshareCard(
                  label: 'Co-telling · Original Tale',
                  sourceAuthorName:
                      '${tale['threadOriginalAuthorName'] ?? tale['thread_original_author_name'] ?? ''}',
                  sourceAuthorAvatarUrl:
                      '${tale['threadOriginalAuthorAvatarUrl'] ?? tale['thread_original_author_avatar_url'] ?? ''}',
                  sourceText:
                      '${firstPart['content'] ?? firstPart['text'] ?? ''}'
                          .trim(),
                  sourceMediaUrls: _mediaUrls(firstPart),
                  onAuthorTap: _threadOriginalAuthorId(tale) == null
                      ? null
                      : () => context.push(
                          '/camp/profile/${_threadOriginalAuthorId(tale)}',
                        ),
                  onSourceTap: firstPart['id'] == null
                      ? null
                      : () => context.push('/tale/${firstPart['id']}'),
                  mediaBuilder: (context, urls) =>
                      _mediaGallery({'mediaUrls': urls}),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 19,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reading this Tale',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${allItems.length} parts',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isLast = index == items.length - 1;
                final itemPosition =
                    int.tryParse(
                      '${item['threadPosition'] ?? item['thread_position'] ?? index + 1}',
                    ) ??
                    index + 1;
                final itemId = item['id']?.toString() ?? '';
                final itemContent = '${item['content'] ?? item['text'] ?? ''}'
                    .trim();
                final itemCommentCount =
                    int.tryParse(
                      '${item['commentCount'] ?? item['comment_count'] ?? 0}',
                    ) ??
                    0;
                return KeyedSubtree(
                  key: itemId.isEmpty ? null : _threadPartKey(itemId),
                  child: CampTaleThreadRail(
                    isLast: isLast,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Part $itemPosition of ${allItems.length}',
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (itemContent.isNotEmpty)
                            CampTaleText(
                              key: ValueKey('text-$itemId'),
                              text: itemContent,
                              fontSize: 15,
                            ),
                          if (_mediaUrls(item).isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _mediaGallery(item),
                          ],
                          if (itemId.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Divider(
                              height: 1,
                              color: colors.outlineVariant.withValues(
                                alpha: .32,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: () => _selectCommentTarget(
                                      itemId,
                                      'Part $itemPosition',
                                      threadId: _threadId(item),
                                    ),
                                    icon: const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 17,
                                    ),
                                    label: Text(
                                      itemCommentCount == 0
                                          ? 'Comment'
                                          : '$itemCommentCount Comments',
                                    ),
                                    style: TextButton.styleFrom(
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                        vertical: 7,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Part actions',
                                  padding: EdgeInsets.zero,
                                  onSelected: (value) {
                                    if (value == 'retell') _retell(item);
                                    if (value == 'cotell') _coTell(item);
                                    if (value == 'tip') {
                                      _tipTaleCreator(item);
                                    }
                                    if (value == 'share') {
                                      SharePlus.instance.share(
                                        ShareParams(
                                          text:
                                              'Read this Tale on Griot: https://griot.network/tale/$itemId',
                                        ),
                                      );
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'retell',
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(Icons.repeat_rounded),
                                        title: Text('Retell this part'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'cotell',
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          Icons.account_tree_outlined,
                                        ),
                                        title: Text('Co-tell this part'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'tip',
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          Icons.volunteer_activism_outlined,
                                        ),
                                        title: Text('Gift creator'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'share',
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(Icons.ios_share_rounded),
                                        title: Text('Share part'),
                                      ),
                                    ),
                                  ],
                                  icon: const Icon(Icons.more_horiz_rounded),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _commentsSection(BuildContext context, Map<String, dynamic> tale) {
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _commentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return GriotBrandedContainer(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.forum_outlined, color: colors.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(child: Text('Comments are unavailable right now.')),
                IconButton(
                  tooltip: 'Retry comments',
                  onPressed: () => setState(() {
                    _commentsFuture = context
                        .read<MessagingApiService>()
                        .getTaleComments(_commentTargetTaleId);
                  }),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          );
        }
        final comments = snapshot.data ?? const <Map<String, dynamic>>[];
        for (final comment in comments) {
          final id = comment['id']?.toString();
          if (id == null || id.isEmpty || _commentVotes.containsKey(id)) {
            continue;
          }
          _commentVotes[id] = {
            'up':
                int.tryParse(
                  '${comment['upvoteCount'] ?? comment['upvote_count'] ?? 0}',
                ) ??
                0,
            'down':
                int.tryParse(
                  '${comment['downvoteCount'] ?? comment['downvote_count'] ?? 0}',
                ) ??
                0,
            'vote':
                int.tryParse(
                  '${comment['viewerVote'] ?? comment['viewer_vote'] ?? 0}',
                ) ??
                0,
            'upVoted':
                comment['viewerUpvoted'] == true ||
                    comment['viewer_upvoted'] == true
                ? 1
                : 0,
            'downVoted':
                comment['viewerDownvoted'] == true ||
                    comment['viewer_downvoted'] == true
                ? 1
                : 0,
          };
        }
        final roots = comments
            .where((comment) => _commentParentId(comment) == null)
            .toList(growable: false);
        final visibleRoots = roots
            .take(_visibleCommentLimit)
            .toList(growable: false);
        final replies = <String, List<Map<String, dynamic>>>{};
        for (final comment in comments) {
          final parent = _commentParentId(comment);
          if (parent != null) {
            replies.putIfAbsent(parent, () => []).add(comment);
          }
        }
        return Padding(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.forum_outlined),
                  const SizedBox(width: 8),
                  Text(
                    'Comments · $_commentTargetLabel',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${comments.length}',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (roots.isEmpty)
                Text(
                  'Be the first to comment on this Tale.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                )
              else
                for (var index = 0; index < visibleRoots.length; index++) ...[
                  _commentTile(
                    context,
                    visibleRoots[index],
                    replies[visibleRoots[index]['id']?.toString()] ?? const [],
                  ),
                  if (visibleRoots.length >= 12 && index == 5) ...[
                    const SizedBox(height: 8),
                    CampNativeAdCard(
                      key: ValueKey('comments-native-ad-$_commentTargetTaleId'),
                      placement: 'Comments',
                      compact: true,
                      height: 250,
                    ),
                  ],
                ],
              if (visibleRoots.length < roots.length)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _visibleCommentLimit += 20;
                      }),
                      icon: const Icon(Icons.expand_more_rounded),
                      label: Text(
                        'Load more comments (${roots.length - visibleRoots.length} remaining)',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _commentTile(
    BuildContext context,
    Map<String, dynamic> comment,
    List<Map<String, dynamic>> replies,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _commentCard(context, comment),
        if (replies.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // The branch starts at the parent comment, not at the next
                // sibling card. The short horizontal arm makes that ownership
                // explicit before the rail continues through the replies.
                Positioned(
                  left: 8,
                  top: 8,
                  bottom: 22,
                  child: Container(
                    width: 2,
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: .72),
                  ),
                ),
                Positioned(
                  left: -8,
                  top: 18,
                  child: Container(
                    width: 16,
                    height: 2,
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: .72),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() {
                          final id = comment['id']?.toString() ?? '';
                          if (!_expandedCommentThreads.add(id)) {
                            _expandedCommentThreads.remove(id);
                          }
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _expandedCommentThreads.contains(
                                      comment['id']?.toString(),
                                    )
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _expandedCommentThreads.contains(
                                      comment['id']?.toString(),
                                    )
                                    ? 'Hide ${replies.length} repl${replies.length == 1 ? 'y' : 'ies'}'
                                    : 'View ${replies.length} repl${replies.length == 1 ? 'y' : 'ies'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_expandedCommentThreads.contains(
                        comment['id']?.toString(),
                      ))
                        ...replies.asMap().entries.map(
                          (entry) => Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: -12,
                                top: 28,
                                child: Container(
                                  width: 12,
                                  height: 2,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: .72),
                                ),
                              ),
                              _commentCard(context, entry.value, reply: true),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _commentCard(
    BuildContext context,
    Map<String, dynamic> comment, {
    bool reply = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final author = _commentAuthor(comment);
    final commentId = comment['id']?.toString() ?? '';
    final authorId = (comment['authorId'] ?? comment['author_id'])?.toString();
    final commentAuthorMap = comment['author'] is Map
        ? Map<String, dynamic>.from(comment['author'] as Map)
        : const <String, dynamic>{};
    final commentIsPlus =
        comment['isPlus'] == true ||
        comment['is_plus'] == true ||
        commentAuthorMap['isPlus'] == true ||
        commentAuthorMap['is_plus'] == true;
    final commentIsPioneer =
        comment['isPioneer'] == true ||
        comment['is_pioneer'] == true ||
        commentAuthorMap['isPioneer'] == true ||
        commentAuthorMap['is_pioneer'] == true;
    return CampTaleCommentSurface(
      reply: reply,
      margin: EdgeInsets.only(bottom: reply ? 8 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CampTaleHeader(
            authorName: author,
            avatarUrl: _commentAvatar(comment),
            isPlus: commentIsPlus,
            isPioneer: commentIsPioneer,
            subtitle: [
              if (_commentUsername(comment).isNotEmpty)
                '@${_commentUsername(comment)}',
              if (_commentDate(comment).isNotEmpty) _commentDate(comment),
            ].join(' · '),
            onAuthorTap: authorId == null || authorId.isEmpty
                ? null
                : () => context.push('/camp/profile/$authorId'),
            menu: _commentMenu(context, comment, author),
          ),
          const SizedBox(height: 9),
          CampTaleText(
            key: ValueKey('comment-text-$commentId'),
            text: '${comment['content'] ?? ''}',
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: .35),
          ),
          const SizedBox(height: 4),
          _commentActions(context, comment),
        ],
      ),
    );
  }

  Widget _commentMenu(
    BuildContext context,
    Map<String, dynamic> comment,
    String author,
  ) {
    final commentId = comment['id']?.toString() ?? '';
    final currentUserId = context.read<UserProvider>().user?.id.toString();
    final commentAuthorId = (comment['authorId'] ?? comment['author_id'])
        ?.toString();
    final canDelete =
        currentUserId != null &&
        commentAuthorId != null &&
        currentUserId == commentAuthorId;
    return PopupMenuButton<String>(
      tooltip: 'Comment actions',
      icon: const Icon(Icons.more_horiz_rounded, size: 18),
      onSelected: (value) {
        if (value == 'reply') {
          setState(() {
            _replyToCommentId = commentId;
            _replyToAuthor = author;
          });
          _commentFocusNode.requestFocus();
        } else if (value == 'retell') {
          _retellComment(comment, author);
        } else if (value == 'cotell') {
          _coTellComment(comment, author);
        } else if (value == 'report') {
          ReportContentSheet.show(
            context: context,
            targetType: 'tale_comment',
            targetId: commentId,
            subjectLabel: 'Comment',
          );
        } else if (value == 'delete') {
          _deleteComment(comment);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'reply',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.reply_rounded),
            title: Text('Reply'),
          ),
        ),
        const PopupMenuItem(
          value: 'retell',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.repeat_rounded),
            title: Text('Retell this comment'),
          ),
        ),
        const PopupMenuItem(
          value: 'cotell',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.link_rounded),
            title: Text('Co-tell this comment'),
          ),
        ),
        if (!canDelete)
          const PopupMenuItem(
            value: 'report',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.flag_outlined),
              title: Text('Report'),
            ),
          ),
        if (canDelete)
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline_rounded),
              title: Text('Delete comment'),
            ),
          ),
      ],
    );
  }

  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    final id = comment['id']?.toString();
    if (id == null || id.isEmpty || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This comment and its replies will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<MessagingApiService>().deleteTaleComment(
        _commentTargetTaleId,
        id,
      );
      if (!mounted) return;
      setState(() {
        _commentsFuture = context.read<MessagingApiService>().getTaleComments(
          _commentTargetTaleId,
        );
      });
      NotificationService.showSuccess(context, 'Comment deleted');
    } catch (error) {
      if (mounted) {
        NotificationService.showError(
          context,
          'Could not delete comment: $error',
        );
      }
    }
  }

  Future<void> _retellComment(
    Map<String, dynamic> comment,
    String author,
  ) async {
    await context.push(
      '/campfires/tales/create',
      extra: {
        'initialText': '${comment['content'] ?? ''}'.trim(),
        'initialReferenceText': '${comment['content'] ?? ''}'.trim(),
        'initialReferenceLabel': 'Comment by $author · retold in a Tale',
        'composerTitle': 'Retell this comment',
      },
    );
  }

  Future<void> _coTellComment(
    Map<String, dynamic> comment,
    String author,
  ) async {
    await context.push(
      '/campfires/tales/create',
      extra: {
        'initialThreadId': _commentTargetThreadId,
        'initialText': '${comment['content'] ?? ''}'.trim(),
        'initialReferenceText': '${comment['content'] ?? ''}'.trim(),
        'initialReferenceLabel': 'Comment by $author · co-told in a Tale',
        'composerTitle': 'Co-tell this comment',
      },
    );
  }

  Widget _commentActions(
    BuildContext context,
    Map<String, dynamic> comment, {
    bool compact = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final id = comment['id']?.toString() ?? '';
    final state = _commentVotes[id] ?? const <String, int>{};
    final vote =
        state['vote'] ??
        int.tryParse(
          '${comment['viewerVote'] ?? comment['viewer_vote'] ?? 0}',
        ) ??
        0;
    final upVoted = (state['upVoted'] ?? (vote == 1 ? 1 : 0)) == 1;
    final downVoted = (state['downVoted'] ?? (vote == -1 ? 1 : 0)) == 1;
    final up =
        state['up'] ??
        int.tryParse(
          '${comment['upvoteCount'] ?? comment['upvote_count'] ?? 0}',
        ) ??
        0;
    final down =
        state['down'] ??
        int.tryParse(
          '${comment['downvoteCount'] ?? comment['downvote_count'] ?? 0}',
        ) ??
        0;
    return Row(
      children: [
        Expanded(
          child: _commentVoteButton(
            context,
            comment,
            upVoted ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
            up,
            upVoted ? colors.primary : colors.onSurfaceVariant,
            upVoted ? 'remove_up' : 'up',
            compact,
          ),
        ),
        Expanded(
          child: _commentVoteButton(
            context,
            comment,
            downVoted
                ? Icons.thumb_down_alt_rounded
                : Icons.thumb_down_alt_outlined,
            down,
            downVoted ? colors.error : colors.onSurfaceVariant,
            downVoted ? 'remove_down' : 'down',
            compact,
          ),
        ),
        Expanded(
          child: CampTaleActionButton(
            icon: Icons.reply_rounded,
            label: 'Reply',
            tooltip: 'Reply to comment',
            onTap: id.isEmpty
                ? null
                : () {
                    setState(() {
                      _replyToCommentId = _commentParentId(comment) ?? id;
                      _replyToAuthor = _commentAuthor(comment);
                    });
                    _commentFocusNode.requestFocus();
                  },
          ),
        ),
        Expanded(
          child: CampTaleActionButton(
            icon: Icons.repeat_rounded,
            label: 'Retell',
            tooltip: 'Retell or co-tell',
            onTap: id.isEmpty ? null : () => _showCommentRetellActions(comment),
          ),
        ),
      ],
    );
  }

  Widget _commentVoteButton(
    BuildContext context,
    Map<String, dynamic> comment,
    IconData icon,
    int count,
    Color color,
    String? nextVote,
    bool compact,
  ) {
    final id = comment['id']?.toString() ?? '';
    final active = nextVote == 'remove_up' || nextVote == 'remove_down';
    return CampTaleActionButton(
      icon: icon,
      label: '$count',
      tooltip: nextVote == 'up' || nextVote == 'remove_up'
          ? (active ? 'Remove upvote' : 'Like comment')
          : (active ? 'Remove downvote' : 'Dislike comment'),
      active: active,
      activeColor: color,
      onTap: id.isEmpty ? null : () => _voteComment(id, nextVote),
    );
  }

  Future<void> _showCommentRetellActions(Map<String, dynamic> comment) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.repeat_rounded),
              title: const Text('Retell'),
              onTap: () => Navigator.pop(sheetContext, 'retell'),
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Co-tell'),
              onTap: () => Navigator.pop(sheetContext, 'cotell'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'retell') _retellComment(comment, _commentAuthor(comment));
    if (choice == 'cotell') _coTellComment(comment, _commentAuthor(comment));
  }

  Future<void> _voteComment(String commentId, String? vote) async {
    try {
      final result = await context
          .read<MessagingApiService>()
          .voteOnTaleComment(_commentTargetTaleId, commentId, vote: vote);
      if (!mounted) return;
      final hasUp =
          result.containsKey('viewerUpvoted') ||
          result.containsKey('viewer_upvoted');
      final hasDown =
          result.containsKey('viewerDownvoted') ||
          result.containsKey('viewer_downvoted');
      setState(() {
        final previous = _commentVotes[commentId] ?? const <String, int>{};
        final returnedVote =
            int.tryParse(
              '${result['viewerVote'] ?? result['viewer_vote'] ?? 0}',
            ) ??
            0;
        _commentVotes[commentId] = {
          'up':
              int.tryParse(
                '${result['upvoteCount'] ?? result['upvote_count'] ?? 0}',
              ) ??
              0,
          'down':
              int.tryParse(
                '${result['downvoteCount'] ?? result['downvote_count'] ?? 0}',
              ) ??
              0,
          'vote': returnedVote,
          'upVoted': hasUp
              ? (result['viewerUpvoted'] == true ||
                        result['viewer_upvoted'] == true
                    ? 1
                    : 0)
              : (previous['upVoted'] ?? 0),
          'downVoted': hasDown
              ? (result['viewerDownvoted'] == true ||
                        result['viewer_downvoted'] == true
                    ? 1
                    : 0)
              : (previous['downVoted'] ?? 0),
        };
      });
    } catch (error) {
      if (mounted) {
        NotificationService.showError(
          context,
          'Could not update comment reaction: $error',
        );
      }
    }
  }

  Widget _commentComposer(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      key: _commentComposerKey,
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyToCommentId != null)
              Row(
                children: [
                  Icon(Icons.reply_rounded, size: 16, color: colors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Replying to ${_replyToAuthor ?? 'comment'} · $_commentTargetLabel',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() {
                      _replyToCommentId = null;
                      _replyToAuthor = null;
                    }),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: _replyToCommentId == null
                          ? 'Comment on $_commentTargetLabel…'
                          : 'Write a reply…',
                      filled: true,
                      fillColor: colors.surfaceContainerHighest.withValues(
                        alpha: .22,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: colors.outlineVariant.withValues(alpha: .45),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: colors.outlineVariant.withValues(alpha: .45),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Post comment',
                  onPressed: _postingComment ? null : () => _postComment(),
                  icon: _postingComment
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _postingComment) return;
    setState(() => _postingComment = true);
    try {
      await context.read<MessagingApiService>().createTaleComment(
        _commentTargetTaleId,
        content: content,
        parentCommentId: _replyToCommentId,
      );
      _commentController.clear();
      if (mounted) {
        setState(() {
          _replyToCommentId = null;
          _replyToAuthor = null;
          _commentsFuture = context.read<MessagingApiService>().getTaleComments(
            _commentTargetTaleId,
          );
        });
        _commentFocusNode.unfocus();
      }
    } catch (error) {
      if (mounted) {
        NotificationService.showError(
          context,
          'Could not post comment: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _postingComment = false);
    }
  }

  void _selectCommentTarget(String taleId, String label, {String? threadId}) {
    if (taleId.isEmpty) return;
    setState(() {
      _commentTargetTaleId = taleId;
      _commentTargetThreadId = threadId;
      _commentTargetLabel = label;
      _visibleCommentLimit = 20;
      _replyToCommentId = null;
      _replyToAuthor = null;
      _commentsFuture = context.read<MessagingApiService>().getTaleComments(
        taleId,
      );
    });
    _commentFocusNode.requestFocus();
    // Keep the selected part as the reader's anchor. Forcing the composer into
    // view here used to jump every part-specific comment to the bottom.
    void revealSelectedPart() {
      if (!mounted) return;
      final target = taleId == widget.taleId
          ? _primaryTaleKey.currentContext
          : _threadPartKeys[taleId]?.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: .16,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      revealSelectedPart();
      // The keyboard can issue a second automatic scroll after focus. Reapply
      // the selected-part anchor once that adjustment has settled.
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (mounted) revealSelectedPart();
      });
    });
  }

  String? _commentParentId(Map<String, dynamic> comment) {
    final value = comment['parentCommentId'] ?? comment['parent_comment_id'];
    final id = value?.toString().trim();
    return id == null || id.isEmpty ? null : id;
  }

  String _commentAuthor(Map<String, dynamic> comment) {
    final author = _commentAuthorMap(comment);
    return '${author['displayName'] ?? author['display_name'] ?? author['username'] ?? 'Griot user'}';
  }

  Map<String, dynamic> _commentAuthorMap(Map<String, dynamic> comment) {
    final nested = comment['author'] ?? comment['user'] ?? comment['commenter'];
    return nested is Map
        ? <String, dynamic>{...comment, ...Map<String, dynamic>.from(nested)}
        : comment;
  }

  String _commentUsername(Map<String, dynamic> comment) {
    final author = _commentAuthorMap(comment);
    return '${author['username'] ?? author['userName'] ?? ''}'.trim();
  }

  String? _commentAvatar(Map<String, dynamic> comment) {
    final author = _commentAuthorMap(comment);
    final value =
        author['avatarUrl'] ??
        author['avatar_url'] ??
        author['profileUrl'] ??
        author['profile_url'] ??
        author['imageUrl'] ??
        author['image_url'];
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    return _absoluteMediaUrl(raw);
  }

  String _commentDate(Map<String, dynamic> comment) {
    final value = comment['createdAt'] ?? comment['created_at'];
    final date = DateTime.tryParse('${value ?? ''}');
    return date == null ? '' : _formatDate(date);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _readerScrollController.dispose();
    _readerChromeAnimation.dispose();
    super.dispose();
  }

  bool _onReaderUserScroll(UserScrollNotification notification) {
    if (!mounted || notification.depth != 0) return false;
    final metrics = notification.metrics;
    final offset = metrics.pixels;
    // Use the user's actual scroll direction. This avoids rebuild/physics
    // deltas making the toolbar reappear while the reader is stationary.
    if (offset <= metrics.minScrollExtent) {
      if (!_readerChromeVisible) {
        setState(() => _readerChromeVisible = true);
        _readerChromeAnimation.forward();
      }
    } else if (notification.direction == ScrollDirection.reverse &&
        offset > 72 &&
        _readerChromeVisible) {
      setState(() => _readerChromeVisible = false);
      _readerChromeAnimation.reverse();
    } else if (notification.direction == ScrollDirection.forward &&
        !_readerChromeVisible) {
      setState(() => _readerChromeVisible = true);
      _readerChromeAnimation.forward();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final chromeFactor = Curves.easeInOutCubic.transform(
      _readerChromeAnimation.value,
    );
    return GradientScaffold(
      useSafeArea: true,
      child: Stack(
        children: [
          Positioned.fill(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _taleFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _TaleReaderLoadingSkeleton();
                }
                if (snapshot.hasError ||
                    snapshot.data == null ||
                    snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.menu_book_outlined, size: 42),
                        const SizedBox(height: 10),
                        const Text('This Tale could not be loaded.'),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _taleFuture = context
                                .read<MessagingApiService>()
                                .getTale(widget.taleId);
                          }),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  );
                }
                final tale = snapshot.data!;
                final upvotes =
                    _upvotes ??
                    int.tryParse(
                      '${tale['upvoteCount'] ?? tale['upvote_count'] ?? 0}',
                    ) ??
                    0;
                final downvotes =
                    _downvotes ??
                    int.tryParse(
                      '${tale['downvoteCount'] ?? tale['downvote_count'] ?? 0}',
                    ) ??
                    0;
                final viewerVote =
                    _viewerVote ??
                    int.tryParse(
                      '${tale['viewerVote'] ?? tale['viewer_vote'] ?? 0}',
                    ) ??
                    0;
                final viewerUpvoted =
                    _viewerUpvoted ??
                    tale['viewerUpvoted'] == true || viewerVote == 1;
                final viewerDownvoted =
                    _viewerDownvoted ??
                    tale['viewerDownvoted'] == true || viewerVote == -1;
                final isBookmarked =
                    _bookmarked ??
                    (tale['isBookmarked'] == true ||
                        tale['is_bookmarked'] == true);
                final author = tale['author'] is Map
                    ? Map<String, dynamic>.from(tale['author'] as Map)
                    : <String, dynamic>{};
                final authorName =
                    '${author['displayName'] ?? author['display_name'] ?? tale['display_name'] ?? tale['displayName'] ?? tale['username'] ?? 'Griot user'}';
                final authorAvatar =
                    (author['avatarUrl'] ??
                            author['avatar_url'] ??
                            tale['avatar_url'] ??
                            tale['avatarUrl'])
                        ?.toString();
                final authorIsPlus =
                    author['isPlus'] == true ||
                    author['is_plus'] == true ||
                    tale['authorIsPlus'] == true ||
                    tale['author_is_plus'] == true;
                final authorIsPioneer =
                    author['isPioneer'] == true ||
                    author['is_pioneer'] == true ||
                    tale['authorIsPioneer'] == true ||
                    tale['author_is_pioneer'] == true;
                final createdAt = DateTime.tryParse(
                  '${tale['createdAt'] ?? tale['created_at'] ?? ''}',
                );
                final authorUsername =
                    '${author['username'] ?? tale['username'] ?? ''}'.trim();
                final content = '${tale['content'] ?? tale['text'] ?? ''}'
                    .trim();
                final category = '${tale['category'] ?? 'Personal'}'.trim();
                final originalAuthor =
                    '${tale['retellSourceAuthorName'] ?? tale['retell_source_author_name'] ?? (tale['retellSource'] is Map ? tale['retellSource']['authorName'] : '')}'
                        .trim();
                final threadOriginalAuthor =
                    '${tale['threadOriginalAuthorName'] ?? tale['thread_original_author_name'] ?? ''}'
                        .trim();
                final threadOriginalAuthorId = _threadOriginalAuthorId(tale);
                final threadCount =
                    int.tryParse(
                      '${tale['threadCount'] ?? tale['thread_count'] ?? 1}',
                    ) ??
                    1;
                final retellCount =
                    int.tryParse(
                      '${tale['retellCount'] ?? tale['retell_count'] ?? tale['repostCount'] ?? tale['repost_count'] ?? 0}',
                    ) ??
                    0;
                final coTellCount = threadCount > 1 ? threadCount - 1 : 0;
                final viewCount =
                    int.tryParse(
                      '${tale['viewCount'] ?? tale['view_count'] ?? tale['views'] ?? 0}',
                    ) ??
                    0;
                final threadPosition =
                    int.tryParse(
                      '${tale['threadPosition'] ?? tale['thread_position'] ?? 1}',
                    ) ??
                    1;
                // The primary Tale must always remain readable while continuity is
                // loading (or if an older deployment cannot serve the thread yet).
                // Continuity is an enhancement below the Tale, never a replacement
                // for its content/media/actions.
                const showThreadArticle = false;
                final taleThreadId = _threadId(tale);
                if (_commentTargetLabel == 'this Tale' &&
                    _commentTargetThreadId == null &&
                    taleThreadId != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || _commentTargetLabel != 'this Tale') return;
                    _commentTargetThreadId = taleThreadId;
                  });
                }
                if (_threadFuture == null &&
                    _threadId(tale) != null &&
                    threadCount > 1) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || _threadFuture != null) return;
                    setState(() {
                      _threadExpanded = true;
                      _threadFuture = context
                          .read<MessagingApiService>()
                          .getTaleThread(widget.taleId);
                    });
                  });
                }
                return NotificationListener<UserScrollNotification>(
                  onNotification: _onReaderUserScroll,
                  child: ListView(
                    controller: _readerScrollController,
                    physics: campScrollPhysics,
                    // Reserve a stable toolbar gutter inside the scroll content. The
                    // reader app bar itself is an overlay, so showing/hiding it never
                    // reflows the Tale or comments.
                    padding: const EdgeInsets.fromLTRB(12, 68, 12, 112),
                    children: [
                      KeyedSubtree(
                        key: _primaryTaleKey,
                        child: CampTaleCardSurface(
                          margin: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CampTaleHeader(
                                authorName: authorName,
                                avatarUrl: authorAvatar,
                                isPlus: authorIsPlus,
                                isPioneer: authorIsPioneer,
                                inlineBadges: [
                                  if (category.isNotEmpty)
                                    _readerCategoryBadge(context, category),
                                  if (threadCount > 1)
                                    _readerCategoryBadge(
                                      context,
                                      'Part $threadPosition/$threadCount',
                                    ),
                                ],
                                subtitle: [
                                  if (authorUsername.isNotEmpty)
                                    '@$authorUsername',
                                  if (createdAt != null) _formatDate(createdAt),
                                  if (originalAuthor.isNotEmpty)
                                    'Originally by $originalAuthor',
                                ].join(' · '),
                                attribution:
                                    originalAuthor.isEmpty &&
                                        threadPosition > 1 &&
                                        threadOriginalAuthor.isNotEmpty
                                    ? InkWell(
                                        onTap: threadOriginalAuthorId == null
                                            ? null
                                            : () => context.push(
                                                '/camp/profile/$threadOriginalAuthorId',
                                              ),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Text(
                                          'Started by $threadOriginalAuthor',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      )
                                    : null,
                                onAuthorTap: () {
                                  final id =
                                      (author['id'] ??
                                              tale['authorId'] ??
                                              tale['author_id'])
                                          ?.toString();
                                  if (id != null && id.isNotEmpty) {
                                    context.push('/camp/profile/$id');
                                  }
                                },
                                menu: PopupMenuButton<String>(
                                  tooltip: 'Tale options',
                                  padding: EdgeInsets.zero,
                                  iconSize: 24,
                                  offset: const Offset(0, 42),
                                  useRootNavigator: true,
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'bookmark':
                                        _toggleBookmark(tale);
                                      case 'retell':
                                        _retell(tale);
                                      case 'cotell':
                                        _coTell(tale);
                                      case 'continue':
                                        _continueTale(tale);
                                      case 'tip':
                                        _tipTaleCreator(tale);
                                      case 'share':
                                        SharePlus.instance.share(
                                          ShareParams(
                                            text:
                                                'Read this Tale on Griot: https://griot.network/tale/${widget.taleId}',
                                          ),
                                        );
                                      case 'report':
                                        ReportContentSheet.show(
                                          context: context,
                                          targetType: 'tale',
                                          targetId: widget.taleId,
                                          subjectLabel: 'Tale',
                                        );
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'bookmark',
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          isBookmarked
                                              ? Icons.bookmark_rounded
                                              : Icons.bookmark_border_rounded,
                                        ),
                                        title: Text(
                                          isBookmarked
                                              ? 'Remove bookmark'
                                              : 'Bookmark Tale',
                                        ),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'retell',
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(Icons.repeat_rounded),
                                        title: Text('Retell ($retellCount)'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'cotell',
                                      enabled: _threadId(tale) != null,
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          Icons.account_tree_rounded,
                                        ),
                                        title: Text('Co-tell ($coTellCount)'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'continue',
                                      enabled: _threadId(tale) != null,
                                      child: const ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(Icons.add_link_rounded),
                                        title: Text('Continue this Tale'),
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'tip',
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          Icons.volunteer_activism_outlined,
                                        ),
                                        title: Text('Gift creator'),
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'share',
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(Icons.ios_share_rounded),
                                        title: Text('Share Tale'),
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'report',
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(Icons.flag_outlined),
                                        title: Text('Report Tale'),
                                      ),
                                    ),
                                  ],
                                  icon: const Icon(Icons.more_horiz_rounded),
                                ),
                              ),
                              const SizedBox(height: 9),
                              if (!showThreadArticle && content.isNotEmpty)
                                CampTaleText(
                                  key: ValueKey('text-${widget.taleId}'),
                                  text: content,
                                  fontSize: 18,
                                ),
                              if (_retellSourceId(tale) != null) ...[
                                const SizedBox(height: 12),
                                _retellSourceCard(context, tale),
                              ],
                              if (!showThreadArticle &&
                                  _mediaUrls(tale).isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _mediaGallery(tale),
                              ],
                              if (!showThreadArticle &&
                                  _linkUrl(tale) != null) ...[
                                const SizedBox(height: 8),
                                LinkPreviewWidget(
                                  url: _linkUrl(tale)!,
                                  isMe: false,
                                ),
                              ],
                              const SizedBox(height: 10),
                              Builder(
                                builder: (context) {
                                  final colors = Theme.of(context).colorScheme;
                                  final commentCount =
                                      int.tryParse(
                                        '${tale['commentCount'] ?? tale['comment_count'] ?? 0}',
                                      ) ??
                                      0;
                                  final retellCount =
                                      int.tryParse(
                                        '${tale['retellCount'] ?? tale['retell_count'] ?? tale['repostCount'] ?? tale['repost_count'] ?? 0}',
                                      ) ??
                                      0;
                                  Widget countAction({
                                    required IconData icon,
                                    required String tooltip,
                                    required String count,
                                    required VoidCallback? onPressed,
                                    Color? color,
                                    bool expand = true,
                                  }) {
                                    final action = CampTaleActionButton(
                                      icon: icon,
                                      label: count,
                                      tooltip: tooltip,
                                      onTap: onPressed,
                                      active: color != null,
                                      activeColor: color,
                                    );
                                    return expand
                                        ? Expanded(child: action)
                                        : action;
                                  }

                                  return Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: PopupMenuButton<String>(
                                              tooltip: 'Tale actions',
                                              padding: EdgeInsets.zero,
                                              icon: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.repeat_rounded,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    '${retellCount + coTellCount}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: colors
                                                          .onSurfaceVariant,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              onSelected: (value) {
                                                if (value == 'retell') {
                                                  _retell(tale);
                                                }
                                                if (value == 'cotell') {
                                                  _coTell(tale);
                                                }
                                                if (value == 'continue') {
                                                  _continueTale(tale);
                                                }
                                                if (value == 'tip') {
                                                  _tipTaleCreator(tale);
                                                }
                                                if (value == 'bookmark') {
                                                  _toggleBookmark(tale);
                                                }
                                              },
                                              itemBuilder: (_) => [
                                                const PopupMenuItem(
                                                  value: 'retell',
                                                  child: ListTile(
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    leading: Icon(
                                                      Icons.repeat_rounded,
                                                    ),
                                                    title: Text('Retell'),
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value: 'cotell',
                                                  enabled:
                                                      _threadId(tale) != null,
                                                  child: ListTile(
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    leading: Icon(
                                                      Icons
                                                          .account_tree_rounded,
                                                    ),
                                                    title: Text(
                                                      'Co-tell ($coTellCount)',
                                                    ),
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value: 'continue',
                                                  enabled:
                                                      _threadId(tale) != null,
                                                  child: const ListTile(
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    leading: Icon(
                                                      Icons.add_link_rounded,
                                                    ),
                                                    title: Text(
                                                      'Continue this Tale',
                                                    ),
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'tip',
                                                  child: ListTile(
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    leading: Icon(
                                                      Icons
                                                          .volunteer_activism_outlined,
                                                    ),
                                                    title: Text('Gift creator'),
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value: 'bookmark',
                                                  child: ListTile(
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    leading: Icon(
                                                      isBookmarked
                                                          ? Icons
                                                                .bookmark_rounded
                                                          : Icons
                                                                .bookmark_border_rounded,
                                                    ),
                                                    title: Text(
                                                      isBookmarked
                                                          ? 'Remove bookmark'
                                                          : 'Bookmark Tale',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          countAction(
                                            icon: viewerUpvoted
                                                ? Icons.thumb_up_alt_rounded
                                                : Icons.thumb_up_alt_outlined,
                                            tooltip: viewerUpvoted
                                                ? 'Remove upvote'
                                                : 'Like Tale',
                                            count: '$upvotes',
                                            color: viewerUpvoted
                                                ? colors.primary
                                                : null,
                                            onPressed: _voting
                                                ? null
                                                : () => _vote(
                                                    tale,
                                                    viewerUpvoted
                                                        ? 'remove_up'
                                                        : 'up',
                                                  ),
                                          ),
                                          countAction(
                                            icon: viewerDownvoted
                                                ? Icons.thumb_down_alt_rounded
                                                : Icons.thumb_down_alt_outlined,
                                            tooltip: viewerDownvoted
                                                ? 'Remove downvote'
                                                : 'Dislike Tale',
                                            count: '$downvotes',
                                            color: viewerDownvoted
                                                ? colors.error
                                                : null,
                                            onPressed: _voting
                                                ? null
                                                : () => _vote(
                                                    tale,
                                                    viewerDownvoted
                                                        ? 'remove_down'
                                                        : 'down',
                                                  ),
                                          ),
                                          countAction(
                                            icon: Icons
                                                .volunteer_activism_outlined,
                                            tooltip: 'Gift creator',
                                            count: '',
                                            onPressed: () =>
                                                _tipTaleCreator(tale),
                                          ),
                                          countAction(
                                            icon: Icons.ios_share_rounded,
                                            tooltip: 'Share Tale',
                                            count: '',
                                            onPressed: () {
                                              SharePlus.instance.share(
                                                ShareParams(
                                                  text:
                                                      'Read this Tale on Griot: https://griot.network/tale/${widget.taleId}',
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      if (viewCount > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.visibility_outlined,
                                                size: 15,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                '$viewCount ${viewCount == 1 ? 'view' : 'views'}',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      SizedBox(
                                        width: double.infinity,
                                        child: countAction(
                                          icon: Icons.forum_outlined,
                                          expand: false,
                                          tooltip: 'Comment on this Tale',
                                          count: '$commentCount Comments',
                                          onPressed: () {
                                            _selectCommentTarget(
                                              widget.taleId,
                                              'this Tale',
                                              threadId: _threadId(tale),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              if (_threadId(tale) != null &&
                                  threadCount > 1) ...[
                                const SizedBox(height: 14),
                                Divider(
                                  height: 1,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant
                                      .withValues(alpha: .35),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: _threadSection(
                                    context,
                                    tale,
                                    threadPosition,
                                    threadCount,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _taleSeparator(context),
                      _commentsSection(context, tale),
                      _commentComposer(context),
                      const SizedBox(height: 12),
                      const CampNativeAdCard(
                        key: ValueKey('tale-reader-native-ad'),
                        placement: 'Tale reader',
                        compact: true,
                        height: 250,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_readerChromeVisible,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                offset: _readerChromeVisible
                    ? Offset.zero
                    : const Offset(0, -.35),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _readerChromeVisible ? 1 : 0,
                  child: AppBar(
                    toolbarHeight: kToolbarHeight * chromeFactor,
                    title: const Text('Tale'),
                    backgroundColor: colors.surface.withValues(
                      alpha: .82 * chromeFactor,
                    ),
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readerCategoryBadge(BuildContext context, String category) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          category,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _taleSeparator(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: .42),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: .28),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: .42),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _vote(Map<String, dynamic> tale, String? vote) async {
    if (_voting) return;
    final id = tale['id']?.toString();
    if (id == null || id.isEmpty) return;
    setState(() => _voting = true);
    try {
      final result = await context.read<MessagingApiService>().voteOnTale(
        id,
        vote: vote,
      );
      if (!mounted) return;
      final hasUp =
          result.containsKey('viewerUpvoted') ||
          result.containsKey('viewer_upvoted');
      final hasDown =
          result.containsKey('viewerDownvoted') ||
          result.containsKey('viewer_downvoted');
      final returnedVote =
          int.tryParse(
            '${result['viewerVote'] ?? result['viewer_vote'] ?? result['vote'] ?? 0}',
          ) ??
          0;
      setState(() {
        _viewerVote = returnedVote;
        _upvotes = int.tryParse(
          '${result['upvoteCount'] ?? result['upvote_count'] ?? 0}',
        );
        _downvotes = int.tryParse(
          '${result['downvoteCount'] ?? result['downvote_count'] ?? 0}',
        );
        if (hasUp) {
          _viewerUpvoted =
              result['viewerUpvoted'] == true ||
              result['viewer_upvoted'] == true;
        }
        if (hasDown) {
          _viewerDownvoted =
              result['viewerDownvoted'] == true ||
              result['viewer_downvoted'] == true;
        }
      });
    } catch (error) {
      if (mounted) {
        NotificationService.showError(
          context,
          'Could not update Tale reaction: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _voting = false);
    }
  }

  Future<void> _toggleBookmark(Map<String, dynamic> tale) async {
    final id = tale['id']?.toString();
    if (id == null || id.isEmpty || _savingToCampList) return;
    final wasBookmarked =
        _bookmarked ??
        (tale['isBookmarked'] == true || tale['is_bookmarked'] == true);
    setState(() => _savingToCampList = true);
    try {
      final api = context.read<MessagingApiService>();
      if (wasBookmarked) {
        await api.removeTaleBookmark(id);
      } else {
        await api.bookmarkTale(id);
      }
      if (!mounted) return;
      setState(() => _bookmarked = !wasBookmarked);
      NotificationService.showSuccess(
        context,
        wasBookmarked ? 'Removed from Bookmarks' : 'Saved to Bookmarks',
      );
    } catch (error) {
      if (mounted) {
        NotificationService.showError(
          context,
          'Could not update bookmark: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _savingToCampList = false);
    }
  }

  Future<void> _tipTaleCreator(Map<String, dynamic> tale) async {
    final author = tale['author'] is Map
        ? Map<String, dynamic>.from(tale['author'] as Map)
        : <String, dynamic>{};
    final authorId =
        '${author['id'] ?? tale['authorId'] ?? tale['author_id'] ?? ''}'.trim();
    if (authorId.isEmpty) {
      if (mounted) {
        NotificationService.showInfo(
          context,
          'Creator details are not available for gifting yet.',
        );
      }
      return;
    }
    var displayName =
        '${author['displayName'] ?? author['display_name'] ?? tale['displayName'] ?? tale['display_name'] ?? 'Griot user'}';
    var walletAddress =
        '${author['walletAddress'] ?? author['wallet_address'] ?? tale['walletAddress'] ?? tale['wallet_address'] ?? ''}'
            .trim();
    var avatarUrl =
        (author['avatarUrl'] ??
                author['avatar_url'] ??
                tale['avatarUrl'] ??
                tale['avatar_url'])
            ?.toString();
    if (walletAddress.isEmpty) {
      try {
        final user = await context
            .read<UserProvider>()
            .userApiService
            .getUserById(authorId);
        displayName = user.effectiveName;
        walletAddress = user.walletAddress.trim();
        avatarUrl = user.avatarUrl ?? avatarUrl;
      } catch (_) {
        // CampTipSheet will still provide a useful error if crypto details
        // cannot be resolved; Gold gifting does not require a wallet.
      }
    }
    if (!mounted) return;
    await CampTipSheet.show(
      context,
      recipient: ChatUser(
        id: authorId,
        walletAddress: walletAddress,
        displayName: displayName,
        profileUrl: avatarUrl,
        timestamp: DateTime.now(),
      ),
      metadata: {'surface': 'tale_detail', 'taleId': widget.taleId},
    );
  }

  String? _mediaUrl(Map<String, dynamic> tale) {
    return _mediaValueUrl(tale['mediaUrl'] ?? tale['media_url']);
  }

  List<String> _mediaUrls(Map<String, dynamic> tale) {
    dynamic rawList =
        tale['mediaUrls'] ??
        tale['media_urls'] ??
        tale['attachments'] ??
        tale['media'];
    if (rawList is Map) {
      rawList =
          rawList['items'] ??
          rawList['media'] ??
          rawList['attachments'] ??
          rawList['urls'];
    }
    if (rawList is String) {
      try {
        rawList = jsonDecode(rawList);
      } catch (_) {
        rawList = const [];
      }
    }
    final urls = rawList is List
        ? rawList.map(_mediaValueUrl).whereType<String>().toList()
        : <String>[];
    final single = _mediaUrl(tale);
    final singleValues = single == null ? const <String>[] : <String>[single];
    return <String>[...singleValues, ...urls.where((url) => url != single)];
  }

  String? _absoluteMediaUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value.trim())) {
      return '${ApiConfig.baseUrl}/media/${value.trim()}';
    }
    final path = value.startsWith('/') ? value : '/$value';
    final apiOrigin = ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    // Accept both `/api/media/...` values returned by the media service and
    // `media/...` values returned by older Tale endpoints.
    return path.startsWith('/api/')
        ? '$apiOrigin$path'
        : '${ApiConfig.baseUrl}$path';
  }

  String? _mediaValueUrl(dynamic value) {
    if (value is Map) {
      value = value['url'] ?? value['mediaUrl'] ?? value['media_url'];
    }
    return _absoluteMediaUrl(value?.toString());
  }

  Widget _mediaGallery(Map<String, dynamic> tale) {
    final urls = _mediaUrls(tale);
    final token = context.read<AuthController>().accessToken;
    return CampTaleMediaGallery(
      urls: urls,
      headers: token == null || token.isEmpty
          ? null
          : <String, String>{'Authorization': 'Bearer $token'},
      onOpen: (index) => _showTaleMediaPreview(urls, index),
    );
  }

  void _showTaleMediaPreview(List<String> urls, int initialIndex) {
    if (urls.isEmpty || !mounted) return;
    final token = context.read<AuthController>().accessToken;
    final headers = token == null || token.isEmpty
        ? null
        : <String, String>{'Authorization': 'Bearer $token'};
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .92),
      builder: (dialogContext) {
        final controller = PageController(initialPage: initialIndex);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(dialogContext).height * .78,
                child: PageView.builder(
                  controller: controller,
                  itemCount: urls.length,
                  itemBuilder: (_, index) => InteractiveViewer(
                    child: Center(
                      child: GriotFeedMedia(
                        url: urls[index],
                        headers: headers,
                        fit: BoxFit.contain,
                        cacheWidth: 1800,
                        cacheHeight: 1800,
                        errorIcon: Icons.broken_image_outlined,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String? _linkUrl(Map<String, dynamic> tale) {
    final raw = tale['linkUrl']?.toString() ?? tale['link_url']?.toString();
    return raw == null || raw.trim().isEmpty ? null : raw.trim();
  }

  String? _threadId(Map<String, dynamic> tale) {
    final value =
        tale['threadId'] ??
        tale['thread_id'] ??
        (tale['thread'] is Map
            ? (tale['thread'] as Map)['id'] ??
                  (tale['thread'] as Map)['threadId']
            : null);
    final id = value?.toString().trim();
    return id == null || id.isEmpty ? null : id;
  }

  String? _retellSourceId(Map<String, dynamic> tale) {
    final value =
        tale['retellSourceId'] ??
        tale['retell_source_id'] ??
        tale['retellOfTaleId'] ??
        tale['retell_of_tale_id'];
    final id = value?.toString().trim();
    return id == null || id.isEmpty ? null : id;
  }

  String? _threadOriginalAuthorId(Map<String, dynamic> tale) {
    final thread = tale['thread'] is Map
        ? Map<String, dynamic>.from(tale['thread'] as Map)
        : <String, dynamic>{};
    final value =
        tale['threadOriginalAuthorId'] ??
        tale['thread_original_author_id'] ??
        thread['originalAuthorId'] ??
        thread['original_author_id'] ??
        thread['authorId'] ??
        thread['author_id'];
    final id = value?.toString().trim();
    return id == null || id.isEmpty ? null : id;
  }

  Widget _retellSourceCard(BuildContext context, Map<String, dynamic> tale) {
    final source =
        '${tale['retellSourceContent'] ?? tale['retell_source_content'] ?? ''}'
            .trim();
    final sourceMap = tale['retellSource'] is Map
        ? Map<String, dynamic>.from(tale['retellSource'] as Map)
        : <String, dynamic>{};
    final sourceAuthorMap = sourceMap['author'] is Map
        ? Map<String, dynamic>.from(sourceMap['author'] as Map)
        : <String, dynamic>{};
    final sourceAuthor =
        '${tale['retellSourceAuthorName'] ?? tale['retell_source_author_name'] ?? sourceMap['authorName'] ?? sourceMap['author_name'] ?? sourceAuthorMap['displayName'] ?? sourceAuthorMap['display_name'] ?? sourceAuthorMap['username'] ?? ''}'
            .trim();
    final sourceId = _retellSourceId(tale);
    final sourceAuthorId = _retellSourceAuthorId(tale);
    final sourceAuthorAvatar = _retellSourceAuthorAvatar(tale);
    final sourceAuthorUsername =
        '${tale['retellSourceAuthorUsername'] ?? tale['retell_source_author_username'] ?? sourceMap['authorUsername'] ?? sourceAuthorMap['username'] ?? ''}'
            .trim();
    final sourceAuthorIsPlus =
        tale['retellSourceAuthorIsPlus'] == true ||
        tale['retell_source_author_is_plus'] == true ||
        sourceMap['authorIsPlus'] == true ||
        sourceAuthorMap['isPlus'] == true ||
        sourceAuthorMap['is_plus'] == true;
    final sourceAuthorIsPioneer =
        tale['retellSourceAuthorIsPioneer'] == true ||
        tale['retell_source_author_is_pioneer'] == true ||
        sourceMap['authorIsPioneer'] == true ||
        sourceAuthorMap['isPioneer'] == true ||
        sourceAuthorMap['is_pioneer'] == true;
    if (source.isEmpty) return const SizedBox.shrink();
    return CampTaleReshareCard(
      sourceTaleId: sourceId,
      sourceAuthorName: sourceAuthor,
      sourceAuthorUsername: sourceAuthorUsername.isEmpty
          ? null
          : sourceAuthorUsername,
      sourceAuthorIsPlus: sourceAuthorIsPlus,
      sourceAuthorIsPioneer: sourceAuthorIsPioneer,
      sourceAuthorAvatarUrl: sourceAuthorAvatar,
      sourceText: source,
      sourceMediaUrls: _retellSourceMediaUrls(tale),
      onAuthorTap: sourceAuthorId == null
          ? null
          : () => context.push('/camp/profile/$sourceAuthorId'),
      onSourceTap: sourceId == null
          ? null
          : () => context.push('/tale/$sourceId'),
      mediaBuilder: (context, urls) => _mediaGallery({'mediaUrls': urls}),
    );
  }

  String? _retellSourceAuthorId(Map<String, dynamic> tale) {
    final source = tale['retellSource'] is Map
        ? Map<String, dynamic>.from(tale['retellSource'] as Map)
        : <String, dynamic>{};
    final author = source['author'] is Map
        ? Map<String, dynamic>.from(source['author'] as Map)
        : <String, dynamic>{};
    final value =
        tale['retellSourceAuthorId'] ??
        tale['retell_source_author_id'] ??
        source['authorId'] ??
        source['author_id'] ??
        author['id'] ??
        author['userId'] ??
        author['user_id'];
    final id = value?.toString().trim();
    return id == null || id.isEmpty ? null : id;
  }

  String? _retellSourceAuthorAvatar(Map<String, dynamic> tale) {
    final source = tale['retellSource'] is Map
        ? Map<String, dynamic>.from(tale['retellSource'] as Map)
        : <String, dynamic>{};
    final author = source['author'] is Map
        ? Map<String, dynamic>.from(source['author'] as Map)
        : <String, dynamic>{};
    final value =
        tale['retellSourceAuthorAvatarUrl'] ??
        tale['retell_source_author_avatar_url'] ??
        source['authorAvatarUrl'] ??
        source['author_avatar_url'] ??
        author['avatarUrl'] ??
        author['avatar_url'];
    final avatar = value?.toString().trim();
    return avatar == null || avatar.isEmpty ? null : avatar;
  }

  List<String> _retellSourceMediaUrls(Map<String, dynamic> tale) {
    final raw =
        tale['retellSourceMediaUrls'] ?? tale['retell_source_media_urls'];
    final urls = raw is List
        ? raw.map(_mediaValueUrl).whereType<String>().toList()
        : <String>[];
    final single = _mediaValueUrl(
      tale['retellSourceMediaUrl'] ?? tale['retell_source_media_url'],
    );
    if (single != null && !urls.contains(single)) urls.insert(0, single);
    return urls;
  }

  Future<void> _retell(Map<String, dynamic> tale) async {
    final taleId = tale['id']?.toString();
    if (taleId == null || taleId.isEmpty) return;
    await context.push(
      '/campfires/tales/create',
      extra: {
        'initialReferenceText': '${tale['content'] ?? tale['text'] ?? ''}'
            .trim(),
        'initialReferenceLabel':
            'Retelling · ${tale['author']?['displayName'] ?? 'another creator'}',
        'initialReferenceMediaUrls': [
          if (_mediaUrls(tale).isNotEmpty) ..._mediaUrls(tale),
        ],
        'composerTitle': 'Retell this Tale',
        'initialRetellOfTaleId': taleId,
      },
    );
    if (mounted) {
      setState(() {
        _taleFuture = context.read<MessagingApiService>().getTale(
          widget.taleId,
        );
      });
    }
  }

  Future<void> _coTell(Map<String, dynamic> tale) async {
    final threadId = _threadId(tale);
    if (threadId == null) return;
    await context.push(
      '/campfires/tales/create',
      extra: {
        'initialThreadId': threadId,
        'initialReferenceText': '${tale['content'] ?? ''}',
        'initialReferenceLabel':
            'Co-telling · Part ${tale['threadPosition'] ?? tale['thread_position'] ?? 1}',
        'initialReferenceMediaUrls': _mediaUrls(tale),
        'composerTitle': 'Co-tell this Tale',
      },
    );
  }

  Future<void> _continueTale(Map<String, dynamic> tale) async {
    final threadId = _threadId(tale);
    if (threadId == null) return;
    await context.push(
      '/campfires/tales/create',
      extra: {
        'initialThreadId': threadId,
        'initialReferenceText': '${tale['content'] ?? ''}',
        'initialReferenceLabel':
            'Continuing · Part ${tale['threadPosition'] ?? tale['thread_position'] ?? 1}',
        'composerTitle': 'Continue this Tale',
      },
    );
  }

  Future<void> _openThread(Map<String, dynamic> tale) async {
    final taleId = tale['id']?.toString();
    if (taleId == null || taleId.isEmpty) return;
    setState(() {
      _threadFuture = context.read<MessagingApiService>().getTaleThread(taleId);
    });
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final age = DateTime.now().difference(local);
    if (age.isNegative || age.inSeconds < 45) return 'now';
    if (age.inMinutes < 60) return '${age.inMinutes}m';
    if (age.inHours < 24) return '${age.inHours}h';
    if (age.inDays < 7) return '${age.inDays}d';
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}

class _TaleReaderLoadingSkeleton extends StatelessWidget {
  const _TaleReaderLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget block(double height, {double width = double.infinity}) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(8),
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        CampTaleCardSurface(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: colors.surfaceContainerHighest,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        block(14, width: 140),
                        const SizedBox(height: 8),
                        block(11, width: 110),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              block(11, width: 170),
              const SizedBox(height: 18),
              block(18),
              const SizedBox(height: 10),
              block(18),
              const SizedBox(height: 10),
              block(18, width: 230),
              const SizedBox(height: 24),
              Row(
                children: [
                  block(16, width: 150),
                  const Spacer(),
                  block(12, width: 42),
                ],
              ),
              const SizedBox(height: 18),
              block(15),
              const SizedBox(height: 10),
              block(15),
              const SizedBox(height: 10),
              block(15, width: 250),
            ],
          ),
        ),
      ],
    );
  }
}
