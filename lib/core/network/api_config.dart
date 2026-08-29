import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  // ==========================================================
  // BASE URL
  // ==========================================================
  //
  // For local development:
  // - Android uses 'localhost' (requires: adb reverse tcp:5001 tcp:5001)
  // - iOS and others use the local IP address
  //
  // ==========================================================

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5001/api';
    }

    if (Platform.isAndroid) {
      // For physical device, use your host IP (192.168.1.95)
      // For emulator, use 10.0.2.2
      return 'http://192.168.1.95:5001/api';
    }

    return 'http://192.168.1.95:5001/api';
  }

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

  static String get notificationDevicesAll =>
      '$baseUrl/notifications/devices/all';

  // ==========================================================
  // USERS
  // ==========================================================

  static String get usersMe => '$baseUrl/users/me';
  static String get usersUpdate => '$baseUrl/users/me';

  static String usersSearch(String query) => Uri.parse(
    '$baseUrl/users/search',
  ).replace(queryParameters: {'q': query}).toString();

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

  // ==========================================================
  // TRANSACTIONS
  // ==========================================================

  static String get transactionBase => '$baseUrl/crypto/transactions';

  static String get prepareNativeTransaction =>
      '$transactionBase/prepare-native';

  static String get prepareTokenTransaction =>
      '$transactionBase/prepare-token';

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

  static String miningHistory({int limit = 20, int offset = 0}) =>
      Uri.parse('$miningBase/history')
          .replace(queryParameters: {'limit': '$limit', 'offset': '$offset'})
          .toString();

  // ==========================================================
  // BLOCKCHAIN
  // ==========================================================

  static String get blockchainBase => '$baseUrl/crypto/blockchain';

  static String blockchainNonce(String network, String address) =>
      '$blockchainBase/nonce/$network/$address';

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

  static String get messagingDirect => '$messagingBase/direct';

  static String get messagingConversations => '$messagingBase/conversations';

  static String messagingDirectList() => messagingConversations;

  static String messagingDirectFind(String otherUserId) =>
      '$messagingDirect/find/$otherUserId';

  static String messagingDirectById(String conversationId) =>
      '$messagingDirect/$conversationId';

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

  static String get messagingRequests => '$messagingBase/requests';

  static String get messagingRequestsReceived => '$messagingRequests/received';

  static String get messagingRequestsSent => '$messagingRequests/sent';

  static String get messagingFriends => '$messagingBase/friends';
  static String get messagingFriendsPage => '$messagingFriends/page';
  static String get messagingFriendsCount => '$messagingFriends/count';

  static String messagingFriendsSearch(String query, {int limit = 20, int offset = 0}) => Uri.parse(
    '$messagingFriends/search',
  ).replace(queryParameters: {
    'q': query,
    'limit': '$limit',
    'offset': '$offset',
  }).toString();

  static String messagingFriendsPaged({int limit = 20, int offset = 0}) => Uri.parse(
    messagingFriendsPage,
  ).replace(queryParameters: {
    'limit': '$limit',
    'offset': '$offset',
  }).toString();

  static String messagingFriendById(String friendId) =>
      '$messagingFriends/$friendId';

  static String get messagingBlocks => '$messagingBase/blocks';
  static String messagingBlockUser(String userId) => '$messagingBlocks/$userId';

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
  // GROUPS & CHANNELS
  // ==========================================================

  static String get messagingGroups => '$messagingBase/groups';

  static String messagingGroupById(String conversationId) =>
      '$messagingGroups/$conversationId';

  static String messagingGroupMembers(String conversationId) =>
      '$messagingGroups/$conversationId/members';

  static String get messagingChannels => '$messagingBase/channels';
  static String get messagingChannelsMe => '$messagingChannels/me';

  static String messagingChannelById(String conversationId) =>
      '$messagingChannels/$conversationId';

  static String messagingChannelSubscribe(String conversationId) =>
      '$messagingChannels/$conversationId/subscribe';
}
