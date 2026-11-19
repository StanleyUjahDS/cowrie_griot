class ApiConfig {
  ApiConfig._();

  // Production backend. Staging remains available explicitly through
  // --dart-define=API_BASE_URL=... for development builds.
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.griot.network/api',
  );
  static String get baseUrl => _baseUrl;

  /// Namespace for local caches. Staging and production must never share
  /// account/session snapshots on the same device.
  static String get cacheNamespace =>
      _baseUrl == 'https://api.griot.network/api'
      ? 'production'
      : 'test-${_baseUrl.hashCode}';

  // ==========================================================
  // AUTHENTICATION
  // ==========================================================

  static String get authNonce => '$baseUrl/auth/nonce';
  static String get authVerify => '$baseUrl/auth/verify';
  static String get authRefresh => '$baseUrl/auth/refresh';
  static String get authLogout => '$baseUrl/auth/logout';

  // ==========================================================
  // NOTIFICATIONS
  // ==========================================================

  static String get notificationDevices => '$baseUrl/notifications/devices';
  static String get notificationVoipDevices =>
      '$baseUrl/notifications/voip-devices';

  static String get notificationDevicesAll =>
      '$baseUrl/notifications/devices/all';

  static String notificationActivity({int limit = 30, int offset = 0}) =>
      Uri.parse('$baseUrl/notifications/activity')
          .replace(queryParameters: {'limit': '$limit', 'offset': '$offset'})
          .toString();

  // ==========================================================
  // USERS
  // ==========================================================

  static String get usersMe => '$baseUrl/users/me';
  static String get usersUpdate => '$baseUrl/users/me';
  static String get userPolicyAcceptance =>
      '$baseUrl/users/me/policy-acceptance';
  static String get userPreferences => '$baseUrl/users/preferences';

  // ==========================================================
  // MEDIA (PRESIGNED FLOW)
  // ==========================================================

  static String get mediaPresign => '$baseUrl/media/presign';
  static String mediaComplete(String mediaId) =>
      '$baseUrl/media/$mediaId/complete';

  static String get stories => '$baseUrl/stories';
  static String storyView(String storyId) => '$stories/$storyId/view';
  static String storyViewers(String storyId) => '$stories/$storyId/viewers';
  static String story(String storyId) => '$stories/$storyId';

  static String usersSearch(String query, {int limit = 20, int offset = 0}) =>
      Uri.parse('$baseUrl/users/search')
          .replace(
            queryParameters: {
              'q': query,
              'limit': '$limit',
              'offset': '$offset',
            },
          )
          .toString();
  static String userById(String userId) => '$baseUrl/users/$userId';
  static String userByUsername(String username) =>
      '$baseUrl/users/username/${Uri.encodeComponent(username)}';

  static String usernameAvailability(String username) => Uri.parse(
    '$baseUrl/users/username/availability',
  ).replace(queryParameters: {'username': username}).toString();

  // ==========================================================
  // WALLET & ASSETS
  // ==========================================================

  static String get walletBase => '$baseUrl/crypto/wallets';
  static String get walletNetworks => '$walletBase/networks';
  static String get walletAssets => '$walletBase/assets';
  static String get walletNfts => '$walletBase/nfts';

  static String get cryptoAssetsBase => '$baseUrl/crypto/assets';

  static String walletFlashLookup(String query) => Uri.parse(
    '$cryptoAssetsBase/flash',
  ).replace(queryParameters: {'q': query}).toString();

  static String walletAssetsSearch(String query, {String? network}) {
    final params = {'q': query};
    if (network != null && network.isNotEmpty) {
      params['network'] = network;
    }
    return Uri.parse(
      '$cryptoAssetsBase/search',
    ).replace(queryParameters: params).toString();
  }

  static String walletAssetsPopular({String? network}) {
    final params = <String, String>{};
    if (network != null && network.isNotEmpty) params['network'] = network;
    return Uri.parse(
      '$cryptoAssetsBase/popular',
    ).replace(queryParameters: params).toString();
  }

  static String walletAssetsByNetwork(String network) =>
      '$walletBase/assets/$network';

  static String walletCustomToken(String network, String tokenAddress) =>
      '$walletBase/custom-token/$network/$tokenAddress';

  static String walletNativeBalance(String network) =>
      '$walletBase/balance/$network';

  static String get walletNativeBalances => '$walletBase/balances';

  static String get walletTokens => '$walletBase/tokens';

  static String walletActivity({int limit = 20, String? pageKey}) {
    final query = <String, String>{'limit': '$limit'};
    if (pageKey != null && pageKey.isNotEmpty) {
      query['pageKey'] = pageKey;
    }
    return Uri.parse(
      '$walletBase/activity',
    ).replace(queryParameters: query).toString();
  }

  // ==========================================================
  // TRANSACTIONS
  // ==========================================================

  static String get transactionBase => '$baseUrl/crypto/transactions';

  static String get prepareNativeTransaction =>
      '$transactionBase/prepare-native';

  static String get prepareTokenTransaction => '$transactionBase/prepare-token';

  static String get estimateTransaction => '$transactionBase/estimate';

  static String get broadcastTransaction => '$transactionBase/broadcast';

  static String transactionStatus(String transactionId, String network) =>
      Uri.parse(
        '$transactionBase/id/$transactionId/status',
      ).replace(queryParameters: {'network': network}).toString();

  static String transactionById(String transactionId) =>
      '$transactionBase/id/$transactionId';

  static String transactionHistory({
    String? walletAccountId,
    String? network,
    int limit = 20,
    int offset = 0,
  }) {
    final query = <String, String>{'limit': '$limit', 'offset': '$offset'};

    if (walletAccountId != null && walletAccountId.isNotEmpty) {
      query['walletAccountId'] = walletAccountId;
    }

    if (network != null && network.isNotEmpty) {
      query['network'] = network;
    }

    return Uri.parse(
      '$transactionBase/history',
    ).replace(queryParameters: query).toString();
  }

  // ==========================================================
  // SWAP
  // ==========================================================

  static String get swapBase => '$baseUrl/crypto/swap';

  static String get swapQuote => '$swapBase/quote';

  static String get swapBroadcast => '$swapBase/broadcast';

  static String swapStatus({
    required String transactionId,
    String? provider,
    String? fromChain,
    String? toChain,
    String? bridge,
    String? quoteId,
    String? fromAddress,
    String? swapType,
  }) {
    final query = <String, String>{'transactionId': transactionId};

    if (provider != null && provider.isNotEmpty) {
      query['provider'] = provider;
    }

    if (fromChain != null && fromChain.isNotEmpty) {
      query['fromChain'] = fromChain;
    }

    if (toChain != null && toChain.isNotEmpty) {
      query['toChain'] = toChain;
    }

    if (bridge != null && bridge.isNotEmpty) {
      query['bridge'] = bridge;
    }

    if (quoteId != null && quoteId.isNotEmpty) {
      query['quoteId'] = quoteId;
    }

    if (fromAddress != null && fromAddress.isNotEmpty) {
      query['fromAddress'] = fromAddress;
    }

    if (swapType != null && swapType.isNotEmpty) {
      query['swapType'] = swapType;
    }

    return Uri.parse(
      '$swapBase/status',
    ).replace(queryParameters: query).toString();
  }

  static String swapReceipt({required String network, required String hash}) =>
      Uri.parse(
        '$swapBase/receipt',
      ).replace(queryParameters: {'network': network, 'hash': hash}).toString();

  static String get swapHealth => '$swapBase/health';

  // ==========================================================
  // MINING
  // ==========================================================

  static String get miningBase => '$baseUrl/crypto/mining';

  static String get miningStatus => '$miningBase/status';

  static String get miningStart => '$miningBase/start';

  static String get miningActivities => '$miningBase/activities';

  static String miningHistory({int limit = 20, int offset = 0}) =>
      Uri.parse('$miningBase/history')
          .replace(queryParameters: {'limit': '$limit', 'offset': '$offset'})
          .toString();

  // ==========================================================
  // BLOCKCHAIN
  // ==========================================================

  static String get blockchainBase => '$baseUrl/crypto/blockchain';

  static String blockchainNonce(String network, String address) {
    final formattedAddress = address.startsWith('0x') ? address : '0x$address';
    return '$blockchainBase/nonce/$network/$formattedAddress';
  }

  static String blockchainCall(String network) =>
      '$blockchainBase/call/$network';

  static String blockchainReceipt(String network, String hash) =>
      '$blockchainBase/receipt/$network/$hash';

  // ==========================================================
  // REFERRALS & REPUTATION
  // ==========================================================

  static String get referralBase => '$baseUrl/referrals';

  static String get referralMe => '$referralBase/me';
  static String get referralClaim => '$referralBase/claim';

  static String get reputationBase => '$baseUrl/reputation';
  static String get reputationMe => '$reputationBase/me';

  // ==========================================================
  // MESSAGING
  // ==========================================================

  static String get messagingBase => '$baseUrl/messaging';
  static String get realtimeToken => '$baseUrl/realtime/token';
  static String get realtimeCalls => '$baseUrl/realtime/calls';
  static String get realtimeActiveCalls => '$baseUrl/realtime/calls/active';
  static String get realtimeCallLinks => '$baseUrl/realtime/call-links';
  static String get realtimeCallLinkResolve =>
      '$baseUrl/realtime/call-links/resolve';

  static String get messagingDirect => '$messagingBase/direct';

  static String get messagingConversations => '$messagingBase/conversations';

  static String messagingDirectList() => messagingConversations;

  static String messagingDirectFind(String otherUserId) =>
      '$messagingDirect/find/$otherUserId';

  static String messagingDirectById(String conversationId) =>
      '$messagingDirect/$conversationId';

  static String messagingDirectOtherUser(String conversationId) =>
      '$messagingDirect/$conversationId/other-user';

  static String messagingDirectMembers(String conversationId) =>
      '$messagingDirect/$conversationId/members';

  static String messagingDirectMembership(String conversationId) =>
      '$messagingDirect/$conversationId/membership';

  static String get messagingMessages => '$messagingBase/messages';

  static String messagingMessagesByConversation(
    String conversationId, {
    int limit = 50,
    String? before,
  }) {
    final query = <String, String>{'limit': '$limit'};
    if (before != null && before.isNotEmpty) {
      query['before'] = before;
    }
    return Uri.parse(
      '$messagingMessages/conversation/$conversationId',
    ).replace(queryParameters: query).toString();
  }

  static String messagingMessageById(String messageId) =>
      '$messagingMessages/$messageId';

  static String messagingConversationRead(String conversationId) =>
      '$messagingMessages/conversation/$conversationId/read';

  static String messagingConversationMessagePin(
    String conversationId,
    String messageId,
  ) =>
      '$messagingMessages/conversation/$conversationId/messages/$messageId/pin';

  static String messagingConversationPinned(String conversationId) =>
      '$messagingMessages/conversation/$conversationId/pinned';

  static String get messagingRequests => '$messagingBase/requests';

  static String get messagingRequestsReceived => '$messagingRequests/received';

  static String get messagingRequestsSent => '$messagingRequests/sent';

  static String get messagingFriends => '$messagingBase/friends';
  static String get messagingFriendsPage => '$messagingFriends/page';
  static String get messagingFriendsCount => '$messagingFriends/count';

  static String messagingFriendsSearch(
    String query, {
    int limit = 20,
    int offset = 0,
  }) => Uri.parse('$messagingFriends/search')
      .replace(
        queryParameters: {'q': query, 'limit': '$limit', 'offset': '$offset'},
      )
      .toString();

  static String messagingFriendsPaged({int limit = 20, int offset = 0}) =>
      Uri.parse(messagingFriendsPage)
          .replace(queryParameters: {'limit': '$limit', 'offset': '$offset'})
          .toString();

  static String messagingFriendById(String friendId) =>
      '$messagingFriends/$friendId';

  static String get messagingBlocks => '$messagingBase/blocks';
  static String messagingBlockUser(String userId) => '$messagingBlocks/$userId';
  static String get messagingMutes => '$messagingBlocks/mutes';
  static String messagingMuteUser(String userId) =>
      '$messagingBlocks/mute/$userId';
  static String messagingUnrecordedCampfires(String userId) =>
      '$messagingBase/camp-profiles/$userId/campfires/unrecorded';

  static String get messagingReports => '$messagingBase/reports';

  static String messagingRequestById(String requestId) =>
      '$messagingRequests/$requestId';

  static String messagingRequestAccept(String requestId) =>
      '$messagingRequests/$requestId/accept';

  static String messagingRequestDecline(String requestId) =>
      '$messagingRequests/$requestId/decline';

  static String messagingRequestCancel(String requestId) =>
      '$messagingRequests/$requestId/cancel';

  static String messagingReceipts(String messageId) =>
      '$messagingMessages/$messageId/receipts';

  static String messagingReactions(String messageId) =>
      '$messagingMessages/$messageId/reactions';

  // ==========================================================
  // PLUS SUBSCRIPTION
  // ==========================================================

  static String get plusBase => '$baseUrl/plus';
  static String get plusStatus => '$plusBase/status';
  static String get plusVerify => '$plusBase/purchases/verify';
  static String get plusCryptoCatalog => '$plusBase/crypto/catalog';
  static String get plusCryptoInvoices => '$plusBase/crypto/invoices';
  static String plusCryptoInvoiceVerify(String invoiceId) =>
      '$plusCryptoInvoices/$invoiceId/verify';
  static String plusCryptoGiftClaim(String invoiceId) =>
      '$plusBase/crypto/gifts/$invoiceId/claim';

  // ==========================================================
  // GRIOT GOLDS
  // ==========================================================

  static String get goldsBase => '$baseUrl/golds';
  static String get goldsCatalog => '$goldsBase/catalog';
  static String get goldsBalance => '$goldsBase/balance';
  static String get goldsTips => '$goldsBase/tips';
  static String get goldsPlus => '$goldsBase/plus';

  // ==========================================================
  // GROUPS & CHANNELS
  // ==========================================================

  static String get messagingGroups => '$messagingBase/groups';
  static String messagingCampfires({
    int limit = 20,
    int offset = 0,
    String region = 'GLOBAL',
  }) => Uri.parse('$messagingBase/campfires')
      .replace(
        queryParameters: {
          'limit': '$limit',
          'offset': '$offset',
          'region': region,
        },
      )
      .toString();
  static String get messagingCampfiresCreate => '$messagingBase/campfires';
  static String messagingCampfiresConversation(String conversationId) =>
      '$messagingBase/campfires/conversation/${Uri.encodeComponent(conversationId)}';
  static String messagingCampfiresUpcoming({
    int limit = 10,
    int offset = 0,
    String region = 'GLOBAL',
  }) => Uri.parse('$messagingBase/campfires/upcoming')
      .replace(
        queryParameters: {
          'limit': '$limit',
          'offset': '$offset',
          'region': region,
        },
      )
      .toString();
  static String messagingCampfireJoin(String id) =>
      '$messagingBase/campfires/$id/join';
  static String messagingCampfireLeave(String id) =>
      '$messagingBase/campfires/$id/leave';
  static String messagingCampfireHeartbeat(String id) =>
      '$messagingBase/campfires/$id/heartbeat';
  static String messagingCampfireParticipants(String id) =>
      '$messagingBase/campfires/$id/participants';
  static String messagingCampfireComments(String id) =>
      '$messagingBase/campfires/$id/comments';
  static String messagingCampfireComment(String id, String commentId) =>
      '$messagingBase/campfires/$id/comments/$commentId';
  static String messagingCampfireRequestSpeaker(String id) =>
      '$messagingBase/campfires/$id/request-speaker';
  static String messagingCampfireModerateParticipant(
    String campfireId,
    String userId,
  ) => '$messagingBase/campfires/$campfireId/participants/$userId';
  static String messagingCampfireEnd(String id) =>
      '$messagingBase/campfires/$id/end';
  static String messagingCampfireReminder(String id) =>
      '$messagingBase/campfires/$id/reminder';

  static String get messagingCampProfiles => '$messagingBase/camp-profiles';
  static String messagingCampProfile(String userId) =>
      '$messagingCampProfiles/${Uri.encodeComponent(userId)}';
  static String messagingCampProfileTales(String userId) =>
      '${messagingCampProfile(userId)}/tales';
  static String messagingCampProfileCampfires(
    String userId, {
    String status = 'all',
    int limit = 20,
    int offset = 0,
  }) => Uri.parse('${messagingCampProfile(userId)}/campfires')
      .replace(
        queryParameters: {
          'status': status,
          'limit': '$limit',
          'offset': '$offset',
        },
      )
      .toString();
  static String messagingCampProfileActivity(
    String userId, {
    String filter = 'all',
    int limit = 20,
    int offset = 0,
  }) => Uri.parse('${messagingCampProfile(userId)}/activity')
      .replace(
        queryParameters: {
          'filter': filter,
          'limit': '$limit',
          'offset': '$offset',
        },
      )
      .toString();
  static String messagingCampProfileFollow(String userId) =>
      '${messagingCampProfile(userId)}/follow';
  static String messagingCampProfileFollowers(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) => Uri.parse('${messagingCampProfile(userId)}/followers')
      .replace(queryParameters: {'limit': '$limit', 'offset': '$offset'})
      .toString();
  static String messagingCampProfileFollowing(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) => Uri.parse('${messagingCampProfile(userId)}/following')
      .replace(queryParameters: {'limit': '$limit', 'offset': '$offset'})
      .toString();
  static String messagingCampProfileKudos(String userId) =>
      '${messagingCampProfile(userId)}/kudos';
  static String get messagingCampProfileSearch =>
      '$messagingCampProfiles/search';
  static String get messagingCampProfileSaves => '$messagingCampProfiles/saves';
  static String get messagingCampProfileMe => '$messagingCampProfiles/me';
  static String messagingCampfireRecordings({int limit = 20, int offset = 0}) =>
      Uri.parse('$messagingCampProfiles/recordings')
          .replace(queryParameters: {'limit': '$limit', 'offset': '$offset'})
          .toString();
  static String messagingCampfireRecordingComments(String recordingId) =>
      '$messagingCampProfiles/recordings/$recordingId/comments';
  static String messagingCampfireRecordingComment(
    String recordingId,
    String commentId,
  ) => '$messagingCampProfiles/recordings/$recordingId/comments/$commentId';
  static String get messagingTales => '$messagingBase/tales';
  static String publicTale(String taleId) => '$baseUrl/public/tales/$taleId';
  static String messagingTalesFeed({
    String feed = 'public',
    String? category,
    String? cursor,
    int limit = 20,
  }) => Uri.parse(messagingTales)
      .replace(
        queryParameters: {
          'feed': feed,
          'limit': '$limit',
          if (category != null && category.isNotEmpty) 'category': category,
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        },
      )
      .toString();
  static String messagingTale(String taleId) => '$messagingTales/$taleId';
  static String get messagingTaleBookmarks => '$messagingTales/bookmarks';
  static String messagingTaleBookmark(String taleId) =>
      '$messagingTaleBookmarks/$taleId';
  static String messagingTaleComments(String taleId) =>
      '${messagingTale(taleId)}/comments';
  static String messagingTaleComment(String taleId, String commentId) =>
      '${messagingTaleComments(taleId)}/$commentId';
  static String messagingTaleCommentVote(String taleId, String commentId) =>
      '${messagingTaleComments(taleId)}/$commentId/vote';
  static String messagingTaleView(String taleId) =>
      '${messagingTale(taleId)}/view';
  static String messagingTaleVote(String taleId) =>
      '${messagingTale(taleId)}/vote';
  static String messagingTaleBoost(String taleId) =>
      '${messagingTale(taleId)}/boost';

  static String messagingConversationById(String conversationId) =>
      '$messagingBase/conversations/$conversationId';

  static String messagingGroupById(String conversationId) =>
      '$messagingGroups/$conversationId';

  static String messagingGroupByUsername(String username) =>
      '$messagingGroups/username/${Uri.encodeComponent(username)}';

  static String messagingGroupJoin(String conversationId) =>
      '$messagingGroups/$conversationId/join';

  static String messagingGroupMembers(String conversationId) =>
      '$messagingGroups/$conversationId/members';

  static String messagingGroupMemberById(
    String conversationId,
    String userId,
  ) => '$messagingGroups/$conversationId/members/$userId';

  static String messagingGroupLeave(String conversationId) =>
      '$messagingGroups/$conversationId/leave';

  static String messagingGroupDelete(String conversationId) =>
      '$messagingGroups/$conversationId';

  static String messagingGroupsDiscover(
    String query, {
    int page = 1,
    int limit = 20,
  }) => Uri.parse('$messagingGroups/discover')
      .replace(
        queryParameters: {'q': query, 'page': '$page', 'limit': '$limit'},
      )
      .toString();

  static String get messagingChannels => '$messagingBase/channels';
  static String get messagingChannelsMe => '$messagingChannels/me';

  static String messagingChannelById(String conversationId) =>
      '$messagingChannels/$conversationId';

  static String messagingChannelByUsername(String username) =>
      '$messagingChannels/username/${Uri.encodeComponent(username)}';

  static String messagingChannelSubscribe(String conversationId) =>
      '$messagingChannels/$conversationId/subscribe';

  static String messagingChannelPosts(String conversationId) =>
      '$messagingChannels/$conversationId/posts';

  static String messagingChannelPostReactions(
    String conversationId,
    String postId,
  ) => '$messagingChannels/$conversationId/posts/$postId/reactions';

  static String messagingChannelComments(
    String conversationId,
    String postId,
  ) => '$messagingChannels/$conversationId/posts/$postId/comments';

  static String messagingChannelsDiscover(
    String query, {
    int page = 1,
    int limit = 20,
  }) => Uri.parse('$messagingChannels/discover')
      .replace(
        queryParameters: {'q': query, 'page': '$page', 'limit': '$limit'},
      )
      .toString();

  // ==========================================================
  // TIPS
  // ==========================================================

  static String get tipBase => '$baseUrl/crypto/tips';
  static String get tipConfig => '$tipBase/config';
  static String get tipPrepare => '$tipBase/prepare';
  static String get tipBroadcast => '$tipBase/broadcast';
}
