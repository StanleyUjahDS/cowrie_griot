import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../network/api_config.dart';
import '../../features/auth/services/auth_storage_service.dart';

/// Bridges Griot's call signalling to the platform call UI.
///
/// Zego remains responsible for the media session. This service only owns
/// ringing, accept/decline/end actions, and the metadata needed to route the
/// user back to the correct conversation.
class NativeCallService {
  NativeCallService._();
  static final NativeCallService instance = NativeCallService._();

  StreamSubscription<CallEvent?>? _eventsSubscription;
  ApiClient? _apiClient;
  Future<void> Function(Map<String, dynamic> data)? _onAccepted;
  String? _voipToken;
  String? _voipDeviceId;
  bool _initialized = false;
  final Set<String> _presentedCallIds = <String>{};
  final Set<String> _acceptedCallIds = <String>{};
  final Map<String, DateTime> _acceptedAt = <String, DateTime>{};

  Future<void> initialize({
    ApiClient? apiClient,
    Future<void> Function(Map<String, dynamic> data)? onAccepted,
  }) async {
    _apiClient = apiClient ?? _apiClient;
    _onAccepted = onAccepted ?? _onAccepted;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      const channel = MethodChannel('griot/native_calls');
      channel.setMethodCallHandler((call) async {
        if (call.method == 'voipTokenUpdated') {
          await _handleVoipToken(call.arguments?.toString());
        }
      });
      try {
        final device = await channel.invokeMapMethod<String, dynamic>(
          'getVoipToken',
        );
        _voipDeviceId = device?['deviceId']?.toString();
        final token = device?['token']?.toString();
        if (token != null && token.isNotEmpty) await _handleVoipToken(token);
      } on MissingPluginException {
        debugPrint('NativeCallService: iOS VoIP token channel is unavailable.');
      } catch (error) {
        debugPrint('NativeCallService: unable to read VoIP token: $error');
      }
    }
    if (_initialized) {
      // The iOS compact CallKit banner can answer while the app is already
      // suspended. Its background callback stores the accepted call, so make
      // sure a later resume (or a second initialization) consumes it instead
      // of leaving CallKit answered with no Flutter media session.
      unawaited(consumePendingAcceptedCall());
      unawaited(syncVoipTokenWithBackend());
      return;
    }
    _initialized = true;

    try {
      _eventsSubscription = FlutterCallkitIncoming.onEvent.listen(
        _handleEvent,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('NativeCallService: event error: $error');
        },
      );

      // This keeps plugin callbacks safe when the app is backgrounded or
      // terminated. The actual iOS terminated-state wake-up additionally
      // requires PushKit and an APNs VoIP credential on the backend.
      await FlutterCallkitIncoming.onBackgroundMessage(
        handleNativeCallBackgroundEvent,
      );
      FlutterCallkitIncoming.acceptCallHandle(
        handleNativeCallAcceptInBackground,
      );

      if (defaultTargetPlatform == TargetPlatform.android) {
        await FlutterCallkitIncoming.requestNotificationPermission({
          'title': 'Allow Griot calls',
          'rationaleMessagePermission':
              'Griot needs notification permission to ring for incoming calls.',
          'postNotificationMessageRequired':
              'Enable notifications for Griot in Android Settings to receive calls.',
        });
        final canUseFullScreen =
            await FlutterCallkitIncoming.canUseFullScreenIntent();
        debugPrint(
          'NativeCallService: Android notification/full-screen permission '
          'ready=$canUseFullScreen',
        );
        if (!canUseFullScreen) {
          await FlutterCallkitIncoming.requestFullIntentPermission();
        }
      }

