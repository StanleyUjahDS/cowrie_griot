import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';

class RealtimeCallSession {
  final int appId;
  final String token;
  final String userId;
  final String roomId;
  final String? callId;
  final String contextType;
  final String? conversationId;
  final String mode;

  const RealtimeCallSession({
    required this.appId,
    required this.token,
    required this.userId,
    required this.roomId,
    this.callId,
    this.contextType = 'direct',
    this.conversationId,
    this.mode = 'voice',
  });
}

class RealtimeCallService {
  final ApiClient apiClient;
  RealtimeCallService(this.apiClient);

  Future<Map<String, dynamic>> history({
    int limit = 20,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    final response = await apiClient.get(
      '${ApiConfig.realtimeCalls}?limit=$limit&offset=$offset',
      forceRefresh: forceRefresh,
    );
    if (response is Map) {
      final nested = response['data'];
      if (nested is Map) return Map<String, dynamic>.from(nested);
      if (nested is List) return {'items': nested, 'hasMore': false};
      if (response['items'] is List) {
        return {
          'items': response['items'],
          'hasMore': response['hasMore'] == true,
        };
      }
    }
    return {'items': <dynamic>[], 'hasMore': false};
  }

  Future<List<Map<String, dynamic>>> activeCalls() async {
    final response = await apiClient.get(
      ApiConfig.realtimeActiveCalls,
      forceRefresh: true,
    );
    final data = (response['data'] as Map?)?.cast<String, dynamic>() ?? {};
    final items = data['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<String> createLink({
    required String roomId,
    required String contextType,
    String? conversationId,
    String mode = 'voice',
  }) async {
    final response = await apiClient.post(
      ApiConfig.realtimeCallLinks,
      body: {
        'roomId': roomId,
        'contextType': contextType,
        ...?(conversationId == null
            ? null
            : <String, String>{'conversationId': conversationId}),
        'mode': mode,
      },
    );
    final data = (response['data'] as Map?)?.cast<String, dynamic>() ?? {};
    final link = data['link']?.toString();
    if (link == null || link.isEmpty) {
      throw StateError('The call link was not created.');
    }
    return link;
  }

  Future<RealtimeCallSession> resolveLink(String invite) async {
    final response = await apiClient.post(
      ApiConfig.realtimeCallLinkResolve,
      body: {'invite': invite},
    );
    final data = (response['data'] as Map?)?.cast<String, dynamic>() ?? {};
    if ((data['token'] as String?)?.isNotEmpty != true) {
      throw StateError('This call link could not be joined.');
    }
    return RealtimeCallSession(
      appId: (data['appId'] as num?)?.toInt() ?? 0,
      token: data['token'] as String,
      userId: data['userId'] as String,
      roomId: data['roomId'] as String,
      callId: data['callId'] as String?,
      contextType: data['contextType']?.toString() ?? 'direct',
      conversationId: data['conversationId']?.toString(),
      mode: data['mode']?.toString() == 'video' ? 'video' : 'voice',
    );
  }

  Future<void> updateStatus(String callId, String status) async {
    await apiClient.patch(
      '${ApiConfig.realtimeCalls}/$callId',
      body: {'status': status},
    );
  }

  Future<void> leave(String callId) async {
    await apiClient.post('${ApiConfig.realtimeCalls}/$callId/leave');
  }

  Future<List<String>> inviteParticipants({
    required String callId,
    required List<String> userIds,
  }) async {
    final response = await apiClient.post(
      '${ApiConfig.realtimeCalls}/$callId/invite',
      body: {'userIds': userIds},
    );
    final data = (response['data'] as Map?)?.cast<String, dynamic>() ?? {};
    final invited = data['invited'];
    return invited is List
        ? invited.map((id) => id.toString()).toList()
        : const [];
  }

  Future<RealtimeCallSession> start({
    required String roomId,
    required String contextType,
    required String conversationId,
    String mode = 'voice',
    String? callId,
  }) async {
    final response = await apiClient.post(
      ApiConfig.realtimeToken,
      body: {
        'roomId': roomId,
        'contextType': contextType,
        'conversationId': conversationId,
        'mode': mode,
        'callId': ?callId,
      },
    );
    final data = (response['data'] as Map?)?.cast<String, dynamic>() ?? {};
    if ((data['token'] as String?)?.isNotEmpty != true) {
      throw StateError('Call authentication was not issued by the server.');
    }
    return RealtimeCallSession(
      appId: (data['appId'] as num?)?.toInt() ?? 0,
      token: data['token'] as String,
      userId: data['userId'] as String,
      roomId: data['roomId'] as String,
      callId: data['callId'] as String?,
      contextType: data['contextType']?.toString() ?? contextType,
      conversationId: data['conversationId']?.toString() ?? conversationId,
      mode: data['mode']?.toString() == 'video' ? 'video' : 'voice',
    );
  }
}
