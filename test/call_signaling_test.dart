import 'package:flutter_test/flutter_test.dart';
import 'package:griot_cowrie/core/network/api_client.dart';
import 'package:griot_cowrie/features/chat/services/active_call_controller.dart';
import 'package:griot_cowrie/features/chat/services/messaging_api_service.dart';
import 'package:griot_cowrie/features/chat/services/realtime_call_service.dart';

class _Api extends Fake implements ApiClient {
  final requests = <String>[];
  Map<String, dynamic>? lastBody;
  @override
  Future<dynamic> post(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    requests.add(url);
    lastBody = body;
    return {
      'data': {
        'appId': 1,
        'token': 'token',
        'userId': 'me',
        'roomId': 'room',
        'callId': 'existing',
      },
    };
  }
}

class _Messaging extends Fake implements MessagingApiService {
  int leaves = 0;
  @override
  Future<void> leaveCampfire(String id) async {
    leaves++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Campfire raise and lower hand use the same request endpoint', () async {
    final api = _Api();
    final service = MessagingApiService(apiClient: api);
    await service.requestCampfireSpeaker('room');
    expect(api.lastBody?['raised'], true);
    await service.requestCampfireSpeaker('room', raised: false);
    expect(api.lastBody?['raised'], false);
    expect(api.requests[0], api.requests[1]);
  });
  test(
    'Campfire minimize and Return do not leave; explicit leave runs once',
    () async {
      final owner = ActiveCallController();
      final messaging = _Messaging();
      owner.open(
        const CallRequest(
          conversationId: 'room',
          conversationType: 'space',
          mode: 'voice',
        ),
      );
      owner.minimize();
      owner.expand();
      expect(messaging.leaves, 0);
      Future<void> leave() => owner.end(
        api: _Api(),
        messaging: messaging,
        connecting: null,
        callId: () => null,
        notifyServer: true,
        timedOut: false,
      );
      await Future.wait([leave(), leave()]);
      expect(messaging.leaves, 1);
      expect(owner.request, isNull);
      owner.dispose();
    },
  );
  test('answer token request identifies the existing call', () async {
    final api = _Api();
    await RealtimeCallService(api).start(
      roomId: 'room',
      contextType: 'direct',
      conversationId: 'conversation',
      callId: 'existing',
    );
    expect(api.lastBody?['callId'], 'existing');
  });
  for (final type in ['direct', 'group', 'public']) {
    test('$type hangup delegates departure rules to backend once', () async {
      final api = _Api();
      final owner = ActiveCallController();
      owner.open(
        CallRequest(
          conversationId: 'room',
          conversationType: type,
          mode: 'voice',
          callId: 'existing',
        ),
      );
      Future<void> end() => owner.end(
        api: api,
        messaging: _Messaging(),
        connecting: null,
        callId: () => 'existing',
        notifyServer: true,
        timedOut: false,
      );
      await Future.wait([end(), end()]);
      expect(api.requests, hasLength(1));
      expect(api.requests.single, endsWith('/existing/leave'));
      expect(owner.request, isNull);
      owner.dispose();
    });
  }
}
