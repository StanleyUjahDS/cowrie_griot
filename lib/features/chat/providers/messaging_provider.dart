import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_config.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../models/conversation_model.dart';
import '../models/message_request.dart';
import '../services/messaging_api_service.dart';
import '../services/media_api_service.dart';
import '../services/tip_api_service.dart';
import '../services/message_cache_service.dart';
import '../services/message_sync_service.dart';
import '../../users/models/user_model.dart';
import '../../users/providers/user_provider.dart';
import '../../miner/services/mining_api_service.dart';
import '../../wallet/services/transaction_api_service.dart';
import '../../wallet/services/wallet_service.dart';
import '../../wallet/services/wallet_rpc_service.dart';

enum RelationshipState { none, pendingSent, pendingReceived, friends, blocked }

class MessagingProvider extends ChangeNotifier {
  final MessagingApiService _apiService;
  final MediaApiService _mediaApiService;
  final UserProvider _userProvider;
  final MessageCacheService _messageCache;
  final MessageSyncService _messageSync;
  final MiningApiService _miningApi;
  final TransactionApiService _transactionApi;
  final TipApiService _tipApi;
  final WalletService _walletService;
  final WalletRpcService _walletRpc;

  MessagingProvider({
    required MessagingApiService apiService,
    required MediaApiService mediaApiService,
    required UserProvider userProvider,
    required MessageCacheService messageCache,
    required MessageSyncService messageSync,
    required MiningApiService miningApi,
    required TransactionApiService transactionApi,
    required TipApiService tipApi,
    required WalletService walletService,
    required WalletRpcService walletRpc,
  }) : _apiService = apiService,
       _mediaApiService = mediaApiService,
       _userProvider = userProvider,
       _messageCache = messageCache,
       _messageSync = messageSync,
       _miningApi = miningApi,
       _transactionApi = transactionApi,
       _tipApi = tipApi,
       _walletService = walletService,
       _walletRpc = walletRpc {
    _loadActivitySeenTime();
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    disconnectSocket();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  // ==========================================================
  // STATE
  // ==========================================================

  final Map<String, List<ChatMessage>> _messagesByConversation = {};
  final Map<String, bool> _isLoadingMessages = {};

  List<Conversation> _conversations = [];
  bool _isLoadingConversations = false;
  DateTime? _lastConversationsLoadedAt;
  Future<void>? _conversationsLoadFuture;

  List<MessageRequest> _receivedRequests = [];
  List<MessageRequest> _sentRequests = [];
  bool _isLoadingRequests = false;

  List<UserModel> _friends = [];
  final Set<String> _friendRequestInFlight = <String>{};
  bool _isLoadingFriends = false;
  int _friendsTotal = 0;
  bool _hasMoreFriends = false;
  int _friendsOffset = 0;
  String? _currentFriendsSearchQuery;
  bool _isLoadingMoreFriends = false;

  List<String> _blockedUserIds = [];
  bool _isLoadingBlocks = false;

  final Map<String, bool> _presenceMap = {};
  Map<String, bool> get presenceMap => _presenceMap;

  Map<String, dynamic>? _tipConfig;
  bool _isLoadingTipConfig = false;

  DateTime? _lastSeenActivityTime;
  DateTime? get lastSeenActivityTime => _lastSeenActivityTime;

  // Real-time
  io.Socket? _socket;
  io.Socket? _walletSocket;
  String? _currentRoomId;
  final Map<String, Set<String>> _typingUsers = {};

  // ==========================================================
  // GETTERS
  // ==========================================================

  List<Conversation> get conversations => _conversations;
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

  List<String> get blockedUserIds => _blockedUserIds;
  bool get isLoadingBlocks => _isLoadingBlocks;

  Map<String, dynamic>? get tipConfig => _tipConfig;
  bool get isLoadingTipConfig => _isLoadingTipConfig;

  int get pendingRequestCount =>
      _receivedRequests.where((r) => r.status == RequestStatus.pending).length;

  // Activity Logic
  List<MessageRequest> get activityItems {
    final list = [
      ..._receivedRequests,
      ..._sentRequests.where((r) => r.status != RequestStatus.pending),
    ];
    list.sort((a, b) {
      final timeA = a.respondedAt ?? a.createdAt;
      final timeB = b.respondedAt ?? b.createdAt;
      return timeB.compareTo(timeA);
    });
    return list;
  }

  // Placeholder for future activity types (System alerts)
  List<Map<String, dynamic>> get genericActivities {
    return [];
  }

  List<Map<String, dynamic>> _miningActivities = [];
  List<Map<String, dynamic>> get miningActivities => _miningActivities;

  int get unreadActivityCount {
    int count = 0;
    final lastSeen =
        _lastSeenActivityTime ?? DateTime.fromMillisecondsSinceEpoch(0);

    // 1. Message Request Activities
    count += activityItems.where((item) {
      final time = item.respondedAt ?? item.createdAt;
      return time.isAfter(lastSeen);
    }).length;

    // 2. Mining Activities
    count += _miningActivities.where((item) {
      final time = item['timestamp'] as DateTime;
      return time.isAfter(lastSeen);
    }).length;

    // 3. Wallet Activities (Tips)
    count += _walletActivities.where((item) {
      final time = item['timestamp'] as DateTime;
      return time.isAfter(lastSeen);
    }).length;

    // 4. Generic Activities
    count += genericActivities.where((item) {
      return (item['timestamp'] as DateTime).isAfter(lastSeen);
    }).length;

    return count;
  }

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

  Future<void> _loadActivitySeenTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString('last_seen_activity_time');
    if (timeStr != null) {
      _lastSeenActivityTime = DateTime.tryParse(timeStr);
      notifyListeners();
    }
  }

