import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:upgrader/upgrader.dart';

import 'core/network/api_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/startup/app_startup_service.dart';

import 'features/auth/services/auth_api_service.dart';
import 'features/auth/services/auth_session_service.dart';
import 'features/auth/services/auth_storage_service.dart';
import 'features/auth/services/wallet_auth_service.dart';
import 'features/auth/auth_controller.dart';
import 'features/users/providers/user_provider.dart';
import 'features/users/services/user_api_service.dart';
import 'features/wallet/services/wallet_crypto_service.dart';
import 'features/wallet/services/wallet_service.dart';
import 'features/wallet/services/wallet_storage_service.dart';

import 'features/wallet/services/wallet_api_service.dart';
import 'features/wallet/services/transaction_api_service.dart';
import 'features/wallet/services/swap_api_service.dart';
import 'features/wallet/services/wallet_rpc_service.dart';
import 'features/miner/services/mining_api_service.dart';
import 'features/miner/services/referral_api_service.dart';
import 'features/miner/services/reputation_api_service.dart';
import 'features/chat/services/messaging_api_service.dart';
import 'features/chat/services/active_call_controller.dart';
import 'features/chat/services/realtime_call_service.dart';
import 'features/chat/services/incoming_call_recovery.dart';
import 'features/chat/widgets/active_call_host.dart';
import 'features/chat/services/media_api_service.dart';
import 'features/chat/services/tip_api_service.dart';
import 'features/chat/services/message_cache_service.dart';
import 'features/chat/services/message_sync_service.dart';
import 'features/miner/providers/reputation_provider.dart';
import 'features/chat/providers/messaging_provider.dart';
import 'features/miner/providers/mining_provider.dart';
import 'features/miner/providers/referral_provider.dart';
import 'features/wallet/providers/wallet_provider.dart';
import 'features/wallet/providers/display_currency_provider.dart';
import 'features/iap/providers/iap_provider.dart';
import 'features/iap/services/plus_api_service.dart';
import 'features/users/providers/user_preference_provider.dart';
import 'features/local_auth/services/app_lock_service.dart';
import 'features/local_auth/services/local_auth_service.dart';
import 'features/local_auth/providers/app_lock_provider.dart';
import 'features/local_auth/screens/pin_verification_screen.dart';
import 'core/services/navigation_scroll_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/native_call_service.dart';
import 'features/chat/models/shared_content.dart';
import 'features/chat/models/conversation_model.dart';
import 'features/chat/services/shared_content_service.dart';

String _safeCurrentRoutePath() {
  try {
    final configuration = AppRouter.router.routerDelegate.currentConfiguration;
    if (configuration.matches.isEmpty) return '/';
    return configuration.uri.path;
  } on StateError {
    // GoRouter can briefly expose an empty match list while restoring state.
    // Reading `.uri` in that window otherwise calls RouteMatchList.last.
    return '/';
  } catch (_) {
    return '/';
  }
}

bool _isActiveConversationNotification(
  Map<String, dynamic> data, {
  String? providerConversationId,
}) {
  final type = data['type']?.toString();
  if (type != 'chat_message' && type != 'message_reaction') return false;

  final conversationId = (data['conversationId'] ?? data['conversation_id'])
      ?.toString()
      .trim();
  if (conversationId == null || conversationId.isEmpty) return false;

  if (providerConversationId != null &&
      providerConversationId.trim() == conversationId) {
    return true;
  }

  final path = _safeCurrentRoutePath();
  final segments = Uri.tryParse(path)?.pathSegments ?? const <String>[];
  // Use path segments instead of a single prefix because shell/deep-link
  // routes can expose the same chat as /conversation/:id or under /chat/.
  for (final marker in const ['conversation', 'groups', 'channels']) {
    final markerIndex = segments.indexOf(marker);
    if (markerIndex >= 0 && markerIndex + 1 < segments.length) {
      return Uri.decodeComponent(segments[markerIndex + 1]) == conversationId;
    }
  }
  return false;
}

class GriotCowrieApp extends StatefulWidget {
  const GriotCowrieApp({super.key});

  @override
  State<GriotCowrieApp> createState() => _GriotCowrieAppState();
}

class _GriotCowrieAppState extends State<GriotCowrieApp> {
  final ThemeController _themeController = ThemeController.instance;

  late final ApiClient _apiClient;
  late final UserApiService _userApiService;
  late final WalletService _walletService;
  late final AuthApiService _authApiService;
  late final AuthSessionService _authSessionService;
  late final WalletApiService _walletApiService;
  late final TransactionApiService _transactionApiService;
  late final SwapApiService _swapApiService;
  late final WalletRpcService _walletRpcService;
  late final MiningApiService _miningApiService;
  late final ReferralApiService _referralApiService;
  late final ReputationApiService _reputationApiService;
  late final MessagingApiService _messagingApiService;
  late final MediaApiService _mediaApiService;
  late final TipApiService _tipApiService;
  late final PlusApiService _plusApiService;
  late final MessageCacheService _messageCacheService;
  late final MessageSyncService _messageSyncService;
  late final AuthController _authController;
  late final AppLockService _appLockService;
  late final LocalAuthService _localAuthService;
  StreamSubscription<SharedContent>? _sharedContentSubscription;
  // A call can produce more than one terminal signal (for example the caller
  // ends while the callee's native UI also times out). Keep one foreground
  // notification per call so those signals never stack as duplicate bars.
  final Map<String, DateTime> _recentTerminalCallNotifications = {};

  void _handleRealtimeIncomingCall(Map<String, dynamic> data) {
    if (data['type']?.toString() != 'incoming_call') return;
    unawaited(_presentIncomingCall(data));
  }

  Future<void> _presentIncomingCall(Map<String, dynamic> data) async {
    try {
      await NativeCallService.instance.showIncoming(data);
    } catch (_) {
      // Keep the existing Flutter incoming-call screen as a compatibility
      // fallback for unsupported devices or plugin failures.
      _openPushNotification(data);
    }
  }

