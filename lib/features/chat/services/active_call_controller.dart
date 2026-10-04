import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../../core/network/api_client.dart';
import '../../../core/services/native_call_service.dart';
import 'messaging_api_service.dart';
import 'realtime_call_service.dart';
import 'call_media_session.dart';
import '../models/space_model.dart';

class CallRequest {
  const CallRequest({
    required this.conversationId,
    required this.conversationType,
    required this.mode,
    this.callId,
    this.session,
    this.roomId,
    this.openParticipants = false,
  });
  final String conversationId, conversationType, mode;
  final String? callId, roomId;
  final RealtimeCallSession? session;
  final bool openParticipants;
}

/// Owns the lifetime and presentation of the single app-level call host.
/// Navigation must never create another media owner for an existing call.
class ActiveCallController extends ChangeNotifier {
  static final instance = ActiveCallController();
  CallRequest? _request;
  CallRequest? get request => _request;
  bool _minimized = false;
  bool get minimized => _minimized;
  bool _closing = false;
  bool get closing => _closing;
  CallMediaSession? _media;
  CallMediaSession get media => _media!;
  final List<StreamSubscription<Map<String, dynamic>>> _subscriptions = [];
  Future<void>? _termination;
  String? callId;
  bool audioEnabled = true;
  bool videoEnabled = false;
  bool videoCallActive = false;
  List<SpaceParticipant> participants = const [];

  void listen(
    Stream<Map<String, dynamic>> stream,
    void Function(Map<String, dynamic>) handler,
  ) {
    _subscriptions.add(stream.listen(handler));
  }

  Future<void> end({
    required ApiClient api,
    required MessagingApiService messaging,
    required Future<void>? connecting,
    required String? Function() callId,
    required bool notifyServer,
    required bool timedOut,
  }) {
    return _termination ??= _end(
      api: api,
      messaging: messaging,
      connecting: connecting,
      callId: callId,
      notifyServer: notifyServer,
      timedOut: timedOut,
    );
  }

  Future<void> _end({
    required ApiClient api,
    required MessagingApiService messaging,
    required Future<void>? connecting,
    required String? Function() callId,
    required bool notifyServer,
    required bool timedOut,
  }) async {
    final request = _request;
    final media = _media;
    if (request == null || media == null) return;
    beginClose();
    try {
      for (final subscription in _subscriptions) {
        await subscription.cancel();
      }
      _subscriptions.clear();
      await connecting;
      final signaling = () async {
        final id = callId();
        if (id != null) {
          try {
            await NativeCallService.instance.end(id);
          } catch (error) {
            // Native UI dismissal must not skip authoritative server cleanup.
            debugPrint('Native call dismissal: $error');
          }
          if (notifyServer) {
            final calls = RealtimeCallService(api);
            if (request.conversationType != 'space') {
              if (timedOut) {
                await calls.updateStatus(id, 'missed');
              } else {
                await calls.leave(id);
              }
            }
          }
        }
        if (request.conversationType == 'space' && notifyServer) {
          await messaging.leaveCampfire(request.conversationId);
        }
      }();
      await Future.wait<void>([
        media.close(),
        signaling.timeout(const Duration(seconds: 15)),
      ]);
    } catch (error) {
      debugPrint('Call cleanup: $error');
    } finally {
      finishClose();
    }
  }

  bool open(CallRequest request) {
    if (_closing) return false;
    if (_request != null) {
      expand();
      return false;
    }
    _request = request;
    _termination = null;
    _media = CallMediaSession();
    callId = request.callId ?? request.session?.callId;
    audioEnabled = request.conversationType != 'space';
    videoCallActive = request.mode == 'video';
    videoEnabled = videoCallActive && request.conversationType != 'space';
    participants = const [];
    _minimized = false;
    notifyListeners();
    return true;
  }

  void minimize() {
    if (_request == null || _closing || _minimized) return;
    _minimized = true;
    notifyListeners();
  }

  void expand() {
    if (_request == null || _closing || !_minimized) return;
    _minimized = false;
    notifyListeners();
  }

  bool beginClose() {
    if (_closing || _request == null) return false;
    _closing = true;
    _minimized = true;
    notifyListeners();
    return true;
  }

  void finishClose() {
    _request = null;
    _media = null;
    callId = null;
    participants = const [];
    _closing = false;
    _minimized = false;
    notifyListeners();
  }
}
