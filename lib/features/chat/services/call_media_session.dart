import 'package:zego_express_engine/zego_express_engine.dart';
import 'realtime_call_service.dart';

/// Engine lifetime belongs to the app's call controller, never a route.
class CallMediaSession {
  bool created = false;
  String? roomId;
  Future<void>? _closing;
  final Set<String> streams = {};

  Future<void> create(RealtimeCallSession session) async {
    if (created) return;
    if (session.appId == 0) {
      throw StateError('Realtime calling is not configured.');
    }
    await ZegoExpressEngine.createEngineWithProfile(
      ZegoEngineProfile(session.appId, ZegoScenario.HighQualityChatroom),
    );
    created = true;
  }

  Future<void> join(RealtimeCallSession session) async {
    roomId = session.roomId;
    final config = ZegoRoomConfig.defaultConfig()
      ..token = session.token
      ..isUserStatusNotify = true;
    final result = await ZegoExpressEngine.instance.loginRoom(
      session.roomId,
      ZegoUser(session.userId, session.userId),
      config: config,
    );
    if (result.errorCode != 0) {
      throw StateError('Unable to join call (code ${result.errorCode}).');
    }
  }

  Future<void> publish(String userId) =>
      ZegoExpressEngine.instance.startPublishingStream(
        'griot-$userId-${DateTime.now().millisecondsSinceEpoch}',
      );

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    if (!created) return;
    ZegoExpressEngine.onRoomStreamUpdate = null;
    for (final stream in streams.toList()) {
      try {
        await ZegoExpressEngine.instance.stopPlayingStream(stream);
      } catch (_) {}
    }
    streams.clear();
    try {
      await ZegoExpressEngine.instance.stopPreview();
    } catch (_) {}
    try {
      await ZegoExpressEngine.instance.stopPublishingStream();
    } catch (_) {}
    if (roomId != null) {
      try {
        await ZegoExpressEngine.instance.logoutRoom(roomId!);
      } catch (_) {}
    }
    try {
      await ZegoExpressEngine.destroyEngine();
    } finally {
      created = false;
    }
  }
}