      await consumePendingAcceptedCall();
    } catch (error, stackTrace) {
      // The existing in-app incoming-call screen remains the safe fallback if
      // a device/OS does not support the native plugin.
      debugPrint('NativeCallService: initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    unawaited(syncVoipTokenWithBackend());
  }

  Future<void> _handleVoipToken(String? token) async {
    final normalized = token?.trim();
    if (normalized == null || normalized.isEmpty) {
      final previousToken = _voipToken;
      _voipToken = null;
      if (previousToken != null) {
        unawaited(_unregisterVoipToken(previousToken));
      }
      return;
    }
    _voipToken = normalized.toLowerCase();
    unawaited(syncVoipTokenWithBackend());
  }

  Future<void> syncVoipTokenWithBackend() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    final apiClient = _apiClient;
    final token = _voipToken;
    if (apiClient == null || token == null || token.isEmpty) return;
    try {
      final accessToken = await AuthStorageService().getAccessToken();
      if (accessToken == null || accessToken.isEmpty) return;
      await apiClient.post(
        ApiConfig.notificationVoipDevices,
        body: {'token': token, 'deviceId': _voipDeviceId},
      );
    } catch (error) {
      debugPrint('NativeCallService: VoIP token registration deferred: $error');
    }
  }

  Future<void> unregisterCurrentVoipDevice() async {
    final token = _voipToken;
    if (token == null || token.isEmpty) return;
    await _unregisterVoipToken(token);
  }

  Future<void> _unregisterVoipToken(String token) async {
    final apiClient = _apiClient;
    if (apiClient == null || token.isEmpty) return;
    try {
      await apiClient.delete(
        ApiConfig.notificationVoipDevices,
        body: {'token': token},
      );
    } catch (error) {
      debugPrint('NativeCallService: VoIP token unregister failed: $error');
    }
  }

  Future<void> showIncoming(Map<String, dynamic> rawData) async {
    final data = Map<String, dynamic>.from(rawData);
    final callId = _string(data['callId']);
    if (callId == null || callId.isEmpty) {
      debugPrint('NativeCallService: incoming call has no callId');
      return;
    }
    if (_presentedCallIds.contains(callId)) return;
    try {
      final active = await FlutterCallkitIncoming.activeCalls();
      if (active.any((call) => call.id == callId)) {
        _presentedCallIds.add(callId);
        return;
      }
    } catch (error) {
      debugPrint('NativeCallService: active call lookup failed: $error');
    }
    _presentedCallIds.add(callId);

    final isVideo = (_string(data['mode']) ?? 'voice') == 'video';
    // CallKit's compact banner has very little horizontal space. Keep the
    // native header readable on iOS/Android while retaining the complete
    // caller name in `extra` for the in-app call screen.
    final callerName = _compactNativeLabel(
      _string(data['callerName']) ?? 'Griot contact',
    );
    final handle = _compactNativeLabel(
      _string(data['callerHandle']) ?? callerName,
    );
    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'Griot',
      handle: handle,
      type: isVideo ? 1 : 0,
      duration: 45000,
      extra: {...data, 'type': 'incoming_call', 'callId': callId},
      android: const AndroidParams(
        isCustomNotification: true,
        isCustomSmallExNotification: true,
        isShowFullLockedScreen: true,
        isFullScreen: true,
        isImportant: true,
        ringtonePath: 'system_ringtone_default',
        incomingCallNotificationChannelName: 'Incoming calls',
        missedCallNotificationChannelName: 'Missed calls',
        backgroundColor: '#101214',
        actionColor: '#3DBB68',
        textColor: '#FFFFFF',
        textAccept: 'Answer',
        textDecline: 'Decline',
      ),
      ios: IOSParams(
        supportsVideo: isVideo,
        handleType: 'generic',
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        includesCallsInRecents: true,
        configureAudioSession: true,
      ),
    );

    try {
      await FlutterCallkitIncoming.showCallkitIncoming(params);
    } catch (error) {
      _presentedCallIds.remove(callId);
      debugPrint('NativeCallService: unable to show call UI: $error');
      rethrow;
    }
  }

  Future<void> end(String callId) async {
    if (callId.isEmpty) return;
    _presentedCallIds.remove(callId);
    _acceptedCallIds.remove(callId);
    _acceptedAt.remove(callId);
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (error) {
      debugPrint('NativeCallService: end call UI failed: $error');
    }
  }

  /// Ends an accepted incoming call that cannot be joined because another
  /// Griot media session is already active. `declined` is used because it is
  /// a supported terminal state across the call API versions.
  Future<void> rejectAsBusy(String callId) async {
    if (callId.isEmpty) return;
    await _updateStatus(callId, 'declined');
    await end(callId);
  }

  Future<void> _handleEvent(CallEvent? event) async {
    if (event == null) return;
    debugPrint('NativeCallService: ${event.eventName}');

    switch (event) {
      case CallEventActionCallIncoming(:final callKitParams):
        _presentedCallIds.add(callKitParams.id);
      case CallEventActionCallAccept(:final callKitParams):
        // `setCallConnected` in flutter_callkit_incoming transitions the
        // native CallKit transaction by requesting an answer action. iOS then
        // emits ACTION_CALL_ACCEPT a second time for the same UUID. Treating
        // that transition as a new incoming call makes the app see its own
        // active call as a second call and immediately run rejectAsBusy/endCall.
        // Accept handling must therefore be idempotent per CallKit UUID.
        if (_acceptedCallIds.contains(callKitParams.id)) {
          debugPrint(
            'NativeCallService: ignored duplicate CallKit accept '
            'callId=${callKitParams.id}',
          );
          break;
        }
        _acceptedCallIds.add(callKitParams.id);
        _acceptedAt[callKitParams.id] = DateTime.now();
        final data = _callData(callKitParams);
        await FlutterCallkitIncoming.setCallConnected(callKitParams.id);
        await _onAccepted?.call(data);
      case CallEventActionCallDecline(:final callKitParams):
        if (_acceptedCallIds.contains(callKitParams.id)) break;
        await _updateStatus(callKitParams.id, 'declined');
        _presentedCallIds.remove(callKitParams.id);
      case CallEventActionCallEnded(:final callKitParams):
        // iOS can emit a transient end transition while promoting a compact
        // banner answer to the connected CallKit state. Treating that event
        // as a real hang-up makes the Android caller drop immediately.
        final acceptedAt = _acceptedAt[callKitParams.id];
        if (_acceptedCallIds.contains(callKitParams.id) &&
            acceptedAt != null &&
            DateTime.now().difference(acceptedAt) <
                const Duration(seconds: 5)) {
          debugPrint(
            'NativeCallService: ignored transient iOS CallKit end after accept '
            'callId=${callKitParams.id}',
          );
          break;
        }
        // `endCall` also emits an ended callback on some Android versions.
        // `end()` removes the id before making that programmatic call, so only
        // a still-present native call is a genuine user hang-up.  Without
        // this guard, dismissing the native surface while browsing could end
        // the live Zego call and insert a premature “Voice call ended” item.
        if (!_presentedCallIds.remove(callKitParams.id)) break;
        _acceptedCallIds.remove(callKitParams.id);
        _acceptedAt.remove(callKitParams.id);
        await _updateStatus(callKitParams.id, 'ended');
      case CallEventActionCallTimeout(:final id):
        if (_acceptedCallIds.contains(id) || !_presentedCallIds.remove(id)) {
          break;
        }
        await _updateStatus(id, 'missed');
        _presentedCallIds.remove(id);
      case CallEventActionCallConnected(:final id):
        _acceptedCallIds.add(id);
        await _updateStatus(id, 'active');
      case CallEventActionCallCallback(:final id):
        final active = await FlutterCallkitIncoming.activeCalls();
        final matches = active.where((item) => item.id == id);
        final call = matches.isEmpty ? null : matches.first;
        if (call != null) await _onAccepted?.call(_callData(call));
      default:
        break;
    }
  }

  Map<String, dynamic> _callData(CallKitParams params) {
    final extra = params.extra;
    final data = <String, dynamic>{
      ...?extra,
      'type': 'incoming_call',
      'callId': params.id,
    };
    // Older CallKit/plugin versions can return the iOS names (`nameCaller`,
    // `handle`) instead of the server names. Normalize both directions so an
    // answer from the native popup always routes to the same call.
    data['callerName'] ??= data['nameCaller'] ?? data['caller_name'];
    data['callerHandle'] ??= data['handle'] ?? data['caller_handle'];
    data['contextType'] ??= data['conversationType'] ?? data['context_type'];
    data['conversationId'] ??= data['conversation_id'];
    data['roomId'] ??= data['room_id'];
    data['mode'] ??= data['isVideo'] == true ? 'video' : 'voice';
    return data;
  }

  Future<void> _updateStatus(String callId, String status) async {
    final apiClient = _apiClient;
    if (apiClient == null || callId.isEmpty) return;
    try {
      await apiClient.patch(
        '${ApiConfig.realtimeCalls}/$callId',
        body: {'status': status},
      );
    } catch (error) {
      debugPrint('NativeCallService: status update $status failed: $error');
    }
  }

  /// Delivers a CallKit answer captured while the Flutter engine was
  /// suspended or terminated. Safe to call repeatedly; the persisted event is
  /// removed before delivery so it cannot open duplicate media sessions.
  Future<void> consumePendingAcceptedCall() async {
    final onAccepted = _onAccepted;
    if (onAccepted == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingAccept = prefs.getString(_pendingAcceptKey);
      if (pendingAccept == null || pendingAccept.isEmpty) return;
      await prefs.remove(_pendingAcceptKey);
      final decoded = jsonDecode(pendingAccept);
      if (decoded is Map) {
        await onAccepted(Map<String, dynamic>.from(decoded));
      }
    } catch (error) {
      debugPrint('NativeCallService: pending accepted call failed: $error');
    }
  }

  String? _string(Object? value) {
    final result = value?.toString().trim();
    return result == null || result.isEmpty ? null : result;
  }

  String _compactNativeLabel(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 32) return normalized;
    return '${normalized.substring(0, 29).trimRight()}…';
  }

  void dispose() {
    unawaited(_eventsSubscription?.cancel());
    _eventsSubscription = null;
  }

  static const String _pendingAcceptKey = 'griot_pending_native_call_accept';

  static Future<void> persistAcceptedCall(Map<dynamic, dynamic> data) async {
    try {
      // iOS CallKit's acceptCallHandle callback returns the plugin's native
      // payload, where the server metadata is nested under `extra`. The
      // foreground event path normalizes this through _callData, but the
      // compact/top-banner path can resume Flutter through this callback
      // instead. Flatten both shapes before persisting so the call screen can
      // always recover conversationId/roomId after the app resumes.
      final raw = Map<String, dynamic>.from(data);
      final nested = raw['extra'];
      final normalized = <String, dynamic>{
        if (nested is Map) ...Map<String, dynamic>.from(nested),
        ...raw,
      };
      normalized.remove('extra');
      normalized['type'] = 'incoming_call';
      normalized['callId'] ??=
          normalized['id'] ?? normalized['uuid'] ?? normalized['call_id'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingAcceptKey, jsonEncode(normalized));
    } catch (error) {
      debugPrint('NativeCallService: unable to persist accepted call: $error');
    }
  }
}

@pragma('vm:entry-point')
Future<void> handleNativeCallBackgroundEvent(CallEvent event) async {
  debugPrint('NativeCallService: background event ${event.eventName}');
  if (event case CallEventActionCallAccept(:final callKitParams)) {
    await NativeCallService.persistAcceptedCall({
      ...?callKitParams.extra,
      'type': 'incoming_call',
      'callId': callKitParams.id,
    });
  }
}

@pragma('vm:entry-point')
void handleNativeCallAcceptInBackground(Map<dynamic, dynamic> data) {
  unawaited(NativeCallService.persistAcceptedCall(data));
}
