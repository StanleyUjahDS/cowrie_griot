import 'dart:async';
import 'dart:convert';
import '../../../core/cache/local_json_cache.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/api_config.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../models/conversation_model.dart';
import '../models/message_request.dart';
import '../services/messaging_api_service.dart';
import '../services/media_api_service.dart';
import '../services/tip_api_service.dart';
import '../services/message_cache_service.dart';
import '../../users/models/user_model.dart';
import '../../users/providers/user_provider.dart';
import '../../wallet/utils/chain_assets.dart';
import '../../miner/services/mining_api_service.dart';
import '../../wallet/services/transaction_api_service.dart';
import '../../wallet/services/wallet_api_service.dart';
import '../../wallet/services/wallet_service.dart';
import '../../wallet/services/wallet_rpc_service.dart';

enum RelationshipState { none, pendingSent, pendingReceived, friends, blocked }

class MessagingProvider extends ChangeNotifier {
  int campfireRevision = 0;
  String? lastEndedCampfireId;
  static const Uuid _uuid = Uuid();
  final MessagingApiService _apiService;
  final MediaApiService _mediaApiService;
  UserProvider _userProvider;
  final MessageCacheService _messageCache;
  final MiningApiService _miningApi;
  final TransactionApiService _transactionApi;
  final TipApiService _tipApi;
  final WalletService _walletService;
  final WalletApiService _walletApi;
  final WalletRpcService _walletRpc;
  final LocalJsonCache _localCache = const LocalJsonCache();
  void Function(Map<String, dynamic> data)? _incomingCallHandler;
  final _callStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _campfireEventController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Emits authoritative call lifecycle changes received from the server.
  /// Call screens subscribe while mounted so a hang-up on either device
  /// closes the local room immediately.
  Stream<Map<String, dynamic>> get callStatusStream =>
      _callStatusController.stream;

  /// Emits realtime Campfire/Space changes for the app-level foreground
  /// notification surface. These are deliberately separate from push
  /// notifications: when the app is open they should appear as one replacing
  /// Griot toast, just like message and tip events.
  Stream<Map<String, dynamic>> get campfireEventStream =>
      _campfireEventController.stream;

  static const _friendsCacheKey = 'social_friends_snapshot_v1';
  static const _receivedRequestsCacheKey = 'social_received_requests_v1';
  static const _sentRequestsCacheKey = 'social_sent_requests_v1';
  static const _notificationsCacheKey = 'social_notifications_snapshot_v1';
  static const _pinnedConversationsKey = 'chat_pinned_conversations_v1';

  MessagingProvider({
    required MessagingApiService apiService,
    required MediaApiService mediaApiService,
    required UserProvider userProvider,
    required MessageCacheService messageCache,
    required MiningApiService miningApi,
    required TransactionApiService transactionApi,
    required TipApiService tipApi,
    required WalletService walletService,
    required WalletApiService walletApi,
    required WalletRpcService walletRpc,
  }) : _apiService = apiService,
       _mediaApiService = mediaApiService,
       _userProvider = userProvider,
       _messageCache = messageCache,
       _miningApi = miningApi,
       _transactionApi = transactionApi,
       _tipApi = tipApi,
       _walletService = walletService,
       _walletApi = walletApi,
       _walletRpc = walletRpc {
    _loadNotificationSeenTime();
    unawaited(_restorePinnedConversations());
    // Social snapshots are account-specific. They are loaded only from the
    // authenticated API, never eagerly from a previous account.
  }