  Future<void> refreshActivity() async {
    await Future.wait([
      loadRequests(),
      loadMiningActivity(),
      loadWalletActivity(),
    ]);
  }

  List<Map<String, dynamic>> _walletActivities = [];
  List<Map<String, dynamic>> get walletActivities => _walletActivities;

  Future<void> loadWalletActivity() async {
    try {
      final history = await _transactionApi.getHistory(limit: 20);
      final List<dynamic> transactions = history is Map
          ? history['transactions'] ?? []
          : history;

      final currentAddress = _userProvider.user?.walletAddress.toLowerCase();

      _walletActivities = transactions
          .where((t) {
            final toAddr = (t['to_address'] ?? t['toAddress'])
                ?.toString()
                .toLowerCase();
            final type = (t['transaction_type'] ?? t['transactionType'])
                ?.toString();

            // Activity for tips is when we receive native coins from someone else
            return toAddr == currentAddress && type == 'send';
          })
          .map((t) {
            final fromAddr =
                (t['from_address'] ?? t['fromAddress'])?.toString() ??
                'Unknown';
            final amountRaw = t['value_raw'] ?? t['valueRaw'] ?? '0';
            final symbol = t['native_symbol'] ?? 'COWRIE';
            final timestamp = DateTime.parse(
              t['created_at'] ??
                  t['createdAt'] ??
                  DateTime.now().toIso8601String(),
            );

            // Simple conversion if possible, otherwise show raw
            String displayAmount = amountRaw;
            try {
              final bigInt = BigInt.parse(amountRaw);
              displayAmount = (bigInt / BigInt.from(10).pow(18))
                  .toStringAsFixed(2);
            } catch (_) {}

            return {
              'id': 'wallet_${t['id']}',
              'type': 'tip',
              'title': 'Received Tip',
              'message':
                  'You received $displayAmount $symbol from ${_shortenAddress(fromAddr)}',
              'timestamp': timestamp,
              'icon': Icons.volunteer_activism_rounded,
              'isTip': true,
              'color': 'amber',
              'fromAddress': fromAddr,
            };
          })
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading wallet activity: $e');
    }
  }

  String _shortenAddress(String addr) {
    if (addr.length < 10) return addr;
    return '${addr.substring(0, 4)}...${addr.substring(addr.length - 4)}';
  }

