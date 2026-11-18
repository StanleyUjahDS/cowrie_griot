import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../iap/providers/iap_provider.dart';
import '../../iap/widgets/plus_required_dialog.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_branded_container.dart';
import '../../../core/ui/widgets/griot_avatar.dart';
import '../../../core/ui/widgets/griot_feed_media.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/navigation_scroll_service.dart';
import '../models/space_model.dart';
import '../models/chat_user.dart';
import '../providers/messaging_provider.dart';
import '../services/realtime_call_service.dart';
import '../services/messaging_api_service.dart';
import '../services/active_call_controller.dart';
import '../widgets/chatting/link_preview_widget.dart';
import '../widgets/camp_tip_sheet.dart';
import '../widgets/camp_tale_components.dart';
import '../widgets/camp_tale_media_gallery.dart';
import '../widgets/chatting/report_content_sheet.dart';
import '../../users/providers/user_provider.dart';
import '../../auth/auth_controller.dart';

/// Home for public Campfires and lightweight status updates.
///
/// Public Campfires are join-and-leave realtime rooms. Direct and group calls
/// remain invitation-based conversation calls.
class SpacesStatusScreen extends StatefulWidget {
  const SpacesStatusScreen({super.key});

  @override
  State<SpacesStatusScreen> createState() => _SpacesStatusScreenState();
}

class _LocalTale {
  final String? id;
  final String? authorId;
  final String? authorWalletAddress;
  final String text;
  final String category;
  final DateTime createdAt;
  final String authorName;
  final String? authorAvatarUrl;
  final bool authorIsPlus;
  final bool authorIsPioneer;
  final String? threadId;
  final int threadPosition;
  final int threadCount;
  final String? mediaUrl;
  final String? mediaType;
  final List<String> mediaUrls;
  final String? linkUrl;
  final String? linkTitle;
  final String? linkDescription;
  final String? linkThumbnailUrl;
  final int commentCount;
  final int viewCount;
  final bool isBoosted;
  final int likeCount;
  final int downvoteCount;
  final int viewerVote;
  final bool viewerUpvoted;
  final bool viewerDownvoted;
  final int retellCount;
  final int coTellCount;
  final String? retellSourceId;
  final String? retellSourceContent;
  final String? retellSourceAuthorId;
  final String? retellSourceAuthorName;
  final String? retellSourceAuthorUsername;
  final bool retellSourceAuthorIsPlus;
  final bool retellSourceAuthorIsPioneer;
  final String? retellSourceAuthorAvatarUrl;
  final List<String> retellSourceMediaUrls;
  final String? threadOriginalAuthorName;
  final String? threadOriginalAuthorId;
  final String? threadOriginalAuthorAvatarUrl;
  final List<String> threadParts;
  final List<List<String>> threadPartMediaUrls;

  const _LocalTale({
    this.id,
    this.authorId,
    this.authorWalletAddress,
    required this.text,
    required this.category,
    required this.createdAt,
    this.authorName = 'You',
    this.authorAvatarUrl,
    this.authorIsPlus = false,
    this.authorIsPioneer = false,
    this.threadId,
    this.threadPosition = 1,
    this.threadCount = 1,
    this.mediaUrl,
    this.mediaType,
    this.mediaUrls = const [],
    this.linkUrl,
    this.linkTitle,
    this.linkDescription,
    this.linkThumbnailUrl,
    this.commentCount = 0,
    this.viewCount = 0,
    this.isBoosted = false,
    this.likeCount = 0,
    this.downvoteCount = 0,
    this.viewerVote = 0,
    this.viewerUpvoted = false,
    this.viewerDownvoted = false,
    this.retellCount = 0,
    this.coTellCount = 0,
    this.retellSourceId,
    this.retellSourceContent,
    this.retellSourceAuthorId,
    this.retellSourceAuthorName,
    this.retellSourceAuthorUsername,
    this.retellSourceAuthorIsPlus = false,
    this.retellSourceAuthorIsPioneer = false,
    this.retellSourceAuthorAvatarUrl,
    this.retellSourceMediaUrls = const [],
    this.threadOriginalAuthorName,
    this.threadOriginalAuthorId,
    this.threadOriginalAuthorAvatarUrl,
    this.threadParts = const [],
    this.threadPartMediaUrls = const [],
  });

  _LocalTale copyWith({
    String? text,
    int? likeCount,
    int? downvoteCount,
    int? viewerVote,
    bool? viewerUpvoted,
    bool? viewerDownvoted,
    int? threadPosition,
    int? threadCount,
    List<String>? threadParts,
    List<List<String>>? threadPartMediaUrls,
  }) => _LocalTale(
    id: id,
    authorId: authorId,
    authorWalletAddress: authorWalletAddress,
    text: text ?? this.text,
    category: category,
    createdAt: createdAt,
    authorName: authorName,
    authorAvatarUrl: authorAvatarUrl,
    authorIsPlus: authorIsPlus,
    authorIsPioneer: authorIsPioneer,
    threadId: threadId,
    threadPosition: threadPosition ?? this.threadPosition,
    threadCount: threadCount ?? this.threadCount,
    mediaUrl: mediaUrl,
    mediaType: mediaType,
    mediaUrls: mediaUrls,
    linkUrl: linkUrl,
    linkTitle: linkTitle,
    linkDescription: linkDescription,
    linkThumbnailUrl: linkThumbnailUrl,
    commentCount: commentCount,
    viewCount: viewCount,
    isBoosted: isBoosted,
    likeCount: likeCount ?? this.likeCount,
    downvoteCount: downvoteCount ?? this.downvoteCount,
    viewerVote: viewerVote ?? this.viewerVote,
    viewerUpvoted: viewerUpvoted ?? this.viewerUpvoted,
    viewerDownvoted: viewerDownvoted ?? this.viewerDownvoted,
    retellCount: retellCount,
    coTellCount: coTellCount,
    retellSourceId: retellSourceId,
    retellSourceContent: retellSourceContent,
    retellSourceAuthorId: retellSourceAuthorId,
    retellSourceAuthorName: retellSourceAuthorName,
    retellSourceAuthorUsername: retellSourceAuthorUsername,
    retellSourceAuthorIsPlus: retellSourceAuthorIsPlus,
    retellSourceAuthorIsPioneer: retellSourceAuthorIsPioneer,
    retellSourceAuthorAvatarUrl: retellSourceAuthorAvatarUrl,
    retellSourceMediaUrls: retellSourceMediaUrls,
    threadOriginalAuthorName: threadOriginalAuthorName,
    threadOriginalAuthorId: threadOriginalAuthorId,
    threadOriginalAuthorAvatarUrl: threadOriginalAuthorAvatarUrl,
    threadParts: threadParts ?? this.threadParts,
    threadPartMediaUrls: threadPartMediaUrls ?? this.threadPartMediaUrls,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorId': authorId,
    'authorWalletAddress': authorWalletAddress,
    'content': text,
    'category': category,
    'createdAt': createdAt.toIso8601String(),
    'author': {'displayName': authorName, 'avatarUrl': authorAvatarUrl},
    'threadId': threadId,
    'threadPosition': threadPosition,
    'threadCount': threadCount,
    'mediaUrl': mediaUrl,
    'mediaType': mediaType,
    'mediaUrls': mediaUrls,
    'linkUrl': linkUrl,
    'linkTitle': linkTitle,
    'linkDescription': linkDescription,
    'linkThumbnailUrl': linkThumbnailUrl,
    'commentCount': commentCount,
    'viewCount': viewCount,
    'isBoosted': isBoosted,
    'upvoteCount': likeCount,
    'downvoteCount': downvoteCount,
    'retellCount': retellCount,
    'coTellCount': coTellCount,
    'retellSourceId': retellSourceId,
    'retellSourceContent': retellSourceContent,
    'retellSourceAuthorId': retellSourceAuthorId,
    'retellSourceAuthorAvatarUrl': retellSourceAuthorAvatarUrl,
    'retellSourceAuthorUsername': retellSourceAuthorUsername,
    'retellSourceAuthorIsPlus': retellSourceAuthorIsPlus,
    'retellSourceAuthorIsPioneer': retellSourceAuthorIsPioneer,
    'retellSourceMediaUrls': retellSourceMediaUrls,
    'threadOriginalAuthorName': threadOriginalAuthorName,
    'threadOriginalAuthorId': threadOriginalAuthorId,
    'threadOriginalAuthorAvatarUrl': threadOriginalAuthorAvatarUrl,
    'threadParts': threadParts,
    'threadPartMediaUrls': threadPartMediaUrls,
    'viewerVote': viewerVote,
    'viewerUpvoted': viewerUpvoted,
    'viewerDownvoted': viewerDownvoted,
  };
}

class _LocalTaleComment {
  final String text;
  final String? replyTo;
  final DateTime createdAt;

  const _LocalTaleComment({
    required this.text,
    this.replyTo,
    required this.createdAt,
  });
}