  Future<void> _restorePinnedConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_pinnedConversationsKey) ?? const [];
      _pinnedConversationIds
        ..clear()
        ..addAll(ids.where((id) => id.trim().isNotEmpty));
      if (_pinnedConversationIds.isNotEmpty) notifyListeners();
    } catch (e) {
      debugPrint('MessagingProvider: unable to restore pinned chats: $e');
    }
  }

  Future<void> _saveSocialCache() async {
    await Future.wait([
      _localCache.write(
        _friendsCacheKey,
        _friends.map((user) => user.toJson()).toList(),
      ),
      _localCache.write(
        _receivedRequestsCacheKey,
        _receivedRequests.map((request) => request.toJson()).toList(),
      ),
      _localCache.write(
        _sentRequestsCacheKey,
        _sentRequests.map((request) => request.toJson()).toList(),
      ),
      _localCache.write(
        _notificationsCacheKey,
        _notificationEvents.map((event) {
          final copy = Map<String, dynamic>.from(event);
          copy.remove('icon');
          final timestamp = copy['timestamp'];
          if (timestamp is DateTime) {
            copy['timestamp'] = timestamp.toIso8601String();
          }
          return copy;
        }).toList(),
      ),
    ]);
  }

  void updateUserProvider(UserProvider provider) {
    _userProvider = provider;
  }

  void setIncomingCallHandler(
    void Function(Map<String, dynamic> data)? handler,
  ) {
    _incomingCallHandler = handler;
  }

  @override
  void dispose() {
    _callStatusController.close();
    _campfireEventController.close();
    disconnectSocket();
    super.dispose();
  }

  // ==========================================================
  // STATE
  // ==========================================================

  final Map<String, List<ChatMessage>> _messagesByConversation = {};
  final Map<String, bool> _isLoadingMessages = {};

  List<Conversation> _conversations = [];
  final Set<String> _pinnedConversationIds = <String>{};
  bool _isLoadingConversations = false;
  DateTime? _lastConversationsLoadedAt;
  Future<void>? _conversationsLoadFuture;

  List<MessageRequest> _receivedRequests = [];
  List<MessageRequest> _sentRequests = [];
  bool _isLoadingRequests = false;
  Future<void>? _requestsLoadFuture;
  DateTime? _lastRequestsLoadedAt;

  List<UserModel> _friends = [];
  final Set<String> _friendRequestInFlight = <String>{};
  bool _isLoadingFriends = false;
  int _friendsTotal = 0;
  bool _hasMoreFriends = false;
  int _friendsOffset = 0;
  String? _currentFriendsSearchQuery;
  bool _isLoadingMoreFriends = false;

  List<Conversation> _discoveredGroups = [];
  List<Conversation> _discoveredChannels = [];
  bool _isSearchingGroups = false;
  bool _isSearchingChannels = false;
  int _groupsPage = 1;
  bool _hasMoreGroups = false;
  int _channelsPage = 1;
  bool _hasMoreChannels = false;
  bool _isLoadingMoreGroups = false;
  bool _isLoadingMoreChannels = false;

  List<String> _blockedUserIds = [];
  bool _isLoadingBlocks = false;

  bool _presenceInitialized = false;
  bool get isPresenceInitialized => _presenceInitialized;

  final Map<String, bool> _presenceMap = {};
  Map<String, bool> get presenceMap => _presenceMap;

  List<Map<String, dynamic>> _walletActivities = [];
  String? _walletNextPageKey;
  bool _isLoadingWalletActivity = false;
  bool _isLoadingMoreWalletActivity = false;

  Map<String, dynamic>? _tipConfig;
  bool _isLoadingTipConfig = false;

  DateTime? _lastSeenNotificationTime;
  final List<DateTime> _liveNotificationTimes = <DateTime>[];
  DateTime? get lastSeenNotificationTime => _lastSeenNotificationTime;

  // Real-time
  io.Socket? _socket;
  io.Socket? _walletSocket;
  Timer? _presenceHeartbeat;
  String? _currentRoomId;
  final Map<String, Set<String>> _typingUsers = {};

  // Tip Event Stream for Global UI
  final _tipReceivedController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get tipReceivedStream =>
      _tipReceivedController.stream;

  // ==========================================================
  // GETTERS
  // ==========================================================

  List<Conversation> get conversations => _conversations;
  bool isConversationPinned(String conversationId) =>
      _pinnedConversationIds.contains(conversationId);
  bool get isLoadingConversations => _isLoadingConversations;
  Map<String, Set<String>> get typingUsers => _typingUsers;

  List<MessageRequest> get receivedRequests => _receivedRequests;
  List<MessageRequest> get sentRequests => _sentRequests;
  bool get isLoadingRequests => _isLoadingRequests;

  List<UserModel> get friends => _friends;
  bool get isLoadingFriends => _isLoadingFriends;
  int get friendsTotal => _friendsTotal;
  bool get hasMoreFriends => _hasMoreFriends;
  bool get isLoadingMoreFriends => _isLoadingMoreFriends;

  List<Conversation> get discoveredGroups => _discoveredGroups;
  List<Conversation> get discoveredChannels => _discoveredChannels;
  bool get isSearchingGroups => _isSearchingGroups;
  bool get isSearchingChannels => _isSearchingChannels;
  bool get hasMoreGroups => _hasMoreGroups;
  bool get hasMoreChannels => _hasMoreChannels;
  bool get isLoadingMoreGroups => _isLoadingMoreGroups;
  bool get isLoadingMoreChannels => _isLoadingMoreChannels;

  List<String> get blockedUserIds => _blockedUserIds;
  bool get isLoadingBlocks => _isLoadingBlocks;

  List<Map<String, dynamic>> get walletActivities => _walletActivities;
  String? get walletNextPageKey => _walletNextPageKey;
  bool get isLoadingWalletActivity => _isLoadingWalletActivity;
  bool get isLoadingMoreWalletActivity => _isLoadingMoreWalletActivity;

  Map<String, dynamic>? get tipConfig => _tipConfig;
  bool get isLoadingTipConfig => _isLoadingTipConfig;

  int get pendingRequestCount =>
      _receivedRequests.where((r) => r.status == RequestStatus.pending).length;

  // Social Notifications Logic (Connection requests and reactions)
  List<MessageRequest> get requestNotifications {
    final list = [
      ..._receivedRequests.where((r) => r.status == RequestStatus.pending),
      ..._sentRequests.where((r) => r.status == RequestStatus.pending),
    ];
    list.sort((a, b) {
      final timeA = a.respondedAt ?? a.createdAt;
      final timeB = b.respondedAt ?? b.createdAt;
      return timeB.compareTo(timeA);
    });
    return list;
  }

  List<Map<String, dynamic>> get notificationEvents {
    return _notificationEvents;
  }

  List<Map<String, dynamic>> _notificationEvents = [];
  static const int _socialActivityPageSize = 30;
  int _notificationOffset = 0;
  bool _isLoadingMoreNotifications = false;
  bool _hasMoreNotifications = true;

  bool get isLoadingMoreNotifications => _isLoadingMoreNotifications;
  bool get hasMoreNotifications => _hasMoreNotifications;

  String _formatBaseUnits(String rawAmount, int decimals) {
    if (decimals <= 0 || !RegExp(r'^-?\d+$').hasMatch(rawAmount)) {
      return rawAmount;
    }
    final negative = rawAmount.startsWith('-');
    final digits = negative ? rawAmount.substring(1) : rawAmount;
    final padded = digits.padLeft(decimals + 1, '0');
    final split = padded.length - decimals;
    final whole = padded.substring(0, split);
    var fraction = padded.substring(split).replaceFirst(RegExp(r'0+$'), '');
    if (fraction.length > 4) {
      fraction = fraction.substring(0, 4).replaceFirst(RegExp(r'0+$'), '');
    }
    final result = fraction.isEmpty ? whole : '$whole.$fraction';
    return negative ? '-$result' : result;
  }

  List<Map<String, dynamic>> _miningActivities = [];
  List<Map<String, dynamic>> get miningActivities => _miningActivities;

  int get unreadNotificationCount {
    int count = 0;
    final lastSeen =
        _lastSeenNotificationTime ?? DateTime.fromMillisecondsSinceEpoch(0);

    // 1. Message Request Notifications
    count += requestNotifications.where((item) {
      final time = item.respondedAt ?? item.createdAt;
      return time.isAfter(lastSeen);
    }).length;

    // Social notification events only.
    count += notificationEvents.where((item) {
      final raw = item['timestamp'];
      final timestamp = raw is DateTime
          ? raw
          : DateTime.tryParse(raw?.toString() ?? '');
      return timestamp != null && timestamp.isAfter(lastSeen);
    }).length;

    // Socket events arrive before the next activity-feed refresh. Keep them
    // visible in the Updates badge immediately instead of waiting for REST.
    count += _liveNotificationTimes
        .where((time) => time.isAfter(lastSeen))
        .length;

    return count;
  }

  int get unreadMessageCount => _conversations.fold<int>(
    0,
    (total, conversation) => total + conversation.unreadCount,
  );

  List<ChatMessage> getMessagesForConversation(String conversationId) =>
      _messagesByConversation[conversationId] ?? [];

  bool isLoadingMessages(String conversationId) =>
      _isLoadingMessages[conversationId] ?? false;

  // ==========================================================
  // CHANNEL POSTS & COMMENTS STATE
  // ==========================================================

  final Map<String, List<ChatMessage>> _channelPosts = {};
  final Map<String, bool> _isLoadingPosts = {};

  final Map<String, List<Map<String, dynamic>>> _postComments = {};
  final Map<String, bool> _isLoadingComments = {};

  List<ChatMessage> getChannelPosts(String conversationId) =>
      _channelPosts[conversationId] ?? [];
  bool isLoadingPosts(String conversationId) =>
      _isLoadingPosts[conversationId] ?? false;

  List<Map<String, dynamic>> getPostComments(String postId) =>
      _postComments[postId] ?? [];
  bool isLoadingComments(String postId) => _isLoadingComments[postId] ?? false;

  // ==========================================================
  // ACTIONS
  // ==========================================================

  Future<void> _loadNotificationSeenTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString('last_seen_notification_time');
    if (timeStr != null) {
      _lastSeenNotificationTime = DateTime.tryParse(timeStr);
      notifyListeners();
    }
  }

  Future<void> refreshNotifications() async {
    await Future.wait([
      loadRequests(force: true),
      loadGenericNotifications(refresh: true),
    ]);
  }

  Future<void> loadGenericNotifications({bool refresh = false}) async {
    if (_isLoadingMoreNotifications) return;
    if (!refresh && !_hasMoreNotifications) return;
    _isLoadingMoreNotifications = true;
    notifyListeners();
    try {
      final offset = refresh ? 0 : _notificationOffset;
      final events = await _apiService.getActivityEvents(
        limit: _socialActivityPageSize,
        offset: offset,
      );
      // Connection requests are rendered from requestNotifications, which is
      // the authoritative request source. The activity feed also contains
      // message_request rows, so keeping them here creates duplicate cards
      // and double-counts unread updates.
      final activityEvents = events.where((event) {
        final type = event['eventType']?.toString();
        return type != 'message_request' &&
            type != 'request_accepted' &&
            type != 'request_declined' &&
            type != 'request_withdrawn';
      }).toList();
      final mapped = activityEvents.map((event) {
        final walletAddress = event['counterpartyWalletAddress']?.toString();
        final actorName =
            event['username'] ?? event['displayName'] ?? 'Someone';
        final metadata = event['metadata'] is Map
            ? Map<String, dynamic>.from(event['metadata'])
            : <String, dynamic>{};

        final type = event['eventType']?.toString() ?? 'generic';
        String title = '';
        String message = '';
        IconData icon = Icons.notifications_rounded;

        final isRecipient = event['isRecipient'] != false;
        if (type == 'message_request') {
          title = 'New Request';
          message = '$actorName sent you a connection request.';
          icon = Icons.person_add_rounded;
        } else if (type == 'request_accepted') {
          title = 'Request Accepted';
          message = '$actorName accepted your connection request.';
          icon = Icons.person_add_alt_1_rounded;
        } else if (type == 'request_declined') {
          title = 'Request Declined';
          message = '$actorName declined your connection request.';
          icon = Icons.person_remove_rounded;
        } else if (type == 'request_withdrawn') {
          title = 'Request Withdrawn';
          message = '$actorName withdrew a connection request.';
          icon = Icons.undo_rounded;
        } else if (type == 'tip_received') {
          title = isRecipient ? 'Tip Received!' : 'Tip Sent';
          final asset = metadata['tokenSymbol']?.toString().trim();
          final rawAmount = metadata['amountRaw']?.toString();
          final decimals = int.tryParse(
            metadata['tokenDecimals']?.toString() ?? '',
          );
          final readableAmount = metadata['amountDisplay']?.toString().trim();
          final summary = readableAmount != null && readableAmount.isNotEmpty
              ? readableAmount
              : (rawAmount != null && decimals != null && decimals > 0
                    ? _formatBaseUnits(rawAmount, decimals)
                    : null);
          final assetLabel = asset != null && asset.isNotEmpty ? ' $asset' : '';
          final readableSummary = summary == null
              ? 'a tip'
              : (assetLabel.isNotEmpty &&
                        summary.toUpperCase().contains(asset!.toUpperCase())
                    ? summary
                    : '$summary$assetLabel');
          message = isRecipient
              ? '$actorName sent you $readableSummary.'
              : 'You sent $readableSummary to $actorName.';
          icon = Icons.volunteer_activism_outlined;
        } else if (type == 'plus_gift_received') {
          title = 'Griot Plus gift received';
          message =
              '$actorName paid for Griot Plus for you. Your membership is now active.';
          icon = Icons.card_giftcard_rounded;
        } else if (type == 'plus_activated') {
          title = 'Griot Plus is active';
          message = 'Your Griot Plus membership is now active.';
          icon = Icons.workspace_premium_rounded;
        } else if (type == 'native_transfer_received' ||
            type == 'token_transfer_received') {
          title = 'Payment received';
          message = 'You received a blockchain payment.';
          icon = Icons.call_received_rounded;
        } else if (type == 'call_log') {
          final status = metadata['status']?.toString().toLowerCase();
          final mode = metadata['mode']?.toString().toLowerCase() == 'video'
              ? 'video'
              : 'voice';
          final callLabel = mode == 'video' ? 'video call' : 'voice call';
          title = status == 'missed'
              ? 'Missed $callLabel'
              : status == 'declined'
              ? 'Call declined'
              : 'Call ended';
          message = status == 'missed'
              ? 'You missed a $callLabel.'
              : status == 'declined'
              ? '$actorName declined the $callLabel.'
              : 'Your $callLabel has ended. View call history for details.';
          icon = mode == 'video'
              ? Icons.videocam_outlined
              : Icons.phone_in_talk_outlined;
        } else if (type == 'mining_settlement') {
          title = 'Mining rewards settled';
          message = 'Your mining rewards are ready to view.';
          icon = Icons.bolt_rounded;
        } else if (type == 'mining_session_complete') {
          title = 'Mining session complete';
          message = 'Your next mining session is ready to start.';
          icon = Icons.bolt_rounded;
        } else {
          title = 'Griot update';
          message = 'You have a new update.';
          icon = Icons.notifications_rounded;
        }

        final createdAt =
            DateTime.tryParse(event['createdAt']?.toString() ?? '') ??
            DateTime.now();
        return {
          'id': 'event_${event['id']}',
          'type': type,
          'title': title,
          'message': message,
          'timestamp': createdAt,
          'icon': icon,
          'color': 'amber',
          'avatarUrl': event['avatarUrl'],
          'counterpartyUserId': event['counterpartyUserId'],
          'counterpartyWalletAddress': walletAddress,
          'isRecipient': isRecipient,
          'displayName': actorName,
          'username': event['username'],
          'metadata': metadata,
        };
      }).toList();
      final grouped = _groupTipEvents(mapped);
      _notificationEvents = refresh
          ? grouped
          : _groupTipEvents([..._notificationEvents, ...grouped]);
      _notificationOffset = offset + events.length;
      _hasMoreNotifications = events.length == _socialActivityPageSize;
      unawaited(_saveSocialCache());
    } catch (e) {
      debugPrint('Error loading activity events: $e');
    } finally {
      _isLoadingMoreNotifications = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreNotifications() => loadGenericNotifications();

  /// Combines events produced by one blockchain transaction. A multi-recipient
  /// tip can create one activity row per recipient; showing the transaction
  /// hash once gives users a compact summary while the UI can still expand the
  /// grouped recipients for full details.
  List<Map<String, dynamic>> _groupTipEvents(
    List<Map<String, dynamic>> events,
  ) {
    final result = <Map<String, dynamic>>[];
    final groupedIndexes = <String, int>{};

    final flattenedEvents = events.expand((event) {
      final items = event['tipItems'];
      if (items is List && items.isNotEmpty) {
        return items.whereType<Map>().map(
          (item) => Map<String, dynamic>.from(item),
        );
      }
      return <Map<String, dynamic>>[event];
    });

    for (final event in flattenedEvents) {
      if (event['type'] != 'tip_received') {
        result.add(event);
        continue;
      }

      final metadata = event['metadata'] is Map
          ? Map<String, dynamic>.from(event['metadata'])
          : <String, dynamic>{};
      final hash = metadata['hash']?.toString() ?? '';
      final batchId =
          metadata['batchId']?.toString() ??
          metadata['batch_id']?.toString() ??
          '';
      final groupingId = hash.isNotEmpty
          ? 'hash:$hash'
          : (batchId.isNotEmpty ? 'batch:$batchId' : '');

      // Events without a transaction/batch identity must remain separate.
      if (groupingId.isEmpty) {
        result.add(event);
        continue;
      }

      final existingIndex = groupedIndexes[groupingId];
      if (existingIndex == null) {
        final grouped = Map<String, dynamic>.from(event);
        grouped['id'] = 'tip_group_${groupingId.replaceAll(':', '_')}';
        grouped['isGroupedTip'] = true;
        grouped['tipCount'] = 1;
        grouped['tipItems'] = [event];
        groupedIndexes[groupingId] = result.length;
        result.add(grouped);
      } else {
        final grouped = result[existingIndex];
        final items = (grouped['tipItems'] as List).toList()..add(event);
        grouped['tipItems'] = items;
        grouped['tipCount'] = items.length;
        final recipient = grouped['isRecipient'] != false;
        final people = items
            .map((item) => (item as Map)['displayName']?.toString())
            .whereType<String>()
            .where((name) => name.trim().isNotEmpty)
            .toSet()
            .toList();
        grouped['title'] = recipient
            ? '${items.length} tips received'
            : '${items.length} tips sent';
        grouped['message'] = recipient
            ? 'From ${people.isEmpty ? 'multiple users' : people.join(', ')}'
            : 'To ${people.isEmpty ? 'multiple users' : people.join(', ')}';
      }
    }

    return result;
  }

  Future<void> loadWalletActivity({bool refresh = true}) async {
    if (refresh) {
      if (_isLoadingWalletActivity) return;
      _isLoadingWalletActivity = true;
    } else {
      if (_isLoadingMoreWalletActivity || _walletNextPageKey == null) return;
      _isLoadingMoreWalletActivity = true;
    }

    notifyListeners();

    try {
      final response = await _walletApi.getActivity(
        limit: 20,
        pageKey: refresh ? null : _walletNextPageKey,
      );

      final List<dynamic> rawList = response['activity'] ?? [];
      _walletNextPageKey = response['nextPageKey'];

      final newActivities = rawList.map((item) {
        final timestamp = DateTime.parse(
          item['timestamp'] ??
              item['minedAt'] ??
              item['submittedAt'] ??
              DateTime.now().toIso8601String(),
        );

        final operationType = item['operationType']?.toString();
        final status = item['status']?.toString();
        final fromUser = item['fromUser'];
        final toUser = item['toUser'];

        String title = 'Wallet Transaction';
        String message = 'Blockchain interaction confirmed';
        IconData icon = Icons.account_balance_wallet_outlined;
        String color = 'primary';

        if (operationType == 'trade') {
          title = 'Asset Swap';
          message = 'Token exchange completed successfully';
          icon = Icons.swap_horiz_rounded;
        } else if (operationType == 'send') {
          final toName = toUser != null
              ? (toUser['displayName'] ?? toUser['username'] ?? 'Griot User')
              : null;
          final amount = item['transfers']?.isNotEmpty == true
              ? '${item['transfers'][0]['amount']} ${item['transfers'][0]['symbol']}'
              : '';

          title = toName != null ? 'Tipped $toName' : 'Sent Funds';
          message = toName != null
              ? 'You sent $amount to $toName'
              : 'Transaction broadcast to the network';
          icon = Icons.north_east_rounded;
        } else if (operationType == 'receive') {
          final fromName = fromUser != null
              ? (fromUser['displayName'] ??
                    fromUser['username'] ??
                    'Griot User')
              : null;
          final amount = item['transfers']?.isNotEmpty == true
              ? '${item['transfers'][0]['amount']} ${item['transfers'][0]['symbol']}'
              : '';

          title = fromName != null ? 'Tip from $fromName' : 'Received Funds';
          message = fromName != null
              ? '$fromName sent you $amount'
              : 'New funds detected in your wallet';
          icon = Icons.volunteer_activism_outlined;
          color = 'amber';
        }

        return {
          'id': 'wallet_${item['id']}',
          'type': 'wallet_activity',
          'operationType': operationType,
          'title': title,
          'message': message,
          'timestamp': timestamp,
          'icon': icon,
          'color': color,
          'status': status,
          'hash': item['hash'],
          'fromUser': fromUser,
          'toUser': toUser,
        };
      }).toList();

      if (refresh) {
        _walletActivities = newActivities;
      } else {
        _walletActivities.addAll(newActivities);
      }
    } catch (e) {
      debugPrint('Error loading wallet activity: $e');
    } finally {
      _isLoadingWalletActivity = false;
      _isLoadingMoreWalletActivity = false;
      notifyListeners();
    }
  }

  Future<void> loadMiningActivity() async {
    try {
      final history = await _miningApi.getMiningHistory(limit: 20);

      // Only show settled (daily) rewards in the activity feed,
      // as per user requirement to not notify on every session press.
      _miningActivities = history
          .where(
            (item) =>
                item['status'] == 'settled' ||
                item['settled'] == true ||
                item['settledAt'] != null ||
                item['settled_at'] != null,
          )
          .map((item) {
            final amount = (item['amount'] ?? item['reward'] ?? 0).toString();
            final currency = item['currency'] ?? 'COWRIE';
            final timestamp = DateTime.parse(
              item['created_at'] ??
                  item['timestamp'] ??
                  DateTime.now().toIso8601String(),
            );

            return {
              'id': 'mining_${item['id']}',
              'type': 'mining',
              'title': 'Daily Mining Settlement',
              'message':
                  'You earned $amount $currency for yesterday\'s activity.',
              'timestamp': timestamp,
              'icon': Icons.bolt_rounded,
              'color': 'green',
            };
          })
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading mining activity: $e');
    }
  }

  // ==========================================================
  // ACTIONS - TIPPING
  // ==========================================================

  Future<void> loadTipConfig() async {
    _isLoadingTipConfig = true;
    notifyListeners();
    try {
      _tipConfig = await _tipApi.getTipConfig();
    } catch (e) {
      debugPrint('Error loading tip config: $e');
    } finally {
      _isLoadingTipConfig = false;
      notifyListeners();
    }
  }

  Future<List<ChatUser>> getConversationMembers(
    String conversationId, {
    bool isGroup = false,
  }) async {
    try {
      return await _apiService.getConversationMembers(
        conversationId,
        isGroup: isGroup,
      );
    } catch (e) {
      debugPrint('Error getting conversation members: $e');
      return [];
    }
  }

  String normalizeNetworkName(String? name) {
    if (name == null) return '';
    return ChainAssets.normalize(name);
  }

  Future<Map<String, dynamic>> prepareTip({
    required String network,
    required String recipient,
    required String amount,
    String? tokenAddress,
  }) async {
    final normalizedSearch = normalizeNetworkName(network);

    // 1. Get Tip Config to find Chain ID
    final config = await _tipApi.getTipConfig();
    final networks = config['networks'] as List;

    final netInfo = networks.firstWhere(
      (n) => normalizeNetworkName(n['network'].toString()) == normalizedSearch,
      orElse: () =>
          throw Exception('Unsupported network for tipping: $network'),
    );
    final int chainId = int.parse(netInfo['chainId'].toString());

    // 2. Prepare Tip Data
    final Map<String, dynamic> response =
        await (tokenAddress != null && tokenAddress.isNotEmpty
            ? _tipApi.prepareTokenTip(
                chainId: chainId,
                token: tokenAddress,
                recipient: recipient,
                amount: amount,
              )
            : _tipApi.prepareNativeTip(
                chainId: chainId,
                recipient: recipient,
                amount: amount,
              ));

    // Verify prepared data against selection before returning (Spec Point Preparation API)
    final int returnedChainId = int.parse(response['chainId'].toString());
    if (returnedChainId != chainId) {
      throw Exception('Security Alert: Prepared chainId mismatch');
    }

    final String returnedNetwork = normalizeNetworkName(
      response['network']?.toString(),
    );
    if (returnedNetwork != normalizedSearch) {
      throw Exception('Security Alert: Prepared network mismatch');
    }

    final String router =
        response['routerAddress']?.toString().toLowerCase() ?? '';
    final txTo = response['transaction']?['to']?.toString().toLowerCase();
    if (txTo != router) {
      throw Exception('Security Alert: Router address mismatch');
    }

    return response;
  }

  Future<Map<String, dynamic>> prepareBatchTip({
    required String network,
    required List<String> recipients,
    required List<String> amounts,
    String? tokenAddress,
  }) async {
    final normalizedSearch = normalizeNetworkName(network);

    // 1. Get Tip Config to find Chain ID
    final config = await _tipApi.getTipConfig();
    final networks = config['networks'] as List;

    final netInfo = networks.firstWhere(
      (n) => normalizeNetworkName(n['network'].toString()) == normalizedSearch,
      orElse: () =>
          throw Exception('Unsupported network for tipping: $network'),
    );
    final int chainId = int.parse(netInfo['chainId'].toString());

    // 2. Prepare Tip Data
    final Map<String, dynamic> response =
        await (tokenAddress != null && tokenAddress.isNotEmpty
            ? _tipApi.prepareBatchTokenTip(
                chainId: chainId,
                token: tokenAddress,
                recipients: recipients,
                amounts: amounts,
              )
            : _tipApi.prepareBatchNativeTip(
                chainId: chainId,
                recipients: recipients,
                amounts: amounts,
              ));

    // Verify prepared data against selection before returning
    final int returnedChainId = int.parse(response['chainId'].toString());
    if (returnedChainId != chainId) {
      throw Exception('Security Alert: Prepared chainId mismatch');
    }

    final String returnedNetwork = normalizeNetworkName(
      response['network']?.toString(),
    );
    if (returnedNetwork != normalizedSearch) {
      throw Exception('Security Alert: Prepared network mismatch');
    }

    final String router =
        response['routerAddress']?.toString().toLowerCase() ?? '';
    final txTo = response['transaction']?['to']?.toString().toLowerCase();
    if (txTo != router) {
      throw Exception('Security Alert: Router address mismatch');
    }

    return response;
  }

  Future<String> executeTip({
    required Map<String, dynamic> preparedTip,
    void Function(String status)? onStatusUpdate,
    String? conversationId,
    String? tipMessage,
  }) async {
    final txData = preparedTip['transaction'];
    final String network = preparedTip['network'].toString();
    final String to = txData['to'].toString();
    final String dataHex = txData['data'].toString();
    final String valueRaw = txData['value'].toString();

    // Use safe parsing for chainId as it might be a String or int from backend
    final int chainId = int.parse(preparedTip['chainId'].toString());

    final String assetType = preparedTip['assetType']?.toString() ?? 'native';
    final String? tokenAddress = preparedTip['token']?.toString();

    // 0. Validation (Spec Point 5 & 6)
    if (dataHex.isEmpty || dataHex == '0x') {
      throw Exception('Security Alert: Transaction data is empty');
    }

    final String configuredRouter = preparedTip['routerAddress']
        .toString()
        .toLowerCase();
    if (to.toLowerCase() != configuredRouter) {
      throw Exception(
        'Security Alert: Target address mismatch ($to vs $configuredRouter)',
      );
    }

    final BigInt backendValue = BigInt.parse(valueRaw);
    if (backendValue < BigInt.zero) {
      throw Exception('Invalid transaction value');
    }

    if (assetType == 'native') {
      if (preparedTip['batch'] == true) {
        final List<dynamic> amounts = preparedTip['amounts'];
        BigInt sum = BigInt.zero;
        for (final a in amounts) {
          sum += BigInt.parse(a.toString());
        }
        if (backendValue != sum) {
          throw Exception('Security Alert: Batch value mismatch');
        }
      } else {
        if (backendValue != BigInt.parse(preparedTip['amount'])) {
          throw Exception('Security Alert: Value mismatch');
        }
      }
    } else {
      if (backendValue != BigInt.zero) {
        throw Exception(
          'Security Alert: Token tip should have zero native value',
        );
      }
    }

    final String? myAddress = await _walletService.getAddress();
    if (myAddress == null) {
      throw Exception('No wallet found');
    }

    // 1. ERC-20 Approval if needed (Spec Point 3 & 5)
    if (assetType == 'token' && tokenAddress != null) {
      if (onStatusUpdate != null) onStatusUpdate('Checking allowance...');

      BigInt totalAmount = BigInt.zero;
      if (preparedTip['batch'] == true) {
        final List<dynamic> amounts = preparedTip['amounts'];
        for (final a in amounts) {
          totalAmount += BigInt.parse(a.toString());
        }
      } else {
        totalAmount = BigInt.parse(preparedTip['amount'] ?? '0');
      }

      final allowance = await _checkAllowance(
        network,
        tokenAddress,
        myAddress,
        to,
      );
      if (allowance < totalAmount) {
        if (onStatusUpdate != null) onStatusUpdate('Approving token...');
        final approveHash = await _approveToken(
          network,
          tokenAddress,
          to,
          totalAmount,
          chainId,
        );
        if (onStatusUpdate != null) onStatusUpdate('Waiting for approval...');
        await _waitForReceipt(network, approveHash);
      }
    }

    // 2. Get Nonce
    if (onStatusUpdate != null) onStatusUpdate('Preparing transaction...');
    final int nonce = await _walletRpc.getPendingNonce(
      network: network,
      address: myAddress,
    );

    // 3. Estimate Gas
    final Map<String, dynamic> estimation = await _transactionApi
        .estimateTransaction(
          network: network,
          transaction: {
            'from': myAddress,
            'to': to,
            'value': valueRaw,
            'data': dataHex,
          },
        );

    final String gasLimit = (estimation['gasLimit'] ?? '400000').toString();
    final String? maxFeePerGas = estimation['maxFeePerGas']?.toString();
    final String? maxPriorityFeePerGas = estimation['maxPriorityFeePerGas']
        ?.toString();
    final String? gasPrice = estimation['gasPrice']?.toString();

    // 4. Sign
    if (onStatusUpdate != null) onStatusUpdate('Signing...');
    final String? signedTx = await _walletService.signNativeTransaction(
      to: to,
      valueRaw: valueRaw,
      nonce: nonce,
      gasLimit: gasLimit,
      gasPrice: gasPrice,
      maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
      chainId: chainId,
      dataHex: dataHex,
    );

    if (signedTx == null) {
      throw Exception('Failed to sign transaction');
    }

    // 5. Broadcast
    if (onStatusUpdate != null) onStatusUpdate('Broadcasting...');
    final hash = await _walletRpc.sendRawTransaction(
      network: network,
      signedTransaction: signedTx,
      transactionType: 'tip',
    );

    // 6. Poll Receipt (Spec Point 7)
    if (onStatusUpdate != null) onStatusUpdate('Confirming...');
    final receipt = await _waitForReceipt(network, hash);

    if (receipt['status'] == 0 || receipt['status'] == '0x0') {
      throw Exception('Transaction reverted on-chain');
    }

    final transactionId = _walletRpc.lastBroadcastTransactionId;
    if (transactionId != null && transactionId.isNotEmpty) {
      await _transactionApi.getTransactionStatus(
        transactionId: transactionId,
        network: network,
      );
      await loadGenericNotifications(refresh: true);
    }

    // 7. Store Local Tip Activity (Spec Integration)
    if (conversationId != null) {
      await _savePersistentTipMessage(
        conversationId: conversationId,
        hash: hash,
        preparedTip: preparedTip,
        senderAddress: myAddress,
        text: tipMessage ?? 'Sent a tip',
      );
    }

    return hash;
  }

  Future<void> _savePersistentTipMessage({
    required String conversationId,
    required String hash,
    required Map<String, dynamic> preparedTip,
    required String senderAddress,
    required String text,
  }) async {
    final tipData = {
      'transactionHash': hash,
      'network': preparedTip['network'],
      'chainId': preparedTip['chainId'],
      'assetType': preparedTip['assetType'],
      'tokenAddress': preparedTip['token'],
      'tokenName': preparedTip['tokenName'],
      'tokenSymbol': preparedTip['tokenSymbol'],
      'tokenDecimals': preparedTip['tokenDecimals'],
      'isBatch': preparedTip['batch'] == true,
      'senderAddress': senderAddress,
      'recipientAddresses': preparedTip['batch'] == true
          ? preparedTip['recipients']
          : [preparedTip['recipient']],
      'amountRaw': preparedTip['amount'] ?? preparedTip['amounts']?.first,
      'amountsRaw': preparedTip['batch'] == true
          ? preparedTip['amounts']
          : [preparedTip['amount']],
      'amountDisplay': preparedTip['amountDisplay'],
      'amountsDisplay': preparedTip['amountsDisplay'],
      'recipientNames': preparedTip['recipientNames'],
      'status': 'confirmed',
      'timestamp': DateTime.now().toIso8601String(),
    };

    final clientMessageId = 'tip_client_${_uuid.v4()}';

    try {
      final message = await _apiService.sendMessage(
        conversationId: conversationId,
        content: text,
        messageType: 'tip',
        clientMessageId: clientMessageId,
        tipData: tipData,
      );
      upsertMessage(message.copyWith(clientMessageId: clientMessageId));
    } catch (error) {
      // The blockchain transaction already succeeded. Keep a local fallback
      // visible if the message API is temporarily unavailable; it can be
      // reconciled on the next successful conversation refresh.
      debugPrint('Unable to persist tip message: $error');
      final fallback = ChatMessage(
        id: clientMessageId,
        clientMessageId: clientMessageId,
        conversationId: conversationId,
        senderId: _userProvider.user?.id ?? '',
        text: text,
        type: MessageType.tip,
        status: MessageStatus.sent,
        createdAt: DateTime.now(),
        tipData: tipData,
      );
      upsertMessage(fallback);
    }
  }

  Future<BigInt> _checkAllowance(
    String network,
    String token,
    String owner,
    String spender,
  ) async {
    // IERC20.allowance(owner, spender)
    final cleanOwner = owner.startsWith('0x') ? owner.substring(2) : owner;
    final cleanSpender = spender.startsWith('0x')
        ? spender.substring(2)
        : spender;
    final data =
        '0xdd62ed3e${cleanOwner.padLeft(64, '0')}${cleanSpender.padLeft(64, '0')}';

    final result = await _walletRpc.call(
      network: network,
      to: token,
      data: data,
    );

    if (result == '0x' || result.isEmpty) return BigInt.zero;
    return BigInt.parse(result.replaceFirst('0x', ''), radix: 16);
  }

  Future<String> _approveToken(
    String network,
    String token,
    String spender,
    BigInt amount,
    int chainId,
  ) async {
    // IERC20.approve(spender, amount)
    final cleanSpender = spender.startsWith('0x')
        ? spender.substring(2)
        : spender;
    final data =
        '0x095ea7b3${cleanSpender.padLeft(64, '0')}${amount.toRadixString(16).padLeft(64, '0')}';

    final String? myAddress = await _walletService.getAddress();
    if (myAddress == null) {
      throw Exception('Wallet address not found');
    }

    final int nonce = await _walletRpc.getPendingNonce(
      network: network,
      address: myAddress,
    );

    // Estimate fees for approval too for production reliability
    String gasLimit = '100000';
    String? maxFeePerGas;
    String? maxPriorityFeePerGas;
    String? gasPrice;

    try {
      final estimation = await _transactionApi.estimateTransaction(
        network: network,
        transaction: {
          'from': myAddress,
          'to': token,
          'value': '0',
          'data': data,
        },
      );
      gasLimit = (estimation['gasLimit'] ?? '100000').toString();
      maxFeePerGas = estimation['maxFeePerGas']?.toString();
      maxPriorityFeePerGas = estimation['maxPriorityFeePerGas']?.toString();
      gasPrice = estimation['gasPrice']?.toString();
    } catch (e) {
      debugPrint('Approval estimation failed, using defaults: $e');
    }

    final String? signedTx = await _walletService.signNativeTransaction(
      to: token,
      valueRaw: '0',
      nonce: nonce,
      gasLimit: gasLimit,
      gasPrice: gasPrice,
      maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
      chainId: chainId,
      dataHex: data,
    );

    if (signedTx == null) {
      throw Exception('Failed to sign approval transaction');
    }

    return await _walletRpc.sendRawTransaction(
      network: network,
      signedTransaction: signedTx,
      transactionType: 'tip',
    );
  }

  Future<Map<String, dynamic>> _waitForReceipt(
    String network,
    String hash,
  ) async {
    // Poll promptly after broadcast so the UI does not sit in
    // "Confirming..." for a full minute on normal blocks. The timeout still
    // protects the user from an indefinitely pending RPC transaction.
    for (int i = 0; i < 45; i++) {
      final receipt = await _walletRpc.getTransactionReceipt(
        network: network,
        hash: hash,
      );
      if (receipt != null) return receipt;
      await Future.delayed(const Duration(seconds: 1));
    }
    throw Exception('Transaction confirmation timeout');
  }

  void markNotificationsSeen() async {
    _lastSeenNotificationTime = DateTime.now();
    _liveNotificationTimes.removeWhere(
      (time) => !time.isAfter(_lastSeenNotificationTime!),
    );
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'last_seen_notification_time',
      _lastSeenNotificationTime!.toIso8601String(),
    );
  }

  // ==========================================================
  // RELATIONSHIP LIFECYCLE
  // ==========================================================

  RelationshipState getRelationship(String userId) {
    if (_blockedUserIds.contains(userId)) {
      return RelationshipState.blocked;
    }

    if (_friends.any((f) => f.id == userId)) {
      return RelationshipState.friends;
    }

    if (_receivedRequests.any(
      (r) => r.senderId == userId && r.status == RequestStatus.pending,
    )) {
      return RelationshipState.pendingReceived;
    }

    if (_sentRequests.any(
      (r) => r.receiverId == userId && r.status == RequestStatus.pending,
    )) {
      return RelationshipState.pendingSent;
    }

    return RelationshipState.none;
  }

  MessageRequest? getPendingRequest(String userId) {
    return _receivedRequests
            .where(
              (r) => r.senderId == userId && r.status == RequestStatus.pending,
            )
            .firstOrNull ??
        _sentRequests
            .where(
              (r) =>
                  r.receiverId == userId && r.status == RequestStatus.pending,
            )
            .firstOrNull;
  }

  // ==========================================================
  // ACTIONS - CONVERSATIONS
  // ==========================================================

  Future<void> toggleConversationPin(String conversationId) async {
    final id = conversationId.trim();
    if (id.isEmpty) return;

    if (!_pinnedConversationIds.add(id)) {
      _pinnedConversationIds.remove(id);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _pinnedConversationsKey,
      _pinnedConversationIds.toList(),
    );
    notifyListeners();
  }

  Future<void> loadConversations({bool force = false}) async {
    if (!force &&
        _conversations.isNotEmpty &&
        _lastConversationsLoadedAt != null &&
        DateTime.now().difference(_lastConversationsLoadedAt!) <
            const Duration(minutes: 1)) {
      return;
    }
    if (_conversationsLoadFuture != null) {
      return _conversationsLoadFuture!;
    }
    _conversationsLoadFuture = _loadConversations();
    try {
      await _conversationsLoadFuture;
    } finally {
      _conversationsLoadFuture = null;
    }
  }

  Future<void> _loadConversations() async {
    if (_conversations.isEmpty) {
      _isLoadingConversations = true;
      notifyListeners();
    }

    try {
      await _messageCache.initialize();
      // 1. Load from cache first (Immediate UI)
      final cached = await _messageCache.getConversations();
      if (cached.isNotEmpty) {
        // Use deduplication Map even for cache for safety
        final byId = <String, Conversation>{};
        for (final c in cached) {
          byId[c.id] = c;
        }
        _conversations = byId.values.toList();
        _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        notifyListeners();
      }

      // 2. Fetch from server in background
      final results = await Future.wait<List<Conversation>>([
        _apiService.getConversations().catchError((error) {
          debugPrint('Messaging: conversations request failed: $error');
          return <Conversation>[];
        }),
        _apiService.getGroups().catchError((error) {
          debugPrint('Messaging: groups request failed: $error');
          return <Conversation>[];
        }),
        _apiService.getChannels().catchError((error) {
          debugPrint('Messaging: channels request failed: $error');
          return <Conversation>[];
        }),
      ]);

      // Deduplicate by server ID
      final byId = <String, Conversation>{};

      // Keep cached ones as baseline
      for (final c in _conversations) {
        byId[c.id] = c;
      }

      // Update with fresh data
      for (final section in results) {
        for (final conversation in section) {
          byId[conversation.id] = conversation;
        }
      }

      final list = byId.values.toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      _conversations = list;
      _lastConversationsLoadedAt = DateTime.now();

      // 3. Update cache with deduplicated list
      await _messageCache.saveConversations(list);
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      if (_conversations.isEmpty) _conversations = [];
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  Future<Conversation> startDirectChat(
    String otherUserId, {
    ChatUser? otherUser,
  }) async {
    try {
      var conversation = await _apiService.findDirectConversation(otherUserId);
      if (conversation.otherUser == null && otherUser != null) {
        conversation = conversation.copyWith(otherUser: otherUser);
      }
      if (!_conversations.any((c) => c.id == conversation.id)) {
        _conversations.insert(0, conversation);
      }
      notifyListeners();
      return conversation;
    } catch (e) {
      debugPrint('Error starting direct chat: $e');
      rethrow;
    }
  }

  // ==========================================================
  // ACTIONS - REQUESTS
  // ==========================================================

  Future<void> loadRequests({bool force = false}) async {
    if (_requestsLoadFuture != null) return _requestsLoadFuture!;
    if (!force &&
        _lastRequestsLoadedAt != null &&
        DateTime.now().difference(_lastRequestsLoadedAt!) <
            const Duration(seconds: 30)) {
      return;
    }
    _requestsLoadFuture = _loadRequests();
    try {
      await _requestsLoadFuture!;
    } finally {
      _requestsLoadFuture = null;
    }
  }

  Future<void> _loadRequests() async {
    _isLoadingRequests = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.getReceivedRequests(),
        _apiService.getSentRequests(),
      ]);
      _receivedRequests = results[0];
      _sentRequests = results[1];
      _lastRequestsLoadedAt = DateTime.now();
      unawaited(_saveSocialCache());
    } catch (e) {
      debugPrint('Error loading requests: $e');
    } finally {
      _isLoadingRequests = false;
      notifyListeners();
    }
  }

  Future<void> sendRequest(String recipientId) async {
    if (getRelationship(recipientId) == RelationshipState.friends ||
        !_friendRequestInFlight.add(recipientId)) {
      return;
    }
    try {
      final request = await _apiService.sendDirectMessageRequest(recipientId);
      _sentRequests.add(request);
      notifyListeners();
    } catch (e) {
      final errorStr = e.toString();
      // Requirement: Handle 409 "already friends"
      if (errorStr.contains('409') ||
          errorStr.toLowerCase().contains('already friends')) {
        debugPrint('MessagingProvider: Already friends, refreshing state...');
        await loadFriends();
        await loadConversations();
        return; // Don't rethrow
      }
      debugPrint('Error sending request: $e');
      rethrow;
    } finally {
      _friendRequestInFlight.remove(recipientId);
    }
  }

  Future<void> sendFriendRequest(String recipientId) async {
    if (getRelationship(recipientId) == RelationshipState.friends ||
        !_friendRequestInFlight.add(recipientId)) {
      return;
    }
    try {
      final request = await _apiService.sendFriendRequest(recipientId);
      _sentRequests.add(request);
      notifyListeners();
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('409') ||
          errorStr.toLowerCase().contains('already friends')) {
        await loadFriends();
        await loadConversations();
        return;
      }
      debugPrint('Error sending friend request: $e');
      rethrow;
    } finally {
      _friendRequestInFlight.remove(recipientId);
    }
  }

  /// Sends a friendship request when a DM already exists; otherwise sends the
  /// initial DM/connection request.
  Future<void> sendConnectionRequest(String recipientId) async {
    // Spec: Use 'dm' for all requests.
    // We consolidate to sendRequest which uses 'dm'.
    await sendRequest(recipientId);
  }

  Future<void> acceptRequest(String requestId) async {
    try {
      final result = await _apiService.acceptRequest(requestId);

      // Update status locally instead of removing
      final index = _receivedRequests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        _receivedRequests[index] = _receivedRequests[index].copyWith(
          status: RequestStatus.accepted,
          respondedAt: DateTime.now(),
        );
      }

      // Update UI state to friends immediately
      await loadFriends();

      final conversationJson = result['conversation'];
      if (conversationJson is Map) {
        final conversation = Conversation.fromJson(
          Map<String, dynamic>.from(conversationJson),
        );
        if (!_conversations.any((c) => c.id == conversation.id)) {
          _conversations.insert(0, conversation);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error accepting request: $e');
      rethrow;
    }
  }

  Future<void> declineRequest(String requestId) async {
    try {
      await _apiService.declineRequest(requestId);

      final index = _receivedRequests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        _receivedRequests[index] = _receivedRequests[index].copyWith(
          status: RequestStatus.declined,
          respondedAt: DateTime.now(),
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error declining request: $e');
      rethrow;
    }
  }

  Future<void> withdrawRequest(String requestId) async {
    try {
      await _apiService.withdrawRequest(requestId);

      final index = _sentRequests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        _sentRequests[index] = _sentRequests[index].copyWith(
          status: RequestStatus.withdrawn,
          respondedAt: DateTime.now(),
        );
      }
      notifyListeners();
    } catch (e) {
      // If 409 Conflict, it means the request is no longer pending (accepted/declined)
      // We should refresh the state to reflect reality.
      if (e.toString().contains('409')) {
        await loadRequests();
        await loadFriends();
        await loadConversations();
      }
      rethrow;
    }
  }

  // ==========================================================
  // ACTIONS - FRIENDS & BLOCKS
  // ==========================================================

  Future<void> loadFriends({bool refresh = true}) async {
    if (_isLoadingFriends) {
      return;
    }

    if (refresh) {
      _friendsOffset = 0;
      _currentFriendsSearchQuery = null;
    }

    _isLoadingFriends = true;
    notifyListeners();

    try {
      final result = await _apiService.getFriendsPage(
        limit: 20,
        offset: _friendsOffset,
      );

      final List<dynamic> friendsJson = result['friends'] ?? [];
      final newFriends = friendsJson
          .map((f) => UserModel.fromJson(Map<String, dynamic>.from(f)))
          .toList();

      if (refresh) {
        _friends = newFriends;
      } else {
        _friends.addAll(newFriends);
      }

      _friendsTotal = result['total'] ?? 0;
      _hasMoreFriends = result['hasMore'] ?? false;
      _friendsOffset = result['offset'] + newFriends.length;
      unawaited(_saveSocialCache());
    } catch (e) {
      debugPrint('Error loading friends: $e');
      if (refresh) _friends = [];
    } finally {
      _isLoadingFriends = false;
      notifyListeners();
    }
  }

  Future<void> searchFriends(String query, {bool refresh = true}) async {
    if (query.isEmpty) {
      loadFriends(refresh: true);
      return;
    }

    if (refresh) {
      _friendsOffset = 0;
      _currentFriendsSearchQuery = query;
      _friends = []; // Clear for new search
    } else if (_currentFriendsSearchQuery != query) {
      // Discard if query changed mid-load
      return;
    }

    _isLoadingFriends = true;
    notifyListeners();

    try {
      final result = await _apiService.searchFriends(
        query: query,
        limit: 20,
        offset: _friendsOffset,
      );

      // Check if query is still relevant
      if (_currentFriendsSearchQuery != query) {
        return;
      }

      final List<dynamic> friendsJson = result['friends'] ?? [];
      final newFriends = friendsJson
          .map((f) => UserModel.fromJson(Map<String, dynamic>.from(f)))
          .toList();

      if (refresh) {
        _friends = newFriends;
      } else {
        _friends.addAll(newFriends);
      }

      _friendsTotal = result['total'] ?? 0;
      _hasMoreFriends = result['hasMore'] ?? false;
      _friendsOffset = result['offset'] + newFriends.length;
    } catch (e) {
      debugPrint('Error searching friends: $e');
    } finally {
      if (_currentFriendsSearchQuery == query) {
        _isLoadingFriends = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreFriends() async {
    if (_isLoadingFriends || _isLoadingMoreFriends || !_hasMoreFriends) {
      return;
    }

    _isLoadingMoreFriends = true;
    notifyListeners();

    try {
      if (_currentFriendsSearchQuery != null) {
        await searchFriends(_currentFriendsSearchQuery!, refresh: false);
      } else {
        await loadFriends(refresh: false);
      }
    } finally {
      _isLoadingMoreFriends = false;
      notifyListeners();
    }
  }

  Future<void> loadBlocks() async {
    _isLoadingBlocks = true;
    notifyListeners();

    try {
      _blockedUserIds = await _apiService.getBlockedUserIds();
    } catch (e) {
      debugPrint('Error loading blocks: $e');
    } finally {
      _isLoadingBlocks = false;
      notifyListeners();
    }
  }

  Future<void> blockUser(String userId) async {
    try {
      await _apiService.blockUser(userId);

      // Update local state
      if (!_blockedUserIds.contains(userId)) {
        _blockedUserIds.add(userId);
      }
      _friends.removeWhere((f) => f.id == userId);

      // Stop retrying failed sends for this user/conversation
      // (This would be handled in a more complex queue system,
      // but for now we just clear the failed status in local state if any)

      notifyListeners();

      // Refresh to ensure we have the latest server state
      await loadConversations();
    } catch (e) {
      // Show normal relationship/privacy message if 403/409
      if (e.toString().contains('403') || e.toString().contains('409')) {
        debugPrint('Privacy/Relationship restriction: $e');
      }
      rethrow;
    }
  }

  Future<void> unblockUser(String userId) async {
    try {
      await _apiService.unblockUser(userId);
      _blockedUserIds.remove(userId);
      notifyListeners();

      // Refresh state
      await loadRequests();
      await loadFriends();
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      rethrow;
    }
  }

  Future<void> reportContent({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  }) {
    return _apiService.reportContent(
      targetType: targetType,
      targetId: targetId,
      reason: reason,
      details: details,
    );
  }

  // ==========================================================
  // ACTIONS - MESSAGES
  // ==========================================================

  final Set<String> _receiptRequestsInFlight = <String>{};
  final Map<String, MessageStatus> _pendingMessageStatuses =
      <String, MessageStatus>{};

  // authoritative delivery and deduplication.
  void upsertMessage(ChatMessage incoming) {
    final list = _messagesByConversation[incoming.conversationId] ?? [];

    final existingIndex = list.indexWhere((message) {
      final sameMediaType =
          message.type == incoming.type ||
          (message.isAudio && incoming.isAudio);
      if (message.id == incoming.id) {
        return true;
      }
      if (incoming.clientMessageId != null &&
          message.clientMessageId == incoming.clientMessageId) {
        return true;
      }
      if (incoming.mediaId != null && message.mediaId == incoming.mediaId) {
        return true;
      }

      // Socket delivery and the HTTP response can arrive in either order.
      // Some older server payloads omit clientMessageId and server timestamps
      // may be UTC while an optimistic timestamp is local. If one side is a
      // client row, reconcile by sender, payload and type within a short
      // compatibility window. New server rows persist clientMessageId, so a
      // broad window would risk merging legitimate repeated messages.
      final hasOptimisticIdentity =
          message.id.startsWith('client_') || incoming.id.startsWith('client_');
      final isLegacyPayload =
          message.clientMessageId == null || incoming.clientMessageId == null;
      final samePayload = message.text == incoming.text && sameMediaType;
      final createdDelta = message.createdAt
          .difference(incoming.createdAt)
          .abs();
      if (hasOptimisticIdentity &&
          isLegacyPayload &&
          message.senderId == incoming.senderId &&
          samePayload &&
          createdDelta <= const Duration(minutes: 2)) {
        return true;
      }

      // Fallback for deduplication if server doesn't return clientMessageId in socket events
      // We only match 'sending' messages with same content from same sender within 60s
      if (message.status == MessageStatus.sending &&
          incoming.status != MessageStatus.sending &&
          incoming.clientMessageId == null &&
          message.senderId == incoming.senderId &&
          sameMediaType &&
          message.text == incoming.text &&
          DateTime.now().difference(message.createdAt).inSeconds < 60) {
        return true;
      }
      // The socket event can arrive before the HTTP send response. Media
      // messages do not always echo clientMessageId in socket payloads, so
      // match the pending local media bubble by sender/type/time as a final
      // deduplication fallback.
      if (incoming.mediaId != null &&
          message.status == MessageStatus.sending &&
          incoming.status != MessageStatus.sending &&
          incoming.clientMessageId == null &&
          message.senderId == incoming.senderId &&
          message.isMedia &&
          sameMediaType &&
          DateTime.now().difference(message.createdAt).inSeconds.abs() < 60) {
        return true;
      }
      return false;
    });

    bool isNewMessage = false;

    if (existingIndex >= 0) {
      final existing = list[existingIndex];

      // Update if:
      // 1. New status is further ahead (e.g., delivered > sent)
      // 2. Incoming message is from server (sent/delivered/read) and overrides local sending/failed
      // 3. The ID has changed (temp client ID -> real server ID)

      final bool isIncomingFromServer =
          incoming.status != MessageStatus.sending &&
          incoming.status != MessageStatus.failed;
      final bool isExistingPending =
          existing.status == MessageStatus.sending ||
          existing.status == MessageStatus.failed;

      bool shouldUpdate = false;

      if (incoming.status.index > existing.status.index) {
        shouldUpdate = true;
      } else if (isIncomingFromServer && isExistingPending) {
        shouldUpdate = true;
      } else if (incoming.id != existing.id) {
        shouldUpdate = true;
      }

      if (shouldUpdate) {
        list[existingIndex] = existing.copyWith(
          id: incoming.id,
          clientMessageId: incoming.clientMessageId ?? existing.clientMessageId,
          conversationId: incoming.conversationId,
          senderId: incoming.senderId,
          status: incoming.status,
          text: incoming.text,
          type: incoming.type,
          createdAt: incoming.createdAt,
          mediaUrl: incoming.mediaUrl ?? existing.mediaUrl,
          thumbnailUrl: incoming.thumbnailUrl ?? existing.thumbnailUrl,
          mediaId: incoming.mediaId ?? existing.mediaId,
          replyToMessageId:
              incoming.replyToMessageId ?? existing.replyToMessageId,
          reactions: incoming.reactions.isNotEmpty
              ? incoming.reactions
              : existing.reactions,
          tipData: incoming.tipData ?? existing.tipData,
          isDeleted: incoming.isDeleted,
          isEdited: incoming.isEdited,
        );
        if (existing.id != incoming.id && existing.id.startsWith('client_')) {
          unawaited(_messageCache.deleteLocalMessage(existing.id));
        }
      }

      final authoritative = list[existingIndex];
      for (var index = list.length - 1; index >= 0; index--) {
        if (index == existingIndex) continue;
        final candidate = list[index];
        final sameIdentity =
            candidate.id == authoritative.id ||
            (authoritative.clientMessageId != null &&
                candidate.clientMessageId == authoritative.clientMessageId) ||
            (authoritative.mediaId != null &&
                candidate.mediaId == authoritative.mediaId);
        final clientDuplicate =
            (candidate.id.startsWith('client_') ||
                authoritative.id.startsWith('client_')) &&
            (candidate.clientMessageId == null ||
                authoritative.clientMessageId == null) &&
            candidate.senderId == authoritative.senderId &&
            candidate.text == authoritative.text &&
            (candidate.type == authoritative.type ||
                (candidate.isAudio && authoritative.isAudio)) &&
            candidate.createdAt.difference(authoritative.createdAt).abs() <=
                const Duration(minutes: 2);
        if (sameIdentity || clientDuplicate) {
          final removed = list.removeAt(index);
          if (removed.id.startsWith('client_')) {
            unawaited(_messageCache.deleteLocalMessage(removed.id));
          }
        }
      }
    } else {
      list.add(incoming);
      isNewMessage = true;
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // The list is sorted after the replacement, so the old index is no
    // longer reliable. Resolve the authoritative message again before
    // caching it or using it for the conversation preview.
    final resolvedIndex = list.indexWhere((message) {
      if (message.id == incoming.id) return true;
      if (incoming.clientMessageId != null &&
          message.clientMessageId == incoming.clientMessageId) {
        return true;
      }
      return incoming.mediaId != null && message.mediaId == incoming.mediaId;
    });
    var messageToCache = resolvedIndex >= 0 ? list[resolvedIndex] : incoming;

    // A receipt can arrive before the REST send response that reveals the
    // server message ID. Apply that buffered status during reconciliation.
    final pendingStatus = _pendingMessageStatuses.remove(messageToCache.id);
    if (pendingStatus != null &&
        messageToCache.status.index < pendingStatus.index &&
        resolvedIndex >= 0) {
      final updated = messageToCache.copyWith(status: pendingStatus);
      list[resolvedIndex] = updated;
      messageToCache = updated;
    }

    _messagesByConversation[incoming.conversationId] = list;
    _messageCache.saveMessage(messageToCache);

    // Update conversation list
    final convIndex = _conversations.indexWhere(
      (c) => c.id == incoming.conversationId,
    );
    if (convIndex != -1) {
      var conv = _conversations[convIndex];

      // Increment unread if new and not current room
      int unreadIncrement = 0;
      if (isNewMessage &&
          incoming.senderId != (_userProvider.user?.id ?? '') &&
          incoming.conversationId != _currentRoomId) {
        unreadIncrement = 1;
      }

      // A message received while its conversation is open has already been
      // seen. Acknowledging it here is important for direct messages,
      // groups, and channels alike; otherwise leaving the screen can leave a
      // stale unread badge until the next full conversation refresh.
      if (isNewMessage &&
          incoming.senderId != (_userProvider.user?.id ?? '') &&
          incoming.conversationId == _currentRoomId) {
        markAsRead(messageToCache.id);
      }

      // Older history/pagination events must not move the conversation tile
      // backwards or replace its preview with an older message.
      if (!incoming.createdAt.isBefore(conv.updatedAt)) {
        _conversations[convIndex] = conv.copyWith(
          lastMessage: messageToCache,
          updatedAt: incoming.createdAt,
          unreadCount: conv.unreadCount + unreadIncrement,
        );
      } else if (unreadIncrement > 0) {
        _conversations[convIndex] = conv.copyWith(
          unreadCount: conv.unreadCount + unreadIncrement,
        );
      }

      // Keep list sorted by recency
      _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } else if (isNewMessage) {
      // If conversation is missing, it might be a new one we haven't loaded yet.
      // We should probably trigger a refresh or handle it if we have enough info.
      loadConversations(force: true);
    }

    notifyListeners();
  }

  Future<void> loadMessages(
    String conversationId, {
    bool refresh = false,
  }) async {
    if (_isLoadingMessages[conversationId] == true) return;

    await _messageCache.initialize();

    final cachedMessages = await _messageCache.getMessages(conversationId);
    final currentMessages =
        _messagesByConversation[conversationId] ?? cachedMessages;
    if (!_messagesByConversation.containsKey(conversationId) &&
        cachedMessages.isNotEmpty) {
      _messagesByConversation[conversationId] = [...cachedMessages]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    }
    String? before;

    if (!refresh && currentMessages.isNotEmpty) {
      // Sort to find the oldest message for pagination
      final sorted = [...currentMessages]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      before = sorted.first.id; // Spec: Use message ID as cursor
    }

    _isLoadingMessages[conversationId] = true;
    notifyListeners();

    try {
      final newMessages = await _apiService.getMessages(
        conversationId,
        before: before,
      );

      for (final msg in newMessages) {
        upsertMessage(msg);
      }

      // Requirement 10: Receipts
      // When we load messages, we might want to mark them as delivered if they were sent to us
      _markIncomingMessagesAsDelivered(conversationId, newMessages);
      // Messages loaded for the active conversation have been seen by the user.
      if (_currentRoomId == conversationId) {
        _markIncomingMessagesAsRead(conversationId, newMessages);
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
    } finally {
      _isLoadingMessages[conversationId] = false;
      notifyListeners();
    }
  }

  void _markIncomingMessagesAsDelivered(
    String conversationId,
    List<ChatMessage> messages,
  ) {
    final currentUserId = _userProvider.user?.id ?? '';
    for (final msg in messages) {
      if (_currentRoomId != conversationId &&
          msg.senderId != currentUserId &&
          msg.status == MessageStatus.sent) {
        markAsDelivered(msg.id);
      }
    }
  }

  void _markIncomingMessagesAsRead(
    String conversationId,
    List<ChatMessage> messages,
  ) {
    final currentUserId = _userProvider.user?.id ?? '';
    for (final msg in messages) {
      if (msg.conversationId == conversationId &&
          msg.senderId != currentUserId &&
          msg.status != MessageStatus.read) {
        markAsRead(msg.id);
      }
    }
  }

  void removeMessageLocally(String conversationId, String messageId) {
    final list = _messagesByConversation[conversationId];
    if (list != null) {
      list.removeWhere((m) => m.id == messageId);
      notifyListeners();
    }
  }

  Future<void> markAsDelivered(String messageId) async {
    await _sendReceipt(messageId, 'delivered');
  }

  Future<void> markAsRead(String messageId) async {
    await _sendReceipt(messageId, 'read');
  }

  Future<void> _sendReceipt(String messageId, String status) async {
    if (messageId.isEmpty) return;

    final targetStatus = status == 'read'
        ? MessageStatus.read
        : MessageStatus.delivered;
    for (final messages in _messagesByConversation.values) {
      final existing = messages
          .where(
            (message) =>
                message.id == messageId || message.clientMessageId == messageId,
          )
          .firstOrNull;
      if (existing != null && existing.status.index >= targetStatus.index) {
        return;
      }
    }

    final requestKey = '$messageId:$status';
    if (!_receiptRequestsInFlight.add(requestKey)) return;

    try {
      await _apiService.markMessageReceipt(messageId, status);
      _updateMessageStatusLocally(messageId, targetStatus);
    } catch (e) {
      debugPrint('Failed to mark message $status: $e');
    } finally {
      _receiptRequestsInFlight.remove(requestKey);
    }
  }

  bool _updateMessageStatusLocally(String messageId, MessageStatus status) {
    bool matched = false;
    bool changed = false;
    String? cid;

    for (final entry in _messagesByConversation.entries) {
      final list = entry.value;
      final index = list.indexWhere(
        (m) => m.id == messageId || m.clientMessageId == messageId,
      );
      if (index != -1) {
        matched = true;
        // Only progress status, don't regress
        if (list[index].status.index < status.index) {
          list[index] = list[index].copyWith(status: status);
          cid = entry.key;
          changed = true;
        }
        break;
      }
    }

    if (changed && cid != null) {
      unawaited(_messageCache.updateMessageStatus(messageId, status));
      // Update last message in conversation list if needed
      final convIndex = _conversations.indexWhere((c) => c.id == cid);
      if (convIndex != -1) {
        final conv = _conversations[convIndex];
        if (conv.lastMessage?.id == messageId) {
          _conversations[convIndex] = conv.copyWith(
            lastMessage: conv.lastMessage?.copyWith(status: status),
          );
        }
      }
      notifyListeners();
    }

    return matched;
  }

  Future<void> deleteMessage(String messageId) async {
    // 1. Identify if it's an optimistic message that hasn't synced yet
    final isOptimistic = messageId.startsWith('client_');

    try {
      if (!isOptimistic) {
        await _apiService.deleteMessage(messageId);
      }
      _markMessageDeletedLocally(messageId);
    } catch (e) {
      debugPrint('Error deleting message: $e');
      // If server says 404, it might have been a client ID or already deleted
      if (e.toString().contains('404')) {
        _markMessageDeletedLocally(messageId);
      } else {
        rethrow;
      }
    }
  }

  Future<void> deleteMessageForMe(String messageId) async {
    await _apiService.deleteMessageForMe(messageId);
    String? conversationId;
    for (final entry in _messagesByConversation.entries) {
      if (entry.value.any((message) => message.id == messageId)) {
        conversationId = entry.key;
        break;
      }
    }
    if (conversationId != null) {
      _messagesByConversation[conversationId]!.removeWhere(
        (message) => message.id == messageId,
      );
    }
    await _messageCache.deleteLocalMessage(messageId);
    notifyListeners();
  }

  void _applyReactionUpdate(Map<String, dynamic> data) {
    final messageId = (data['messageId'] ?? data['message_id'] ?? data['id'])
        ?.toString();
    if (messageId == null || messageId.isEmpty) return;

    final rawReactions = data['reactions'];
    if (rawReactions is! Map) return;

    final reactions = <String, List<String>>{};
    for (final entry in rawReactions.entries) {
      final users = entry.value;
      if (users is List) {
        reactions[entry.key.toString()] = users
            .map((u) => u.toString())
            .toList();
      }
    }

    for (final entry in _messagesByConversation.entries) {
      final list = entry.value;
      final index = list.indexWhere((message) => message.id == messageId);
      if (index != -1) {
        list[index] = list[index].copyWith(reactions: reactions);
        notifyListeners();
        return;
      }
    }
  }

  void _markMessageDeletedLocally(String messageId) {
    bool found = false;
    for (final entry in _messagesByConversation.entries) {
      final list = entry.value;

      // Match by server ID OR client ID
      final index = list.indexWhere(
        (m) => m.id == messageId || m.clientMessageId == messageId,
      );

      if (index != -1) {
        final deletedMessage = list[index].copyWith(
          isDeleted: true,
          text: 'This message was deleted',
          status: MessageStatus.sent, // Clear 'failed' or 'sending' status
        );
        list[index] = deletedMessage;
        unawaited(_messageCache.saveMessage(deletedMessage));

        final conversationIndex = _conversations.indexWhere(
          (conversation) => conversation.id == entry.key,
        );
        if (conversationIndex != -1 &&
            _conversations[conversationIndex].lastMessage != null &&
            (_conversations[conversationIndex].lastMessage!.id == messageId ||
                _conversations[conversationIndex]
                        .lastMessage!
                        .clientMessageId ==
                    messageId)) {
          _conversations[conversationIndex] = _conversations[conversationIndex]
              .copyWith(lastMessage: deletedMessage);
        }
        found = true;
        // Don't break, check other conversations just in case (though unlikely)
      }
    }
    if (found) notifyListeners();
  }

  Future<void> sendMessage(
    String conversationId,
    String content, {
    String? replyToMessageId,
  }) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.length > 4000) {
      throw Exception('Message exceeds 4,000 character limit');
    }

    final currentUserId = _userProvider.user?.id ?? '';
    final clientMsgId = 'client_${_uuid.v4()}';

    final optimisticMessage = ChatMessage(
      id: clientMsgId, // Use client ID as temp ID
      clientMessageId: clientMsgId,
      conversationId: conversationId,
      senderId: currentUserId,
      text: trimmed,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
      replyToMessageId: replyToMessageId,
    );

    upsertMessage(optimisticMessage);

    try {
      final realMessage = await _apiService.sendMessage(
        conversationId: conversationId,
        content: trimmed,
        replyToMessageId: replyToMessageId,
        clientMessageId: clientMsgId,
      );

      // Update with server ID but keep client ID for deduplication
      upsertMessage(realMessage.copyWith(clientMessageId: clientMsgId));
    } catch (e) {
      final list = _messagesByConversation[conversationId] ?? [];
      final index = list.indexWhere((m) => m.clientMessageId == clientMsgId);
      if (index != -1) {
        list[index] = list[index].copyWith(status: MessageStatus.failed);
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> sendMediaMessage({
    required String conversationId,
    required String filePath,
    required MessageType type,
    String? content,
    String? replyToMessageId,
    String? clientMessageId, // Optional for retries
  }) async {
    final currentUserId = _userProvider.user?.id ?? '';
    final clientMsgId = clientMessageId ?? 'client_media_${_uuid.v4()}';

    final String defaultText;
    switch (type) {
      case MessageType.image:
        defaultText = '📷 Image';
        break;
      case MessageType.video:
        defaultText = '🎬 Video';
        break;
      case MessageType.voice:
      case MessageType.audio:
        defaultText = '🎤 Voice Message';
        break;
      default:
        defaultText = '📎 Attachment';
    }

    final optimisticMessage = ChatMessage(
      id: clientMsgId,
      clientMessageId: clientMsgId,
      conversationId: conversationId,
      senderId: currentUserId,
      text: content ?? defaultText,
      type: type,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
      replyToMessageId: replyToMessageId,
      mediaUrl: filePath, // Show local path while uploading
    );

    upsertMessage(optimisticMessage);

    try {
      // 1. Upload
      final Map<String, dynamic> uploadResult = await _mediaApiService
          .uploadMedia(filePath, conversationId: conversationId);

      final String mediaId =
          (uploadResult['id'] ?? uploadResult['mediaId'])?.toString() ?? '';
      final String mediaUrl =
          (uploadResult['mediaUrl'] ?? uploadResult['url'])?.toString() ?? '';

      if (mediaId.isEmpty) {
        throw Exception('Media upload failed: No ID returned');
      }

      // 2. Send Message with mediaId and clientMessageId
      // Backend expects 'video', 'image', or 'audio'
      final String apiMessageType =
          (type == MessageType.voice || type == MessageType.audio)
          ? 'audio'
          : type.name;

      final realMessage = await _apiService.sendMessage(
        conversationId: conversationId,
        content: content ?? '',
        messageType: apiMessageType,
        replyToMessageId: replyToMessageId,
        mediaId: mediaId,
        clientMessageId: clientMsgId,
      );

      // Update with server ID and media URL
      upsertMessage(
        realMessage.copyWith(
          clientMessageId: clientMsgId,
          mediaUrl: mediaUrl.isNotEmpty ? mediaUrl : realMessage.mediaUrl,
        ),
      );
    } catch (e) {
      debugPrint('sendMediaMessage error: $e');
      final list = _messagesByConversation[conversationId] ?? [];
      final index = list.indexWhere((m) => m.clientMessageId == clientMsgId);
      if (index != -1) {
        list[index] = list[index].copyWith(status: MessageStatus.failed);
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> sendContactMessage({
    required String conversationId,
    required String contactName,
    required String contactPhone,
    String? replyToMessageId,
  }) async {
    final currentUserId = _userProvider.user?.id ?? '';
    final clientMsgId = 'client_contact_${_uuid.v4()}';
    // Keep the contact payload structured so names and phone numbers remain
    // unambiguous across devices. The message body is encrypted by the
    // messaging backend like every other message.
    final content = jsonEncode({
      'type': 'contact',
      'name': contactName.trim(),
      'phone': contactPhone.trim(),
    });

    final optimisticMessage = ChatMessage(
      id: clientMsgId,
      clientMessageId: clientMsgId,
      conversationId: conversationId,
      senderId: currentUserId,
      text: content,
      type: MessageType.contact,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
      replyToMessageId: replyToMessageId,
    );

    upsertMessage(optimisticMessage);

    try {
      final realMessage = await _apiService.sendMessage(
        conversationId: conversationId,
        content: content,
        messageType: 'contact',
        replyToMessageId: replyToMessageId,
        clientMessageId: clientMsgId,
      );

      upsertMessage(realMessage.copyWith(clientMessageId: clientMsgId));
    } catch (e) {
      final list = _messagesByConversation[conversationId] ?? [];
      final index = list.indexWhere((m) => m.clientMessageId == clientMsgId);
      if (index != -1) {
        list[index] = list[index].copyWith(status: MessageStatus.failed);
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> retryMessage(ChatMessage message) async {
    if (message.isMedia) {
      await retryMediaMessage(message);
    } else {
      await sendMessage(
        message.conversationId,
        message.text,
        replyToMessageId: message.replyToMessageId,
      );
    }
  }

  Future<void> retryMediaMessage(ChatMessage message) async {
    final filePath = message.mediaUrl;
    if (filePath == null ||
        filePath.isEmpty ||
        !(filePath.startsWith('/') || filePath.startsWith('file://'))) {
      throw Exception(
        'Original file is no longer available. Please select it again.',
      );
    }
    await sendMediaMessage(
      conversationId: message.conversationId,
      filePath: filePath.replaceFirst('file://', ''),
      type: message.type,
      content: message.text.startsWith('📷') || message.text.startsWith('🎬')
          ? null
          : message.text,
      replyToMessageId: message.replyToMessageId,
      clientMessageId: message.clientMessageId,
    );
  }

  // ==========================================================
  // REAL-TIME (SOCKET.IO)
  // ==========================================================

  void _handleRealtimeMessage(dynamic data) {
    if (data is! Map) return;

    final map = Map<String, dynamic>.from(data);
    if (map['type'] == 'reaction_update') {
      _applyReactionUpdate(map);
      return;
    }

    if (map['isDeleted'] == true || map['is_deleted'] == true) {
      final messageId = map['messageId'] ?? map['message_id'] ?? map['id'];
      if (messageId != null) {
        _markMessageDeletedLocally(messageId.toString());
      }
      return;
    }

    final message = ChatMessage.fromJson(map);
    if (message.id.isEmpty || message.conversationId.isEmpty) return;

    upsertMessage(message);

    // A message arriving over Socket.IO is now present on this device. If
    // the conversation is open, it has also been seen; otherwise it is only
    // delivered. The receipt service notifies the sender in real time.
    final currentUserId = _userProvider.user?.id;
    if (currentUserId == null || message.senderId == currentUserId) return;

    if (_currentRoomId == message.conversationId) {
      unawaited(markAsRead(message.id));
    } else {
      unawaited(markAsDelivered(message.id));
    }
  }

  void _handleRealtimeStatus(dynamic data) {
    if (data is! Map) return;

    final messageId = (data['messageId'] ?? data['message_id'])?.toString();
    final statusStr = (data['status'] ?? data['state'])?.toString();
    if (messageId == null || messageId.isEmpty || statusStr == null) return;

    final status = _parseMessageStatus(statusStr);
    final matched = _updateMessageStatusLocally(messageId, status);
    if (!matched) {
      final previous = _pendingMessageStatuses[messageId];
      if (previous == null || status.index > previous.index) {
        _pendingMessageStatuses[messageId] = status;
        if (_pendingMessageStatuses.length > 200) {
          _pendingMessageStatuses.remove(_pendingMessageStatuses.keys.first);
        }
      }
    }
  }

  void initSocket(String accessToken) {
    _initMessageSocket(accessToken);
    _initWalletSocket(accessToken);
  }

  void _initMessageSocket(String accessToken) {
    // If the socket exists, we check if the token has changed.
    // If it has, we must disconnect and recreate it to ensure the new token is used.
    if (_socket != null) {
      final currentToken = _socket!.io.options?['auth']?['token'];
      if (currentToken != accessToken) {
        debugPrint('Socket: Token changed, reconnecting...');
        disconnectSocket();
      } else {
        if (!_socket!.connected) {
          _socket!.connect();
        }
        return;
      }
    }

    final socketUrl =
        '${ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '').replaceFirst(RegExp(r'/+$'), '')}/messages';

    debugPrint('Socket: Initializing for $socketUrl');

    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': accessToken})
          .setExtraHeaders({'Authorization': 'Bearer $accessToken'})
          .enableReconnection()
          .setReconnectionAttempts(double.infinity)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(10000)
          .enableAutoConnect()
          .build(),
    );

    _socket?.onConnect((_) async {
      debugPrint('Socket: Connected to /messages');
      _presenceHeartbeat?.cancel();
      _presenceHeartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
        _socket?.emit('presence_heartbeat');
      });

      // Capture the room before refreshes. A failed refresh must not prevent
      // rejoining the open conversation after a reconnect.
      final roomId = _currentRoomId;
      try {
        await loadConversations(force: true);
        await loadFriends();
      } finally {
        if (roomId != null && _socket?.connected == true) {
          _joinSocketConversation(roomId);
          unawaited(loadMessages(roomId, refresh: true));
        }
      }
    });

    _socket?.onConnectError(
      (data) => debugPrint('Socket: /messages Connect Error: $data'),
    );
    _socket?.onReconnectError(
      (data) => debugPrint('Socket: /messages Reconnect Error: $data'),
    );
    _socket?.onError((data) => debugPrint('Socket: /messages Error: $data'));

    _socket?.onDisconnect((_) {
      debugPrint('Socket: Disconnected');
      _presenceHeartbeat?.cancel();
      _presenceHeartbeat = null;
    });

    _socket?.on('presence_snapshot', (data) {
      debugPrint('Socket: presence_snapshot');
      final rawIds = data is List
          ? data
          : data is Map && data['userIds'] is List
          ? data['userIds'] as List
          : data is Map && data['user_ids'] is List
          ? data['user_ids'] as List
          : const <dynamic>[];
      final ids = rawIds.map((id) => id.toString()).toSet();

      _presenceMap.clear();

      for (final id in ids) {
        _presenceMap[id] = true;
      }

      _presenceInitialized = true;
      notifyListeners();
    });

    _socket?.on('incoming_call', (data) {
      if (data is Map) {
        debugPrint('Socket: incoming_call');
        _incomingCallHandler?.call(Map<String, dynamic>.from(data));
      }
    });

    void emitCampfireEvent(String type, dynamic raw) {
      final payload = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      payload['type'] = type;
      if (!_campfireEventController.isClosed) {
        _campfireEventController.add(payload);
      }
    }

    _socket?.on('campfire_created', (data) {
      emitCampfireEvent('campfire_created', data);
      campfireRevision++;
      notifyListeners();
    });
    _socket?.on('campfire_participants_changed', (data) {
      emitCampfireEvent('campfire_participants_changed', data);
      campfireRevision++;
      notifyListeners();
    });
    _socket?.on('campfire_speaker_requested', (data) {
      emitCampfireEvent('campfire_speaker_requested', data);
      campfireRevision++;
      notifyListeners();
    });
    _socket?.on('campfire_ended', (data) {
      emitCampfireEvent('campfire_ended', data);
      if (data is Map) {
        lastEndedCampfireId =
            (data['spaceId'] ?? data['space_id'] ?? data['campfireId'])?.toString();
      }
      campfireRevision++;
      notifyListeners();
    });

    _socket?.on('presence_updated', (data) {
      if (data is! Map) {
        return;
      }

      final userId = (data['userId'] ?? data['user_id'])?.toString();
      if (userId == null || userId.isEmpty) {
        return;
      }

      _presenceMap[userId] =
          data['isOnline'] == true || data['is_online'] == true;
      notifyListeners();
    });

    _socket?.on('message_received', (data) {
      debugPrint('Socket: message_received');
      _handleRealtimeMessage(data);
    });

    _socket?.on('new_message', (data) {
      debugPrint('Socket: new_message');
      _handleRealtimeMessage(data);
    });

    _socket?.on('message', (data) {
      debugPrint('Socket: message');
      _handleRealtimeMessage(data);
    });

    _socket?.on('conversation_updated', (data) {
      debugPrint('Socket: conversation_updated');
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        // autoritative message creation is now exclusively from 'message_received'
        // or when payload specifically contains a full message structure.
        if (map.containsKey('id') && map.containsKey('content')) {
          upsertMessage(ChatMessage.fromJson(map));
        } else {
          loadConversations(force: true);
        }
      }
    });

    _socket?.on('conversation_settings_updated', (data) {
      debugPrint('Socket: conversation_settings_updated');
      // Metadata changes (lock state, title, avatar, visibility) are pushed
      // immediately by the server. Refresh the lightweight conversation list
      // so every open list/header reflects the authoritative value without
      // requiring a screen reopen.
      unawaited(loadConversations(force: true));
      notifyListeners();
    });

    _socket?.on('message_sent', (data) {
      debugPrint('Socket: message_sent');
      _handleRealtimeMessage(data);
    });

    _socket?.on('message_status_updated', (data) {
      debugPrint('Socket: message_status_updated');
      _handleRealtimeStatus(data);
    });

    _socket?.on('status_updated', (data) {
      debugPrint('Socket: status_updated');
      _handleRealtimeStatus(data);
    });

    _socket?.on('call_status_updated', (data) {
      if (data is Map && !_callStatusController.isClosed) {
        debugPrint('Socket: call_status_updated');
        _callStatusController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket?.on('message_receipt_updated', (data) {
      debugPrint('Socket: message_receipt_updated');
      _handleRealtimeStatus(data);
    });

    _socket?.on('user_typing', (data) {
      final String? conversationId = data['conversationId']?.toString();
      final String? userId = data['userId']?.toString();
      final bool isTyping = data['isTyping'] == true;

      if (conversationId != null && userId != null) {
        final currentUserId = _userProvider.user?.id;
        if (userId == currentUserId) {
          return;
        }

        final users = _typingUsers[conversationId] ?? {};
        if (isTyping) {
          users.add(userId);
        } else {
          users.remove(userId);
        }
        _typingUsers[conversationId] = users;
        notifyListeners();
      }
    });

    _socket?.on('message_reaction_updated', (data) {
      if (data is Map) {
        _applyReactionUpdate(Map<String, dynamic>.from(data));
      }
    });

    _socket?.on('message_deleted', (data) {
      debugPrint('Socket: message_deleted');
      final String? messageId = data['messageId']?.toString();
      if (messageId != null) {
        _markMessageDeletedLocally(messageId);
      }
    });

    // ==========================================================
    // CHANNEL EVENTS
    // ==========================================================

    _socket?.on('channel_post_created', (data) {
      debugPrint('Socket: channel_post_created');
      final post = ChatMessage.fromJson(Map<String, dynamic>.from(data));
      final list = _channelPosts[post.conversationId] ?? [];
      if (!list.any((p) => p.id == post.id)) {
        _channelPosts[post.conversationId] = [post, ...list];
        notifyListeners();
      }
    });

    _socket?.on('channel_comment_created', (data) {
      debugPrint('Socket: channel_comment_created');
      if (data is! Map) return;
      final comment = Map<String, dynamic>.from(data);
      final postId = (comment['postId'] ?? comment['post_id'])?.toString();
      if (postId != null) {
        final list = _postComments[postId] ?? [];
        final commentId = (comment['id'] ?? comment['comment_id'])?.toString();
        if (commentId != null &&
            !list.any((c) => c['id']?.toString() == commentId)) {
          comment['postId'] = postId;
          _postComments[postId] = [...list, comment];
          notifyListeners();
        }
      }
    });

    _socket?.on('channel_comment_deleted', (data) {
      debugPrint('Socket: channel_comment_deleted');
      if (data is! Map) return;
      final map = Map<String, dynamic>.from(data);
      final postId = (map['postId'] ?? map['post_id'])?.toString();
      final commentId = (map['commentId'] ?? map['comment_id'])?.toString();
      if (postId == null || commentId == null) return;
      final list = _postComments[postId];
      if (list == null) return;
      list.removeWhere((comment) => comment['id']?.toString() == commentId);
      notifyListeners();
    });

    // ==========================================================
    // MESSAGE REQUEST EVENTS
    // ==========================================================

    _socket?.on('message_request_created', (data) {
      debugPrint('Socket: message_request_created');
      final request = MessageRequest.fromJson(Map<String, dynamic>.from(data));
      _handleRequestReceived(request);
    });

    _socket?.on('message_request_received', (data) {
      debugPrint('Socket: message_request_received');
      final request = MessageRequest.fromJson(Map<String, dynamic>.from(data));
      _handleRequestReceived(request);
    });

    _socket?.on('message_request_accepted', (data) {
      debugPrint('Socket: message_request_accepted');
      if (data is! Map) {
        return;
      }

      // The backend broadcasts the full acceptance result:
      // { request: {...}, conversation: {...} }.
      // Older clients expected the request object directly, so unwrap the
      // nested request while retaining the conversation for an immediate UI
      // update.
      final payload = Map<String, dynamic>.from(data);
      final requestJson = payload['request'] is Map
          ? Map<String, dynamic>.from(payload['request'])
          : payload;
      final request = MessageRequest.fromJson(requestJson);
      _handleRequestAccepted(request);

      final conversationJson = payload['conversation'];
      if (conversationJson is Map) {
        final conversation = Conversation.fromJson(
          Map<String, dynamic>.from(conversationJson),
        );
        if (!_conversations.any((c) => c.id == conversation.id)) {
          _conversations.insert(0, conversation);
          notifyListeners();
        }
      }
    });

    _socket?.on('message_request_declined', (data) {
      debugPrint('Socket: message_request_declined');
      final request = MessageRequest.fromJson(Map<String, dynamic>.from(data));
      _handleRequestDeclined(request);
    });

    _socket?.on('message_request_withdrawn', (data) {
      debugPrint('Socket: message_request_withdrawn');
      final request = MessageRequest.fromJson(Map<String, dynamic>.from(data));
      _handleRequestWithdrawn(request);
    });

    _socket?.on('tip_received', (data) {
      debugPrint('Socket: tip_received');
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        _handleTipReceived(map);
        _tipReceivedController.add(map);
      }
    });
  }

  void _handleTipReceived(Map<String, dynamic> data) {
    // 1. Refresh global state
    loadWalletActivity();

    // 2. Refresh wallet provider if available
    // Note: MessagingProvider doesn't have direct access to WalletProvider,
    // but the WalletSocket 'wallet_updated' event usually handles this.
    // However, for immediate feedback, we ensure activity is fresh.

    // 3. UI Notification trigger (handled in UI via listener if needed,
    // or we can use a global notification event stream)

    notifyListeners();
  }

  void _initWalletSocket(String accessToken) {
    if (_walletSocket != null) {
      final currentToken = _walletSocket!.io.options?['auth']?['token'];
      if (currentToken != accessToken) {
        _walletSocket!.disconnect();
        _walletSocket!.dispose();
        _walletSocket = null;
      } else {
        if (!_walletSocket!.connected) {
          _walletSocket!.connect();
        }
        return;
      }
    }

    final walletSocketUrl =
        '${ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '').replaceFirst(RegExp(r'/+$'), '')}/wallet';

    debugPrint('Socket: Initializing wallet socket for $walletSocketUrl');

    _walletSocket = io.io(
      walletSocketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': accessToken})
          .setExtraHeaders({'Authorization': 'Bearer $accessToken'})
          .enableAutoConnect()
          .build(),
    );

    _walletSocket?.onConnect((_) {
      debugPrint('Socket: Connected to /wallet');
    });

    _walletSocket?.onConnectError(
      (data) => debugPrint('Socket: /wallet Connect Error: $data'),
    );
    _walletSocket?.onReconnectError(
      (data) => debugPrint('Socket: /wallet Reconnect Error: $data'),
    );
    _walletSocket?.onError(
      (data) => debugPrint('Socket: /wallet Error: $data'),
    );

    _walletSocket?.on('wallet_updated', (data) {
      debugPrint('Socket: wallet_updated - refreshing activity');

      final activity = data['activity'];
      if (activity != null) {
        final fromUser = activity['fromUser'];
        if (fromUser != null) {
          _tipReceivedController.add({
            'senderName':
                fromUser['displayName'] ?? fromUser['username'] ?? 'Griot User',
            'amount': activity['value']?.toString() ?? '',
            'asset': activity['asset']?.toString() ?? '',
            'senderUserId': fromUser['id'],
          });
        }
      }

      refreshNotifications();
    });

    _walletSocket?.onDisconnect(
      (_) => debugPrint('Socket: Wallet disconnected'),
    );
  }

  void disconnectSocket() {
    _presenceHeartbeat?.cancel();
    _presenceHeartbeat = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    _walletSocket?.disconnect();
    _walletSocket?.dispose();
    _walletSocket = null;
  }

  Future<void> clearState() async {
    disconnectSocket();

    _messagesByConversation.clear();
    _isLoadingMessages.clear();
    _conversations = [];
    _isLoadingConversations = false;
    _lastConversationsLoadedAt = null;
    _conversationsLoadFuture = null;

    _receivedRequests = [];
    _sentRequests = [];
    _isLoadingRequests = false;

    _friends = [];
    _friendRequestInFlight.clear();
    _isLoadingFriends = false;
    _friendsTotal = 0;
    _hasMoreFriends = false;
    _friendsOffset = 0;
    _currentFriendsSearchQuery = null;
    _isLoadingMoreFriends = false;

    _discoveredGroups = [];
    _discoveredChannels = [];
    _isSearchingGroups = false;
    _isSearchingChannels = false;

    _blockedUserIds = [];
    _isLoadingBlocks = false;

    _presenceMap.clear();
    _walletActivities = [];
    _walletNextPageKey = null;
    _isLoadingWalletActivity = false;
    _isLoadingMoreWalletActivity = false;

    _tipConfig = null;
    _isLoadingTipConfig = false;

    _lastSeenNotificationTime = null;
    _currentRoomId = null;
    _typingUsers.clear();

    _channelPosts.clear();
    _isLoadingPosts.clear();
    _postComments.clear();
    _isLoadingComments.clear();

    await _messageCache.wipe();

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      _localCache.remove(_friendsCacheKey),
      _localCache.remove(_receivedRequestsCacheKey),
      _localCache.remove(_sentRequestsCacheKey),
      _localCache.remove(_notificationsCacheKey),
      prefs.remove(_pinnedConversationsKey),
      prefs.remove('last_seen_notification_time'),
    ]);

    notifyListeners();
  }

  void _handleRequestReceived(MessageRequest request) {
    // Add to received requests if not already there
    final index = _receivedRequests.indexWhere((r) => r.id == request.id);
    if (index == -1) {
      _receivedRequests.insert(0, request);
    } else {
      _receivedRequests[index] = request;
    }
    _recordLiveNotification();
    unawaited(loadGenericNotifications(refresh: true));
    notifyListeners();
  }

  void _recordLiveNotification() {
    _liveNotificationTimes.add(DateTime.now());
    if (_liveNotificationTimes.length > 200) {
      _liveNotificationTimes.removeRange(
        0,
        _liveNotificationTimes.length - 200,
      );
    }
    // The chat-home bell listens to this provider.  Realtime events can land
    // before the activity-feed refresh completes, so publish the badge change
    // immediately instead of waiting for the REST response.
    notifyListeners();
  }

  void _handleRequestAccepted(MessageRequest request) {
    // Update status in received/sent lists instead of removing
    final rIndex = _receivedRequests.indexWhere((r) => r.id == request.id);
    if (rIndex != -1) {
      _receivedRequests[rIndex] = request.copyWith(
        status: RequestStatus.accepted,
        respondedAt: DateTime.now(),
      );
    }
    final sIndex = _sentRequests.indexWhere((r) => r.id == request.id);
    if (sIndex != -1) {
      _sentRequests[sIndex] = request.copyWith(
        status: RequestStatus.accepted,
        respondedAt: DateTime.now(),
      );
    }

    // Refresh friends and conversations since a new friendship/DM is created
    loadFriends();
    loadConversations();

    _recordLiveNotification();
    unawaited(loadGenericNotifications(refresh: true));

    notifyListeners();
  }

  void _handleRequestDeclined(MessageRequest request) {
    final rIndex = _receivedRequests.indexWhere((r) => r.id == request.id);
    if (rIndex != -1) {
      _receivedRequests[rIndex] = request.copyWith(
        status: RequestStatus.declined,
        respondedAt: DateTime.now(),
      );
    }
    final sIndex = _sentRequests.indexWhere((r) => r.id == request.id);
    if (sIndex != -1) {
      _sentRequests[sIndex] = request.copyWith(
        status: RequestStatus.declined,
        respondedAt: DateTime.now(),
      );
    }
    _recordLiveNotification();
    unawaited(loadGenericNotifications(refresh: true));
    notifyListeners();
  }

  void _handleRequestWithdrawn(MessageRequest request) {
    final rIndex = _receivedRequests.indexWhere((r) => r.id == request.id);
    if (rIndex != -1) {
      _receivedRequests[rIndex] = request.copyWith(
        status: RequestStatus.withdrawn,
        respondedAt: DateTime.now(),
      );
    }
    final sIndex = _sentRequests.indexWhere((r) => r.id == request.id);
    if (sIndex != -1) {
      _sentRequests[sIndex] = request.copyWith(
        status: RequestStatus.withdrawn,
        respondedAt: DateTime.now(),
      );
    }
    _recordLiveNotification();
    unawaited(loadGenericNotifications(refresh: true));
    notifyListeners();
  }

  void setTyping(String conversationId, bool isTyping) {
    _socket?.emit(isTyping ? 'typing_start' : 'typing_stop', {
      'conversationId': conversationId,
    });
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    final currentUserId = _userProvider.user?.id;
    if (currentUserId == null) {
      return;
    }

    // Check if we already have this reaction from this user
    bool alreadyReacted = false;
    for (final entry in _messagesByConversation.values) {
      final msg = entry.where((m) => m.id == messageId).firstOrNull;
      if (msg != null) {
        if (msg.reactions.containsKey(emoji) &&
            msg.reactions[emoji]!.contains(currentUserId)) {
          alreadyReacted = true;
        }
        break;
      }
    }

    try {
      if (alreadyReacted) {
        await _apiService.removeReaction(messageId, emoji);
      } else {
        await _apiService.toggleReaction(messageId, emoji);
      }
      // Local update will happen via socket event 'message_reaction_updated'
    } catch (e) {
      debugPrint('Failed to toggle reaction: $e');
    }
  }

  void joinConversation(String conversationId) {
    _currentRoomId = conversationId;

    if (_socket?.connected == true) {
      _joinSocketConversation(conversationId);
    }

    // Reset unread count locally
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversations[index] = _conversations[index].copyWith(unreadCount: 0);

      // Mark existing messages as read
      final messages = _messagesByConversation[conversationId] ?? [];
      _markIncomingMessagesAsRead(conversationId, messages);

      notifyListeners();
    }
  }

  /// The conversation currently open in the chat UI, if any.
  String? get activeConversationId => _currentRoomId;

  void leaveConversation(String conversationId) {
    if (_socket?.connected == true) {
      _socket?.emit('leave_conversation', {'conversationId': conversationId});
    }
    _currentRoomId = null;
  }

  void _joinSocketConversation(String conversationId) {
    final socket = _socket;
    if (socket?.connected != true || conversationId.trim().isEmpty) return;

    socket!.emitWithAck(
      'join_conversation',
      {'conversationId': conversationId},
      ack: (response, [extra]) {
        final result = response is Map
            ? Map<String, dynamic>.from(response)
            : <String, dynamic>{};
        if (result['success'] == true) {
          debugPrint('Socket: Joined conversation $conversationId');
        } else {
          debugPrint(
            'Socket: Conversation join rejected for $conversationId: '
            '${result['message'] ?? 'unknown error'}',
          );
        }
      },
    );
  }

  void clearSearchResults() {
    notifyListeners();
  }

  MessageStatus _parseMessageStatus(String status) {
    switch (status.toLowerCase()) {
      case 'read':
      case 'seen':
        return MessageStatus.read;
      case 'delivered':
      case 'received':
        return MessageStatus.delivered;
      case 'sent':
      case 'pending':
      case 'accepted':
        return MessageStatus.sent;
      case 'failed':
      case 'error':
        return MessageStatus.failed;
      default:
        return MessageStatus.sending;
    }
  }

  Future<Conversation> createGroup({
    required String name,
    List<String> memberIds = const [],
    String visibility = 'public',
    bool messagesLocked = false,
    String? username,
    String? description,
  }) async {
    final conversation = await _apiService.createGroup(
      name: name,
      memberIds: memberIds,
      visibility: visibility,
      messagesLocked: messagesLocked,
      username: username,
      description: description,
    );
    _conversations.removeWhere((item) => item.id == conversation.id);
    _conversations.insert(0, conversation);
    _lastConversationsLoadedAt = DateTime.now();
    notifyListeners();
    return conversation;
  }

  // ==========================================================
  // ACTIONS - CHANNELS
  // ==========================================================

  Future<void> loadChannelPosts(String conversationId) async {
    _isLoadingPosts[conversationId] = true;
    notifyListeners();

    try {
      final posts = await _apiService.getChannelPosts(conversationId);
      _channelPosts[conversationId] = posts;
    } catch (e) {
      debugPrint('Error loading channel posts: $e');
    } finally {
      _isLoadingPosts[conversationId] = false;
      notifyListeners();
    }
  }

  Future<void> createChannelPost(
    String conversationId,
    String content, {
    String? mediaId,
  }) async {
    try {
      final post = await _apiService.createChannelPost(
        conversationId,
        content,
        mediaId: mediaId,
      );
      final list = _channelPosts[conversationId] ?? [];
      if (!list.any((item) => item.id == post.id)) {
        _channelPosts[conversationId] = [post, ...list];
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error creating channel post: $e');
      rethrow;
    }
  }

  Future<void> sendChannelMediaPost({
    required String conversationId,
    required String filePath,
    required MessageType type,
    String? content,
  }) async {
    try {
      // 1. Upload
      final Map<String, dynamic> uploadResult = await _mediaApiService
          .uploadMedia(filePath, conversationId: conversationId);
      final String mediaId = uploadResult['id']?.toString() ?? '';

      // 2. Create Post
      await createChannelPost(conversationId, content ?? '', mediaId: mediaId);
    } catch (e) {
      debugPrint('Error sending channel media post: $e');
      rethrow;
    }
  }

  Future<void> loadPostComments(String conversationId, String postId) async {
    _isLoadingComments[postId] = true;
    notifyListeners();

    try {
      final comments = await _apiService.getChannelComments(
        conversationId,
        postId,
      );
      _postComments[postId] = comments;
    } catch (e) {
      debugPrint('Error loading post comments: $e');
    } finally {
      _isLoadingComments[postId] = false;
      notifyListeners();
    }
  }

  Future<void> submitChannelComment({
    required String conversationId,
    required String postId,
    required String content,
    String? replyToCommentId,
  }) async {
    try {
      final comment = await _apiService.createChannelComment(
        conversationId: conversationId,
        postId: postId,
        content: content,
        replyToCommentId: replyToCommentId,
      );

      final list = _postComments[postId] ?? [];
      if (!list.any(
        (item) => item['id']?.toString() == comment['id']?.toString(),
      )) {
        _postComments[postId] = [...list, comment];
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error submitting channel comment: $e');
      rethrow;
    }
  }

  Future<void> deleteChannelComment(
    String conversationId,
    String postId,
    String commentId,
  ) async {
    try {
      await _apiService.deleteChannelComment(conversationId, postId, commentId);
      final list = _postComments[postId];
      if (list != null) {
        list.removeWhere((c) => c['id']?.toString() == commentId.toString());
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error deleting channel comment: $e');
      rethrow;
    }
  }

  Future<Conversation> createChannel({
    required String name,
    required String username,
    String? description,
    String? imageUrl,
    String visibility = 'public',
    bool commentsLocked = false,
  }) async {
    final conversation = await _apiService.createChannel(
      name: name,
      username: username,
      description: description,
      imageUrl: imageUrl,
      visibility: visibility,
      commentsLocked: commentsLocked,
    );
    _conversations.removeWhere((item) => item.id == conversation.id);
    _conversations.insert(0, conversation);
    _lastConversationsLoadedAt = DateTime.now();
    notifyListeners();
    return conversation;
  }

  Future<void> addGroupMember(String conversationId, String userId) async {
    await _apiService.addGroupMember(conversationId, userId);
    await loadConversations(force: true);
  }

  Future<void> removeGroupMember(String conversationId, String userId) async {
    await _apiService.removeGroupMember(conversationId, userId);
    await loadConversations(force: true);
  }

  Future<void> updateGroupMemberRole(
    String conversationId,
    String userId,
    String role,
  ) async {
    await _apiService.updateGroupMemberRole(conversationId, userId, role);
    notifyListeners();
  }

  Future<void> leaveGroup(String conversationId) async {
    await _apiService.leaveGroup(conversationId);
    _conversations.removeWhere((c) => c.id == conversationId);
    notifyListeners();
  }

  Future<void> deleteConversation(String conversationId) async {
    await _apiService.deleteConversation(conversationId);
    _conversations.removeWhere((c) => c.id == conversationId);
    await _messageCache.deleteConversation(conversationId);
    notifyListeners();
  }

  Future<void> clearGroupMessages(String conversationId) async {
    await _apiService.clearGroupMessages(conversationId);
    _messagesByConversation[conversationId] = [];
    await _messageCache.deleteMessages(conversationId);
    notifyListeners();
  }

  Future<void> updateGroup(
    String conversationId, {
    String? name,
    String? description,
    String? imageUrl,
    String? visibility,
    bool? messagesLocked,
    String? username,
  }) async {
    final conversation = await _apiService.updateGroup(
      conversationId,
      name: name,
      description: description,
      imageUrl: imageUrl,
      visibility: visibility,
      messagesLocked: messagesLocked,
      username: username,
    );
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversations[index] = conversation;
      notifyListeners();
    }
  }

  Future<void> updateChannel(
    String conversationId, {
    String? name,
    String? description,
    String? imageUrl,
    String? visibility,
    String? username,
    bool? commentsLocked,
  }) async {
    final conversation = await _apiService.updateChannel(
      conversationId,
      name: name,
      description: description,
      imageUrl: imageUrl,
      visibility: visibility,
      username: username,
      commentsLocked: commentsLocked,
    );
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversations[index] = conversation;
      notifyListeners();
    }
  }

  Future<void> deleteChannel(String conversationId) async {
    await _apiService.deleteChannel(conversationId);
    _conversations.removeWhere((c) => c.id == conversationId);
    notifyListeners();
  }

  Future<void> removeChannelMember(
    String conversationId,
    String memberId,
  ) async {
    await _apiService.removeChannelMember(conversationId, memberId);
    await loadConversations(force: true);
  }

  Future<void> addChannelAdmin(String conversationId, String userId) async {
    await _apiService.addChannelAdmin(conversationId, userId);
    notifyListeners();
  }

  Future<void> removeChannelAdmin(String conversationId, String userId) async {
    await _apiService.removeChannelAdmin(conversationId, userId);
    notifyListeners();
  }

  Future<void> subscribeToChannel(String conversationId) async {
    try {
      await _apiService.subscribeToChannel(conversationId);
      // Immediately update local status if possible, then refresh
      _updateConversationStatus(conversationId, 'active', 'member');
      await loadConversations(force: true);
    } catch (e) {
      debugPrint('Failed to subscribe: $e');
      rethrow;
    }
  }

  Future<void> joinPublicGroup(String conversationId) async {
    try {
      await _apiService.joinPublicGroup(conversationId);
      _updateConversationStatus(conversationId, 'active', 'member');
      await loadConversations(force: true);
    } catch (e) {
      debugPrint('Failed to join group: $e');
      rethrow;
    }
  }

  Future<MessageRequest> requestToJoinConversation({
    required String ownerId,
    required String conversationId,
    required String requestType,
  }) {
    return _apiService.requestToJoinConversation(
      ownerId: ownerId,
      conversationId: conversationId,
      requestType: requestType,
    );
  }

  Future<void> unsubscribeFromChannel(String conversationId) async {
    try {
      await _apiService.unsubscribeFromChannel(conversationId);
      _conversations.removeWhere(
        (conversation) => conversation.id == conversationId,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to unsubscribe: $e');
      rethrow;
    }
  }

  void _updateConversationStatus(String id, String status, String? role) {
    final index = _conversations.indexWhere((c) => c.id == id);
    if (index != -1) {
      _conversations[index] = _conversations[index].copyWith(
        status: status,
        role: role,
      );
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> getGroupMembers(
    String conversationId,
  ) async {
    try {
      return await _apiService.getGroupMembers(conversationId);
    } catch (e) {
      debugPrint('Error getting group members: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getChannelMembers(
    String conversationId,
  ) async {
    try {
      return await _apiService.getChannelMembers(conversationId);
    } catch (e) {
      debugPrint('Error getting channel members: $e');
      return [];
    }
  }

  Future<void> removeFriend(String userId) async {
    try {
      await _apiService.removeFriend(userId);
      _friends.removeWhere((f) => f.id == userId);
      notifyListeners();

      // Refresh state to ensure lists are in sync
      await loadConversations();
    } catch (e) {
      debugPrint('Error removing friend: $e');
      rethrow;
    }
  }

  // ==========================================================
  // DISCOVERY
  // ==========================================================

  Future<void> discoverGroups(String query, {bool refresh = true}) async {
    if (query.length < 3) {
      _discoveredGroups = [];
      _groupsPage = 1;
      _hasMoreGroups = false;
      notifyListeners();
      return;
    }

    if (refresh) {
      _isSearchingGroups = true;
      _groupsPage = 1;
    } else {
      if (_isLoadingMoreGroups || !_hasMoreGroups) return;
      _isLoadingMoreGroups = true;
    }
    notifyListeners();

    try {
      final results = await _apiService.discoverGroups(
        query,
        page: _groupsPage,
        limit: 20,
      );

      if (refresh) {
        _discoveredGroups = results;
      } else {
        _discoveredGroups.addAll(results);
      }

      _hasMoreGroups = results.length >= 20;
      if (_hasMoreGroups) _groupsPage++;
    } catch (e) {
      debugPrint('Error discovering groups: $e');
      if (refresh) _discoveredGroups = [];
      rethrow;
    } finally {
      _isSearchingGroups = false;
      _isLoadingMoreGroups = false;
      notifyListeners();
    }
  }

  Future<void> discoverChannels(String query, {bool refresh = true}) async {
    if (query.length < 3) {
      _discoveredChannels = [];
      _channelsPage = 1;
      _hasMoreChannels = false;
      notifyListeners();
      return;
    }

    if (refresh) {
      _isSearchingChannels = true;
      _channelsPage = 1;
    } else {
      if (_isLoadingMoreChannels || !_hasMoreChannels) return;
      _isLoadingMoreChannels = true;
    }
    notifyListeners();

    try {
      final results = await _apiService.discoverChannels(
        query,
        page: _channelsPage,
        limit: 20,
      );

      if (refresh) {
        _discoveredChannels = results;
      } else {
        _discoveredChannels.addAll(results);
      }

      _hasMoreChannels = results.length >= 20;
      if (_hasMoreChannels) _channelsPage++;
    } catch (e) {
      debugPrint('Error discovering channels: $e');
      if (refresh) _discoveredChannels = [];
      rethrow;
    } finally {
      _isSearchingChannels = false;
      _isLoadingMoreChannels = false;
      notifyListeners();
    }
  }

  // ==========================================================
  // RESOLVE USERNAME (DEEP LINKS)
  // ==========================================================

  Future<Conversation> resolveConversationByUsername(
    String username,
    ConversationType type,
  ) async {
    try {
      if (type == ConversationType.group) {
        return await _apiService.getGroupByUsername(username);
      } else if (type == ConversationType.channel) {
        return await _apiService.getChannelByUsername(username);
      } else {
        throw Exception('Invalid conversation type for username resolution');
      }
    } catch (e) {
      debugPrint('Error resolving username: $e');
      rethrow;
    }
  }
}