  Future<void> loadMiningActivity() async {
    try {
      final history = await _miningApi.getMiningHistory(limit: 20);

      // Only show settled (daily) rewards in the activity feed,
      // as per user requirement to not notify on every session press.
      _miningActivities = history
          .where(
            (item) => item['status'] == 'settled' || item['settled'] == true,
          )
          .map((item) {
            final amount = (item['amount'] ?? 0).toString();
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
    final normalized = name.trim().toLowerCase();
    switch (normalized) {
      case 'bnb':
      case 'binance-smart-chain':
      case 'binance smart chain':
      case 'binance':
        return 'bsc';
      case 'ethereum':
      case 'eth':
        return 'ethereum';
      case 'polygon':
      case 'matic':
        return 'polygon';
      case 'base-mainnet':
      case 'base':
        return 'base';
      default:
        return normalized;
    }
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

    return response;
  }

  Future<String> executeTip({
    required Map<String, dynamic> preparedTip,
    void Function(String status)? onStatusUpdate,
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
    if (myAddress == null) throw Exception('No wallet found');

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

    // 4. Sign
    if (onStatusUpdate != null) onStatusUpdate('Signing...');
    final String? signedTx = await _walletService.signNativeTransaction(
      to: to,
      valueRaw: valueRaw,
      nonce: nonce,
      gasLimit: gasLimit,
      maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
      chainId: chainId,
      dataHex: dataHex,
    );

    if (signedTx == null) throw Exception('Failed to sign transaction');

    // 5. Broadcast
    if (onStatusUpdate != null) onStatusUpdate('Broadcasting...');
    final hash = await _walletRpc.sendRawTransaction(
      network: network,
      signedTransaction: signedTx,
    );

    // 6. Poll Receipt (Spec Point 7)
    if (onStatusUpdate != null) onStatusUpdate('Confirming...');
    final receipt = await _waitForReceipt(network, hash);

    if (receipt['status'] == 0 || receipt['status'] == '0x0') {
      throw Exception('Transaction reverted on-chain');
    }

    return hash;
  }

  Future<BigInt> _checkAllowance(
    String network,
    String token,
    String owner,
    String spender,
  ) async {
    // IERC20.allowance(owner, spender)
    final data =
        '0xdd62ed3e${owner.substring(2).padLeft(64, '0')}${spender.substring(2).padLeft(64, '0')}';

    final result = await _walletRpc.call(
      network: network,
      to: token,
      data: data,
    );
    return BigInt.parse(result);
  }

  Future<String> _approveToken(
    String network,
    String token,
    String spender,
    BigInt amount,
    int chainId,
  ) async {
    // IERC20.approve(spender, amount)
    final data =
        '0x095ea7b3${spender.substring(2).padLeft(64, '0')}${amount.toRadixString(16).padLeft(64, '0')}';

    final String? myAddress = await _walletService.getAddress();
    final int nonce = await _walletRpc.getPendingNonce(
      network: network,
      address: myAddress!,
    );

    final String? signedTx = await _walletService.signNativeTransaction(
      to: token,
      valueRaw: '0',
      nonce: nonce,
      gasLimit: '100000',
      chainId: chainId,
      dataHex: data,
    );

    return await _walletRpc.sendRawTransaction(
      network: network,
      signedTransaction: signedTx!,
    );
  }

  Future<Map<String, dynamic>> _waitForReceipt(
    String network,
    String hash,
  ) async {
    for (int i = 0; i < 30; i++) {
      final receipt = await _walletRpc.getTransactionReceipt(
        network: network,
        hash: hash,
      );
      if (receipt != null) return receipt;
      await Future.delayed(const Duration(seconds: 2));
    }
    throw Exception('Transaction confirmation timeout');
  }

  void markActivitiesSeen() async {
    _lastSeenActivityTime = DateTime.now();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'last_seen_activity_time',
      _lastSeenActivityTime!.toIso8601String(),
    );
  }

  // ==========================================================
  // RELATIONSHIP LIFECYCLE
  // ==========================================================

  RelationshipState getRelationship(String userId) {
    if (_blockedUserIds.contains(userId)) return RelationshipState.blocked;

    if (_friends.any((f) => f.id == userId)) return RelationshipState.friends;

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

  Future<void> loadConversations({bool force = false}) async {
    if (!force &&
        _conversations.isNotEmpty &&
        _lastConversationsLoadedAt != null &&
        DateTime.now().difference(_lastConversationsLoadedAt!) <
            const Duration(minutes: 1)) {
      return;
    }
    if (_conversationsLoadFuture != null) return _conversationsLoadFuture!;
    _conversationsLoadFuture = _loadConversations();
    try {
      await _conversationsLoadFuture;
    } finally {
      _conversationsLoadFuture = null;
    }
  }

  Future<void> _loadConversations() async {
    _isLoadingConversations = true;
    notifyListeners();

    try {
      // 1. Load from cache first
      final cached = await _messageCache.getConversations();
      if (cached.isNotEmpty) {
        _conversations = cached;
        notifyListeners();
      }

      // 2. Fetch from server
      // Keep successful sections visible when one endpoint has a transient
      // failure (for example, channels during a migration). A failed channel
      // request must not hide valid direct conversations or groups.
      final results = await Future.wait<List<Conversation>>([
        _apiService.getConversations().catchError((_) => <Conversation>[]),
        _apiService.getGroups().catchError((_) => <Conversation>[]),
        _apiService.getChannels().catchError((_) => <Conversation>[]),
      ]);
      // A conversation can be returned by more than one endpoint. Dart sets
      // do not deduplicate model instances unless equality is overridden, so
      // key by the server id explicitly.
      final byId = <String, Conversation>{};
      for (final section in results) {
        for (final conversation in section) {
          byId[conversation.id] = conversation;
        }
      }
      final list = byId.values.toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _conversations = list;
      _lastConversationsLoadedAt = DateTime.now();

      // 3. Update cache
      await _messageCache.saveConversations(list);
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      if (_conversations.isEmpty) _conversations = [];
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  Future<Conversation> startDirectChat(String otherUserId) async {
    try {
      final conversation = await _apiService.findDirectConversation(
        otherUserId,
      );
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

  Future<void> loadRequests() async {
    _isLoadingRequests = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.getReceivedRequests(),
        _apiService.getSentRequests(),
      ]);
      _receivedRequests = results[0];
      _sentRequests = results[1];
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
    if (_isLoadingFriends) return;

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
      if (_currentFriendsSearchQuery != query) return;

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
    if (_isLoadingFriends || _isLoadingMoreFriends || !_hasMoreFriends) return;

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

  // ==========================================================
  // ACTIONS - MESSAGES
  // ==========================================================

  Future<void> loadMessages(
    String conversationId, {
    bool refresh = false,
  }) async {
    if (_isLoadingMessages[conversationId] == true) return;

    final cachedMessages = await _messageCache.getMessages(conversationId);
    final currentMessages =
        _messagesByConversation[conversationId] ?? cachedMessages;
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

      await _messageCache.saveMessages(newMessages);
      final merged = <String, ChatMessage>{
        for (final message in currentMessages) message.id: message,
        for (final message in newMessages) message.id: message,
      };
      _messagesByConversation[conversationId] = merged.values.toList();

      _messagesByConversation[conversationId]?.sort(
        (a, b) => b.createdAt.compareTo(a.createdAt),
      );

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

  Future<void> markAsDelivered(String messageId) async {
    try {
      await _apiService.markMessageReceipt(messageId, 'delivered');
      _updateMessageStatusLocally(messageId, MessageStatus.delivered);
    } catch (e) {
      debugPrint('Failed to mark as delivered: $e');
    }
  }

  Future<void> markAsRead(String messageId) async {
    try {
      await _apiService.markMessageReceipt(messageId, 'read');
      _updateMessageStatusLocally(messageId, MessageStatus.read);
    } catch (e) {
      debugPrint('Failed to mark as read: $e');
    }
  }

  void _updateMessageStatusLocally(String messageId, MessageStatus status) {
    bool found = false;
    for (final entry in _messagesByConversation.entries) {
      final list = entry.value;
      final index = list.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        // Only progress status, don't regress
        if (list[index].status.index < status.index) {
          list[index] = list[index].copyWith(status: status);
          found = true;
        }
        break;
      }
    }
    if (found) notifyListeners();
  }

  void _markMessageDeletedLocally(String messageId) {
    bool found = false;
    for (final entry in _messagesByConversation.entries) {
      final list = entry.value;
      final index = list.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        list[index] = list[index].copyWith(
          isDeleted: true,
          text: 'This message was deleted',
        );
        found = true;
        break;
      }
    }
    if (found) notifyListeners();
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _apiService.deleteMessage(messageId);
      _markMessageDeletedLocally(messageId);
    } catch (e) {
      debugPrint('Error deleting message: $e');
      rethrow;
    }
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

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMessage = ChatMessage(
      id: tempId,
      conversationId: conversationId,
      senderId: currentUserId,
      text: trimmed,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
      replyToMessageId: replyToMessageId,
    );

    await _messageCache.saveMessage(optimisticMessage);

    final currentMessages = _messagesByConversation[conversationId] ?? [];
    _messagesByConversation[conversationId] = [
      optimisticMessage,
      ...currentMessages,
    ];
    notifyListeners();

    try {
      final realMessage = await _apiService.sendMessage(
        conversationId: conversationId,
        content: trimmed,
        replyToMessageId: replyToMessageId,
      );
      await _messageCache.saveMessage(realMessage);
      await _messageCache.markSynced(realMessage.id);

      final list = _messagesByConversation[conversationId] ?? [];

      // 1. Remove the temp message and any other matching temp messages
      list.removeWhere(
        (m) =>
            m.id == tempId ||
            (m.id.startsWith('temp_') &&
                m.text == realMessage.text &&
                m.senderId == realMessage.senderId),
      );

      // 2. Only add the real message if it's not already there (e.g. added by socket)
      if (!list.any((m) => m.id == realMessage.id)) {
        list.add(realMessage);
      }

      // 3. Ensure consistent sorting (newest first)
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    } catch (e) {
      final list = _messagesByConversation[conversationId] ?? [];
      final index = list.indexWhere((m) => m.id == tempId);
      if (index != -1) {
        list[index] = optimisticMessage.copyWith(status: MessageStatus.failed);
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
  }) async {
    final currentUserId = _userProvider.user?.id ?? '';
    final tempId = 'temp_media_${DateTime.now().millisecondsSinceEpoch}';

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
      id: tempId,
      conversationId: conversationId,
      senderId: currentUserId,
      text: content ?? defaultText,
      type: type,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
      replyToMessageId: replyToMessageId,
      mediaUrl: filePath, // Show local path while uploading
    );

    final currentMessages = _messagesByConversation[conversationId] ?? [];
    _messagesByConversation[conversationId] = [
      optimisticMessage,
      ...currentMessages,
    ];
    notifyListeners();

    try {
      // 1. Upload
      final Map<String, dynamic> uploadResult = await _mediaApiService
          .uploadMedia(filePath, conversationId: conversationId);
      final String mediaId = uploadResult['id']?.toString() ?? '';
      final String mediaUrl = uploadResult['mediaUrl']?.toString() ?? '';

      // 2. Small delay to ensure backend consistency after /complete
      await Future.delayed(const Duration(milliseconds: 300));

      // 3. Send Message with mediaId
      final realMessage = await _apiService.sendMessage(
        conversationId: conversationId,
        content: content ?? '',
        messageType: type.name,
        replyToMessageId: replyToMessageId,
        mediaId: mediaId,
      );

      // Update real message with media URL if the server didn't already
      final finalMessage = realMessage.copyWith(mediaUrl: mediaUrl);

      await _messageCache.saveMessage(finalMessage);

      final list = _messagesByConversation[conversationId] ?? [];
      list.removeWhere((m) => m.id == tempId);
      if (!list.any((m) => m.id == finalMessage.id)) {
        list.add(finalMessage);
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    } catch (e) {
      final list = _messagesByConversation[conversationId] ?? [];
      final index = list.indexWhere((m) => m.id == tempId);
      if (index != -1) {
        list[index] = optimisticMessage.copyWith(status: MessageStatus.failed);
        notifyListeners();
      }
      rethrow;
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
    final messages = _messagesByConversation[message.conversationId];
    messages?.removeWhere((item) => item.id == message.id);
    notifyListeners();
    await sendMediaMessage(
      conversationId: message.conversationId,
      filePath: filePath.replaceFirst('file://', ''),
      type: message.type,
      content: message.text.startsWith('📷') || message.text.startsWith('📎')
          ? null
          : message.text,
      replyToMessageId: message.replyToMessageId,
    );
  }

  // ==========================================================
  // REAL-TIME (SOCKET.IO)
  // ==========================================================

  void initSocket(String accessToken) {
    _initMessageSocket(accessToken);
    _initWalletSocket(accessToken);
  }

  void _initMessageSocket(String accessToken) {
    if (_socket != null) {
      if (!_socket!.connected) _socket!.connect();
      return;
    }

    final socketUrl =
        ApiConfig.baseUrl
            .replaceFirst(RegExp(r'/api/?$'), '')
            .replaceFirst(RegExp(r'/+$'), '') +
        '/messages';

    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          // Allow the Engine.IO polling handshake to fall back on local
          // networks/dev servers, then upgrade to WebSocket when available.
          .setTransports(['polling', 'websocket'])
          .setAuth({'token': accessToken})
          .enableReconnection()
          .setReconnectionAttempts(double.infinity)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(10000)
          .enableAutoConnect()
          .build(),
    );

    _socket?.onConnect((_) async {
      debugPrint('Socket: Connected to /messages');
      
      // On reconnect, refresh data as per instructions
      await loadConversations(force: true);
      await loadFriends();
      
      // Spec: Reload the currently open conversation
      if (_currentRoomId != null) {
        loadMessages(_currentRoomId!, refresh: true);
      }
    });

    _socket?.onDisconnect((_) => debugPrint('Socket: Disconnected'));

    _socket?.on('presence_snapshot', (data) {
      debugPrint('Socket: presence_snapshot');
      final ids = data is List
          ? data.map((id) => id.toString()).toSet()
          : <String>{};

      _presenceMap.clear();

      for (final id in ids) {
        _presenceMap[id] = true;
      }

      notifyListeners();
    });

    _socket?.on('presence_updated', (data) {
      if (data is! Map) return;

      final userId = data['userId']?.toString();
      if (userId == null || userId.isEmpty) return;

      _presenceMap[userId] = data['isOnline'] == true;
      notifyListeners();
    });

    _socket?.on('message_received', (data) {
      final message = ChatMessage.fromJson(Map<String, dynamic>.from(data));
      _handleIncomingMessage(message);
    });

    _socket?.on('conversation_updated', (data) {
      debugPrint('Socket: conversation_updated');
      if (data is Map) {
        // If it looks like a message, handle it as one
        if (data.containsKey('content') || data.containsKey('text')) {
          _handleIncomingMessage(
            ChatMessage.fromJson(Map<String, dynamic>.from(data)),
          );
        } else {
          // If it's a conversation update, refresh the list
          loadConversations(force: true);
        }
      }
    });

    _socket?.on('message_sent', (data) {
      debugPrint('Socket: message_sent');
      final message = ChatMessage.fromJson(Map<String, dynamic>.from(data));
      _handleIncomingMessage(message);
    });

    _socket?.on('message_status_updated', (data) {
      debugPrint('Socket: message_status_updated');
      final String? messageId = data['messageId']?.toString();
      final String? statusStr = data['status']?.toString();

      if (messageId != null && statusStr != null) {
        final status = _parseMessageStatus(statusStr);
        _updateMessageStatusLocally(messageId, status);
      }
    });

    _socket?.on('message_receipt_updated', (data) {
      debugPrint('Socket: message_receipt_updated');
      final String? messageId = (data['messageId'] ?? data['message_id'])?.toString();
      final String? statusStr = data['status']?.toString();

      if (messageId != null && statusStr != null) {
        final status = _parseMessageStatus(statusStr);
        _updateMessageStatusLocally(messageId, status);
      }
    });

    _socket?.on('user_typing', (data) {
      final String? conversationId = data['conversationId']?.toString();
      final String? userId = data['userId']?.toString();
      final bool isTyping = data['isTyping'] == true;

      if (conversationId != null && userId != null) {
        final currentUserId = _userProvider.user?.id;
        if (userId == currentUserId) return;

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
      final String? messageId = data['messageId']?.toString();
      if (messageId != null) {
        // Find message and update reactions
        for (final entry in _messagesByConversation.entries) {
          final list = entry.value;
          final index = list.indexWhere((m) => m.id == messageId);
          if (index != -1) {
            final reactions = Map<String, List<String>>.from(
              data['reactions'] ?? {},
            );
            list[index] = list[index].copyWith(reactions: reactions);
            notifyListeners();
            break;
          }
        }
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
      final postId = data['postId']?.toString();
      if (postId != null) {
        final list = _postComments[postId] ?? [];
        if (!list.any((c) => c['id'] == data['id'])) {
          _postComments[postId] = [...list, data];
          notifyListeners();
        }
      }
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
      final request = MessageRequest.fromJson(Map<String, dynamic>.from(data));
      _handleRequestAccepted(request);
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
  }

  void _initWalletSocket(String accessToken) {
    if (_walletSocket != null) {
      if (!_walletSocket!.connected) _walletSocket!.connect();
      return;
    }

    final walletSocketUrl =
        ApiConfig.baseUrl
            .replaceFirst(RegExp(r'/api/?$'), '')
            .replaceFirst(RegExp(r'/+$'), '') +
        '/wallet';

    _walletSocket = io.io(
      walletSocketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': accessToken})
          .enableAutoConnect()
          .build(),
    );

    _walletSocket?.onConnect((_) {
      debugPrint('Socket: Connected to /wallet');
    });

    _walletSocket?.on('wallet_updated', (data) {
      debugPrint('Socket: wallet_updated - refreshing activity');
      loadWalletActivity();
    });

    _walletSocket?.onDisconnect(
      (_) => debugPrint('Socket: Wallet disconnected'),
    );
  }

  void disconnectSocket() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;

    _walletSocket?.disconnect();
    _walletSocket?.dispose();
    _walletSocket = null;
  }

  Future<void> _refreshAllData() async {
    await Future.wait([refreshActivity(), loadFriends(), loadConversations()]);
  }

  void _handleRequestReceived(MessageRequest request) {
    // Add to received requests if not already there
    final index = _receivedRequests.indexWhere((r) => r.id == request.id);
    if (index == -1) {
      _receivedRequests.insert(0, request);
    } else {
      _receivedRequests[index] = request;
    }
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
    notifyListeners();
  }

  void _handleIncomingMessage(ChatMessage message) {
    _messageSync.saveIncomingMessage(message);
    final conversationId = message.conversationId;

    // Requirement 12: Add it only to the matching conversation.
    final list = _messagesByConversation[conversationId] ?? [];

    // 1. If the message with this ID already exists, update it and return.
    final existingIndex = list.indexWhere((m) => m.id == message.id);
    if (existingIndex != -1) {
      list[existingIndex] = message;
      notifyListeners();
      return;
    }

    // 2. If it's my message, try to find and replace a temp one.
    final currentUserId = _userProvider.user?.id ?? '';
    if (message.senderId == currentUserId) {
      final tempIndex = list.indexWhere(
        (m) => m.id.startsWith('temp_') && m.text == message.text,
      );
      if (tempIndex != -1) {
        list[tempIndex] = message;
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        notifyListeners();
        return;
      }
    }

    // 3. Otherwise, add it to the list and sort.
    list.add(message);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _messagesByConversation[conversationId] = list;

    // Update conversation last message and unread count if not current
    final convIndex = _conversations.indexWhere((c) => c.id == conversationId);
    if (convIndex != -1) {
      final conv = _conversations[convIndex];
      _conversations[convIndex] = conv.copyWith(
        lastMessage: message,
        updatedAt: message.createdAt,
        unreadCount: _currentRoomId == conversationId
            ? conv.unreadCount
            : conv.unreadCount + 1,
      );
      _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } else {
      // Requirement 12: Refresh the conversation if we don't have it (or if auth fails)
      loadConversations();
    }

    // Requirement 10: Receipts - mark as delivered when received via socket
    if (message.senderId != currentUserId) {
      if (_currentRoomId == conversationId) {
        markAsRead(message.id);
      } else {
        markAsDelivered(message.id);
      }
    }

    notifyListeners();
  }

  void setTyping(String conversationId, bool isTyping) {
    _socket?.emit(isTyping ? 'typing_start' : 'typing_stop', {
      'conversationId': conversationId,
    });
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    final currentUserId = _userProvider.user?.id;
    if (currentUserId == null) return;

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

  void _updateUserPresence(String userId, bool isOnline) {
    var changed = false;
    
    // 0. Update presence map
    if (_presenceMap[userId] != isOnline) {
      _presenceMap[userId] = isOnline;
      changed = true;
    }

    // 1. Update conversations
    for (var i = 0; i < _conversations.length; i++) {
      final conversation = _conversations[i];
      final otherUser = conversation.otherUser;
      if (otherUser?.id == userId && otherUser!.isOnline != isOnline) {
        _conversations[i] = conversation.copyWith(
          otherUser: otherUser.copyWith(isOnline: isOnline),
        );
        changed = true;
      }
    }

    // 2. Update friends list
    for (var i = 0; i < _friends.length; i++) {
      if (_friends[i].id == userId && _friends[i].isOnline != isOnline) {
        _friends[i] = _friends[i].copyWith(isOnline: isOnline);
        changed = true;
      }
    }

    if (changed) notifyListeners();
  }

  void joinConversation(String conversationId) {
    if (_socket == null) return;
    _currentRoomId = conversationId;
    _socket?.emit('join_conversation', {'conversationId': conversationId});

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

  void leaveConversation(String conversationId) {
    if (_socket == null) return;
    _socket?.emit('leave_conversation', {'conversationId': conversationId});
    _currentRoomId = null;
  }

  void clearSearchResults() {
    notifyListeners();
  }

  MessageStatus _parseMessageStatus(String status) {
    switch (status.toLowerCase()) {
      case 'read':
        return MessageStatus.read;
      case 'delivered':
        return MessageStatus.delivered;
      case 'sent':
        return MessageStatus.sent;
      default:
        return MessageStatus.sending;
    }
  }

  Future<Conversation> createGroup({
    required String name,
    List<String> memberIds = const [],
    String visibility = 'public',
  }) async {
    final conversation = await _apiService.createGroup(
      name: name,
      memberIds: memberIds,
      visibility: visibility,
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

  Future<void> createChannelPost(String conversationId, String content) async {
    try {
      final post = await _apiService.createChannelPost(conversationId, content);
      final list = _channelPosts[conversationId] ?? [];
      _channelPosts[conversationId] = [post, ...list];
      notifyListeners();
    } catch (e) {
      debugPrint('Error creating channel post: $e');
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
      _postComments[postId] = [...list, comment];
      notifyListeners();
    } catch (e) {
      debugPrint('Error submitting channel comment: $e');
      rethrow;
    }
  }

  Future<Conversation> createChannel({
    required String name,
    required String username,
  }) async {
    final conversation = await _apiService.createChannel(
      name: name,
      username: username,
    );
    _conversations.removeWhere((item) => item.id == conversation.id);
    _conversations.insert(0, conversation);
    _lastConversationsLoadedAt = DateTime.now();
    notifyListeners();
    return conversation;
  }

  Future<void> addGroupMember(String conversationId, String userId) async {
    await _apiService.addGroupMember(conversationId, userId);
    // Optionally refresh members or conversation list
  }

  Future<void> removeGroupMember(String conversationId, String userId) async {
    await _apiService.removeGroupMember(conversationId, userId);
  }

  Future<void> leaveGroup(String conversationId) async {
    await _apiService.leaveGroup(conversationId);
    _conversations.removeWhere((c) => c.id == conversationId);
    notifyListeners();
  }

  Future<void> updateGroup(
    String conversationId, {
    String? name,
    String? description,
    String? imageUrl,
    String? visibility,
  }) async {
    final conversation = await _apiService.updateGroup(
      conversationId,
      name: name,
      description: description,
      imageUrl: imageUrl,
      visibility: visibility,
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
  }) async {
    final conversation = await _apiService.updateChannel(
      conversationId,
      name: name,
      description: description,
      imageUrl: imageUrl,
      visibility: visibility,
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

  Future<void> unsubscribeFromChannel(String conversationId) async {
    try {
      await _apiService.unsubscribeFromChannel(conversationId);
      _updateConversationStatus(conversationId, 'left', null);
      await loadConversations(force: true);
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

  Future<List<Map<String, dynamic>>> getGroupMembers(String conversationId) async {
    try {
      return await _apiService.getGroupMembers(conversationId);
    } catch (e) {
      debugPrint('Error getting group members: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getChannelMembers(String conversationId) async {
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