  Future<void> _handleNativeCallAccepted(Map<String, dynamic> data) async {
    // iOS may relaunch the app from CallKit before Flutter has restored all
    // PushKit extras. Recover the authoritative session by call ID so a valid
    // answer is not treated as an invalid call and immediately dismissed.
    final acceptedData = await _recoverAcceptedCallData(data);
    // Direct/group calls use conversationId; Campfires use roomId. Both map
    // to the call screen route so accepting from a terminated Android app
    // always lands in the active room.
    final conversationId = _firstNonEmpty(
      acceptedData['conversationId'],
      acceptedData['conversation_id'],
      acceptedData['roomId'],
    );
    if (conversationId == null || conversationId.isEmpty) {
      debugPrint(
        'NativeCallService: accepted call has no conversation or room id',
      );
      return;
    }
    // Griot owns one media session at a time. Do not report a second call as
    // connected when the existing call host cannot replace the active call.
    // The native call UI is dismissed and the server receives a clear busy
    // terminal state instead of leaving the caller waiting indefinitely.
    final activeCall = ActiveCallController.instance.request;
    final incomingCallId = _firstNonEmpty(
      acceptedData['callId'],
      acceptedData['id'],
    );
    if (activeCall != null &&
        !ActiveCallController.instance.closing &&
        incomingCallId != null &&
        incomingCallId.isNotEmpty) {
      await NativeCallService.instance.rejectAsBusy(incomingCallId);
      return;
    }
    ActiveCallController.instance.open(
      CallRequest(
        conversationId: conversationId,
        conversationType:
            _firstNonEmpty(
              acceptedData['contextType'],
              acceptedData['conversationType'],
              acceptedData['context_type'],
            ) ??
            'direct',
        mode: _firstNonEmpty(acceptedData['mode']) ?? 'voice',
        roomId: _firstNonEmpty(acceptedData['roomId'], acceptedData['room_id']),
        callId: incomingCallId,
      ),
    );
  }

  Future<Map<String, dynamic>> _recoverAcceptedCallData(
    Map<String, dynamic> data,
  ) async {
    final merged = <String, dynamic>{...data};
    final callId = _firstNonEmpty(data['callId'], data['id']);
    final hasConversation =
        _firstNonEmpty(data['conversationId'], data['conversation_id']) != null;
    final hasRoom = _firstNonEmpty(data['roomId'], data['room_id']) != null;
    if (callId == null || (hasConversation && hasRoom)) return merged;
    try {
      final calls = await RealtimeCallService(_apiClient).activeCalls();
      Map<String, dynamic>? match;
      for (final call in calls) {
        if (_firstNonEmpty(call['id'], call['callId']) == callId) {
          match = call;
          break;
        }
      }
      if (match == null) return merged;
      merged['conversationId'] ??=
          match['conversation_id'] ?? match['conversationId'];
      merged['roomId'] ??= match['room_id'] ?? match['roomId'];
      merged['contextType'] ??= match['context_type'] ?? match['contextType'];
      merged['mode'] ??= match['mode'];
    } catch (error) {
      debugPrint('NativeCallService: accepted-call recovery deferred: $error');
    }
    return merged;
  }

  String? _firstNonEmpty(Object? first, [Object? second, Object? third]) {
    for (final value in [first, second, third]) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();

    // ----------------------------------------------------------
    // CORE INFRASTRUCTURE
    // ----------------------------------------------------------

    final authStorage = AuthStorageService();
    final walletStorage = WalletStorageService();

    _apiClient = ApiClient(authStorageService: authStorage);
    unawaited(
      NativeCallService.instance.initialize(
        apiClient: _apiClient,
        onAccepted: _handleNativeCallAccepted,
      ),
    );
    PushNotificationService.instance.configure(
      apiClient: _apiClient,
      onNotificationTap: _openPushNotification,
      onForegroundMessage: _showForegroundPush,
    );

    _walletService = WalletService(
      cryptoService: WalletCryptoService(),
      storageService: walletStorage,
    );

    _appLockService = AppLockService();
    _localAuthService = LocalAuthService();

    _userApiService = UserApiService(apiClient: _apiClient);

    _walletApiService = WalletApiService(apiClient: _apiClient);

    _transactionApiService = TransactionApiService(apiClient: _apiClient);

    _swapApiService = SwapApiService(apiClient: _apiClient);

    _walletRpcService = WalletRpcService(apiClient: _apiClient);

    _miningApiService = MiningApiService(apiClient: _apiClient);

    _referralApiService = ReferralApiService(apiClient: _apiClient);

    _reputationApiService = ReputationApiService(apiClient: _apiClient);

    _messagingApiService = MessagingApiService(apiClient: _apiClient);

    _mediaApiService = MediaApiService(apiClient: _apiClient);

    _tipApiService = TipApiService(apiClient: _apiClient);

    _plusApiService = PlusApiService(apiClient: _apiClient);

    _messageCacheService = MessageCacheService();
    _messageSyncService = MessageSyncService(
      cache: _messageCacheService,
      api: _messagingApiService,
    );

    _authApiService = AuthApiService(
      apiClient: _apiClient,
      authStorageService: authStorage,
    );

    final walletAuthService = WalletAuthService(
      walletService: _walletService,
      authApiService: _authApiService,
    );

    _authSessionService = AuthSessionService(
      walletService: _walletService,
      authApiService: _authApiService,
      authStorageService: authStorage,
      walletAuthService: walletAuthService,
    );

    _authController = AuthController(
      authService: _authApiService,
      walletService: _walletService,
    );

    // Cache initialization is best-effort because storage is unavailable in
    // some test and newly supported platform environments.
    unawaited(_initializeMessageCache());
    _messageSyncService.initialize();

    ConnectivityService.instance.initialize();
    DeepLinkService.instance.initialize();

    // ==========================================================
    // THEME CONTROLLER
    // ==========================================================

    AppRouter.setThemeController(_themeController);
    _initializeSharedContent();
  }