class _SpacesStatusScreenState extends State<SpacesStatusScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final List<SpaceModel> _spaces = [];
  final List<SpaceModel> _upcomingSpaces = [];
  final List<_LocalTale> _localTales = [];
  final Map<String, bool> _suggestionFollowing = {};
  final Set<String> _loadingSuggestionProfiles = {};
  final Set<String> _followingSuggestions = {};
  final Set<String> _hiddenSuggestionAuthors = {};
  final Set<String> _votingTales = <String>{};
  final Map<String, List<_LocalTaleComment>> _taleComments = {};
  static const _taleCategories = <String>[
    'All',
    'Personal',
    'Finance',
    'Crypto',
    'Football',
    'Sports',
    'Technology',
    'Health',
    'Education',
    'Lessons',
    'Culture',
    'Community',
    'Ideas',
    'History',
    'Music',
  ];
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _feedScrollController = ScrollController();
  bool _loading = true;
  bool _loadingTales = true;
  bool _initialCampLoadComplete = false;
  bool _loadingMoreTales = false;
  String? _talesLoadError;
  bool _hasMoreTales = false;
  String? _taleCursor;
  bool _hasMore = true;
  int _offset = 0;
  int _spacesRequestId = 0;
  int _upcomingRequestId = 0;
  int _campfireRevision = 0;
  // Camp navigation order: Tales first, Campfires second, then Search.
  int _campfireTab = 0;
  String _campfireView = 'live';
  late final TabController _campfireTabs;
  final Set<String> _campfireReminders = <String>{};
  final Set<String> _expandedUpcomingGroups = <String>{};
  String _region = 'GLOBAL';
  int _lastCampRefreshNonce = 0;
  int _lastCampScrollNonce = 0;
  String? _error;
  String _searchQuery = '';
  bool _searchSubmitted = false;
  bool _searchLoading = false;
  bool _searchLoadingMore = false;
  int _searchOffset = 0;
  bool _searchHasMore = false;
  Map<String, dynamic> _campSearchResults = const {};
  String _searchScope = 'all';
  String _selectedTaleCategory = 'All';
  final Set<String> _campInterests = <String>{};
  final Set<String> _expandedTaleThreads = <String>{};
  String _taleFeed = 'public';
  late final FocusNode _searchFocusNode;
  Timer? _socketRefreshTimer;
  bool _chromeVisible = true;
  double _lastFeedOffset = 0;
  late final AnimationController _chromeAnimation;
  MessagingProvider? _messagingProvider;

  Future<void> _runCampSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (mounted) {
        setState(() {
          _campSearchResults = const {};
          _searchOffset = 0;
          _searchHasMore = false;
        });
      }
      return;
    }
    setState(() {
      _searchLoading = true;
      _searchOffset = 0;
      _searchHasMore = false;
    });
    try {
      final result = await context.read<MessagingApiService>().searchCampside(
        trimmed,
        limit: 20,
        offset: 0,
      );
      if (mounted && _searchQuery.trim() == trimmed) {
        setState(() {
          _campSearchResults = result;
          _searchOffset = 20;
          _searchHasMore = result['hasMore'] == true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _campSearchResults = const {});
        NotificationService.showError(context, 'Camp search failed: $error');
      }
    } finally {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  Future<void> _loadMoreCampSearch() async {
    final query = _searchQuery.trim();
    if (query.isEmpty || !_searchHasMore || _searchLoadingMore) return;
    setState(() => _searchLoadingMore = true);
    try {
      final page = await context.read<MessagingApiService>().searchCampside(
        query,
        limit: 20,
        offset: _searchOffset,
      );
      if (!mounted || _searchQuery.trim() != query) return;
      final merged = <String, dynamic>{..._campSearchResults};
      for (final key in const ['profiles', 'campfires', 'tales', 'comments']) {
        final current = (merged[key] as List?) ?? const [];
        final next = (page[key] as List?) ?? const [];
        merged[key] = [...current, ...next];
      }
      setState(() {
        _campSearchResults = merged;
        _searchOffset += 20;
        _searchHasMore = page['hasMore'] == true;
      });
    } catch (error) {
      if (mounted) {
        NotificationService.showError(
          context,
          'Could not load more results: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _searchLoadingMore = false);
    }
  }

  List<SpaceModel> _parseSpaces(Object? raw) {
    if (raw is! List) return <SpaceModel>[];
    final parsed = <SpaceModel>[];
    for (final value in raw) {
      if (value is! Map) continue;
      try {
        parsed.add(SpaceModel.fromJson(Map<String, dynamic>.from(value)));
      } catch (error) {
        debugPrint('Campfire item skipped: $error');
      }
    }
    return parsed;
  }

  @override
  void initState() {
    super.initState();
    _chromeAnimation =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
          value: 1,
        )..addListener(() {
          if (mounted) setState(() {});
        });
    _campfireTabs = TabController(length: 3, vsync: this);
    _campfireTabs.addListener(() {
      if (!_campfireTabs.indexIsChanging &&
          _campfireTab != _campfireTabs.index &&
          mounted) {
        setState(() {
          _campfireTab = _campfireTabs.index;
        });
        if (_campfireTabs.index == 0) {
          unawaited(_loadTales());
        }
      }
    });
    WidgetsBinding.instance.addObserver(this);
    _searchFocusNode = FocusNode();
    _feedScrollController.addListener(_onFeedScroll);
    NavigationScrollService.instance.addListener(_onNavigationSignal);
    _messagingProvider = context.read<MessagingProvider>();
    _campfireRevision = _messagingProvider!.campfireRevision;
    _messagingProvider!.addListener(_onCampfireSocketEvent);
    _region = 'GLOBAL';
    // Let ApiClient serve its short-lived cache first. A background refresh
    // still reconciles newly-created Campfires, but the cached cards remain
    // mounted instead of flashing the loading state on every return to this
    // screen.
    unawaited(_loadInitialCamp());
  }

  Future<void> _loadInitialCamp() async {
    await Future.wait<void>([
      _loadSpaces(),
      _loadUpcomingSpaces(),
      _loadTales(),
    ]);
    if (mounted) setState(() => _initialCampLoadComplete = true);
  }

  Future<void> _loadTales({bool nextPage = false}) async {
    if (nextPage) {
      if (_loadingMoreTales || !_hasMoreTales) return;
      if (mounted) setState(() => _loadingMoreTales = true);
    } else if (mounted) {
      setState(() {
        _loadingTales = true;
        _taleCursor = null;
        _hasMoreTales = false;
        _expandedTaleThreads.clear();
        // A refreshed feed always starts at the primary Part 1 surface; the
        // dedicated Tale reader is the place for the full continuity view.
      });
    }
    try {
      final result = await context.read<MessagingApiService>().getTales(
        feed: _taleFeed,
        category: _selectedTaleCategory == 'All' ? null : _selectedTaleCategory,
        cursor: nextPage ? _taleCursor : null,
        limit: 20,
      );
      final rawItems = result['items'] ?? result['tales'] ?? result['results'];
      if (!mounted || rawItems is! List) {
        if (mounted) {
          setState(() => _talesLoadError = 'Tales could not be loaded yet.');
        }
        return;
      }
      final remote = rawItems.whereType<Map>().map((raw) {
        final item = Map<String, dynamic>.from(raw);
        final author = item['author'] is Map
            ? Map<String, dynamic>.from(item['author'] as Map)
            : <String, dynamic>{};
        final retellSource = item['retellSource'] is Map
            ? Map<String, dynamic>.from(item['retellSource'] as Map)
            : <String, dynamic>{};
        final retellSourceAuthor = retellSource['author'] is Map
            ? Map<String, dynamic>.from(retellSource['author'] as Map)
            : <String, dynamic>{};
        final threadMeta = item['thread'] is Map
            ? Map<String, dynamic>.from(item['thread'] as Map)
            : <String, dynamic>{};
        final rawThreadParts = item['threadParts'] ?? item['thread_parts'];
        final itemMediaUrls = _mediaUrlList(
          item['mediaUrls'] ?? item['media_urls'],
        );
        final itemMedia = _absoluteMediaValue(
          item['mediaUrl'] ?? item['media_url'],
        );
        final allItemMedia = <String>[
          ...?itemMedia == null ? null : <String>[itemMedia],
          ...itemMediaUrls.where((url) => url != itemMedia),
        ];
        return _LocalTale(
          id: (item['id'] ?? item['taleId'] ?? item['tale_id'])?.toString(),
          authorId:
              (author['id'] ??
                      author['userId'] ??
                      author['user_id'] ??
                      item['authorId'] ??
                      item['author_id'] ??
                      item['userId'] ??
                      item['user_id'])
                  ?.toString(),
          authorWalletAddress:
              (author['walletAddress'] ??
                      author['wallet_address'] ??
                      item['authorWalletAddress'] ??
                      item['author_wallet_address'] ??
                      item['walletAddress'] ??
                      item['wallet_address'])
                  ?.toString(),
          text: '${item['content'] ?? ''}',
          category: '${item['category'] ?? 'Personal'}',
          createdAt:
              DateTime.tryParse(
                '${item['createdAt'] ?? item['created_at'] ?? ''}',
              ) ??
              DateTime.now(),
          authorName:
              '${author['displayName'] ?? author['display_name'] ?? item['display_name'] ?? item['displayName'] ?? item['username'] ?? 'Griot user'}',
          authorAvatarUrl:
              (author['avatarUrl'] ??
                      author['avatar_url'] ??
                      item['avatar_url'] ??
                      item['avatarUrl'])
                  ?.toString(),
          authorIsPlus:
              author['isPlus'] == true ||
              author['is_plus'] == true ||
              item['authorIsPlus'] == true ||
              item['author_is_plus'] == true,
          authorIsPioneer:
              author['isPioneer'] == true ||
              author['is_pioneer'] == true ||
              item['authorIsPioneer'] == true ||
              item['author_is_pioneer'] == true,
          threadId:
              item['threadId']?.toString() ?? item['thread_id']?.toString(),
          threadPosition:
              int.tryParse(
                '${item['threadPosition'] ?? item['thread_position'] ?? 1}',
              ) ??
              1,
          threadCount:
              int.tryParse(
                '${item['threadCount'] ?? item['thread_count'] ?? 1}',
              ) ??
              1,
          mediaUrl: itemMedia,
          mediaType:
              item['mediaType']?.toString() ?? item['media_type']?.toString(),
          mediaUrls: itemMediaUrls,
          linkUrl: item['linkUrl']?.toString() ?? item['link_url']?.toString(),
          linkTitle:
              item['linkTitle']?.toString() ?? item['link_title']?.toString(),
          linkDescription:
              item['linkDescription']?.toString() ??
              item['link_description']?.toString(),
          linkThumbnailUrl:
              item['linkThumbnailUrl']?.toString() ??
              item['link_thumbnail_url']?.toString(),
          commentCount:
              int.tryParse(
                '${item['commentCount'] ?? item['comment_count'] ?? 0}',
              ) ??
              0,
          viewCount:
              int.tryParse(
                '${item['viewCount'] ?? item['view_count'] ?? item['views'] ?? 0}',
              ) ??
              0,
          isBoosted: item['isBoosted'] == true || item['is_boosted'] == true,
          likeCount:
              int.tryParse(
                '${item['upvoteCount'] ?? item['upvote_count'] ?? 0}',
              ) ??
              0,
          downvoteCount:
              int.tryParse(
                '${item['downvoteCount'] ?? item['downvote_count'] ?? 0}',
              ) ??
              0,
          viewerVote:
              int.tryParse(
                '${item['viewerVote'] ?? item['viewer_vote'] ?? 0}',
              ) ??
              0,
          viewerUpvoted:
              item['viewerUpvoted'] == true ||
              item['viewer_upvoted'] == true ||
              int.tryParse(
                    '${item['viewerVote'] ?? item['viewer_vote'] ?? 0}',
                  ) ==
                  1,
          viewerDownvoted:
              item['viewerDownvoted'] == true ||
              item['viewer_downvoted'] == true ||
              int.tryParse(
                    '${item['viewerVote'] ?? item['viewer_vote'] ?? 0}',
                  ) ==
                  -1,
          retellCount:
              int.tryParse(
                '${item['retellCount'] ?? item['retell_count'] ?? 0}',
              ) ??
              0,
          coTellCount:
              int.tryParse(
                '${item['coTellCount'] ?? item['co_tell_count'] ?? 0}',
              ) ??
              0,
          retellSourceId:
              (item['retellSourceId'] ??
                      item['retell_source_id'] ??
                      item['retellOfTaleId'] ??
                      item['retell_of_tale_id'])
                  ?.toString(),
          retellSourceContent:
              (item['retellSourceContent'] ?? item['retell_source_content'])
                  ?.toString(),
          retellSourceAuthorId:
              (item['retellSourceAuthorId'] ??
                      item['retell_source_author_id'] ??
                      retellSource['authorId'] ??
                      retellSource['author_id'] ??
                      retellSourceAuthor['id'] ??
                      retellSourceAuthor['userId'] ??
                      retellSourceAuthor['user_id'])
                  ?.toString(),
          retellSourceAuthorName:
              (item['retellSourceAuthorName'] ??
                      item['retell_source_author_name'] ??
                      retellSource['authorName'] ??
                      retellSource['author_name'] ??
                      item['originalAuthorName'] ??
                      item['original_author_name'] ??
                      threadMeta['authorName'] ??
                      threadMeta['author_name'] ??
                      (retellSource['author'] is Map
                          ? (retellSource['author'] as Map)['displayName']
                          : null))
                  ?.toString(),
          retellSourceAuthorUsername:
              (item['retellSourceAuthorUsername'] ??
                      item['retell_source_author_username'] ??
                      retellSource['authorUsername'] ??
                      retellSource['author_username'] ??
                      retellSourceAuthor['username'])
                  ?.toString(),
          retellSourceAuthorIsPlus:
              item['retellSourceAuthorIsPlus'] == true ||
              item['retell_source_author_is_plus'] == true ||
              retellSource['authorIsPlus'] == true ||
              retellSourceAuthor['isPlus'] == true ||
              retellSourceAuthor['is_plus'] == true,
          retellSourceAuthorIsPioneer:
              item['retellSourceAuthorIsPioneer'] == true ||
              item['retell_source_author_is_pioneer'] == true ||
              retellSource['authorIsPioneer'] == true ||
              retellSourceAuthor['isPioneer'] == true ||
              retellSourceAuthor['is_pioneer'] == true,
          retellSourceAuthorAvatarUrl:
              (item['retellSourceAuthorAvatarUrl'] ??
                      item['retell_source_author_avatar_url'] ??
                      retellSource['authorAvatarUrl'] ??
                      retellSource['author_avatar_url'] ??
                      retellSourceAuthor['avatarUrl'] ??
                      retellSourceAuthor['avatar_url'])
                  ?.toString(),
          retellSourceMediaUrls: _mediaUrlList(
            item['retellSourceMediaUrls'] ??
                item['retell_source_media_urls'] ??
                retellSource['mediaUrls'] ??
                retellSource['media_urls'] ??
                retellSource['mediaUrl'] ??
                retellSource['media_url'] ??
                item['retellSourceMediaUrl'] ??
                item['retell_source_media_url'],
          ),
          threadOriginalAuthorName:
              (item['threadOriginalAuthorName'] ??
                      item['thread_original_author_name'] ??
                      threadMeta['originalAuthorName'] ??
                      threadMeta['original_author_name'])
                  ?.toString(),
          threadOriginalAuthorId:
              (item['threadOriginalAuthorId'] ??
                      item['thread_original_author_id'] ??
                      threadMeta['originalAuthorId'] ??
                      threadMeta['original_author_id'] ??
                      threadMeta['authorId'] ??
                      threadMeta['author_id'])
                  ?.toString(),
          threadOriginalAuthorAvatarUrl:
              (item['threadOriginalAuthorAvatarUrl'] ??
                      item['thread_original_author_avatar_url'] ??
                      threadMeta['originalAuthorAvatarUrl'] ??
                      threadMeta['original_author_avatar_url'])
                  ?.toString(),
          threadParts: _threadPartList(
            rawThreadParts,
            fallback: '${item['content'] ?? ''}',
          ),
          threadPartMediaUrls: _threadPartMediaList(
            rawThreadParts,
            fallback: allItemMedia,
          ),
        );
      }).toList();
      final groupedThreads = <String, List<_LocalTale>>{};
      final standalone = <_LocalTale>[];
      for (final tale in remote) {
        final threadId = tale.threadId;
        if (threadId == null || threadId.isEmpty || tale.threadCount <= 1) {
          standalone.add(tale);
        } else {
          groupedThreads.putIfAbsent(threadId, () => <_LocalTale>[]).add(tale);
        }
      }
      for (final parts in groupedThreads.values) {
        parts.sort((a, b) => a.threadPosition.compareTo(b.threadPosition));
        final first = parts.first;
        standalone.add(
          first.copyWith(
            // The feed card represents Part 1 as a normal Tale. The linked
            // continuation is revealed only after the reader taps View all.
            text: first.text.trim(),
            threadPosition: 1,
            threadCount: parts.length,
            threadParts: parts.map((part) => part.text.trim()).toList(),
            threadPartMediaUrls: parts
                .map(
                  (part) => <String>[
                    if (part.mediaUrl != null) part.mediaUrl!,
                    ...part.mediaUrls.where((url) => url != part.mediaUrl),
                  ],
                )
                .toList(growable: false),
          ),
        );
      }
      final rankedTales = _rankTales(standalone);
      final remoteTales = rankedTales;
      final existingIds = remote
          .map((tale) => tale.id)
          .whereType<String>()
          .toSet();
      // Materialise this before replacing the backing list. Keeping it lazy
      // would make local drafts disappear when the list is cleared below.
      final localOnly = _localTales
          .where((tale) => tale.id == null || !existingIds.contains(tale.id))
          .toList(growable: false);
      final nextCursor =
          result['nextCursor']?.toString() ??
          result['next_cursor']?.toString() ??
          result['cursor']?.toString();
      final pageHasMore =
          result['hasMore'] == true ||
          (nextCursor != null && nextCursor.isNotEmpty);
      setState(() {
        _talesLoadError = null;
        if (nextPage) {
          final existing = _localTales.map((tale) => tale.id).toSet();
          _localTales.addAll(
            remoteTales.where(
              (tale) => tale.id == null || !existing.contains(tale.id),
            ),
          );
        } else {
          _localTales
            ..clear()
            ..addAll([...remoteTales, ...localOnly]);
        }
        final ranked = _rankTales(_localTales);
        _localTales
          ..clear()
          ..addAll(ranked);
        _taleCursor = nextCursor;
        _hasMoreTales = pageHasMore;
        if (!nextPage) _loadingTales = false;
      });
      unawaited(_loadSuggestionProfiles());
    } catch (error) {
      // Keep locally-created Tales visible if the feed is temporarily offline.
      if (mounted && _localTales.isEmpty) {
        setState(() => _talesLoadError = '$error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingTales = false;
          _loadingMoreTales = false;
        });
      }
    }
  }

  Future<void> _loadSuggestionProfiles({String? authorId}) async {
    if (!mounted) return;
    final ownId = context.read<UserProvider>().user?.id;
    final service = context.read<MessagingApiService>();
    final ids = authorId == null
        ? _localTales
              .map((tale) => tale.authorId?.trim())
              .whereType<String>()
              .where(
                (id) =>
                    id.isNotEmpty &&
                    id != ownId &&
                    !_suggestionFollowing.containsKey(id) &&
                    !_hiddenSuggestionAuthors.contains(id),
              )
              .toSet()
              .take(8)
              .toList()
        : <String>[authorId];
    await Future.wait(
      ids.map((id) async {
        if (!_loadingSuggestionProfiles.add(id)) return;
        try {
          final profile = await service.getCampProfile(id);
          final following = profile['is_following'] ?? profile['isFollowing'];
          if (mounted &&
              following is bool &&
              !_followingSuggestions.contains(id)) {
            setState(() => _suggestionFollowing[id] = following);
          }
        } catch (_) {
          // Unknown relationships are omitted; a later feed refresh retries.
        } finally {
          _loadingSuggestionProfiles.remove(id);
        }
      }),
    );
  }

  Future<void> _followSuggestion(String id) async {
    if (!_followingSuggestions.add(id)) return;
    setState(() {});
    try {
      await context.read<MessagingApiService>().followCampProfile(id);
      if (mounted) setState(() => _suggestionFollowing[id] = true);
    } catch (error) {
      if (mounted) {
        NotificationService.showError(
          context,
          'Could not follow profile: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _followingSuggestions.remove(id));
    }
  }

  List<_LocalTale> _rankTales(List<_LocalTale> input) {
    if (input.length < 2) return List<_LocalTale>.from(input);
    final now = DateTime.now();
    final preferred = _selectedTaleCategory == 'All'
        ? null
        : _selectedTaleCategory.toLowerCase();
    double score(_LocalTale tale) {
      final ageHours = math.max(
        0.0,
        now.difference(tale.createdAt).inMinutes / 60.0,
      );
      final freshness = math.exp(-ageHours / 48.0) * 3.0;
      final engagement =
          math.log(
            1 +
                tale.likeCount +
                tale.commentCount * 2 +
                tale.retellCount * 2 +
                tale.coTellCount,
          ) /
          2.0;
      final category = tale.category.trim().toLowerCase();
      final selectedCategoryBoost = preferred != null && category == preferred
          ? 2.5
          : 0.0;
      final interestBoost = _campInterests.contains(tale.category)
          ? 2.0
          : (_campInterests.any(
                  (interest) => interest.toLowerCase() == category,
                )
                ? 2.0
                : 0.0);
      final mediaBoost = tale.mediaUrl != null || tale.mediaUrls.isNotEmpty
          ? .15
          : 0.0;
      final feedBoost = _taleFeed == 'for_you'
          ? engagement + selectedCategoryBoost + interestBoost
          : 0.0;
      return freshness +
          engagement +
          selectedCategoryBoost +
          interestBoost +
          mediaBoost +
          feedBoost;
    }

    final sorted = List<_LocalTale>.from(input)
      ..sort((a, b) {
        final difference = score(b).compareTo(score(a));
        if (difference != 0) return difference;
        return b.createdAt.compareTo(a.createdAt);
      });

    // Keep one prolific author from filling the first screen. This is a
    // lightweight diversity pass that works with the existing paginated API.
    final result = <_LocalTale>[];
    final remaining = <_LocalTale>[...sorted];
    String? previousAuthor;
    while (remaining.isNotEmpty) {
      var index = 0;
      if (previousAuthor != null) {
        final alternate = remaining.indexWhere(
          (tale) => tale.authorId != null && tale.authorId != previousAuthor,
        );
        if (alternate >= 0) index = alternate;
      }
      final next = remaining.removeAt(index);
      result.add(next);
      previousAuthor = next.authorId;
    }
    return result;
  }

  String? _absoluteMediaUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final url = value.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    // Older Tale rows may contain a media UUID instead of a resolved path.
    // Resolve it through the authenticated API route so every gallery item
    // (not only the first URL) renders correctly.
    if (RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(url)) {
      return '${ApiConfig.baseUrl}/media/$url';
    }
    // API responses can contain either `/api/...` or `api/...`. Always join
    // the path with a single slash so secondary gallery items do not become
    // malformed URLs (the first item often arrives as a fully-qualified URL).
    final path = url.startsWith('/') ? url : '/$url';
    return '${ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '')}$path';
  }

  List<String> _mediaUrlList(dynamic raw) {
    dynamic value = raw;
    if (value is Map) {
      value =
          value['items'] ??
          value['media'] ??
          value['attachments'] ??
          value['urls'];
    }
    if (value is String) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        return const [];
      }
    }
    if (value is! List) return const [];
    return value.map(_absoluteMediaValue).whereType<String>().toList();
  }

  List<String> _threadPartList(dynamic raw, {required String fallback}) {
    if (raw is List) {
      final parts = raw
          .map(
            (value) => value is Map
                ? '${value['content'] ?? value['text'] ?? ''}'.trim()
                : '$value'.trim(),
          )
          .where((value) => value.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) return parts;
    }
    return fallback.trim().isEmpty ? const [] : [fallback.trim()];
  }

  List<List<String>> _threadPartMediaList(
    dynamic raw, {
    required List<String> fallback,
  }) {
    if (raw is List && raw.isNotEmpty) {
      if (!raw.any((value) => value is Map)) {
        return <List<String>>[
          fallback,
          ...List<List<String>>.generate(
            raw.length - 1,
            (_) => const <String>[],
          ),
        ];
      }
      return raw
          .map<List<String>>((value) {
            if (value is! Map) return const <String>[];
            final media = <String>[];
            final single = _absoluteMediaValue(
              value['mediaUrl'] ?? value['media_url'],
            );
            if (single != null) media.add(single);
            media.addAll(
              _mediaUrlList(
                value['mediaUrls'] ?? value['media_urls'],
              ).where((url) => url != single),
            );
            return media;
          })
          .toList(growable: false);
    }
    return fallback.isEmpty ? const [] : <List<String>>[fallback];
  }

  String? _absoluteMediaValue(dynamic value) {
    if (value is Map) {
      value = value['url'] ?? value['mediaUrl'] ?? value['media_url'];
    }
    return _absoluteMediaUrl(value?.toString());
  }

  @override
  void dispose() {
    _campfireTabs.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _feedScrollController.dispose();
    NavigationScrollService.instance.removeListener(_onNavigationSignal);
    _socketRefreshTimer?.cancel();
    _chromeAnimation.dispose();
    _messagingProvider?.removeListener(_onCampfireSocketEvent);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onCampfireSocketEvent() {
    final revision = _messagingProvider?.campfireRevision ?? _campfireRevision;
    if (!mounted || revision == _campfireRevision) return;
    _campfireRevision = revision;
    // Socket events can arrive in a burst (create + participant update +
    // status update). Coalesce them into one silent refresh and keep the
    // existing list mounted while the request is in flight. This prevents the
    // visible loading/flicker loop that polling caused.
    _socketRefreshTimer?.cancel();
    _socketRefreshTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || _searchQuery.trim().isNotEmpty) return;
      unawaited(_loadSpaces(forceRefresh: true, silent: true));
      unawaited(_loadUpcomingSpaces(forceRefresh: true));
    });
  }

  void _onNavigationSignal() {
    final navigation = NavigationScrollService.instance;
    if (navigation.tappedIndex != 1) {
      return;
    }
    if (navigation.scrollNonce != _lastCampScrollNonce) {
      _lastCampScrollNonce = navigation.scrollNonce;
      if (_feedScrollController.hasClients) {
        _feedScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 460),
          curve: Curves.easeOutCubic,
        );
      }
      _setChromeVisible(true);
    }
    if (navigation.refreshNonce != _lastCampRefreshNonce) {
      _lastCampRefreshNonce = navigation.refreshNonce;
      // Keep the current cards mounted while the fresh data arrives. This is
      // the same interaction users expect from a social feed refresh.
      unawaited(_loadTales());
      unawaited(_loadSpaces(forceRefresh: true, silent: true));
      unawaited(_loadUpcomingSpaces(forceRefresh: true, silent: true));
    }
  }

  void _onFeedScroll() {
    if (_feedScrollController.hasClients) {
      final position = _feedScrollController.position;
      final offset = position.pixels;
      final delta = offset - _lastFeedOffset;
      // Ignore the tiny oscillations generated by physics, refresh, and
      // nested horizontal lists. They used to make the app bar/FAB flicker
      // and cover the first rows while the user was still reading.
      if (delta.abs() >= 8) {
        _lastFeedOffset = offset;
        if (delta > 0 && offset > 72) {
          _setChromeVisible(false);
        } else if (delta < 0) {
          _setChromeVisible(true);
        }
      }
      if (offset <= position.minScrollExtent) {
        _lastFeedOffset = offset;
        _setChromeVisible(true);
      }
    }
    if (!_feedScrollController.hasClients ||
        _loading ||
        !_hasMore ||
        _searchQuery.trim().isNotEmpty) {
      return;
    }
    if (_feedScrollController.position.extentAfter < 500) {
      _loadSpaces(nextPage: true);
    }
  }

  void _setChromeVisible(bool visible) {
    NavigationScrollService.instance.setNavigationVisible(visible);
    if (!mounted || _chromeVisible == visible) return;
    setState(() => _chromeVisible = visible);
    if (visible) {
      _chromeAnimation.forward();
    } else {
      _chromeAnimation.reverse();
    }
  }

  void _animateCampfireTab(int index) {
    if (index == _campfireTab || index < 0 || index > 2) return;
    _campfireTabs.animateTo(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(_loadSpaces(forceRefresh: true, silent: true));
      unawaited(_loadUpcomingSpaces(forceRefresh: true, silent: true));
    }
  }

  Future<void> _loadUpcomingSpaces({
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    final requestId = ++_upcomingRequestId;
    try {
      final result = await context
          .read<MessagingApiService>()
          .getUpcomingCampfires(
            region: _region,
            limit: 50,
            forceRefresh: forceRefresh,
          );
      final raw = result['items'] ?? result['spaces'] ?? [];
      if (!mounted || requestId != _upcomingRequestId || raw is! List) return;
      final parsed = raw
          .whereType<Map>()
          .map((item) => SpaceModel.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
      if (!mounted || requestId != _upcomingRequestId) return;
      setState(() {
        _upcomingSpaces
          ..clear()
          ..addAll(parsed);
        _campfireReminders
          ..removeWhere((id) => parsed.every((space) => space.id != id))
          ..addAll(
            parsed
                .where((space) => space.reminderEnabled)
                .map((space) => space.id),
          );
      });
    } catch (_) {
      // Upcoming Campfires are supplementary; live discovery remains usable.
    }
  }

  Future<void> _loadSpaces({
    bool nextPage = false,
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    if (!_hasMore && nextPage) return;
    final requestId = ++_spacesRequestId;
    final messagingApi = context.read<MessagingApiService>();
    if (mounted && !silent) setState(() => _loading = true);
    try {
      final result = await messagingApi.getActiveCampfires(
        limit: 20,
        offset: nextPage ? _offset : 0,
        region: _region,
        forceRefresh: forceRefresh,
      );
      var raw =
          result['items'] ??
          result['spaces'] ??
          result['campfires'] ??
          result['data'] ??
          [];
      var items = _parseSpaces(raw);
      var hasMore = result['hasMore'] == true || items.length == 20;

      // If regional filter returned no spaces, fall back to global campfires
      if (items.isEmpty && _region != 'GLOBAL' && !nextPage) {
        try {
          final globalResult = await messagingApi.getActiveCampfires(
            limit: 20,
            offset: 0,
            region: 'GLOBAL',
            forceRefresh: forceRefresh,
          );
          final globalRaw =
              globalResult['items'] ??
              globalResult['spaces'] ??
              globalResult['campfires'] ??
              globalResult['data'] ??
              [];
          if (globalRaw is List) {
            items = _parseSpaces(globalRaw);
            hasMore = globalResult['hasMore'] == true || items.length == 20;
          }
        } catch (_) {}
      }

      if (!mounted || requestId != _spacesRequestId) return;
      setState(() {
        _error = null;
        if (nextPage) {
          _spaces.addAll(items);
        } else {
          // Replace the feed in one rebuild. In particular, silent socket
          // reconciliation must never clear the visible cards while the
          // request is in flight, otherwise avatars/cards visibly flicker.
          _spaces
            ..clear()
            ..addAll(items);
        }
        _offset = _spaces.length;
        _hasMore = hasMore;
        _loading = silent ? _loading : false;
      });
    } catch (_) {
      if (mounted && requestId == _spacesRequestId) {
        setState(() {
          _loading = silent ? _loading : false;
          _error =
              'Campfires could not be loaded. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final chromeFactor = Curves.easeInOutCubic.transform(
      _chromeAnimation.value,
    );
    final currentUser = context.watch<UserProvider>().user;
    final unreadNotifications = context.select<MessagingProvider, int>(
      (provider) => provider.unreadCampNotificationCount,
    );
    final visibleSpaces = _spaces.where((space) {
      final query = _campfireTab == 2 ? _searchQuery.trim().toLowerCase() : '';
      if (query.isEmpty) return true;
      return space.title.toLowerCase().contains(query) ||
          (space.description?.toLowerCase().contains(query) ?? false) ||
          space.regionCode.toLowerCase().contains(query);
    }).toList();
    final visibleTales = _localTales
        .where((tale) {
          final query = _campfireTab == 2
              ? _searchQuery.trim().toLowerCase()
              : '';
          final matchesCategory =
              _selectedTaleCategory == 'All' ||
              tale.category == _selectedTaleCategory;
          final matchesFeed = true;
          final matchesSearch =
              query.isEmpty ||
              tale.text.toLowerCase().contains(query) ||
              tale.category.toLowerCase().contains(query) ||
              tale.authorName.toLowerCase().contains(query) ||
              (tale.retellSourceAuthorName?.toLowerCase().contains(query) ??
                  false);
          return matchesFeed && matchesCategory && matchesSearch;
        })
        .toList(growable: false);
    final visibleUpcoming = _upcomingSpaces
        .where((space) {
          final query = _campfireTab == 2
              ? _searchQuery.trim().toLowerCase()
              : '';
          if (query.isEmpty) return true;
          return space.title.toLowerCase().contains(query) ||
              (space.description?.toLowerCase().contains(query) ?? false) ||
              space.hostName.toLowerCase().contains(query);
        })
        .toList(growable: false);
    final initialCampLoading = !_initialCampLoadComplete;

    return GradientScaffold(
      useSafeArea: false,
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        // Fade first, then collapse the chrome so it no longer leaves an
        // invisible block over the feed while the user scrolls.
        toolbarHeight: 56 * chromeFactor,
        titleSpacing: 0,
        title: AnimatedSlide(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          offset: _chromeVisible ? Offset.zero : const Offset(0, -.35),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            opacity: _chromeVisible ? 1 : 0,
            child: const Text('Griot Camp'),
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.surface.withValues(alpha: .82 * chromeFactor),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 72,
        leading: AnimatedOpacity(
          duration: const Duration(milliseconds: 280),
          opacity: _chromeVisible ? 1 : 0,
          child: IconButton(
            tooltip: 'Camp Profile',
            padding: const EdgeInsets.only(left: 14),
            icon: GriotAvatar(
              avatarUrl: currentUser?.avatarUrl,
              radius: 22,
              backgroundColor: colors.surfaceContainerHighest,
              iconColor: colors.primary,
            ),
            onPressed: () => context.push('/camp/profile'),
          ),
        ),
        actions: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            opacity: _chromeVisible ? 1 : 0,
            child: IgnorePointer(
              ignoring: !_chromeVisible,
              child: IconButton(
                tooltip: 'Camp notifications',
                onPressed: () {
                  context.read<MessagingProvider>().markCampNotificationsSeen();
                  context.push('/notifications', extra: {'campOnly': true});
                },
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      unreadNotifications > 0
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                    if (unreadNotifications > 0)
                      Positioned(
                        right: -9,
                        top: -9,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 17,
                            minHeight: 17,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: colors.error,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: colors.surface,
                              width: 1.5,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unreadNotifications > 99
                                ? '99+'
                                : '$unreadNotifications',
                            style: TextStyle(
                              color: colors.onError,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48 * chromeFactor),
          child: SizedBox(
            height: 48 * chromeFactor,
            child: ClipRect(
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                offset: _chromeVisible ? Offset.zero : const Offset(0, -.35),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  opacity: _chromeVisible ? 1 : 0,
                  child: IgnorePointer(
                    ignoring: !_chromeVisible,
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(22),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: colors.primary.withValues(alpha: .58),
                            width: 1.2,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                        child: _CampSectionSwitcher(
                          selected: _campfireTab,
                          onChanged: _animateCampfireTab,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _campfireTab == 2
          ? null
          : AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: _chromeVisible ? 1 : 0,
              child: IgnorePointer(
                ignoring: !_chromeVisible,
                child: Padding(
                  // Scaffold already lifts the FAB above the persistent Camp
                  // navigation. Keeping this inset small prevents the action
                  // from floating over the Tale body or its action row.
                  padding: EdgeInsets.only(
                    bottom: 104 + MediaQuery.viewPaddingOf(context).bottom,
                    right: 8,
                  ),
                  child: HeroMode(
                    enabled: false,
                    child: FloatingActionButton.extended(
                      heroTag: 'camp-home-create-action',
                      onPressed: _campfireTab == 0
                          ? _showCreateTale
                          : _showCreateSpace,
                      tooltip: _campfireTab == 0
                          ? 'Tell a Tale'
                          : 'Start a Campfire',
                      icon: Icon(
                        _campfireTab == 0
                            ? Icons.menu_book_rounded
                            : Icons.local_fire_department_rounded,
                      ),
                      label: Text(
                        _campfireTab == 0 ? 'Tell a Tale' : 'Start a Campfire',
                      ),
                    ),
                  ),
                ),
              ),
            ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _searchFocusNode.unfocus(),
        child: NotificationListener<ScrollNotification>(
          onNotification: (_) => false,
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                _loadSpaces(forceRefresh: true),
                _loadUpcomingSpaces(forceRefresh: true),
                _loadTales(),
              ]);
            },
            child: ListView(
              controller: _feedScrollController,
              physics: campScrollPhysics,
              // The Camp navigation is a persistent overlay. Keep enough
              // scrollable space after the final Tale so its actions and
              // bottom border can be brought fully above that navigation.
              padding: EdgeInsets.fromLTRB(
                12,
                0,
                12,
                188 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _campfireTab == 2
                      ? KeyedSubtree(
                          key: const ValueKey('camp-search-visible'),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _searchField(context),
                          ),
                        )
                      : const SizedBox(key: ValueKey('camp-search-hidden')),
                ),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  layoutBuilder: (currentChild, previousChildren) => ClipRect(
                    child: Stack(
                      alignment: Alignment.topCenter,
                      clipBehavior: Clip.hardEdge,
                      children: [...previousChildren, ?currentChild],
                    ),
                  ),
                  transitionBuilder: (child, animation) {
                    final opacity = Tween<double>(
                      begin: 0.0,
                      end: 1.0,
                    ).chain(CurveTween(curve: Curves.easeOut));
                    return FadeTransition(
                      opacity: animation.drive(opacity),
                      child: child,
                    );
                  },
                  child: initialCampLoading
                      ? const _CampFullLoadingSkeleton()
                      : KeyedSubtree(
                          key: ValueKey(_campfireTab),
                          child: _campfireTab == 0
                              ? _talesTab(context, visibleTales)
                              : _campfireTab == 1
                              ? _campfiresTab(
                                  context,
                                  visibleSpaces,
                                  visibleUpcoming,
                                )
                              : _searchTab(
                                  context,
                                  visibleSpaces,
                                  visibleUpcoming,
                                  visibleTales,
                                ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchTab(
    BuildContext context,
    List<SpaceModel> spaces,
    List<SpaceModel> upcoming,
    List<_LocalTale> tales,
  ) {
    final query = _searchQuery.trim();
    final hasQuery = query.isNotEmpty;
    final showCampfires = _searchScope == 'all' || _searchScope == 'campfires';
    final showTales = _searchScope == 'all' || _searchScope == 'tales';
    final showProfiles =
        _searchScope == 'all' ||
        _searchScope == 'profiles' ||
        _searchScope == 'camp_profiles';
    final showComments = _searchScope == 'all' || _searchScope == 'comments';
    final scopedSpaces = showCampfires ? spaces : <SpaceModel>[];
    final scopedUpcoming = showCampfires ? upcoming : <SpaceModel>[];
    final scopedTales = showTales ? tales : <_LocalTale>[];
    final remoteProfiles = showProfiles
        ? ((_campSearchResults['profiles'] as List?) ?? const [])
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList()
        : <Map<String, dynamic>>[];
    final remoteCampfires = showCampfires
        ? ((_campSearchResults['campfires'] as List?) ?? const [])
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList()
        : <Map<String, dynamic>>[];
    final remoteTales = showTales
        ? ((_campSearchResults['tales'] as List?) ?? const [])
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList()
        : <Map<String, dynamic>>[];
    final remoteComments = showComments
        ? ((_campSearchResults['comments'] as List?) ?? const [])
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList()
        : <Map<String, dynamic>>[];
    final total =
        remoteProfiles.length +
        remoteCampfires.length +
        remoteTales.length +
        remoteComments.length +
        scopedSpaces.length +
        scopedUpcoming.length +
        scopedTales.length;
    return Column(
      key: const ValueKey('camp-search'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_searchSubmitted)
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _searchScopeChip('all', 'All', Icons.search_rounded),
                _searchScopeChip('tales', 'Tales', Icons.menu_book_rounded),
                _searchScopeChip(
                  'campfires',
                  'Campfires',
                  Icons.local_fire_department_rounded,
                ),
                _searchScopeChip('comments', 'Comments', Icons.forum_outlined),
                _searchScopeChip(
                  'profiles',
                  'Profiles',
                  Icons.person_outline_rounded,
                ),
                _searchScopeChip(
                  'camp_profiles',
                  'Camp profiles',
                  Icons.cabin_outlined,
                ),
              ],
            ),
          ),
        if (_searchSubmitted) const SizedBox(height: 10),
        if (hasQuery)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 2),
            child: Text(
              '$total result${total == 1 ? '' : 's'}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (!_searchSubmitted)
          _searchLanding(context)
        else if (_searchLoading)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (hasQuery && total == 0)
          _emptyState(
            context,
            icon: Icons.search_off_rounded,
            title: 'No results found',
            message: _searchScope == 'all'
                ? 'Try another Campfire title, topic or Tale category.'
                : 'No ${_searchScopeLabel(_searchScope).toLowerCase()} matches this search.',
            action: 'Clear search',
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _searchSubmitted = false;
              });
            },
          )
        else if (!hasQuery)
          _emptyState(
            context,
            icon: Icons.explore_rounded,
            title: 'Start searching',
            message: 'Enter a name, title or topic above.',
            action: 'Browse Campfires',
            onPressed: () => _animateCampfireTab(1),
          ),
        if (hasQuery && total > 0) ...[
          if (remoteProfiles.isNotEmpty) ...[
            _searchSectionLabel(
              context,
              'People and Camp Profiles',
              Icons.person_outline_rounded,
            ),
            for (final profile in remoteProfiles)
              _profileSearchResultTile(context, profile),
          ],
          if (remoteCampfires.isNotEmpty) ...[
            _searchSectionLabel(
              context,
              'Campfires',
              Icons.local_fire_department_rounded,
            ),
            for (final campfire in remoteCampfires)
              _searchResultTile(
                context,
                icon: Icons.local_fire_department_rounded,
                title: '${campfire['title'] ?? 'Campfire'}',
                subtitle: 'Campfire · ${campfire['host_name'] ?? 'Griot user'}',
                onTap: campfire['id'] == null
                    ? null
                    : () {
                        // Retained recordings are discoverable after a
                        // Campfire ends; open the Camp Profile for those,
                        // while live/scheduled rooms open their exact room
                        // preview and can be joined from there.
                        if (campfire['ended_at'] != null &&
                            campfire['owner_id'] != null) {
                          context.push('/camp/profile/${campfire['owner_id']}');
                          return;
                        }
                        final space = SpaceModel.fromJson(
                          Map<String, dynamic>.from(campfire),
                        );
                        if (space.id.isNotEmpty) {
                          _previewCampfire(context, space);
                        }
                      },
              ),
          ],
          if (remoteTales.isNotEmpty) ...[
            _searchSectionLabel(context, 'Tales', Icons.menu_book_rounded),
            for (final tale in remoteTales)
              _searchTaleResultCard(context, tale),
          ],
          if (remoteComments.isNotEmpty) ...[
            _searchSectionLabel(context, 'Comments', Icons.forum_outlined),
            for (final comment in remoteComments)
              _searchCommentResultCard(context, comment),
          ],
          if (scopedSpaces.isNotEmpty || scopedUpcoming.isNotEmpty) ...[
            _searchSectionLabel(
              context,
              'Campfires',
              Icons.local_fire_department_rounded,
            ),
            for (final space in [...scopedSpaces, ...scopedUpcoming])
              _searchResultTile(
                context,
                icon: Icons.local_fire_department_rounded,
                title: space.title,
                subtitle: 'Campfire · ${space.hostName}',
                badge: scopedUpcoming.contains(space) ? 'Scheduled' : 'Live',
                onTap: () => _previewCampfire(context, space),
              ),
          ],
          if (scopedTales.isNotEmpty) ...[
            _searchSectionLabel(context, 'Tales', Icons.menu_book_rounded),
            for (final tale in scopedTales)
              _searchResultTile(
                context,
                icon: Icons.menu_book_rounded,
                title: tale.text,
                subtitle: 'Tale · ${tale.category}',
                onTap: tale.id == null
                    ? null
                    : () => context.push(
                        '/tale/${tale.id}',
                        extra: tale.toJson(),
                      ),
              ),
          ],
          if (_searchHasMore)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: Center(
                child: _searchLoadingMore
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : OutlinedButton.icon(
                        onPressed: _loadMoreCampSearch,
                        icon: const Icon(Icons.expand_more_rounded),
                        label: const Text('Load more results'),
                      ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _searchScopeChip(String value, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        selected: _searchScope == value,
        onSelected: (_) => setState(() => _searchScope = value),
      ),
    );
  }

  Widget _searchLanding(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final suggestions = <(String, String, IconData)>[
      ('Tales', 'tales', Icons.menu_book_rounded),
      ('Campfires', 'campfires', Icons.local_fire_department_rounded),
      ('Profiles', 'profiles', Icons.person_outline_rounded),
      ('Finance', 'finance', Icons.account_balance_rounded),
      ('Technology', 'technology', Icons.auto_awesome_rounded),
    ];
    return GriotBrandedContainer(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      margin: const EdgeInsets.only(top: 10),
      borderRadius: 22,
      showBorder: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.explore_rounded, color: colors.primary, size: 24),
              const SizedBox(width: 10),
              const Text(
                'Explore Griot Camp',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Search for Tales, Campfires and people, or start with a quick filter.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(
            'Quick search',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final suggestion in suggestions)
                ActionChip(
                  avatar: Icon(suggestion.$3, size: 16),
                  label: Text(suggestion.$1),
                  onPressed: () {
                    setState(() {
                      _searchScope =
                          suggestion.$2 == 'tales' ||
                              suggestion.$2 == 'campfires' ||
                              suggestion.$2 == 'profiles'
                          ? suggestion.$2
                          : 'tales';
                      _searchQuery = suggestion.$2;
                      _searchController.text = suggestion.$2;
                      _searchSubmitted = true;
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _searchScopeLabel(String value) {
    switch (value) {
      case 'campfires':
        return 'Campfire';
      case 'camp_profiles':
        return 'Camp profile';
      case 'comments':
        return 'Comment';
      case 'profiles':
        return 'Profile';
      case 'tales':
        return 'Tale';
      default:
        return 'Result';
    }
  }

  Widget _searchSectionLabel(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
      child: Row(
        children: [
          Icon(icon, size: 17, color: colors.primary),
          const SizedBox(width: 7),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _searchResultTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    VoidCallback? onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GriotBrandedContainer(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        borderRadius: 22,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(alpha: .12),
                ),
                child: Icon(icon, color: colors.primary, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchTaleResultCard(
    BuildContext context,
    Map<String, dynamic> tale,
  ) {
    final colors = Theme.of(context).colorScheme;
    final author = tale['author'] is Map
        ? Map<String, dynamic>.from(tale['author'] as Map)
        : const <String, dynamic>{};
    final id = (tale['id'] ?? tale['tale_id'] ?? tale['taleId'])?.toString();
    final authorId =
        (author['id'] ??
                author['userId'] ??
                author['user_id'] ??
                tale['author_id'] ??
                tale['authorId'])
            ?.toString();
    final authorName =
        '${author['displayName'] ?? author['display_name'] ?? tale['author_name'] ?? tale['authorName'] ?? author['username'] ?? tale['username'] ?? 'Griot user'}';
    final avatarUrl =
        (author['avatarUrl'] ??
                author['avatar_url'] ??
                tale['author_avatar_url'] ??
                tale['authorAvatarUrl'])
            ?.toString();
    final category = '${tale['category'] ?? 'Personal'}';
    final content = '${tale['content'] ?? tale['text'] ?? ''}'.trim();
    final media = <String>{
      if ('${tale['media_url'] ?? tale['mediaUrl'] ?? ''}'.trim().isNotEmpty)
        '${tale['media_url'] ?? tale['mediaUrl']}',
      ..._mediaUrlList(tale['media_urls'] ?? tale['mediaUrls']),
    }.toList();
    final comments =
        int.tryParse('${tale['comment_count'] ?? tale['commentCount'] ?? 0}') ??
        0;
    final upvotes =
        int.tryParse(
          '${tale['upvote_count'] ?? tale['upvoteCount'] ?? tale['like_count'] ?? 0}',
        ) ??
        0;
    final downvotes =
        int.tryParse(
          '${tale['downvote_count'] ?? tale['downvoteCount'] ?? 0}',
        ) ??
        0;
    final retells =
        int.tryParse(
          '${tale['retell_count'] ?? tale['retellCount'] ?? tale['co_tell_count'] ?? 0}',
        ) ??
        0;
    final linkUrl = (tale['link_url'] ?? tale['linkUrl'])?.toString().trim();
    final viewerUpvoted =
        tale['viewer_upvoted'] == true || tale['viewerUpvoted'] == true;
    final viewerDownvoted =
        tale['viewer_downvoted'] == true || tale['viewerDownvoted'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CampTaleCardSurface(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: id == null
              ? null
              : () => context.push('/tale/$id', extra: tale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CampTaleHeader(
                authorName: authorName,
                avatarUrl: avatarUrl,
                subtitle: 'Tale',
                inlineBadges: [
                  _taleBadge(
                    context,
                    category,
                    colors.surfaceContainerHighest,
                    foreground: colors.onSurfaceVariant,
                  ),
                ],
                onAuthorTap: authorId == null
                    ? null
                    : () => context.push('/camp/profile/$authorId'),
                menu: const SizedBox.shrink(),
              ),
              const SizedBox(height: 10),
              CampTaleText(text: content, fontSize: 17),
              if (media.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildTaleGallery(context, media),
              ],
              if (linkUrl != null && linkUrl.isNotEmpty)
                LinkPreviewWidget(
                  url: linkUrl,
                  isMe: false,
                  title:
                      tale['link_title']?.toString() ??
                      tale['linkTitle']?.toString(),
                  description:
                      tale['link_description']?.toString() ??
                      tale['linkDescription']?.toString(),
                  imageUrl:
                      tale['link_thumbnail_url']?.toString() ??
                      tale['linkThumbnailUrl']?.toString(),
                ),
              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: .35),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: CampTaleActionButton(
                      icon: viewerUpvoted
                          ? Icons.thumb_up_alt_rounded
                          : Icons.thumb_up_alt_outlined,
                      label: '$upvotes',
                      tooltip: 'Upvote Tale',
                      active: viewerUpvoted,
                      onTap: id == null
                          ? null
                          : () => context.push('/tale/$id'),
                    ),
                  ),
                  Expanded(
                    child: CampTaleActionButton(
                      icon: viewerDownvoted
                          ? Icons.thumb_down_alt_rounded
                          : Icons.thumb_down_alt_outlined,
                      label: '$downvotes',
                      tooltip: 'Downvote Tale',
                      active: viewerDownvoted,
                      activeColor: colors.error,
                      onTap: id == null
                          ? null
                          : () => context.push('/tale/$id'),
                    ),
                  ),
                  Expanded(
                    child: CampTaleActionButton(
                      icon: Icons.repeat_rounded,
                      label: '$retells',
                      tooltip: 'Retell or co-tell',
                      onTap: id == null
                          ? null
                          : () => context.push('/tale/$id'),
                    ),
                  ),
                  Expanded(
                    child: CampTaleActionButton(
                      icon: Icons.forum_outlined,
                      label: '$comments',
                      tooltip: 'Comments',
                      onTap: id == null
                          ? null
                          : () => context.push('/tale/$id'),
                    ),
                  ),
                  Expanded(
                    child: CampTaleActionButton(
                      icon: Icons.ios_share_rounded,
                      label: '',
                      tooltip: 'Share Tale',
                      onTap: id == null
                          ? null
                          : () => SharePlus.instance.share(
                              ShareParams(
                                text:
                                    'Read this Tale on Griot:\nhttps://griot.network/tale/$id',
                              ),
                            ),
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

  Widget _searchCommentResultCard(
    BuildContext context,
    Map<String, dynamic> comment,
  ) {
    final colors = Theme.of(context).colorScheme;
    final author = comment['author'] is Map
        ? Map<String, dynamic>.from(comment['author'] as Map)
        : const <String, dynamic>{};
    final taleId =
        (comment['tale_id'] ?? comment['taleId'] ?? comment['thread_id'])
            ?.toString();
    final authorId = (author['id'] ?? author['user_id'] ?? comment['author_id'])
        ?.toString();
    final authorName =
        '${author['displayName'] ?? author['display_name'] ?? comment['author_name'] ?? comment['authorName'] ?? 'Griot user'}';
    final avatar = _absoluteMediaValue(
      author['avatarUrl'] ??
          author['avatar_url'] ??
          comment['author_avatar_url'] ??
          comment['authorAvatarUrl'],
    );
    final content = '${comment['content'] ?? comment['text'] ?? ''}'.trim();
    final upvotes =
        int.tryParse(
          '${comment['upvote_count'] ?? comment['upvoteCount'] ?? 0}',
        ) ??
        0;
    final downvotes =
        int.tryParse(
          '${comment['downvote_count'] ?? comment['downvoteCount'] ?? 0}',
        ) ??
        0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CampTaleCardSurface(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CampTaleHeader(
              authorName: authorName,
              avatarUrl: avatar,
              subtitle: 'Comment',
              onAuthorTap: authorId == null
                  ? null
                  : () => context.push('/camp/profile/$authorId'),
              menu: const SizedBox.shrink(),
            ),
            const SizedBox(height: 10),
            Text(content, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 10),
            Divider(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: .35),
            ),
            Row(
              children: [
                Expanded(
                  child: CampTaleActionButton(
                    icon: Icons.thumb_up_alt_outlined,
                    label: '$upvotes',
                    tooltip: 'Upvote comment',
                    onTap: taleId == null
                        ? null
                        : () => context.push('/tale/$taleId'),
                  ),
                ),
                Expanded(
                  child: CampTaleActionButton(
                    icon: Icons.thumb_down_alt_outlined,
                    label: '$downvotes',
                    tooltip: 'Downvote comment',
                    activeColor: colors.error,
                    onTap: taleId == null
                        ? null
                        : () => context.push('/tale/$taleId'),
                  ),
                ),
                Expanded(
                  child: CampTaleActionButton(
                    icon: Icons.reply_rounded,
                    label: '',
                    tooltip: 'Reply to comment',
                    onTap: taleId == null
                        ? null
                        : () => context.push('/tale/$taleId'),
                  ),
                ),
                Expanded(
                  child: CampTaleActionButton(
                    icon: Icons.open_in_new_rounded,
                    label: 'View Tale',
                    tooltip: 'View commented Tale',
                    onTap: taleId == null
                        ? null
                        : () => context.push('/tale/$taleId'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileSearchResultTile(
    BuildContext context,
    Map<String, dynamic> profile,
  ) {
    final colors = Theme.of(context).colorScheme;
    final nested = profile['user'] is Map
        ? Map<String, dynamic>.from(profile['user'] as Map)
        : profile['profile'] is Map
        ? Map<String, dynamic>.from(profile['profile'] as Map)
        : <String, dynamic>{};
    final id =
        (profile['id'] ??
                profile['userId'] ??
                profile['user_id'] ??
                nested['id'] ??
                nested['userId'] ??
                nested['user_id'])
            ?.toString();
    final name =
        '${profile['display_name'] ?? profile['displayName'] ?? profile['name'] ?? nested['display_name'] ?? nested['displayName'] ?? nested['name'] ?? profile['username'] ?? nested['username'] ?? 'Griot user'}';
    final rawUsername =
        profile['username'] ??
        profile['user_name'] ??
        nested['username'] ??
        nested['user_name'];
    final username = rawUsername?.toString().trim();
    final following =
        profile['is_following'] == true || profile['isFollowing'] == true;
    final avatar = _searchProfileAvatar(profile);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GriotBrandedContainer(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        borderRadius: 22,
        child: Row(
          children: [
            GriotAvatar(radius: 21, avatarUrl: avatar),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: id == null
                    ? null
                    : () => context.push('/camp/profile/$id'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (username != null && username.isNotEmpty)
                      Text(
                        username.startsWith('@') ? username : '@$username',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (id != null && id != context.read<UserProvider>().user?.id)
              OutlinedButton(
                onPressed: () async {
                  final service = context.read<MessagingApiService>();
                  final notificationContext = context;
                  try {
                    if (following) {
                      await service.unfollowCampProfile(id);
                    } else {
                      await service.followCampProfile(id);
                    }
                    if (mounted) {
                      await _runCampSearch(_searchQuery);
                    }
                  } catch (error) {
                    if (notificationContext.mounted) {
                      NotificationService.showError(
                        notificationContext,
                        'Could not update follow: $error',
                      );
                    }
                  }
                },
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: colors.primary.withValues(alpha: .5)),
                ),
                child: Text(following ? 'Following' : 'Follow'),
              ),
          ],
        ),
      ),
    );
  }

  String? _searchProfileAvatar(Map<String, dynamic> profile) {
    final nested = profile['user'] is Map
        ? Map<String, dynamic>.from(profile['user'] as Map)
        : profile['profile'] is Map
        ? Map<String, dynamic>.from(profile['profile'] as Map)
        : profile['author'] is Map
        ? Map<String, dynamic>.from(profile['author'] as Map)
        : <String, dynamic>{};
    final value =
        profile['avatar_url'] ??
        profile['avatarUrl'] ??
        profile['avatar'] ??
        profile['avatar_media_url'] ??
        profile['avatarMediaUrl'] ??
        profile['profile_image'] ??
        profile['profileImage'] ??
        profile['profile_image_url'] ??
        profile['profileImageUrl'] ??
        profile['image_url'] ??
        profile['imageUrl'] ??
        nested['avatar_url'] ??
        nested['avatarUrl'] ??
        nested['profile_image'] ??
        nested['profileImage'] ??
        nested['profile_image_url'] ??
        nested['profileImageUrl'] ??
        nested['image_url'] ??
        nested['imageUrl'];
    return _absoluteMediaValue(value);
  }

  Widget _campfiresTab(
    BuildContext context,
    List<SpaceModel> visibleSpaces,
    List<SpaceModel> visibleUpcoming,
  ) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) => _swipeSection(
        details,
        const ['live', 'scheduled'],
        _campfireView,
        (value) => setState(() {
          _campfireView = value;
          _searchController.clear();
          _searchQuery = '';
        }),
      ),
      child: Column(
        key: const ValueKey('campfires'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _lineSwitch(
            options: const [
              ('live', 'Happening now', Icons.podcasts_rounded),
              ('scheduled', 'Scheduled', Icons.event_rounded),
            ],
            selected: _campfireView,
            onChanged: (value) => setState(() {
              _campfireView = value;
              _searchController.clear();
              _searchQuery = '';
            }),
          ),
          const SizedBox(height: 18),
          if (_campfireView == 'live') ...[
            Text(
              'Campfires happening right now',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),
            _loading && visibleSpaces.isEmpty
                ? const _CampLoadingSkeleton(tale: false)
                : _spacesSection(context, visibleSpaces),
          ] else ...[
            _loading && visibleUpcoming.isEmpty
                ? const _CampLoadingSkeleton(tale: false)
                : visibleUpcoming.isNotEmpty
                ? _upcomingSection(context, visibleUpcoming)
                : _emptyUpcomingSection(context),
          ],
        ],
      ),
    );
  }

  Widget _talesTab(BuildContext context, List<_LocalTale> tales) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) => _swipeSection(
        details,
        const ['public', 'following', 'for_you'],
        _taleFeed,
        (value) {
          setState(() {
            _taleFeed = value;
            _localTales.clear();
            _taleCursor = null;
          });
          unawaited(_loadTales());
        },
      ),
      child: Column(
        key: const ValueKey('campfire-tales'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _lineSwitch(
            options: const [
              ('public', 'Public', Icons.public_rounded),
              ('following', 'Following', Icons.person_add_alt_1_rounded),
              ('for_you', 'For You', Icons.auto_awesome_rounded),
            ],
            selected: _taleFeed,
            onChanged: (value) {
              setState(() {
                _taleFeed = value;
                _localTales.clear();
                _taleCursor = null;
              });
              unawaited(_loadTales());
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Browse by category',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _taleCategories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _taleCategories[index];
                return ChoiceChip(
                  label: Text(category),
                  selected: _selectedTaleCategory == category,
                  onSelected: (_) {
                    setState(() {
                      _selectedTaleCategory = category;
                      _localTales.clear();
                      _taleCursor = null;
                    });
                    unawaited(_loadTales());
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingTales && tales.isEmpty)
            const _CampLoadingSkeleton(tale: true)
          else if (tales.isEmpty)
            GriotBrandedContainer(
              padding: const EdgeInsets.all(24),
              borderRadius: 22,
              child: Column(
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 42,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _talesLoadError != null
                        ? 'Tales are temporarily unavailable'
                        : _taleFeed == 'following'
                        ? 'No Tales from people you follow'
                        : _taleFeed == 'for_you'
                        ? 'No personalised Tales yet'
                        : _localTales.isEmpty
                        ? 'No public Tales yet'
                        : 'No Tales found',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _talesLoadError != null
                        ? 'The feed did not return a valid Tale list. Try again.'
                        : _taleFeed == 'following'
                        ? 'Follow Camp Profiles to build a personal reading feed.'
                        : _taleFeed == 'for_you'
                        ? 'Read a few Tales and react to improve your For You feed.'
                        : 'Read public Tales with text, links and media, or publish your own with a category.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _talesLoadError != null
                        ? () => _loadTales()
                        : _showCreateTale,
                    icon: Icon(
                      _talesLoadError != null
                          ? Icons.refresh_rounded
                          : Icons.edit_note_rounded,
                    ),
                    label: Text(
                      _talesLoadError != null ? 'Try again' : 'Tell a Tale',
                    ),
                  ),
                ],
              ),
            )
          else
            for (var index = 0; index < tales.length; index++) ...[
              if (index > 0) _taleSeparator(context),
              _taleCard(context, tales[index]),
              if (_taleFeed == 'public' &&
                  index == math.min(1, tales.length - 1)) ...[
                _discoverCampProfiles(context, tales),
              ],
              if (_shouldInsertTaleAd(index)) ...[_taleNativeAd(index)],
            ],
          if (_loadingMoreTales)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _discoverCampProfiles(BuildContext context, List<_LocalTale> tales) {
    final colors = Theme.of(context).colorScheme;
    final profileScores = <String, double>{};
    final profileTales = <String, _LocalTale>{};
    for (final tale in tales) {
      final id = tale.authorId?.trim();
      if (id == null ||
          id.isEmpty ||
          id == context.read<UserProvider>().user?.id ||
          _suggestionFollowing[id] == true ||
          _hiddenSuggestionAuthors.contains(id)) {
        continue;
      }
      profileTales.putIfAbsent(id, () => tale);
      final interestBoost =
          _campInterests.any(
            (interest) => interest.toLowerCase() == tale.category.toLowerCase(),
          )
          ? 3.0
          : 0.0;
      profileScores[id] =
          (profileScores[id] ?? 0) +
          interestBoost +
          1.0 +
          math.log(1 + tale.likeCount + tale.commentCount * 2);
    }
    final profiles = profileTales.keys.toList()
      ..sort(
        (a, b) => (profileScores[b] ?? 0).compareTo(profileScores[a] ?? 0),
      );
    if (profiles.isEmpty) return const SizedBox.shrink();
    // Rotate equally-scored suggestions once per day so the row feels fresh
    // without reshuffling while the user is scrolling.
    final daySeed = DateTime.now().difference(DateTime(2024, 1, 1)).inDays;
    final shift = daySeed % profiles.length;
    final rotatedProfiles = <String>[
      ...profiles.skip(shift),
      ...profiles.take(shift),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 16, color: colors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'People you may like',
                style: TextStyle(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        CampTaleCardSurface(
          padding: const EdgeInsets.symmetric(vertical: 8),
          margin: EdgeInsets.zero,
          child: SizedBox(
            height: 94,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: math.min(rotatedProfiles.length, 8),
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final profileId = rotatedProfiles[index];
                final tale = profileTales[profileId]!;
                return InkWell(
                  onTap: () => _openTaleAuthor(tale),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 188,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withValues(
                        alpha: .3,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: .22),
                      ),
                    ),
                    child: Row(
                      children: [
                        GriotAvatar(
                          radius: 20,
                          avatarUrl: tale.authorAvatarUrl,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tale.authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Based on ${tale.category}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        FilledButton(
                          onPressed: _followingSuggestions.contains(profileId)
                              ? null
                              : () => _followSuggestion(profileId),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: Text(
                            _followingSuggestions.contains(profileId)
                                ? 'Following…'
                                : 'Follow',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _taleNativeAd(int slot) {
    return CampNativeAdCard(
      adKey: ValueKey('tale-native-ad-$slot'),
      placement: 'Tale feed',
    );
  }

  bool _shouldInsertTaleAd(int index) {
    // Wider, intentionally uneven gaps keep the feed from feeling like an
    // ad grid while still giving ads predictable, viewable breaks.
    // The first placement is after the third Tale so a normal feed page can
    // actually reach an ad; later placements remain spaced farther apart.
    const breaks = <int>{2, 8, 15, 23};
    if (breaks.contains(index)) return true;
    return index > 23 && (index - 23) % 9 == 0;
  }

  Widget _taleSeparator(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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

  Future<void> _tipCreator({
    required String? userId,
    required String? walletAddress,
    required String displayName,
    String? avatarUrl,
    Map<String, dynamic>? metadata,
  }) async {
    final id = userId?.trim() ?? '';
    final wallet = walletAddress?.trim() ?? '';
    if (id.isEmpty) {
      NotificationService.showInfo(
        context,
        'Creator details are not available for tipping yet.',
      );
      return;
    }
    var resolvedWallet = wallet;
    var resolvedName = displayName;
    var resolvedAvatar = avatarUrl;
    if (resolvedWallet.isEmpty) {
      try {
        final user = await context
            .read<UserProvider>()
            .userApiService
            .getUserById(id);
        resolvedWallet = user.walletAddress.trim();
        resolvedName = user.effectiveName;
        resolvedAvatar = user.avatarUrl ?? resolvedAvatar;
      } catch (_) {
        // The action below gives the user a clear explanation if the profile
        // cannot be resolved instead of failing silently.
      }
    }
    // Griot Golds are ledger-based tips and do not require a crypto wallet.
    // The crypto tab in the chooser will validate the wallet separately.
    if (!mounted) return;
    CampTipSheet.show(
      context,
      recipient: ChatUser(
        id: id,
        walletAddress: resolvedWallet,
        displayName: resolvedName,
        profileUrl: resolvedAvatar,
        timestamp: DateTime.now(),
      ),
      metadata: metadata ?? {'surface': 'camp'},
    );
  }

  Widget _lineSwitch({
    required List<(String, String, IconData)> options,
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.outline.withValues(alpha: .18)),
        ),
      ),
      child: Row(
        children: options.map((option) {
          final active = option.$1 == selected;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(option.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 11),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? colors.primary : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      option.$3,
                      size: 15,
                      color: active ? colors.primary : colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        option.$2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active
                              ? colors.primary
                              : colors.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _swipeSection(
    DragEndDetails details,
    List<String> values,
    String selected,
    ValueChanged<String> onChanged,
  ) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 220) return;
    final index = values.indexOf(selected);
    if (index < 0) return;
    final nextIndex = velocity < 0 ? index + 1 : index - 1;
    if (nextIndex >= 0 && nextIndex < values.length) {
      onChanged(values[nextIndex]);
    }
  }

  Widget _taleCard(BuildContext context, _LocalTale tale) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CampTaleCardSurface(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: tale.id == null
              ? null
              : () => context.push('/tale/${tale.id}', extra: tale.toJson()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CampTaleHeader(
                authorName: tale.authorName,
                avatarUrl: tale.authorAvatarUrl,
                isPlus: tale.authorIsPlus,
                isPioneer: tale.authorIsPioneer,
                inlineBadges: [
                  if (tale.category.isNotEmpty)
                    _taleBadge(
                      context,
                      tale.category,
                      colors.surfaceContainerHighest,
                      foreground: colors.onSurfaceVariant,
                    ),
                  if (tale.threadCount > 1)
                    _taleBadge(
                      context,
                      'Part ${tale.threadPosition}/${tale.threadCount}',
                      colors.surfaceContainerHighest,
                      foreground: colors.onSurfaceVariant,
                    ),
                  if (tale.isBoosted)
                    _taleBadge(
                      context,
                      'Boosted',
                      colors.primary.withValues(alpha: .16),
                      foreground: colors.primary,
                    ),
                ],
                subtitle: [
                  _formatTaleTime(tale.createdAt),
                  if (tale.retellSourceAuthorName?.trim().isNotEmpty == true)
                    'Originally by ${tale.retellSourceAuthorName}',
                ].join(' · '),
                attribution:
                    tale.retellSourceAuthorName?.trim().isNotEmpty != true &&
                        tale.threadOriginalAuthorName?.trim().isNotEmpty ==
                            true &&
                        tale.threadPosition > 1
                    ? InkWell(
                        onTap: tale.threadOriginalAuthorId == null
                            ? null
                            : () => context.push(
                                '/camp/profile/${tale.threadOriginalAuthorId}',
                              ),
                        borderRadius: BorderRadius.circular(8),
                        child: Text(
                          'Started by ${tale.threadOriginalAuthorName}',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : null,
                onAuthorTap: tale.authorId == null
                    ? null
                    : () => _openTaleAuthor(tale),
                menu: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 24,
                  offset: const Offset(0, 42),
                  useRootNavigator: true,
                  tooltip: 'Tale options',
                  onSelected: (value) {
                    switch (value) {
                      case 'copy':
                        unawaited(_copyTaleLink(tale));
                      case 'continue':
                        unawaited(_continueTale(tale));
                      case 'delete':
                        unawaited(_deleteTale(tale));
                      case 'mute':
                        if (tale.authorId != null) {
                          unawaited(_muteTaleAuthor(tale.authorId!));
                        }
                      case 'block':
                        if (tale.authorId != null) {
                          unawaited(_blockTaleAuthor(tale.authorId!));
                        }
                      case 'report':
                        if (tale.id != null) {
                          unawaited(
                            ReportContentSheet.show(
                              context: context,
                              targetType: 'tale',
                              targetId: tale.id!,
                              subjectLabel: 'Tale',
                            ),
                          );
                        }
                    }
                  },
                  itemBuilder: (_) {
                    final isOwn = _isOwnTale(tale);
                    return [
                      if (tale.threadId != null && tale.threadId!.isNotEmpty)
                        const PopupMenuItem(
                          value: 'continue',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.add_link_rounded),
                            title: Text('Continue this Tale'),
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'copy',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.link_rounded),
                          title: Text('Copy Tale link'),
                        ),
                      ),
                      if (isOwn)
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.delete_outline_rounded),
                            title: Text('Delete Tale'),
                          ),
                        ),
                      if (!isOwn && tale.authorId != null) ...[
                        const PopupMenuItem(
                          value: 'mute',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.volume_off_outlined),
                            title: Text('Mute this creator'),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'block',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.block_outlined),
                            title: Text('Block this creator'),
                          ),
                        ),
                        if (tale.id != null)
                          const PopupMenuItem(
                            value: 'report',
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.flag_outlined),
                              title: Text('Report Tale'),
                            ),
                          ),
                      ],
                    ];
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (tale.threadCount > 1 && tale.threadParts.length > 1)
                _threadPreview(context, tale)
              else ...[
                CampTaleText(
                  key: ValueKey('text-${tale.id}'),
                  text: tale.text,
                  fontSize: 17,
                ),
                if (tale.mediaUrl != null || tale.mediaUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _taleMediaGallery(context, tale),
                ],
              ],
              if (tale.retellSourceId == null &&
                  tale.threadCount > 1 &&
                  tale.threadPosition > 1 &&
                  tale.threadParts.isNotEmpty) ...[
                const SizedBox(height: 10),
                CampTaleReshareCard(
                  label: 'Co-telling · Original Tale',
                  sourceAuthorName: tale.threadOriginalAuthorName ?? '',
                  sourceAuthorAvatarUrl: tale.threadOriginalAuthorAvatarUrl,
                  sourceText: tale.threadParts.first,
                  sourceMediaUrls: tale.threadPartMediaUrls.isNotEmpty
                      ? tale.threadPartMediaUrls.first
                      : const [],
                  onAuthorTap: tale.threadOriginalAuthorId == null
                      ? null
                      : () => context.push(
                          '/camp/profile/${tale.threadOriginalAuthorId}',
                        ),
                  onSourceTap: tale.threadId == null
                      ? null
                      : () => context.push('/tale/${tale.threadId}'),
                  mediaBuilder: (context, urls) =>
                      _buildTaleGallery(context, urls),
                ),
              ],
              if (tale.retellSourceId != null &&
                  tale.retellSourceContent != null &&
                  tale.retellSourceContent!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                CampTaleReshareCard(
                  sourceTaleId: tale.retellSourceId,
                  sourceAuthorName: tale.retellSourceAuthorName ?? '',
                  sourceAuthorUsername: tale.retellSourceAuthorUsername,
                  sourceAuthorIsPlus: tale.retellSourceAuthorIsPlus,
                  sourceAuthorIsPioneer: tale.retellSourceAuthorIsPioneer,
                  sourceAuthorAvatarUrl: tale.retellSourceAuthorAvatarUrl,
                  sourceText: tale.retellSourceContent!.trim(),
                  onAuthorTap: tale.retellSourceAuthorId == null
                      ? null
                      : () => context.push(
                          '/camp/profile/${tale.retellSourceAuthorId}',
                        ),
                  onSourceTap: () =>
                      context.push('/tale/${tale.retellSourceId}'),
                  sourceMediaUrls: tale.retellSourceMediaUrls,
                  mediaBuilder: (context, urls) =>
                      _buildTaleGallery(context, urls),
                ),
              ],
              if (tale.linkUrl != null && tale.linkUrl!.isNotEmpty)
                LinkPreviewWidget(
                  url: tale.linkUrl!,
                  isMe: false,
                  title: tale.linkTitle,
                  description: tale.linkDescription,
                  imageUrl: tale.linkThumbnailUrl,
                ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: .35),
              ),
              if (tale.viewCount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      size: 15,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${tale.viewCount} ${tale.viewCount == 1 ? 'view' : 'views'}',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: _taleAction(
                      context,
                      icon: tale.viewerUpvoted
                          ? Icons.thumb_up_alt_rounded
                          : Icons.thumb_up_alt_outlined,
                      label: '${tale.likeCount}',
                      tooltip: tale.viewerUpvoted
                          ? 'Remove upvote'
                          : 'Upvote Tale',
                      active: tale.viewerUpvoted,
                      onTap: tale.id == null
                          ? null
                          : () => _voteOnTale(
                              tale,
                              tale.viewerUpvoted ? 'remove_up' : 'up',
                            ),
                    ),
                  ),
                  Expanded(
                    child: _taleAction(
                      context,
                      icon: tale.viewerDownvoted
                          ? Icons.thumb_down_alt_rounded
                          : Icons.thumb_down_alt_outlined,
                      label: '${tale.downvoteCount}',
                      tooltip: tale.viewerDownvoted
                          ? 'Remove downvote'
                          : 'Downvote Tale',
                      active: tale.viewerDownvoted,
                      activeColor: colors.error,
                      onTap: tale.id == null
                          ? null
                          : () => _voteOnTale(
                              tale,
                              tale.viewerDownvoted ? 'remove_down' : 'down',
                            ),
                    ),
                  ),
                  Expanded(
                    child: _taleAction(
                      context,
                      icon: Icons.repeat_rounded,
                      label: '${tale.retellCount + tale.coTellCount}',
                      tooltip: 'Retell or co-tell',
                      onTap: tale.id == null
                          ? null
                          : () => _showTaleActions(tale),
                    ),
                  ),
                  Expanded(
                    child: _taleAction(
                      context,
                      icon: Icons.volunteer_activism_outlined,
                      label: '',
                      tooltip: 'Tip creator',
                      onTap: () => _tipCreator(
                        userId: tale.authorId,
                        walletAddress: tale.authorWalletAddress,
                        displayName: tale.authorName,
                        avatarUrl: tale.authorAvatarUrl,
                        metadata: {
                          'surface': 'camp_tale',
                          if (tale.id != null) 'taleId': tale.id,
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: _taleAction(
                      context,
                      icon: Icons.ios_share_rounded,
                      label: '',
                      tooltip: 'Share Tale',
                      onTap: tale.id == null
                          ? null
                          : () => SharePlus.instance.share(
                              ShareParams(
                                text:
                                    'Read this Tale on Griot:\nhttps://griot.network/tale/${tale.id}',
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: _taleAction(
                  context,
                  icon: Icons.forum_outlined,
                  label: '${tale.commentCount} Comments',
                  tooltip: 'Comments',
                  onTap: () => _showTaleComments(tale),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _taleBadge(
    BuildContext context,
    String label,
    Color background, {
    Color? foreground,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 94),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground ?? colors.onSurfaceVariant,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }

  Future<void> _openTaleAuthor(_LocalTale tale) async {
    final authorId = tale.authorId?.trim();
    if (authorId == null || authorId.isEmpty) return;
    final ownId = context.read<UserProvider>().user?.id;
    if (ownId == authorId) {
      await context.push('/camp/profile');
    } else {
      await context.push('/camp/profile/$authorId');
      if (mounted) await _loadSuggestionProfiles(authorId: authorId);
    }
  }

  bool _isOwnTale(_LocalTale tale) {
    final currentUserId = context.read<UserProvider>().user?.id;
    return currentUserId != null &&
        tale.authorId != null &&
        currentUserId == tale.authorId;
  }

  Future<void> _muteTaleAuthor(String userId) async {
    try {
      await context.read<MessagingApiService>().muteUser(userId);
      if (mounted) {
        setState(() {
          _hiddenSuggestionAuthors.add(userId);
          _localTales.removeWhere((tale) => tale.authorId == userId);
        });
        NotificationService.showInfo(
          context,
          'Creator muted. Their Camp content will be hidden from your feed.',
        );
      }
    } catch (error) {
      if (mounted) {
        NotificationService.showError(
          context,
          'Could not mute creator: $error',
        );
      }
    }
  }

  Future<void> _blockTaleAuthor(String userId) async {
    try {
      await context.read<MessagingProvider>().blockUser(userId);
      if (!mounted) return;
      setState(() {
        _hiddenSuggestionAuthors.add(userId);
        _localTales.removeWhere((tale) => tale.authorId == userId);
      });
      NotificationService.showInfo(
        context,
        'Creator blocked. Their Camp content is no longer shown.',
      );
    } catch (error) {
      if (mounted) {
        NotificationService.showError(
          context,
          'Could not block creator: $error',
        );
      }
    }
  }

  Future<void> _deleteTale(_LocalTale tale) async {
    final taleId = tale.id;
    if (!mounted || taleId == null || taleId.isEmpty || !_isOwnTale(tale)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Tale?'),
        content: const Text('This Tale and its comments will be removed.'),
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
    if (!mounted || confirmed != true) return;
    try {
      await context.read<MessagingApiService>().deleteTale(taleId);
      if (!mounted) return;
      setState(() => _localTales.removeWhere((item) => item.id == taleId));
      NotificationService.showInfo(context, 'Tale deleted.');
    } catch (error) {
      if (mounted) {
        NotificationService.showError(context, 'Could not delete Tale: $error');
      }
    }
  }

  Future<void> _continueTale(_LocalTale tale) async {
    final threadId = tale.threadId;
    if (!mounted || threadId == null || threadId.isEmpty) return;
    await context.push(
      '/campfires/tales/create',
      extra: {
        'initialThreadId': threadId,
        'initialReferenceText': tale.text,
        'initialReferenceLabel': 'Continuing · ${tale.authorName}',
        'composerTitle': 'Continue this Tale',
      },
    );
    if (mounted) unawaited(_loadTales());
  }

  Future<void> _copyTaleLink(_LocalTale tale) async {
    final taleId = tale.id;
    if (taleId == null || taleId.isEmpty) return;
    await Clipboard.setData(
      ClipboardData(text: 'https://griot.network/camp/tales/$taleId'),
    );
    if (mounted) NotificationService.showInfo(context, 'Tale link copied.');
  }

  Widget _taleAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback? onTap,
    bool active = false,
    Color? activeColor,
  }) {
    return CampTaleActionButton(
      icon: icon,
      label: label,
      tooltip: tooltip,
      onTap: onTap,
      active: active,
      activeColor: activeColor,
    );
  }

  Future<void> _showTaleActions(_LocalTale tale) async {
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
              title: Text('Retell (${tale.retellCount})'),
              onTap: () => Navigator.pop(sheetContext, 'retell'),
            ),
            if (_isOwnTale(tale))
              ListTile(
                leading: const Icon(Icons.rocket_launch_outlined),
                title: const Text('Boost with Griot Golds'),
                subtitle: const Text('250 Golds · 24 hours'),
                onTap: () => Navigator.pop(sheetContext, 'boost'),
              ),
            ListTile(
              enabled: tale.threadId != null,
              leading: const Icon(Icons.link_rounded),
              title: Text('Co-tell (${tale.coTellCount})'),
              onTap: tale.threadId == null
                  ? null
                  : () => Navigator.pop(sheetContext, 'cotell'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'retell') {
      await _retellTale(tale);
    } else if (choice == 'cotell') {
      await _coTellTale(tale);
    } else if (choice == 'boost') {
      await _boostTale(tale);
    }
  }

  Future<void> _boostTale(_LocalTale tale) async {
    final taleId = tale.id;
    if (!mounted || taleId == null || taleId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Boost this Tale?'),
        content: const Text(
          '250 Griot Golds will promote this Tale in eligible Camp feeds for 24 hours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Boost for 250 Golds'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await context.read<MessagingApiService>().boostTale(taleId);
      if (mounted) {
        NotificationService.showInfo(context, 'Tale boosted for 24 hours.');
        unawaited(_loadTales());
      }
    } catch (error) {
      if (mounted) {
        NotificationService.showError(context, 'Could not boost Tale: $error');
      }
    }
  }

  Future<void> _retellTale(_LocalTale tale) async {
    final taleId = tale.id;
    if (!mounted || taleId == null || taleId.isEmpty) return;
    await context.push(
      '/campfires/tales/create',
      extra: {
        'initialReferenceText': tale.text,
        'initialReferenceLabel': 'Retelling · ${tale.authorName}',
        'initialReferenceMediaUrls': [
          if (tale.mediaUrl != null) tale.mediaUrl!,
          ...tale.mediaUrls.where((url) => url != tale.mediaUrl),
        ],
        'composerTitle': 'Retell this Tale',
        'initialRetellOfTaleId': taleId,
      },
    );
    if (mounted) unawaited(_loadTales());
  }

  Future<void> _voteOnTale(_LocalTale tale, String? vote) async {
    final id = tale.id;
    if (id == null || id.isEmpty || !_votingTales.add(id)) return;
    final isUp = vote == 'up' || vote == 'remove_up';
    final isDown = vote == 'down' || vote == 'remove_down';
    final optimisticUp = isUp ? vote == 'up' : tale.viewerUpvoted;
    final optimisticDown = isDown ? vote == 'down' : tale.viewerDownvoted;
    final optimistic = tale.copyWith(
      likeCount: tale.likeCount + (isUp ? (optimisticUp ? 1 : -1) : 0),
      downvoteCount:
          tale.downvoteCount + (isDown ? (optimisticDown ? 1 : -1) : 0),
      viewerUpvoted: optimisticUp,
      viewerDownvoted: optimisticDown,
      viewerVote: optimisticUp && !optimisticDown
          ? 1
          : optimisticDown && !optimisticUp
          ? -1
          : 0,
    );
    final index = _localTales.indexWhere((item) => item.id == id);
    if (index == -1) {
      _votingTales.remove(id);
      return;
    }
    setState(() => _localTales[index] = optimistic);
    try {
      final result = await context.read<MessagingApiService>().voteOnTale(
        id,
        vote: vote,
      );
      if (!mounted) return;
      final nextVote =
          int.tryParse(
            '${result['viewerVote'] ?? result['viewer_vote'] ?? result['vote'] ?? optimistic.viewerVote}',
          ) ??
          optimistic.viewerVote;
      final hasUp =
          result.containsKey('viewerUpvoted') ||
          result.containsKey('viewer_upvoted');
      final hasDown =
          result.containsKey('viewerDownvoted') ||
          result.containsKey('viewer_downvoted');
      // Keep upvotes and downvotes independent. Older API responses only
      // expose one viewerVote, so do not let that response erase the other
      // optimistic reaction.
      final nextUpvoted = hasUp
          ? (result['viewerUpvoted'] == true ||
                result['viewer_upvoted'] == true)
          : optimistic.viewerUpvoted;
      final nextDownvoted = hasDown
          ? (result['viewerDownvoted'] == true ||
                result['viewer_downvoted'] == true)
          : optimistic.viewerDownvoted;
      final upvotes =
          int.tryParse(
            '${result['upvoteCount'] ?? result['upvote_count'] ?? tale.likeCount}',
          ) ??
          tale.likeCount;
      final downvotes =
          int.tryParse(
            '${result['downvoteCount'] ?? result['downvote_count'] ?? tale.downvoteCount}',
          ) ??
          tale.downvoteCount;
      setState(() {
        final index = _localTales.indexWhere((item) => item.id == id);
        if (index == -1) return;
        _localTales[index] = optimistic.copyWith(
          likeCount: upvotes,
          downvoteCount: downvotes,
          viewerVote: nextVote,
          viewerUpvoted: nextUpvoted,
          viewerDownvoted: nextDownvoted,
        );
      });
    } catch (error) {
      if (mounted) {
        final rollbackIndex = _localTales.indexWhere((item) => item.id == id);
        if (rollbackIndex != -1) {
          setState(() => _localTales[rollbackIndex] = tale);
        }
        NotificationService.showError(
          context,
          'Could not update Tale reaction: $error',
        );
      }
    } finally {
      _votingTales.remove(id);
    }
  }

  Future<void> _coTellTale(_LocalTale tale) async {
    final threadId = tale.threadId;
    if (!mounted || threadId == null || threadId.isEmpty) return;
    await context.push(
      '/campfires/tales/create',
      extra: {
        'initialThreadId': threadId,
        'initialReferenceText': tale.text,
        'initialReferenceLabel': 'Co-telling · ${tale.authorName}',
        'initialReferenceMediaUrls': [
          if (tale.mediaUrl != null) tale.mediaUrl!,
          ...tale.mediaUrls.where((url) => url != tale.mediaUrl),
        ],
        'composerTitle': 'Co-tell this Tale',
      },
    );
    if (mounted) unawaited(_loadTales());
  }

  Widget _taleMediaGallery(BuildContext context, _LocalTale tale) {
    final urls = <String>[
      if (tale.mediaUrl != null) tale.mediaUrl!,
      ...tale.mediaUrls.where((url) => url != tale.mediaUrl),
    ];
    return _buildTaleGallery(context, urls);
  }

  Widget _buildTaleGallery(BuildContext context, List<String> urls) {
    final token = context.read<AuthController>().accessToken;
    return CampTaleMediaGallery(
      urls: urls,
      headers: token == null || token.isEmpty
          ? null
          : <String, String>{'Authorization': 'Bearer $token'},
      onOpen: (index) => _showTaleMediaPreview(context, urls, index),
    );
  }

  Widget _threadPreview(BuildContext context, _LocalTale tale) {
    final threadKey = tale.threadId ?? tale.id ?? 'thread-${tale.createdAt}';
    final parts = List.generate(
      tale.threadParts.length,
      (index) => CampTalePart(
        content: tale.threadParts[index],
        mediaUrls: index < tale.threadPartMediaUrls.length
            ? tale.threadPartMediaUrls[index]
            : const <String>[],
      ),
    );
    final expanded = _expandedTaleThreads.contains(threadKey);
    final fallbackMedia = <String>[
      if (tale.mediaUrl != null) tale.mediaUrl!,
      ...tale.mediaUrls.where((url) => url != tale.mediaUrl),
    ];
    final first = parts.isEmpty
        ? CampTalePart(content: tale.text, mediaUrls: fallbackMedia)
        : (parts.first.mediaUrls.isEmpty && fallbackMedia.isNotEmpty
              ? CampTalePart(
                  content: parts.first.content,
                  mediaUrls: fallbackMedia,
                )
              : parts.first);
    final allParts = parts.isEmpty ? [first] : parts;
    return CampTaleMultipart(
      parts: allParts,
      totalPartCount: math.max(allParts.length, tale.threadCount),
      expanded: expanded,
      keyPrefix: threadKey,
      mediaBuilder: _buildTaleGallery,
      onToggle: parts.length >= tale.threadCount
          ? () => setState(() {
              if (expanded) {
                _expandedTaleThreads.remove(threadKey);
              } else {
                _expandedTaleThreads.add(threadKey);
              }
            })
          : null,
      onViewAll: tale.id == null
          ? null
          : () => context.push('/tale/${tale.id}'),
    );
  }

  void _showTaleMediaPreview(
    BuildContext context,
    List<String> urls,
    int initialIndex,
  ) {
    if (urls.isEmpty) return;
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

  String _formatTaleTime(DateTime createdAt) {
    final local = createdAt.toLocal();
    final now = DateTime.now();
    final elapsed = now.difference(local);
    if (elapsed.isNegative || elapsed.inMinutes < 1) return 'Just now';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
    if (elapsed.inDays < 1) {
      return 'Today · ${DateFormat('h:mm a').format(local)}';
    }
    final today = DateTime(now.year, now.month, now.day);
    final postedDay = DateTime(local.year, local.month, local.day);
    if (today.difference(postedDay).inDays == 1) {
      return 'Yesterday · ${DateFormat('h:mm a').format(local)}';
    }
    final datePattern = now.year == local.year ? 'd MMM' : 'd MMM yyyy';
    return '${DateFormat(datePattern).format(local)} · ${DateFormat('h:mm a').format(local)}';
  }

  String _taleKey(_LocalTale tale) => tale.createdAt.toIso8601String();

  Future<void> _showTaleComments(_LocalTale tale) async {
    final taleId = tale.id;
    if (taleId == null || taleId.isEmpty) return;

    // Use the canonical Tale reader so comments always belong to the exact
    // Tale/part that was tapped and use the same threaded card presentation as
    // the dedicated reader and Camp Profile.
    await context.push('/tale/$taleId', extra: tale.toJson());
    if (mounted) unawaited(_loadTales());
    return;

    // Kept below for compatibility with older hot-reload sessions. New taps
    // always use the canonical reader above.
    // ignore: dead_code
    final comments = _taleComments.putIfAbsent(_taleKey(tale), () => []);
    final controller = TextEditingController();
    String? replyingTo;
    // ignore: use_build_context_synchronously
    await showModalBottomSheet<void>(
      // ignore: use_build_context_synchronously
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      // ignore: use_build_context_synchronously
      backgroundColor: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                4,
                18,
                MediaQuery.viewInsetsOf(context).bottom + 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Comments',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: comments.isEmpty
                        ? Center(
                            child: Text(
                              'Be the first to comment on this Tale.',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: comments.length,
                            itemBuilder: (context, index) {
                              final comment = comments[index];
                              final isReply = comment.replyTo != null;
                              return Padding(
                                padding: EdgeInsets.only(
                                  left: isReply ? 28 : 0,
                                  bottom: 10,
                                ),
                                child: GriotBrandedContainer(
                                  padding: const EdgeInsets.all(12),
                                  borderRadius: 16,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (isReply)
                                        Text(
                                          'Replying to ${comment.replyTo}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      Text(
                                        comment.text,
                                        style: const TextStyle(height: 1.35),
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () => setSheetState(
                                            () => replyingTo = comment.text,
                                          ),
                                          child: const Text('Reply'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (replyingTo != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Replying to $replyingTo',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cancel reply',
                            onPressed: () =>
                                setSheetState(() => replyingTo = null),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Write a comment…',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Send comment',
                        onPressed: () {
                          final text = controller.text.trim();
                          if (text.isEmpty) return;
                          setState(() {
                            comments.add(
                              _LocalTaleComment(
                                text: text,
                                replyTo: replyingTo,
                                createdAt: DateTime.now(),
                              ),
                            );
                          });
                          controller.clear();
                          setSheetState(() => replyingTo = null);
                        },
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _showCreateTale() async {
    final created = await context.push<bool>('/campfires/tales/create');
    if (created == true && mounted) {
      unawaited(_loadTales());
      setState(() {});
    }
  }

  // Retained temporarily while older hot-reload sessions are still active.
  // New publishing uses the dedicated full-screen CreateTaleScreen route.
  // ignore: unused_element
  Future<void> _showCreateTaleLegacy() async {
    final isPlus = context.read<IapProvider>().status.isPlus;
    final maxLength = isPlus ? 2000 : 500;
    final author = context.read<UserProvider>().user;
    final textController = TextEditingController();
    var category = 'Personal';
    final created = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  Expanded(
                    child: Text(
                      'New Tale',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Text only. Choose a category so readers can discover it.',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  GriotAvatar(radius: 18, avatarUrl: author?.avatarUrl),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      author?.displayName ?? author?.username ?? 'You',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.public_rounded,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Public',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: textController,
                autofocus: true,
                maxLines: 8,
                maxLength: maxLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: isPlus
                      ? 'Write your tale…'
                      : 'Write your tale (up to 1,000 characters)…',
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: .55),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isPlus
                    ? 'Griot Plus members can publish longer Tales with more room per part.'
                    : 'Everyone can publish Tales. Griot Plus members can publish longer parts.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: InputDecoration(
                  labelText: 'Category',
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: .45),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: _taleCategories
                    .where((value) => value != 'All')
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setSheetState(() => category = value);
                },
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () async {
                  final text = textController.text.trim();
                  if (text.isEmpty) return;
                  final notificationContext = context;
                  try {
                    final result = await context
                        .read<MessagingApiService>()
                        .publishTale(category: category, content: text);
                    final taleId = result['id']?.toString();
                    _localTales.insert(
                      0,
                      _LocalTale(
                        id: taleId,
                        text: text,
                        category: category,
                        createdAt: DateTime.now(),
                        authorName: 'You',
                      ),
                    );
                    if (sheetContext.mounted) Navigator.pop(sheetContext, true);
                  } catch (error) {
                    if (!notificationContext.mounted) return;
                    NotificationService.showError(
                      notificationContext,
                      'Could not publish Tale: $error',
                    );
                  }
                },
                icon: const Icon(Icons.publish_rounded),
                label: const Text('Publish Tale'),
              ),
            ],
          ),
        ),
      ),
    );
    textController.dispose();
    if (created == true && mounted) setState(() {});
  }

  Widget _upcomingSection(
    BuildContext context,
    List<SpaceModel> upcomingSpaces,
  ) {
    final colors = Theme.of(context).colorScheme;
    final groups = <String, List<SpaceModel>>{
      'mine': upcomingSpaces
          .where((space) => space.hostRelationship == 'mine' || space.isHost)
          .toList(),
      'friends': upcomingSpaces
          .where(
            (space) => space.hostRelationship == 'friends' && !space.isHost,
          )
          .toList(),
      'following': upcomingSpaces
          .where(
            (space) => space.hostRelationship == 'following' && !space.isHost,
          )
          .toList(),
      'public': upcomingSpaces
          .where(
            (space) =>
                !space.isHost &&
                space.hostRelationship != 'friends' &&
                space.hostRelationship != 'following',
          )
          .toList(),
    };
    final labels = <String, (String, IconData)>{
      'mine': ('Your scheduled Campfires', Icons.event_available_rounded),
      'friends': ('From friends', Icons.people_alt_rounded),
      'following': ('From people you follow', Icons.person_add_alt_1_rounded),
      'public': ('Public discovery', Icons.public_rounded),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Get these in your calendar',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          'A calmer schedule built around people and communities you care about.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        for (final group in groups.entries)
          if (group.value.isNotEmpty)
            _upcomingGroupSection(
              context,
              group.key,
              labels[group.key]!.$1,
              labels[group.key]!.$2,
              group.value,
            ),
      ],
    );
  }

  Widget _upcomingGroupSection(
    BuildContext context,
    String groupKey,
    String title,
    IconData icon,
    List<SpaceModel> spaces,
  ) {
    final colors = Theme.of(context).colorScheme;
    final expanded = _expandedUpcomingGroups.contains(groupKey);
    final visible = expanded ? spaces : spaces.take(6).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${spaces.length}',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...visible.map((space) => _upcomingSpaceCard(context, space)),
          if (spaces.length > 6)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  if (expanded) {
                    _expandedUpcomingGroups.remove(groupKey);
                  } else {
                    _expandedUpcomingGroups.add(groupKey);
                  }
                }),
                icon: Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
                label: Text(
                  expanded ? 'Show fewer' : 'Show all ${spaces.length}',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _upcomingSpaceCard(BuildContext context, SpaceModel space) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GriotBrandedContainer(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderRadius: 18,
        child: Row(
          children: [
            GriotAvatar(
              avatarUrl: space.hostAvatarUrl,
              radius: 20,
              backgroundColor: colors.primary.withValues(alpha: .14),
              iconColor: colors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    space.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatScheduledTime(space.scheduledAt),
                    style: TextStyle(color: colors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hosted by ${space.hostName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (space.description != null &&
                      space.description!.trim().isNotEmpty)
                    Text(
                      space.description!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant.withValues(alpha: .78),
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),
                ],
              ),
            ),
            if (space.isHost &&
                space.scheduledAt != null &&
                !space.scheduledAt!.isAfter(DateTime.now()))
              FilledButton.icon(
                onPressed: () => _joinSpace(context, space),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start'),
              )
            else
              IconButton.filledTonal(
                tooltip: _reminderActive(space)
                    ? 'Reminder enabled'
                    : 'Notify me',
                onPressed: () => _toggleReminder(context, space),
                icon: Icon(
                  _reminderActive(space)
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                ),
              ),
            IconButton(
              tooltip: 'Share scheduled Campfire',
              onPressed: () => _shareCampfire(context, space),
              icon: const Icon(Icons.ios_share_rounded),
            ),
            if (space.isHost)
              IconButton(
                tooltip: 'Manage scheduled Campfire',
                onPressed: () => _removeScheduledSpace(context, space),
                icon: const Icon(Icons.more_vert_rounded),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyUpcomingSection(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GriotBrandedContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 22,
      child: Column(
        children: [
          Icon(Icons.event_available_rounded, size: 42, color: colors.primary),
          const SizedBox(height: 10),
          const Text(
            'No upcoming Campfires yet',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Scheduled community spaces will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Future<void> _removeScheduledSpace(
    BuildContext context,
    SpaceModel space,
  ) async {
    final messagingApi = context.read<MessagingApiService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          space.scheduledAt != null &&
                  space.scheduledAt!.isAfter(DateTime.now())
              ? 'Cancel scheduled Campfire?'
              : 'End Campfire?',
        ),
        content: Text('“${space.title}” will no longer appear in Upcoming.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Remove it immediately so a stale/cached upcoming response cannot make
    // a successful cancellation look like it failed.
    final previousIndex = _upcomingSpaces.indexWhere(
      (item) => item.id == space.id,
    );
    if (previousIndex >= 0 && mounted) {
      setState(() => _upcomingSpaces.removeAt(previousIndex));
    }
    try {
      await messagingApi.endCampfire(space.id);
      await _loadUpcomingSpaces(forceRefresh: true);
    } catch (error) {
      if (mounted && previousIndex >= 0) {
        setState(() {
          final insertAt = previousIndex
              .clamp(0, _upcomingSpaces.length)
              .toInt();
          _upcomingSpaces.insert(insertAt, space);
        });
      }
      if (!context.mounted) return;
      NotificationService.showError(
        context,
        'Could not cancel Campfire: $error',
      );
    }
  }

  String _formatScheduledTime(DateTime? value) {
    if (value == null) return 'Upcoming';
    final local = value.toLocal();
    final now = DateTime.now();
    final day = DateUtils.isSameDay(local, now)
        ? 'Today'
        : DateUtils.isSameDay(local, now.add(const Duration(days: 1)))
        ? 'Tomorrow'
        : '${local.day}/${local.month}/${local.year}';
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day at $hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }

  bool _reminderActive(SpaceModel space) {
    final scheduledAt = space.scheduledAt;
    if (scheduledAt != null && scheduledAt.isBefore(DateTime.now())) {
      _campfireReminders.remove(space.id);
      return false;
    }
    return _campfireReminders.contains(space.id);
  }

  Future<void> _toggleReminder(BuildContext context, SpaceModel space) async {
    final enabled = _reminderActive(space);
    try {
      final api = context.read<MessagingApiService>();
      if (enabled) {
        await api.removeCampfireReminder(space.id);
      } else {
        await api.addCampfireReminder(space.id);
      }
      if (!context.mounted) return;
      setState(() {
        if (enabled) {
          _campfireReminders.remove(space.id);
        } else {
          _campfireReminders.add(space.id);
        }
      });
      NotificationService.showInfo(
        context,
        enabled
            ? 'Reminder removed for ${space.title}'
            : 'You will be notified when ${space.title} is ready',
      );
    } catch (error) {
      if (context.mounted) {
        NotificationService.showError(
          context,
          'Could not update reminder: $error',
        );
      }
    }
  }

  Widget _spacesSection(BuildContext context, List<SpaceModel> visibleSpaces) {
    if (_loading && _spaces.isEmpty) {
      return GriotBrandedContainer(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(
              'Finding live Campfires…',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Checking ${_region == 'GLOBAL' ? 'the community' : _region} for active conversations.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    if (_error != null && _spaces.isEmpty) {
      return GriotBrandedContainer(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Campfires are temporarily unavailable',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _loadSpaces(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    if (_spaces.isEmpty) {
      final isPlus = context.read<IapProvider>().status.isPlus;
      return _emptyState(
        context,
        icon: Icons.local_fire_department_rounded,
        title: 'No Campfires are live',
        message: isPlus
            ? 'There are no live Campfires in this region yet. Start one and invite people to join the conversation.'
            : 'There are no live Campfires in this region yet. Griot Plus members can start the next one.',
        action: isPlus ? 'Start a Campfire' : 'Get Griot Plus',
      );
    }
    if (visibleSpaces.isEmpty) {
      return _emptyState(
        context,
        icon: Icons.search_off_rounded,
        title: 'No Campfires found',
        message: 'Try another search or browse all Campfires currently live.',
        action: 'Clear search',
        onPressed: () {
          _searchController.clear();
          setState(() => _searchQuery = '');
        },
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Trending',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_spaces.length} live',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Live conversations from the Griot community.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (_loading) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 2),
        ],
        const SizedBox(height: 16),
        for (final space in visibleSpaces) _spaceCard(context, space),
        if (_hasMore && _searchQuery.trim().isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: OutlinedButton.icon(
              onPressed: _loading ? null : () => _loadSpaces(nextPage: true),
              icon: const Icon(Icons.expand_more_rounded),
              label: const Text('Load more Campfires'),
            ),
          ),
      ],
    );
  }

  Future<void> _showCreateSpace() async {
    if (!context.read<IapProvider>().status.isPlus) {
      final shouldOpenPlus = await showPlusRequiredDialog(context);
      if (shouldOpenPlus && mounted) {
        context.push('/settings/griot-plus');
      }
      return;
    }
    if (!mounted) return;
    final created = await context.push<Map<String, dynamic>>(
      '/campfires/create',
    );
    if (created != null && mounted) {
      _loadSpaces(forceRefresh: true);
      _loadUpcomingSpaces(forceRefresh: true);
      final campfireId = created['id']?.toString();
      if (campfireId != null && campfireId.isNotEmpty) {
        // The API returns snake_case while older clients returned camelCase.
        // Treat either shape as a reservation so scheduled Campfires never
        // auto-join or open the media screen before the host explicitly
        // starts them.
        final scheduledRaw = created['scheduledAt'] ?? created['scheduled_at'];
        final scheduledAt = scheduledRaw == null
            ? null
            : DateTime.tryParse(scheduledRaw.toString());
        if (scheduledAt != null && scheduledAt.isAfter(DateTime.now())) {
          NotificationService.showCampfireScheduled(
            context,
            campfireId: campfireId,
            scheduledAt: scheduledAt,
            title: created['title']?.toString(),
          );
          return;
        }
        // Creation and membership are separate backend operations on some
        // deployments. Joining explicitly is idempotent on the server and
        // guarantees the creator appears as host/self before CallScreen starts
        // its participant reconciliation.
        try {
          await context.read<MessagingApiService>().joinCampfire(campfireId);
        } catch (error) {
          if (mounted) {
            NotificationService.showError(
              context,
              'Could not join the new Campfire: $error',
            );
          }
          return;
        }
        if (!mounted) return;
        context.push(
          '/calls/$campfireId',
          extra: {
            'type': 'space',
            'mode': created['mode']?.toString() ?? 'voice',
            'title':
                created['title']?.toString() ?? created['name']?.toString(),
          },
        );
      }
    }
    return;
    /*
    final title = TextEditingController();
    final description = TextEditingController();
    var mode = 'voice';
    var recordSpace = false;
    DateTime? scheduledAt;
    var creating = false;
    final created = await showDialog<bool>(
      context: context,
      // Do not dismiss the creation flow when the user taps outside a field.
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (sheetContext) => Align(
        alignment: Alignment.bottomCenter,
        child: Dialog(
          alignment: Alignment.bottomCenter,
          insetPadding: const EdgeInsets.fromLTRB(12, 24, 12, 24),
          backgroundColor: Theme.of(sheetContext).colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .9,
            child: StatefulBuilder(
            builder: (context, setSheetState) {
          final colors = Theme.of(context).colorScheme;
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.78,
            minChildSize: 0.45,
            maxChildSize: 0.96,
            builder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                // Keep the form and primary action above Griot's persistent
                // bottom navigation as well as the system keyboard.
                MediaQuery.of(context).viewInsets.bottom + 104,
              ),
              child: GriotBrandedContainer(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                borderRadius: 26,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Start a Campfire',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start a public conversation people can join. Your device region is selected automatically; you can change it below.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: title,
                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Campfire name',
                        hintText: 'What would you like to talk about?',
                        prefixIcon: Icon(Icons.campaign_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: description,
                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Optional context for listeners',
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Campfire options',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: recordSpace,
                      onChanged: (value) =>
                          setSheetState(() => recordSpace = value),
                      title: const Text('Record this Campfire'),
                      subtitle: const Text(
                        'Save the conversation for people who cannot join live.',
                      ),
                      secondary: const Icon(Icons.radio_rounded),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Format',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'voice',
                          label: Text('Voice'),
                          icon: Icon(Icons.mic_rounded),
                        ),
                        ButtonSegment(
                          value: 'video',
                          label: Text('Video'),
                          icon: Icon(Icons.videocam_rounded),
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (value) =>
                          setSheetState(() => mode = value.first),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final now = DateTime.now();
                        final date = await showDatePicker(
                          context: context,
                          firstDate: now,
                          lastDate: now.add(const Duration(days: 365)),
                          initialDate: scheduledAt ?? now,
                        );
                        if (date == null || !context.mounted) return;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: scheduledAt == null
                              ? TimeOfDay.now()
                              : TimeOfDay.fromDateTime(scheduledAt!),
                        );
                        if (time == null) return;
                        final selected = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                        if (!selected.isAfter(DateTime.now())) {
                          if (context.mounted) {
                            NotificationService.showInfo(
                              context,
                              'Choose a future start time.',
                            );
                          }
                          return;
                        }
                        setSheetState(() => scheduledAt = selected);
                      },
                      icon: Icon(
                        scheduledAt == null
                            ? Icons.calendar_month_rounded
                            : Icons.event_available_rounded,
                      ),
                      label: Text(
                        scheduledAt == null
                            ? 'Schedule for later'
                            : 'Starts ${_formatScheduledTime(scheduledAt)}',
                      ),
                    ),
                    if (scheduledAt != null)
                      TextButton(
                        onPressed: () =>
                            setSheetState(() => scheduledAt = null),
                        child: const Text('Start immediately instead'),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: creating
                            ? null
                            : () async {
                                if (title.text.trim().isEmpty) {
                                  NotificationService.showInfo(
                                    context,
                                    'Add a Campfire name first.',
                                  );
                                  return;
                                }
                                setSheetState(() => creating = true);
                                try {
                                  await context
                                      .read<MessagingApiService>()
                                      .createCampfire(
                                        title: title.text.trim(),
                                        description: description.text.trim(),
                                        mode: mode,
                                        regionCode: 'GLOBAL',
                                        recordingEnabled: recordSpace,
                                        scheduledAt: scheduledAt,
                                      );
                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext, true);
                                  }
                                } catch (error) {
                                  if (context.mounted) {
                                    setSheetState(() => creating = false);
                                    NotificationService.showError(
                                      context,
                                      'Could not start Campfire: $error',
                                    );
                                  }
                                }
                              },
                        icon: creating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_rounded),
                        label: Text(creating ? 'Starting…' : 'Start Campfire'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
            },
            ),
          ),
        ),
      ),
    );
    title.dispose();
    description.dispose();
    if (created == true && mounted) {
      _loadSpaces(forceRefresh: true);
      _loadUpcomingSpaces(forceRefresh: true);
    }
  }
  */
  }

  Widget _spaceCard(BuildContext context, SpaceModel space) {
    final colors = Theme.of(context).colorScheme;
    final friends = space.friendsPresent.length;
    final listenerLabel = space.participantCount == 1
        ? '1 listener'
        : '${space.participantCount} listeners';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: CampTaleCardSurface(
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _previewCampfire(context, space),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary,
                      Color.lerp(colors.primary, colors.secondary, .28) ??
                          colors.primary,
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        space.mode == 'video'
                            ? Icons.videocam_rounded
                            : Icons.graphic_eq_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF65E38A),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'LIVE CAMPFIRE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .75,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            space.mode == 'video' ? 'Video room' : 'Audio room',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .78),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (space.isHost)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Campfire options',
                        onPressed: () => _showCampfireOptions(context, space),
                        icon: const Icon(
                          Icons.more_horiz_rounded,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary.withValues(alpha: .14),
                      colors.surface.withValues(alpha: .78),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      space.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 23,
                      ),
                    ),
                    if (space.description?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        space.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: space.hostId == null
                          ? null
                          : () => context.push('/camp/profile/${space.hostId}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            GriotAvatar(
                              avatarUrl: space.hostAvatarUrl,
                              radius: 15,
                              backgroundColor: colors.surfaceContainerHighest,
                              iconColor: colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                space.isHost
                                    ? 'You are hosting this Campfire'
                                    : 'Hosted by ${space.hostName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Host',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Tip host',
                              onPressed: () => _tipCreator(
                                userId: space.hostId,
                                walletAddress: space.hostWalletAddress,
                                displayName: space.hostName,
                                avatarUrl: space.hostAvatarUrl,
                                metadata: {
                                  'surface': 'campfire',
                                  'campfireId': space.id,
                                },
                              ),
                              icon: Icon(
                                Icons.volunteer_activism_outlined,
                                size: 20,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _FriendAvatars(friends: space.friendsPresent),
                        const SizedBox(width: 10),
                        Text(
                          listenerLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (friends > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '· $friends friend${friends == 1 ? '' : 's'} here',
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows the room details before changing membership or opening realtime.
  /// A card tap is intentionally non-joining so users can inspect a Campfire
  /// and decide whether to spend network/audio resources entering it.
  Future<void> _previewCampfire(BuildContext context, SpaceModel space) async {
    // Returning to a minimized Campfire must never reopen the join preview or
    // issue a second membership request. The app-level call host already owns
    // the live media session; simply restore it.
    final activeCall = ActiveCallController.instance.request;
    if (activeCall != null &&
        !ActiveCallController.instance.closing &&
        activeCall.conversationType == 'space' &&
        activeCall.conversationId == space.id) {
      ActiveCallController.instance.expand();
      return;
    }
    final colors = Theme.of(context).colorScheme;
    final shouldJoin = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: GriotBrandedContainer(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          borderRadius: 26,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GriotAvatar(
                    avatarUrl: space.hostAvatarUrl,
                    radius: 28,
                    backgroundColor: colors.primary.withValues(alpha: .14),
                    iconColor: colors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          space.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Hosted by ${space.hostName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(dialogContext, false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${space.participantCount} ${space.participantCount == 1 ? 'listener' : 'listeners'} · ${space.mode == 'video' ? 'Video' : 'Voice'} Campfire',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              if (space.description?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 14),
                Text(
                  space.description!.trim(),
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Join Campfire'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
    if (shouldJoin == true && context.mounted) {
      await _joinSpace(context, space);
    }
  }

  Future<void> _joinSpace(BuildContext context, SpaceModel space) async {
    try {
      await context.read<MessagingApiService>().joinCampfire(space.id);
      if (!context.mounted) return;
      context.push(
        '/calls/${space.id}',
        extra: {'type': 'space', 'mode': space.mode, 'title': space.title},
      );
    } catch (error) {
      if (context.mounted) {
        NotificationService.showError(
          context,
          'Could not join this Campfire: $error',
        );
      }
    }
  }

  Future<void> _showCampfireOptions(
    BuildContext context,
    SpaceModel space,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(space.title),
        content: const Text('Choose an action for this Campfire.'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _shareCampfire(context, space);
            },
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Share'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(dialogContext),
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Report'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareCampfire(BuildContext context, SpaceModel space) async {
    try {
      final link = await RealtimeCallService(context.read<ApiClient>())
          .createLink(
            roomId: 'griot-space-${space.id}',
            contextType: 'space',
            conversationId: space.id,
            mode: space.mode,
          );
      await SharePlus.instance.share(
        ShareParams(
          text:
              'Join my ${space.mode == 'video' ? 'video' : 'voice'} Campfire “${space.title}” on Griot:\n$link',
          subject: 'Join a Griot Campfire',
        ),
      );
    } catch (error) {
      if (context.mounted) {
        NotificationService.showError(
          context,
          'Could not share this Campfire: $error',
        );
      }
    }
  }

  Widget _searchField(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GriotBrandedContainer(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      margin: const EdgeInsets.only(top: 8),
      borderRadius: 18,
      blurSigma: 12,
      backgroundColor: colors.surfaceContainerHighest.withValues(alpha: .62),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (value) => setState(() {
          _searchQuery = value;
          _searchSubmitted = false;
        }),
        onSubmitted: (value) {
          setState(() {
            _searchQuery = value.trim();
            _searchSubmitted = _searchQuery.isNotEmpty;
          });
          if (_searchQuery.isNotEmpty) unawaited(_runCampSearch(_searchQuery));
          _searchFocusNode.unfocus();
        },
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: _campfireTab == 0
              ? 'Search Tales'
              : _campfireTab == 2
              ? 'Search Campfires and Tales'
              : _campfireView == 'scheduled'
              ? 'Search scheduled Campfires'
              : 'Search live Campfires',
          hintStyle: TextStyle(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: colors.primary),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _searchSubmitted = false;
                      _campSearchResults = const {};
                      _searchOffset = 0;
                      _searchHasMore = false;
                      _searchLoadingMore = false;
                    });
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _emptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String action,
    VoidCallback? onPressed,
  }) {
    final colors = Theme.of(context).colorScheme;
    return GriotBrandedContainer(
      padding: const EdgeInsets.all(28),
      borderRadius: 24,
      child: Column(
        children: [
          Icon(icon, size: 54, color: colors.primary),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          // Campfire creation is available from the single floating action
          // button. Keeping the empty state informational avoids presenting
          // two competing start controls on this screen.
        ],
      ),
    );
  }
}

class _FriendAvatars extends StatelessWidget {
  final List<Map<String, dynamic>> friends;

  const _FriendAvatars({required this.friends});

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.people_alt_outlined,
          size: 17,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    final visible = friends.take(3).toList();
    return SizedBox(
      width: 24 + ((visible.length - 1) * 18),
      height: 34,
      child: Stack(
        children: [
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: index * 18,
              top: 1,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.surface,
                child: CircleAvatar(
                  radius: 13,
                  child: Text(
                    _initial(visible[index]),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _initial(Map<String, dynamic> friend) {
    final name =
        (friend['displayName'] ??
                friend['display_name'] ??
                friend['username'] ??
                'G')
            .toString()
            .trim();
    return name.isEmpty ? 'G' : name[0].toUpperCase();
  }
}

class _CampSectionSwitcher extends StatelessWidget {
  const _CampSectionSwitcher({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const options = <(String, IconData)>[
      ('Tales', Icons.menu_book_rounded),
      ('Campfires', Icons.local_fire_department_rounded),
      ('Search', Icons.search_rounded),
    ];
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          for (var index = 0; index < options.length; index++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => onChanged(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: selected == index
                          ? colors.primary
                          : colors.primary.withValues(alpha: .05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border(
                        top: BorderSide(
                          color: colors.primary.withValues(
                            alpha: selected == index ? 0 : .6,
                          ),
                          width: 1.5,
                        ),
                        bottom: BorderSide(
                          color: colors.primary.withValues(
                            alpha: selected == index ? 0 : .6,
                          ),
                          width: 1.5,
                        ),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          options[index].$2,
                          size: 16,
                          color: selected == index
                              ? colors.onPrimary
                              : colors.onSurfaceVariant.withValues(alpha: .5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          options[index].$1,
                          style: TextStyle(
                            color: selected == index
                                ? colors.onPrimary
                                : colors.onSurfaceVariant.withValues(alpha: .7),
                            fontWeight: selected == index
                                ? FontWeight.w900
                                : FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CampFullLoadingSkeleton extends StatelessWidget {
  const _CampFullLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CampSkeletonBlock(
          width: double.infinity,
          height: 42,
          radius: 22,
          color: colors.surfaceContainerHighest,
        ),
        const SizedBox(height: 14),
        _CampSkeletonBlock(
          width: 150,
          height: 14,
          color: colors.surfaceContainerHighest,
        ),
        const SizedBox(height: 10),
        ...List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: const _CampLoadingSkeleton(tale: true),
          ),
        ),
      ],
    );
  }
}

class _CampLoadingSkeleton extends StatefulWidget {
  const _CampLoadingSkeleton({required this.tale});

  final bool tale;

  @override
  State<_CampLoadingSkeleton> createState() => _CampLoadingSkeletonState();
}

class _CampLoadingSkeletonState extends State<_CampLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = (_controller.value * 2) - .5;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.2 + progress, 0),
            end: Alignment(progress + 1.2, 0),
            colors: [
              colors.surfaceContainerHighest.withValues(alpha: .58),
              colors.surfaceContainerHighest.withValues(alpha: .9),
              colors.surfaceContainerHighest.withValues(alpha: .58),
            ],
            stops: const [0, .5, 1],
          ).createShader(bounds),
          child: child,
        );
      },
      child: Column(
        children: [
          for (var index = 0; index < 3; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: widget.tale
                  ? _taleSkeleton(context, colors)
                  : _campfireSkeleton(context, colors),
            ),
        ],
      ),
    );
  }

  Widget _taleSkeleton(BuildContext context, ColorScheme colors) {
    return GriotBrandedContainer(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CampSkeletonBlock(
                width: 44,
                height: 44,
                radius: 22,
                color: colors.surface,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CampSkeletonBlock(
                      width: 130,
                      height: 13,
                      color: colors.surface,
                    ),
                    const SizedBox(height: 7),
                    FractionallySizedBox(
                      widthFactor: .62,
                      child: _CampSkeletonBlock(
                        width: double.infinity,
                        height: 10,
                        color: colors.surface,
                      ),
                    ),
                  ],
                ),
              ),
              _CampSkeletonBlock(
                width: 52,
                height: 22,
                radius: 8,
                color: colors.surface,
              ),
              const SizedBox(width: 6),
              _CampSkeletonBlock(
                width: 20,
                height: 24,
                radius: 8,
                color: colors.surface,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              _CampSkeletonBlock(
                width: 106,
                height: 10,
                radius: 5,
                color: colors.surface,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Divider(
                  height: 1,
                  color: colors.outlineVariant.withValues(alpha: .35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          _CampSkeletonBlock(
            width: double.infinity,
            height: 15,
            color: colors.surface,
          ),
          const SizedBox(height: 9),
          FractionallySizedBox(
            widthFactor: .88,
            child: _CampSkeletonBlock(
              width: double.infinity,
              height: 15,
              color: colors.surface,
            ),
          ),
          const SizedBox(height: 9),
          FractionallySizedBox(
            widthFactor: .57,
            child: _CampSkeletonBlock(
              width: double.infinity,
              height: 15,
              color: colors.surface,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: _CampSkeletonBlock(
              width: double.infinity,
              height: 208,
              radius: 0,
              color: colors.surface,
            ),
          ),
          const SizedBox(height: 14),
          _CampSkeletonBlock(width: 94, height: 10, color: colors.surface),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: .4),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              5,
              (_) => _CampSkeletonBlock(
                width: 38,
                height: 22,
                radius: 10,
                color: colors.surface,
              ),
            ),
          ),
          const SizedBox(height: 4),
          _CampSkeletonBlock(
            width: double.infinity,
            height: 30,
            radius: 12,
            color: colors.surface,
          ),
        ],
      ),
    );
  }

  Widget _campfireSkeleton(BuildContext context, ColorScheme colors) {
    return GriotBrandedContainer(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CampSkeletonBlock(
                width: 44,
                height: 44,
                radius: 22,
                color: colors.surface,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CampSkeletonBlock(
                      width: double.infinity,
                      height: 14,
                      color: colors.surface,
                    ),
                    const SizedBox(height: 8),
                    FractionallySizedBox(
                      widthFactor: .55,
                      child: _CampSkeletonBlock(
                        width: double.infinity,
                        height: 10,
                        color: colors.surface,
                      ),
                    ),
                  ],
                ),
              ),
              _CampSkeletonBlock(
                width: 58,
                height: 22,
                radius: 8,
                color: colors.surface,
              ),
              const SizedBox(width: 6),
              _CampSkeletonBlock(
                width: 20,
                height: 24,
                radius: 8,
                color: colors.surface,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CampSkeletonBlock(
            width: double.infinity,
            height: 17,
            color: colors.surface,
          ),
          const SizedBox(height: 10),
          FractionallySizedBox(
            widthFactor: .82,
            child: _CampSkeletonBlock(
              width: double.infinity,
              height: 13,
              color: colors.surface,
            ),
          ),
          const SizedBox(height: 8),
          FractionallySizedBox(
            widthFactor: .64,
            child: _CampSkeletonBlock(
              width: double.infinity,
              height: 13,
              color: colors.surface,
            ),
          ),
          const SizedBox(height: 14),
          _CampSkeletonBlock(
            width: double.infinity,
            height: 82,
            radius: 16,
            color: colors.surface,
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: .4),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              4,
              (_) => _CampSkeletonBlock(
                width: 44,
                height: 22,
                radius: 10,
                color: colors.surface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampSkeletonBlock extends StatelessWidget {
  const _CampSkeletonBlock({
    required this.width,
    required this.height,
    required this.color,
    this.radius = 6,
  });

  final double width;
  final double height;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
