import 'dart:async';

import 'package:zego_express_engine/zego_express_engine.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'realtime_call_service.dart';

/// Engine lifetime belongs to the app's call controller, never a route.
class CallMediaSession {
  static const _engineChannel = MethodChannel(
    'plugins.zego.im/zego_express_engine',
  );
  bool created = false;
  String? roomId;
  Future<void>? _closing;
  final Set<String> streams = {};
  bool screenSharing = false;

  Future<void> create(RealtimeCallSession session) async {
    if (created) return;
    if (session.appId == 0) {
      throw StateError('Realtime calling is not configured.');
    }
    await ZegoExpressEngine.createEngineWithProfile(
      ZegoEngineProfile(
        session.appId,
        // Campfires are one-to-many rooms: listeners should receive streams,
        // while only hosts/speakers publish. Keep ordinary calls on the
        // chatroom profile.
        session.contextType == 'space'
            ? ZegoScenario.Broadcast
            : ZegoScenario.HighQualityChatroom,
      ),
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

  Future<String> publish(String userId) async {
    final streamId = 'griot-$userId-${DateTime.now().millisecondsSinceEpoch}';
    await ZegoExpressEngine.instance.startPublishingStream(streamId);
    return streamId;
  }

  /// Starts ZEGO's native mobile screen-capture source and switches the
  /// existing publisher to it. The native Express plugin requests the
  /// Android MediaProjection/iOS ReplayKit permission when required.
  Future<void> startScreenSharing({bool inApp = false}) async {
    if (screenSharing) return;
    if (Platform.isIOS) {
      await _engineChannel.invokeMethod<void>(
        'setAppGroupIDScreenCaptureSource',
        {'groupID': 'group.com.griotcowrie.griot_cowrie'},
      );
    }
    // The native permission UI is asynchronous. Switching Zego's published
    // sources immediately after requesting capture races Android MediaProjection
    // and iOS ReplayKit, producing a subscribed stream with no video frames.
    final captureStarted = Completer<void>();
    final previousCaptureStart = ZegoExpressEngine.onMobileScreenCaptureStart;
    final previousCaptureError =
        ZegoExpressEngine.onMobileScreenCaptureExceptionOccurred;
    ZegoExpressEngine.onMobileScreenCaptureStart = () {
      previousCaptureStart?.call();
      if (!captureStarted.isCompleted) captureStarted.complete();
    };
    ZegoExpressEngine.onMobileScreenCaptureExceptionOccurred = (error) {
      previousCaptureError?.call(error);
      if (!captureStarted.isCompleted) {
        captureStarted.completeError(
          StateError('Screen capture failed (code ${error.index}).'),
        );
      }
    };
    try {
      await _engineChannel.invokeMethod<void>(
        'startCaptureScreenCaptureSource',
        {
          // false requests system-wide capture on iOS (ReplayKit) and
          // MediaProjection capture on Android. The native permission prompt
          // is shown by ZEGO.
          'inApp': inApp,
          'config': {
            'captureVideo': true,
            'captureAudio': true,
            'applicationVolume': 100,
            'microphoneVolume': 100,
            'orientation': ZegoScreenCaptureOrientation.Auto.index,
            'audioDeviceMode': ZegoScreenCaptureAudioDeviceMode.None.index,
            'audioParam': null,
            'cropRect': null,
            'muteExtensMicrophone': false,
          },
        },
      );
      await captureStarted.future.timeout(const Duration(seconds: 20));
    } finally {
      ZegoExpressEngine.onMobileScreenCaptureStart = previousCaptureStart;
      ZegoExpressEngine.onMobileScreenCaptureExceptionOccurred =
          previousCaptureError;
    }

    // ZEGO requires the audio source to be switched after capture has really
    // started. Doing it earlier is rejected on some devices and silently
    // leaves the remote screen stream empty.
    final audioSourceResult = await ZegoExpressEngine.instance.setAudioSource(
      ZegoAudioSourceType.ScreenCapture,
    );
    if (audioSourceResult != 0) {
      throw StateError(
        'Unable to enable shared-screen audio (code $audioSourceResult).',
      );
    }
    final result = await ZegoExpressEngine.instance.setVideoSource(
      ZegoVideoSourceType.ScreenCapture,
    );
    if (result != 0) {
      await _engineChannel.invokeMethod<void>('stopCaptureScreenCaptureSource');
      throw StateError(
        'Unable to switch the call to screen sharing (code $result).',
      );
    }
    screenSharing = true;
  }

  Future<void> stopScreenSharing() async {
    if (!screenSharing) {
      // A permission denial or native capture error can happen after the
      // audio source has already been switched. Always restore microphone
      // audio so the call does not become silent after a failed attempt.
      await ZegoExpressEngine.instance.setAudioSource(
        ZegoAudioSourceType.Microphone,
      );
      return;
    }
    await ZegoExpressEngine.instance.setVideoSource(ZegoVideoSourceType.Camera);
    await _engineChannel.invokeMethod<void>('stopCaptureScreenCaptureSource');
    await ZegoExpressEngine.instance.setAudioSource(
      ZegoAudioSourceType.Microphone,
    );
    screenSharing = false;
  }

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    if (!created) return;
    ZegoExpressEngine.onRoomStreamUpdate = null;
    ZegoExpressEngine.onPublisherStateUpdate = null;
    ZegoExpressEngine.onPlayerStateUpdate = null;
    ZegoExpressEngine.onAudioRouteChange = null;
    for (final stream in streams.toList()) {
      try {
        await ZegoExpressEngine.instance.stopPlayingStream(stream);
      } catch (_) {}
    }
    streams.clear();
    try {
      await stopScreenSharing();
    } catch (_) {}
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