  void _initializeSharedContent() {
    _sharedContentSubscription = SharedContentService.instance.stream.listen(
      _openSharedContent,
      onError: (error) => debugPrint('Share receiver error: $error'),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final content = await SharedContentService.instance.getInitial();
      if (content != null && mounted) _openSharedContent(content);
    });
  }

  void _openSharedContent(SharedContent content, {int attempt = 0}) {
    if (!content.isSupported) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Shared content can arrive during Router restoration. In that
        // window GoRouter's match list is legitimately empty and calling go()
        // makes its parser read RouteMatchList.last. Wait for the first valid
        // match instead of allowing a transient startup assertion.
        if (!_routerHasMatch()) {
          if (attempt < 25) {
            Future<void>.delayed(
              const Duration(milliseconds: 200),
              () => _openSharedContent(content, attempt: attempt + 1),
            );
          }
          return;
        }
        try {
          AppRouter.router.go('/shared-content', extra: content);
        } on StateError {
          if (attempt < 25) {
            Future<void>.delayed(
              const Duration(milliseconds: 200),
              () => _openSharedContent(content, attempt: attempt + 1),
            );
          }
        }
      }
    });
  }

  bool _routerHasMatch() {
    try {
      return AppRouter
          .router
          .routerDelegate
          .currentConfiguration
          .matches
          .isNotEmpty;
    } catch (_) {
      // Firebase can deliver an initial notification before MaterialApp.router
      // has restored its first match. Never navigate while GoRouter's match
      // list is empty; RouteMatchList.last would throw and crash the app.
      return false;
    }
  }

  void _openPushNotification(Map<String, dynamic> data, {int attempt = 0}) {
    if (!_routerHasMatch()) {
      if (attempt < 25) {
        Future<void>.delayed(
          const Duration(milliseconds: 200),
          () => _openPushNotification(data, attempt: attempt + 1),
        );
      }
      return;
    }
    final route = data['route']?.toString().trim() ?? '';
    final type = data['type']?.toString() ?? '';

    // A speaker request belongs to the active Campfire room, not the public
    // discovery feed. Open the room and its dedicated participants/controls
    // screen so the host can approve or decline the request immediately.
    if (type == 'campfire_speaker_request') {
      final spaceId = (data['spaceId'] ?? data['space_id'])?.toString().trim();
      if (spaceId == null || spaceId.isEmpty) {
        AppRouter.router.go('/campfires');
        return;
      }
      AppRouter.router.push(
        '/calls/$spaceId',
        extra: {
          'type': 'space',
          'mode': data['mode']?.toString() ?? 'voice',
          'roomId': data['roomId']?.toString() ?? 'griot-space-$spaceId',
          'openParticipants': true,
        },
      );
      return;
    }

    // A scheduled Campfire becoming due is only a reminder for its creator.
    // Keep the user on the Campfires list so they must press Start manually;
    // opening the call route would violate the scheduled-start rule.
    if (type == 'campfire_scheduled_ready') {
      AppRouter.router.go('/campfires');
      return;
    }

    // Campfire activity belongs to the Campfires shell. Use `go` instead of
    // pushing another copy of the stateful shell (which can leave a broken
    // nested navigator when the notification is tapped from a call screen or
    // while the app is restoring its route stack).
    if (type == 'campfire_started' ||
        type == 'campfire_joined' ||
        type == 'campfire_ended' ||
        route == '/campfires') {
      final currentPath = _safeCurrentRoutePath();
      if (!currentPath.startsWith('/calls/')) {
        AppRouter.router.go('/campfires');
      }
      return;
    }

    if (type == 'incoming_call') {
      final conversationId = data['conversationId']?.toString();
      final contextType = data['contextType']?.toString() ?? 'direct';
      if (conversationId != null && conversationId.isNotEmpty) {
        AppRouter.router.push(
          '/calls/incoming',
          extra: {
            'conversationId': conversationId,
            'contextType': contextType,
            'mode': data['mode']?.toString() ?? 'voice',
            'callId': data['callId']?.toString() ?? '',
            'roomId': data['roomId']?.toString(),
            'callerName': data['callerName']?.toString() ?? 'Griot contact',
            'callerAvatarUrl': data['callerAvatarUrl']?.toString(),
            'callerWalletAddress': data['callerWalletAddress']?.toString(),
          },
        );
      }
      return;
    }

    // The server provides routes only for destinations that are safe to open
    // from a notification. Fall back to the appropriate chat home instead of
    // leaving the user on a blank or invalid route.
    // Call history is intentionally represented in Updates now. Older push
    // payloads may still carry the removed /chat/calls route; never navigate
    // to that dead path or leave the user on an empty route.
    if (type == 'call_log' || route == '/chat/calls') {
      AppRouter.router.go('/notifications');
      return;
    }

    // Mining notifications belong to the Miner shell. Older payloads used
    // `/mining`, while current payloads use `/miner`; handle both explicitly
    // and replace the shell location instead of pushing a nested copy. This
    // keeps the session-complete notification from landing on a stale page or
    // closing without opening the mining screen.
    if (type == 'mining_session_complete' ||
        type == 'mining_settlement' ||
        route == '/mining' ||
        route == '/miner') {
      AppRouter.router.go('/miner');
      return;
    }

    // Group/channel notification payloads have historically used several
    // route shapes (`/group/...`, `/channel/...`, and `/chat/...`) and some
    // payloads only include conversationId. Normalize them to the canonical
    // conversation route and pass the cached Conversation so GoRouter can
    // select the correct group or channel screen instead of assuming DM.
    final notificationConversationId =
        (data['conversationId'] ??
                data['conversation_id'] ??
                data['groupId'] ??
                data['group_id'] ??
                data['channelId'] ??
                data['channel_id'])
            ?.toString()
            .trim();
    final lowerRoute = route.toLowerCase();
    final explicitConversationType =
        (data['conversationType'] ??
                data['conversation_type'] ??
                data['contextType'] ??
                data['context_type'])
            ?.toString()
            .toLowerCase();
    final notificationConversationType =
        explicitConversationType ??
        ((data['groupId'] ?? data['group_id']) != null
            ? 'group'
            : (data['channelId'] ?? data['channel_id']) != null
            ? 'channel'
            : null);
    final cachedNotificationConversation = AppRouter
        .router
        .routerDelegate
        .navigatorKey
        .currentContext
        ?.read<MessagingProvider>()
        .conversations
        .where((item) => item.id == notificationConversationId)
        .firstOrNull;
    final cachedConversationType =
        cachedNotificationConversation?.type == ConversationType.group
        ? 'group'
        : cachedNotificationConversation?.type == ConversationType.channel
        ? 'channel'
        : null;
    final isGroupOrChannelNotification =
        type.contains('group') ||
        type.contains('channel') ||
        notificationConversationType == 'group' ||
        notificationConversationType == 'channel' ||
        cachedConversationType != null ||
        lowerRoute.startsWith('/group/') ||
        lowerRoute.startsWith('/channel/') ||
        lowerRoute.startsWith('/chat/groups/') ||
        lowerRoute.startsWith('/chat/channels/');
    if (isGroupOrChannelNotification &&
        notificationConversationId != null &&
        notificationConversationId.isNotEmpty) {
      unawaited(
        _openConversationNotification(
          conversationId: notificationConversationId,
          conversationType:
              notificationConversationType ?? cachedConversationType,
        ),
      );
      return;
    }

    if (route.startsWith('/')) {
      AppRouter.router.push(route);
      return;
    }

    switch (data['type']?.toString()) {
      case 'message_request':
      case 'request_accepted':
      case 'request_declined':
      case 'request_withdrawn':
        AppRouter.router.push('/chat/requests');
      case 'chat_message':
      case 'message_reaction':
        AppRouter.router.push('/chat');
      case 'tip_received':
      case 'tip_sent':
      case 'native_transfer_received':
      case 'token_transfer_received':
        AppRouter.router.push('/wallet?tab=activity');
      case 'call_log':
        AppRouter.router.push('/notifications');
      case 'plus_gift_received':
      case 'plus_activated':
        AppRouter.router.push('/notifications');
      default:
        AppRouter.router.push('/notifications');
    }
  }

  Future<void> _openConversationNotification({
    required String conversationId,
    String? conversationType,
  }) async {
    final context = AppRouter.router.routerDelegate.navigatorKey.currentContext;
    final messaging = context?.read<MessagingProvider>();
    Conversation? conversation;
    if (messaging != null) {
      conversation = messaging.conversations
          .where((item) => item.id == conversationId)
          .firstOrNull;
    }

    final normalizedType = conversationType?.trim().toLowerCase();
    // A notification can arrive before the conversation cache has hydrated.
    // Resolve shared conversations by their type so a group/channel never
    // falls through to the DM screen.
    if (conversation == null &&
        (normalizedType == 'group' || normalizedType == 'channel')) {
      try {
        conversation = normalizedType == 'group'
            ? await _messagingApiService.getGroup(conversationId)
            : await _messagingApiService.getChannel(conversationId);
      } catch (error) {
        debugPrint(
          'Push: unable to resolve conversation $conversationId: $error',
        );
      }
    }

    if (!mounted || !_routerHasMatch()) return;
    AppRouter.router.push('/conversation/$conversationId', extra: conversation);
  }

  void _showForegroundPush(RemoteMessage message) {
    final context = AppRouter.router.routerDelegate.navigatorKey.currentContext;
    if (context == null) return;

    final data = message.data;
    final type = data['type']?.toString() ?? '';
    // Campfire push events are meaningful only while the user is actively in
    // that exact room. Hosts, speakers, and co-hosts who have left must not
    // receive foreground join/leave/status toasts for a room they exited.
    const campfirePushTypes = {
      'campfire_started',
      'campfire_scheduled',
      'campfire_joined',
      'campfire_speaker_request',
      'campfire_ended',
    };
    if (campfirePushTypes.contains(type)) {
      final spaceId =
          (data['spaceId'] ?? data['space_id'] ?? data['campfireId'])
              ?.toString()
              .trim();
      final active = ActiveCallController.instance.request;
      final path = _safeCurrentRoutePath();
      final inExactCampfire =
          spaceId != null &&
          spaceId.isNotEmpty &&
          path == '/calls/$spaceId' &&
          !ActiveCallController.instance.closing &&
          active?.conversationType == 'space' &&
          active?.conversationId == spaceId;
      if (!inExactCampfire) return;
    }
    final status = data['status']?.toString().toLowerCase();
    if (type == 'call_log' &&
        const {'ended', 'declined', 'missed', 'failed'}.contains(status)) {
      final callId = (data['callId'] ?? data['call_id'])?.toString().trim();
      if (callId != null && callId.isNotEmpty) {
        final now = DateTime.now();
        _recentTerminalCallNotifications.removeWhere(
          (_, timestamp) =>
              now.difference(timestamp) > const Duration(seconds: 10),
        );
        final previous = _recentTerminalCallNotifications[callId];
        if (previous != null &&
            now.difference(previous) <= const Duration(seconds: 10)) {
          return;
        }
        _recentTerminalCallNotifications[callId] = now;
      }
    }
    final isChatNotification = const {
      'chat_message',
      'message_request',
      'message_reaction',
      'call_log',
    }.contains(type);
    final preferences = context.read<UserPreferenceProvider>().preferences;
    if (isChatNotification && preferences['chat_notifications'] == false) {
      return;
    }

    final allowPreview = preferences['message_preview'] != false;
    final notification = message.notification;
    String title = notification?.title?.trim() ?? '';
    String body = notification?.body?.trim() ?? '';

    if (isChatNotification && !allowPreview) {
      title = 'New message';
      body = 'Open Griot to view it.';
    }
    if (title.isEmpty) title = _pushFallbackTitle(type);
    if (body.isEmpty) body = _pushFallbackBody(type);

    if (type == 'message_reaction') {
      final actorName =
          (data['actorName'] ?? data['reactorName'] ?? data['senderName'])
              ?.toString()
              .trim();
      final reaction = data['reaction']?.toString().trim();
      if (actorName != null && actorName.isNotEmpty) {
        title = '$actorName reacted';
        body = reaction != null && reaction.isNotEmpty
            ? '$actorName reacted $reaction to your message.'
            : '$actorName reacted to your message.';
      }
    }

    // Use a clear terminal state instead of the generic "Call update" copy.
    // This is also what remains after the ringing/native call UI is dismissed.
    if (type == 'call_log') {
      final label = data['mode']?.toString() == 'video'
          ? 'Video call'
          : 'Voice call';
      switch (status) {
        case 'missed':
          title = 'Missed $label';
          body = 'You missed a call. Tap to view your call history.';
          break;
        case 'declined':
          title = 'Call declined';
          body = '$label was declined.';
          break;
        case 'failed':
          title = 'Call failed';
          body = '$label could not be completed.';
          break;
        case 'ended':
          title = 'Call ended';
          body = '$label has ended.';
          break;
      }
    }

    if (type == 'incoming_call') {
      title = title.isEmpty ? 'Incoming Griot call' : title;
      body = body.isEmpty ? 'Tap to answer the call.' : body;

      // FCM does not automatically create a system call UI while the app is
      // in the foreground. Open the in-app incoming-call screen immediately
      // so the recipient can accept or decline instead of having to notice a
      // transient toast.
      final currentPath = _safeCurrentRoutePath();
      if (!currentPath.startsWith('/calls/')) {
        unawaited(_presentIncomingCall(data));
      }
      return;
    }

    final messaging = context.read<MessagingProvider>();
    if (type == 'chat_message' || type == 'message_reaction') {
      unawaited(messaging.loadConversations(force: true));
    }

    // The user is already looking at this conversation, so the incoming
    // message is visible in the chat stream. Keep the data refresh above, but
    // do not cover the conversation with a duplicate foreground toast.
    if (_isActiveConversationNotification(
      data,
      providerConversationId: messaging.activeConversationId,
    )) {
      return;
    }

    if (type == 'message_request') {
      unawaited(messaging.loadRequests(force: true));
      unawaited(messaging.loadGenericNotifications(refresh: true));
    }
    if (type == 'request_accepted' ||
        type == 'request_declined' ||
        type == 'request_withdrawn') {
      unawaited(messaging.loadRequests(force: true));
      unawaited(messaging.loadGenericNotifications(refresh: true));
    }
    if (type == 'mining_session_complete' || type == 'mining_settlement') {
      unawaited(context.read<MiningProvider>().loadStatus());
      unawaited(messaging.loadGenericNotifications(refresh: true));
    }
    if (type == 'plus_gift_received' ||
        type == 'plus_activated' ||
        type == 'tip_received' ||
        type == 'tip_sent' ||
        type == 'native_transfer_received' ||
        type == 'token_transfer_received') {
      unawaited(messaging.loadGenericNotifications(refresh: true));
    }

    NotificationService.showPush(
      context,
      title: title,
      message: body,
      icon: _pushIcon(type),
      onTap: () => _openPushNotification(data),
    );
  }

  String _pushFallbackTitle(String type) => switch (type) {
    'chat_message' => 'New message',
    'message_request' => 'New connection request',
    'request_accepted' => 'Connection request accepted',
    'request_declined' => 'Connection request declined',
    'request_withdrawn' => 'Connection request withdrawn',
    'message_reaction' => 'New reaction',
    'incoming_call' => 'Incoming Griot call',
    'mining_session_complete' => 'Mining session complete',
    'mining_settlement' => 'Mining rewards settled',
    'plus_gift_received' => 'Griot Plus gift received',
    'plus_activated' => 'Griot Plus is active',
    'tip_received' => 'Tip received',
    'tip_sent' => 'Tip confirmed',
    'campfire_started' => 'Campfire is burning',
    'campfire_scheduled' => 'Campfire scheduled',
    'campfire_scheduled_ready' => 'Your Campfire is ready',
    'campfire_joined' => 'Someone joined your Campfire',
    'campfire_speaker_request' => 'Join the Fire request',
    'campfire_ended' => 'Campfire ended',
    'call_log' => 'Call update',
    'native_transfer_received' ||
    'token_transfer_received' => 'Payment received',
    _ => 'Griot update',
  };

  String _pushFallbackBody(String type) => switch (type) {
    'chat_message' => 'You have a new message on Griot.',
    'message_request' => 'Someone would like to connect with you.',
    'request_accepted' => 'Your connection request was accepted on Griot.',
    'request_declined' => 'Your connection request was declined on Griot.',
    'request_withdrawn' => 'A connection request was withdrawn on Griot.',
    'message_reaction' => 'Someone reacted to your message.',
    'mining_session_complete' => 'Your next mining session is ready to start.',
    'mining_settlement' => 'Your mining rewards are ready to view.',
    'plus_gift_received' =>
      'Someone paid for Griot Plus for you. Your membership is now active.',
    'plus_activated' => 'Your Griot Plus membership is now active.',
    'tip_received' => 'You received a tip on Griot.',
    'tip_sent' => 'Your tip was confirmed on Griot.',
    'campfire_started' => 'A Campfire you may know about is live now.',
    'campfire_scheduled' => 'A Campfire you may know about is coming up.',
    'campfire_scheduled_ready' =>
      'Your scheduled Campfire is ready. Open Campfires and press Start when you are ready.',
    'campfire_joined' => 'A listener joined your Campfire.',
    'campfire_speaker_request' => 'A listener wants to join the conversation.',
    'campfire_ended' => 'The Campfire has ended.',
    'call_log' => 'View your call history for details.',
    'native_transfer_received' ||
    'token_transfer_received' => 'You received a blockchain payment.',
    _ => 'You have a new update.',
  };

  IconData _pushIcon(String type) => switch (type) {
    'chat_message' => Icons.chat_bubble_rounded,
    'message_request' => Icons.person_add_rounded,
    'request_accepted' => Icons.person_add_alt_1_rounded,
    'request_declined' => Icons.person_remove_rounded,
    'request_withdrawn' => Icons.undo_rounded,
    'message_reaction' => Icons.favorite_rounded,
    'mining_session_complete' || 'mining_settlement' => Icons.bolt_rounded,
    'plus_gift_received' => Icons.card_giftcard_rounded,
    'plus_activated' => Icons.workspace_premium_rounded,
    'tip_received' || 'tip_sent' => Icons.volunteer_activism_outlined,
    'campfire_started' ||
    'campfire_scheduled' ||
    'campfire_scheduled_ready' ||
    'campfire_joined' ||
    'campfire_speaker_request' ||
    'campfire_ended' => Icons.local_fire_department_rounded,
    'native_transfer_received' ||
    'token_transfer_received' => Icons.call_received_rounded,
    'call_log' => Icons.phone_in_talk_outlined,
    _ => Icons.notifications_rounded,
  };

  Future<void> _initializeMessageCache() async {
    try {
      await _messageCacheService.initialize();
    } catch (error, stackTrace) {
      debugPrint('Message cache initialization deferred: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    _sharedContentSubscription?.cancel();
    _recentTerminalCallNotifications.clear();
    _apiClient.dispose();
    _walletRpcService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ======================================================
        // DATA SERVICES
        // ======================================================

        Provider<ApiClient>.value(value: _apiClient),
        Provider<WalletService>.value(value: _walletService),
        Provider<UserApiService>.value(value: _userApiService),
        Provider<AuthSessionService>.value(value: _authSessionService),
        Provider<WalletApiService>.value(value: _walletApiService),
        Provider<TransactionApiService>.value(value: _transactionApiService),
        Provider<SwapApiService>.value(value: _swapApiService),
        Provider<WalletRpcService>.value(value: _walletRpcService),
        Provider<MiningApiService>.value(value: _miningApiService),
        Provider<ReferralApiService>.value(value: _referralApiService),
        Provider<ReputationApiService>.value(value: _reputationApiService),
        Provider<MessagingApiService>.value(value: _messagingApiService),
        Provider<MediaApiService>.value(value: _mediaApiService),
        Provider<TipApiService>.value(value: _tipApiService),
        Provider<MessageCacheService>.value(value: _messageCacheService),
        Provider<MessageSyncService>.value(value: _messageSyncService),
        Provider<AppLockService>.value(value: _appLockService),
        Provider<LocalAuthService>.value(value: _localAuthService),
        ChangeNotifierProvider<AuthController>.value(value: _authController),
        ChangeNotifierProvider<NavigationScrollService>.value(
          value: NavigationScrollService.instance,
        ),

        // ======================================================
        // APP LOCK PROVIDER
        // ======================================================
        ChangeNotifierProvider<AppLockProvider>(
          create: (_) => AppLockProvider(appLockService: _appLockService),
        ),

        // ======================================================
        // USER PROVIDER
        // ======================================================
        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider(
            userApiService: _userApiService,
            mediaApiService: _mediaApiService,
          ),
        ),

        // ======================================================
        // USER PREFERENCE PROVIDER
        // ======================================================
        ChangeNotifierProvider<UserPreferenceProvider>(
          create: (_) => UserPreferenceProvider(apiService: _userApiService),
        ),

        // ======================================================
        // WALLET PROVIDER
        // ======================================================
        ChangeNotifierProvider<WalletProvider>(
          create: (_) => WalletProvider(
            walletService: _walletService,
            walletApiService: _walletApiService,
          ),
        ),
        ChangeNotifierProvider<DisplayCurrencyProvider>(
          create: (_) => DisplayCurrencyProvider(),
        ),

        // ======================================================
        // REPUTATION PROVIDER
        // ======================================================
        ChangeNotifierProxyProvider<UserProvider, ReputationProvider>(
          create: (_) => ReputationProvider(apiService: _reputationApiService),
          update: (_, userProvider, reputation) =>
              (reputation ??
                    ReputationProvider(apiService: _reputationApiService))
                ..updateUserProvider(userProvider),
        ),

        // ======================================================
        // MESSAGING PROVIDER
        // ======================================================
        ChangeNotifierProxyProvider<UserProvider, MessagingProvider>(
          create: (pCtx) => MessagingProvider(
            apiService: _messagingApiService,
            mediaApiService: _mediaApiService,
            userProvider: pCtx.read<UserProvider>(),
            messageCache: _messageCacheService,
            miningApi: _miningApiService,
            transactionApi: _transactionApiService,
            tipApi: _tipApiService,
            walletService: _walletService,
            walletApi: _walletApiService,
            walletRpc: _walletRpcService,
          ),
          update: (_, userProvider, messaging) {
            final provider =
                (messaging ??
                      MessagingProvider(
                        apiService: _messagingApiService,
                        mediaApiService: _mediaApiService,
                        userProvider: userProvider,
                        messageCache: _messageCacheService,
                        miningApi: _miningApiService,
                        transactionApi: _transactionApiService,
                        tipApi: _tipApiService,
                        walletService: _walletService,
                        walletApi: _walletApiService,
                        walletRpc: _walletRpcService,
                      ))
                  ..updateUserProvider(userProvider);

            // Ensure AuthController is kept in sync
            _authController.setMessagingProvider(provider);
            _authController.setUserProvider(userProvider);
            _apiClient.onAccessTokenRefreshed = provider.initSocket;
            return provider;
          },
        ),

        // ======================================================
        // REFERRAL PROVIDER
        // ======================================================
        ChangeNotifierProvider<ReferralProvider>(
          create: (_) => ReferralProvider(apiService: _referralApiService),
        ),

        // ======================================================
        // MINING PROVIDER
        // ======================================================
        ChangeNotifierProvider<MiningProvider>(
          create: (_) => MiningProvider(apiService: _miningApiService),
        ),

        // ======================================================
        // IAP PROVIDER
        // ======================================================
        ChangeNotifierProvider<IapProvider>(
          create: (_) => IapProvider(apiService: _plusApiService),
        ),

        // ======================================================
        // STARTUP SERVICE
        // ======================================================
        ProxyProvider<WalletProvider, AppStartupService>(
          update: (ctx, wallet, previous) => AppStartupService(
            authSessionService: ctx.read<AuthSessionService>(),
            authController: ctx.read<AuthController>(),
            userProvider: ctx.read<UserProvider>(),
            userPreferenceProvider: ctx.read<UserPreferenceProvider>(),
            messagingProvider: ctx.read<MessagingProvider>(),
            walletProvider: wallet,
            miningProvider: ctx.read<MiningProvider>(),
            referralProvider: ctx.read<ReferralProvider>(),
            reputationProvider: ctx.read<ReputationProvider>(),
          ),
        ),
      ],

      // ========================================================
      // APP
      // ========================================================
      child: _IncomingCallProviderBinding(
        onIncomingCall: _handleRealtimeIncomingCall,
        child: AnimatedBuilder(
          animation: _themeController,
          builder: (context, child) {
            return MaterialApp.router(
              debugShowCheckedModeBanner: false,

              // ==================================================
              // LIGHT THEME
              // ==================================================
              theme: AppTheme.theme(
                style: _themeController.themeStyle,
                brightness: Brightness.light,
              ),

              // ==================================================
              // DARK THEME
              // ==================================================
              darkTheme: AppTheme.theme(
                style: _themeController.themeStyle,
                brightness: Brightness.dark,
              ),

              // ==================================================
              // CURRENT THEME MODE
              // ==================================================
              themeMode: _themeController.themeMode,

              // ==================================================
              // ROUTER
              // ==================================================
              routerConfig: AppRouter.router,

              // ==================================================
              // APP LOCK BUILDER
              // ==================================================
              builder: (context, child) {
                final theme = Theme.of(context);
                final overlayStyle =
                    theme.appBarTheme.systemOverlayStyle ??
                    SystemUiOverlayStyle(
                      statusBarColor: theme.scaffoldBackgroundColor,
                      statusBarIconBrightness:
                          theme.brightness == Brightness.dark
                          ? Brightness.light
                          : Brightness.dark,
                      statusBarBrightness: theme.brightness == Brightness.dark
                          ? Brightness.dark
                          : Brightness.light,
                      systemNavigationBarColor: theme.scaffoldBackgroundColor,
                      systemNavigationBarIconBrightness:
                          theme.brightness == Brightness.dark
                          ? Brightness.light
                          : Brightness.dark,
                      systemNavigationBarDividerColor:
                          theme.scaffoldBackgroundColor,
                    );

                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: overlayStyle,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(_themeController.textScale),
                    ),
                    child: UpgradeAlert(
                      child: TipNotificationListener(
                        child: CampfireNotificationListener(
                          child: Stack(
                            children: [
                              ?child,
                              const ActiveCallHost(),
                              const _ActiveCallBanner(),
                              const _AppLockOverlay(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ActiveCallBanner extends StatefulWidget {
  const _ActiveCallBanner();

  @override
  State<_ActiveCallBanner> createState() => _ActiveCallBannerState();
}

class _ActiveCallBannerState extends State<_ActiveCallBanner> {
  Offset _offset = Offset.zero;

  void _move(DragUpdateDetails details) {
    setState(() {
      _offset = Offset(
        (_offset.dx + details.delta.dx).clamp(-160.0, 160.0),
        (_offset.dy + details.delta.dy).clamp(-40.0, 520.0),
      );
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ActiveCallController.instance,
    builder: (context, _) {
      final owner = ActiveCallController.instance;
      final call = owner.request;
      if (call == null || !owner.minimized || owner.closing) {
        return const SizedBox.shrink();
      }
      final liveTitle = call.title?.trim().isNotEmpty == true
          ? call.title!.trim()
          : (call.conversationType == 'space' ? 'Campfire' : 'Call');
      return SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Transform.translate(
            offset: _offset,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 58, 12, 0),
              child: GestureDetector(
                onPanUpdate: _move,
                child: Semantics(
                  button: true,
                  label: '$liveTitle. Tap to return to the live call.',
                  child: Material(
                    elevation: 10,
                    color: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                      side: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.onPrimary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: InkWell(
                      onTap: owner.expand,
                      borderRadius: BorderRadius.circular(22),
                      child: SizedBox(
                        width: 292,
                        height: 78,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.onPrimary
                                      .withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                ),
                                child: SizedBox.square(
                                  dimension: 48,
                                  child: Icon(
                                    call.conversationType == 'space'
                                        ? Icons.local_fire_department_rounded
                                        : call.mode == 'video'
                                        ? Icons.videocam_rounded
                                        : Icons.phone_in_talk_rounded,
                                    size: 25,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      liveTitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const SizedBox.square(
                                            dimension: 6,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            call.conversationType == 'space'
                                                ? 'Campfire · Live now'
                                                : call.mode == 'video'
                                                ? 'Video call · Live now'
                                                : 'Voice call · Live now',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimary
                                                  .withValues(alpha: 0.78),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.keyboard_arrow_up_rounded,
                                size: 22,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ],
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
      );
    },
  );
}

class _IncomingCallProviderBinding extends StatefulWidget {
  final Widget child;
  final void Function(Map<String, dynamic> data) onIncomingCall;

  const _IncomingCallProviderBinding({
    required this.child,
    required this.onIncomingCall,
  });

  @override
  State<_IncomingCallProviderBinding> createState() =>
      _IncomingCallProviderBindingState();
}

class _IncomingCallProviderBindingState
    extends State<_IncomingCallProviderBinding>
    with WidgetsBindingObserver {
  MessagingProvider? _boundProvider;
  UserProvider? _userProvider;
  StreamSubscription<Map<String, dynamic>>? _callStatusSubscription;
  IncomingCallRecovery? _callRecovery;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<MessagingProvider>();
    if (_boundProvider != provider) {
      _callStatusSubscription?.cancel();
      _boundProvider = provider;
      provider.setIncomingCallHandler(widget.onIncomingCall);
      // Terminal status events must dismiss the native ringing UI even when
      // the recipient never opened the Flutter call screen.
      _callStatusSubscription = provider.callStatusStream.listen((data) {
        final status = data['status']?.toString().toLowerCase();
        if (!const {'ended', 'declined', 'missed', 'failed'}.contains(status)) {
          return;
        }
        final callId = (data['callId'] ?? data['call_id'])?.toString().trim();
        if (callId != null && callId.isNotEmpty) {
          unawaited(NativeCallService.instance.end(callId));
        }
      });
    }

    final userProvider = context.read<UserProvider>();
    if (_userProvider != userProvider) {
      _userProvider?.removeListener(_onUserChanged);
      _userProvider = userProvider;
      userProvider.addListener(_onUserChanged);
    }
    _onUserChanged();
  }

  void _onUserChanged() {
    _callRecovery ??= IncomingCallRecovery(
      fetch: () => RealtimeCallService(context.read<ApiClient>()).activeCalls(),
      present: (data) => widget.onIncomingCall(data),
      onError: (error) => debugPrint('Active call recovery failed: $error'),
    );
    final state = WidgetsBinding.instance.lifecycleState;
    _callRecovery!.update(
      userId: _userProvider?.user?.id,
      foreground: state == null || state == AppLifecycleState.resumed,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _onUserChanged();
    if (state == AppLifecycleState.resumed) {
      // Compact iOS CallKit answers may be delivered through the background
      // callback while the app is suspended. Consume that event when Flutter
      // becomes interactive so the accepted call is not immediately dropped.
      unawaited(NativeCallService.instance.consumePendingAcceptedCall());
      unawaited(NativeCallService.instance.syncVoipTokenWithBackend());
    }
  }

  @override
  void dispose() {
    _callRecovery?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _userProvider?.removeListener(_onUserChanged);
    _callStatusSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class TipNotificationListener extends StatefulWidget {
  final Widget child;
  const TipNotificationListener({super.key, required this.child});

  @override
  State<TipNotificationListener> createState() =>
      _TipNotificationListenerState();
}

class _TipNotificationListenerState extends State<TipNotificationListener> {
  StreamSubscription? _subscription;
  MessagingProvider? _messagingProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final messaging = Provider.of<MessagingProvider>(context);
    if (_messagingProvider != messaging) {
      _subscription?.cancel();
      _messagingProvider = messaging;
      _subscription = messaging.tipReceivedStream.listen(_onTipReceived);
    }
  }

  void _onTipReceived(Map<String, dynamic> data) {
    if (!mounted) return;

    final userProvider = context.read<UserProvider>();
    final walletProvider = context.read<WalletProvider>();

    final currentUserId = userProvider.user?.id;
    final senderId = data['senderUserId']?.toString();

    // Don't show toast to the sender (duplicates)
    if (senderId != null && senderId == currentUserId) return;

    final amount = data['amount']?.toString() ?? '0';
    final symbol = data['symbol']?.toString() ?? 'COWRIE';
    final fromName = data['senderName']?.toString() ?? 'Someone';

    NotificationService.showTipReceived(
      context,
      amount: amount,
      symbol: symbol,
      fromName: fromName,
    );

    // Also refresh wallet balance
    walletProvider.loadWallet(force: true);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Presents realtime Campfire changes in the same replacing, top-of-screen
/// toast used by other foreground activity. System push notifications remain
/// responsible for the background/terminated experience; this listener is
/// intentionally scoped to the Spaces/Campfire UI so public activity does not
/// interrupt unrelated parts of the app.
class CampfireNotificationListener extends StatefulWidget {
  final Widget child;

  const CampfireNotificationListener({super.key, required this.child});

  @override
  State<CampfireNotificationListener> createState() =>
      _CampfireNotificationListenerState();
}

class _CampfireNotificationListenerState
    extends State<CampfireNotificationListener> {
  StreamSubscription<Map<String, dynamic>>? _subscription;
  MessagingProvider? _messagingProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final messaging = context.read<MessagingProvider>();
    if (_messagingProvider == messaging) return;
    _subscription?.cancel();
    _messagingProvider = messaging;
    _subscription = messaging.campfireEventStream.listen(_onCampfireEvent);
  }

  void _onCampfireEvent(Map<String, dynamic> data) {
    if (!mounted) return;

    final type = data['type']?.toString() ?? '';
    final spaceId = (data['spaceId'] ?? data['space_id'] ?? data['campfireId'])
        ?.toString()
        .trim();
    final path = _safeCurrentRoutePath();
    final onCampfireDiscovery = path == '/campfires';
    // A call route is shared by direct, group, and Campfire calls. Only treat
    // it as a Campfire context when the event carries a concrete space id;
    // otherwise a public Campfire update must never interrupt a normal call,
    // chat, wallet, or any other screen.
    final onCampfireCall =
        path.startsWith('/calls/') && spaceId != null && spaceId.isNotEmpty;
    final activeCall = ActiveCallController.instance.request;
    final activeCampfireCall =
        onCampfireCall &&
        !ActiveCallController.instance.closing &&
        activeCall?.conversationType == 'space' &&
        activeCall?.conversationId == spaceId;
    if (!onCampfireDiscovery && !activeCampfireCall) return;

    // Socket Campfire events are broadcast to the messages namespace. Only
    // show participant/request activity for the room currently being viewed;
    // otherwise one public room would create toasts for every listener.
    final currentRoom = path.startsWith('/calls/')
        ? path.substring('/calls/'.length).split('/').first
        : null;
    if ((type == 'campfire_participants_changed' ||
            type == 'campfire_speaker_requested' ||
            type == 'campfire_ended' ||
            type == 'campfire_joined') &&
        // Participant activity is only relevant inside that exact Campfire.
        // Do not show join/leave/mute traffic on the discovery screen or for
        // another Campfire the user is not currently attending.
        (!activeCampfireCall ||
            currentRoom == null ||
            currentRoom != spaceId)) {
      return;
    }

    // The live room already reflects these events through its call-state
    // listeners. Keep the room quiet instead of stacking a toast on every
    // attendee; users outside the room can still receive the notification.
    if (activeCampfireCall &&
        currentRoom == spaceId &&
        const {
          'campfire_participants_changed',
          'campfire_speaker_requested',
          'campfire_ended',
          'campfire_joined',
        }.contains(type)) {
      return;
    }

    final currentUserId = context.read<UserProvider>().user?.id.toString();
    final recipients = data['recipientUserIds'] ?? data['recipient_user_ids'];
    if (recipients is List &&
        currentUserId != null &&
        !recipients.map((value) => value.toString()).contains(currentUserId)) {
      return;
    }
    final actorId = (data['userId'] ?? data['user_id'])?.toString();
    // The originator already sees the result locally; don't echo their own
    // join, leave, moderation, or speaker-request action as a toast.
    if (actorId != null && actorId.isNotEmpty && actorId == currentUserId) {
      return;
    }

    String title;
    String message;
    IconData icon;
    switch (type) {
      case 'campfire_speaker_requested':
        title = 'Request to speak';
        message = 'A listener wants to speak in this Campfire.';
        icon = Icons.record_voice_over_rounded;
      case 'campfire_participants_changed':
        final action = data['action']?.toString().toLowerCase();
        final actionText = switch (action) {
          'promote' || 'approve_speaker' => 'A participant is now speaking.',
          'demote' => 'A speaker moved back to listening.',
          'mute' => 'A participant was muted.',
          'unmute' => 'A participant was unmuted.',
          'remove' || 'block' => 'A participant left the Campfire.',
          _ => 'The participant list was updated.',
        };
        title = 'Campfire updated';
        message = actionText;
        icon = Icons.groups_rounded;
      case 'campfire_ended':
        title = 'Campfire ended';
        message = 'The host ended this Campfire.';
        icon = Icons.call_end_rounded;
      case 'campfire_created':
        // New public Campfires are discovery activity, not activity for an
        // already-open call. Keep this toast on the Campfires screen only.
        if (!onCampfireDiscovery) return;
        title = 'New Campfire live';
        message = 'A new public Campfire is available to join.';
        icon = Icons.local_fire_department_rounded;
      default:
        return;
    }

    NotificationService.showPush(
      context,
      title: title,
      message: message,
      icon: icon,
      onTap: () {
        if (type == 'campfire_ended') {
          AppRouter.router.go('/campfires');
          return;
        }
        if (spaceId != null && spaceId.isNotEmpty) {
          AppRouter.router.push(
            '/calls/$spaceId',
            extra: {
              'type': 'space',
              'mode': 'voice',
              'roomId': 'griot-space-$spaceId',
              'openParticipants': true,
            },
          );
        } else {
          AppRouter.router.go('/campfires');
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _AppLockOverlay extends StatefulWidget {
  const _AppLockOverlay();

  @override
  State<_AppLockOverlay> createState() => _AppLockOverlayState();
}

class _AppLockOverlayState extends State<_AppLockOverlay> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppLockProvider>(
      builder: (context, lockProvider, _) {
        // Do not let an asynchronous secure-storage read race with a route
        // rebuild (for example, changing the accent color). Until the stored
        // lock state is known, show one opaque surface instead of briefly
        // exposing the route and then unexpectedly launching biometric auth.
        if (!lockProvider.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If not locked, don't show the overlay.
        if (!lockProvider.isLocked) {
          return const SizedBox.shrink();
        }

        // Check if we're on a public onboarding/auth screen.
        // We use the router instance directly as this builder is outside the route context.
        final String location = _safeCurrentRoutePath();

        // Only routes that do not expose wallet/app data remain public while
        // locked. Password, recovery-phrase, biometric, and PIN routes must
        // not be allow-listed: a crafted deep link must not bypass the lock.
        final bool isPublicRoute =
            location == '/' ||
            location.startsWith('/login') ||
            location.startsWith('/create_account') ||
            location.startsWith('/recover_account') ||
            location.startsWith('/welcome_');

        if (isPublicRoute) {
          return const SizedBox.shrink();
        }

        // Cover the retained router and call host with the opaque PIN screen.
        // Unlock must not remount Router and replay a pending navigation.
        return PinVerificationScreen(
          showAppBar: false,
          autoBiometrics: true,
          title: 'App Locked',
          description: 'Please enter your PIN to continue.',
          onSuccess: (BuildContext ctx) async {
            final authController = ctx.read<AuthController>();
            if (!authController.hasValidSession) {
              await authController.authenticateWallet();
            }
            lockProvider.unlock();
          },
        );
      },
    );
  }
}
