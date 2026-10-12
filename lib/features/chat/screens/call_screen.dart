import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/ui/dialogs/griot_confirm_dialog.dart';
import '../../../core/router/app_router.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_branded_container.dart';
import '../../../core/ui/widgets/griot_plus_badge.dart';
import '../../../core/ui/widgets/griot_pioneer_badge.dart';
import '../../users/models/user_model.dart';
import '../../users/providers/user_provider.dart';
import '../services/realtime_call_service.dart';
import '../services/active_call_controller.dart';
import '../services/messaging_api_service.dart';
import '../models/space_model.dart';
import '../providers/messaging_provider.dart';
import '../widgets/friend_selector_sheet.dart';

enum _VideoThumbnailCorner { topLeft, topRight, bottomLeft, bottomRight }

extension on _VideoThumbnailCorner {
  bool get isLeft =>
      this == _VideoThumbnailCorner.topLeft ||
      this == _VideoThumbnailCorner.bottomLeft;
  bool get isTop =>
      this == _VideoThumbnailCorner.topLeft ||
      this == _VideoThumbnailCorner.topRight;
}

class CallScreen extends StatefulWidget {
  final String conversationId, conversationType, mode;
  final String? title;
  final String? initialCallId;
  final RealtimeCallSession? initialSession;
  final String? initialRoomId;
  final bool openParticipantsOnLoad;
  const CallScreen({
    super.key,
    required this.conversationId,
    required this.conversationType,
    required this.mode,
    this.initialCallId,
    this.initialSession,
    this.initialRoomId,
    this.title,
    this.openParticipantsOnLoad = false,
  });
  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  String _status = 'Connecting…';
  String? _error;
  bool _started = false;
  String? get _callId => _owner.callId;
  set _callId(String? value) => _owner.callId = value;
  bool _cleaningUp = false;
  bool _connecting = false;
  final _owner = ActiveCallController.instance;
  late final _media = _owner.media;
  bool get _engineCreated => _media.created;
  Completer<void>? _connectionCompleted;
  Widget? _localVideoView;
  int? _localViewId;
  final Map<String, Widget> _remoteVideoViews = <String, Widget>{};
  bool _showLocalMain = false;
  bool _showVideoControls = true;
  bool _usingFrontCamera = true;
  // Voice calls use the handset/earpiece; video and Campfires use speaker.
  // The control lets users switch routes without changing mute.
  bool _speakerEnabled = false;
  ZegoAudioRoute _audioRoute = ZegoAudioRoute.Receiver;
  // Direct and group calls can be upgraded from voice to video in place.
  // Campfires keep the format selected by their host.
  bool get _videoCallActive => _owner.videoCallActive;
  set _videoCallActive(bool value) => _owner.videoCallActive = value;
  bool get _videoEnabled => _owner.videoEnabled;
  set _videoEnabled(bool value) => _owner.videoEnabled = value;
  bool get _audioEnabled => _owner.audioEnabled;
  set _audioEnabled(bool value) => _owner.audioEnabled = value;
  bool _sharingLink = false;
  String _localDisplayName = 'You';
  String _remoteDisplayName = '';
  String? _remoteAvatarUrl;
  final Map<String, Map<String, dynamic>> _callParticipantProfiles = {};
  double _localSoundLevel = 0;
  final Map<String, double> _remoteSoundLevels = <String, double>{};
  final Map<String, bool> _remoteMuted = <String, bool>{};
  String? _publishedStreamId;
  bool _campfireCanPublish = true;
  bool _campfireL3Enabled = false;
  static const _callReactionChoices = ['👏', '❤️', '🔥', '😂', '🎉', '👍'];
  static const _maxCampfireStageSeats = 8;
  static const _callReactionLibrary = [
    '😀',
    '😃',
    '😄',
    '😁',
    '😂',
    '🤣',
    '😊',
    '😍',
    '🥰',
    '😘',
    '🤩',
    '🥳',
    '😮',
    '😢',
    '😭',
    '😡',
    '🤯',
    '😴',
    '🤔',
    '🙄',
    '😇',
    '😎',
    '🥹',
    '😅',
    '👍',
    '👎',
    '👏',
    '🙏',
    '🙌',
    '🤝',
    '💪',
    '👌',
    '✌️',
    '🤞',
    '👋',
    '🫶',
    '💯',
    '🔥',
    '🎉',
    '❤️',
    '💔',
    '✨',
    '⭐',
    '✅',
    '❌',
    '💡',
    '🎤',
    '🎶',
  ];
  final List<String> _recentCallReactions = [..._callReactionChoices];

  String get _campfireTitle {
    final value = widget.title?.trim() ?? '';
    return value.isEmpty ? 'Campfire' : value;
  }

  /// Campfire audiences use ZEGOCLOUD's L3 distribution path once it has
  /// been enabled for the project. Direct and group calls stay on RTC.
  ZegoPlayerConfig _playerConfigForStream() {
    final config = ZegoPlayerConfig.defaultConfig();
    if (widget.conversationType == 'space') {
      config.resourceMode = ZegoStreamResourceMode.OnlyL3;
      // ZEGOCLOUD's L3 Flutter guidance requires OnlyL3 playback. Keep the
      // source resource type at its SDK default: forcing sourceResourceType
      // is support-directed and can interfere with the SDK's RTC co-host
      // transition when an approved speaker starts publishing.
    }
    return config;
  }

  final Map<String, String> _spaceReactions = <String, String>{};
  final Map<String, Timer> _spaceReactionTimers = <String, Timer>{};
  List<SpaceParticipant> get _spaceParticipants => _owner.participants;
  set _spaceParticipants(List<SpaceParticipant> value) =>
      _owner.participants = value;
  _VideoThumbnailCorner _thumbnailCorner = _VideoThumbnailCorner.topRight;
  Offset _thumbnailDragOffset = Offset.zero;
  Timer? _answerTimeout;
  Timer? _participantRefreshDebounce;
  Timer? _participantRefreshTimer;
  Timer? _soundLevelFrameTimer;
  double? _pendingLocalSoundLevel;
  final Map<String, double> _pendingRemoteSoundLevels = <String, double>{};
  bool _participantRefreshInFlight = false;
  int _campfireRevision = 0;
  MessagingProvider? _messagingProvider;
  bool _remoteJoined = false;
  bool _timedOut = false;
  bool _spaceControlsOpen = false;
  // Direct calls can be upgraded in place. Keep this presentation state
  // separate from conversationType, which intentionally remains "direct" for
  // the existing call/session and backend lifecycle.
  bool _multiPartyMode = false;
  int _missingSelfRefreshes = 0;
  final Set<String> _terminalCallIds = {};
  Set<String> get _remoteStreams => _media.streams;
  // A direct call can be upgraded in place when the host invites additional
  // people. Once more than one remote stream is present, render the same
  // multi-party layout used by group calls instead of keeping the two-person
  // presentation mounted.
  bool get _isMultiPartyCall =>
      widget.conversationType == 'group' ||
      widget.conversationType == 'channel' ||
      _multiPartyMode ||
      _remoteStreams.length > 1;
  late final String _roomId =
      widget.initialRoomId ??
      'griot-${widget.conversationType}-${widget.conversationId}';
  @override
  void initState() {
    super.initState();
    _speakerEnabled =
        widget.conversationType == 'space' || widget.mode == 'video';
    _callId = widget.initialCallId ?? widget.initialSession?.callId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.conversationType == 'space') {
        final provider = context.read<MessagingProvider>();
        _messagingProvider = provider;
        _campfireRevision = provider.campfireRevision;
        provider.addListener(_onCampfireRevision);
        _owner.listen(provider.campfireEventStream, _onCampfireEvent);
      }
      final provider = context.read<MessagingProvider>();
      _owner.listen(provider.callStatusStream, _onCallStatusUpdated);
      final endedBeforeJoin =
          widget.conversationType == 'space' &&
          _messagingProvider?.lastEndedCampfireId == widget.conversationId;
      if (endedBeforeJoin) {
        unawaited(_close(notifyServer: false));
        return;
      }
      _connect();
      if (widget.conversationType == 'space') {
        // Socket updates are preferred; this low-frequency reconciliation
        // keeps the host's participant grid correct after reconnects or when
        // the join happened before this screen subscribed.
        _participantRefreshTimer = Timer.periodic(
          // Socket events are the primary update path. This slower
          // reconciliation protects large rooms from overlapping requests.
          const Duration(seconds: 10),
          (_) => unawaited(_refreshCampfireParticipants()),
        );
        if (widget.openParticipantsOnLoad) {
          // Wait for the room screen to mount, then open the full-screen
          // participant controls rather than dropping the host on discovery.
          Future<void>.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_cleaningUp) unawaited(_showSpaceControls());
          });
        }
      }
    });
  }

  void _onCallStatusUpdated(Map<String, dynamic> event) {
    if (!mounted || _cleaningUp) return;
    final eventCallId = (event['callId'] ?? event['call_id'])?.toString();
    final status = event['status']?.toString().toLowerCase();
    if (eventCallId == null || eventCallId.isEmpty) {
      return;
    }
    if (!const {'ended', 'declined', 'missed', 'failed'}.contains(status)) {
      return;
    }
    _terminalCallIds.add(eventCallId);
    if (eventCallId != _callId) return;
    // The other participant has already changed the authoritative state.
    // Clean up locally without PATCHing the same call again.
    unawaited(_close(notifyServer: false));
  }

  void _onCampfireRevision() {
    if (!mounted || widget.conversationType != 'space') return;
    final provider = context.read<MessagingProvider>();
    if (provider.campfireRevision == _campfireRevision) return;
    _campfireRevision = provider.campfireRevision;
    if (provider.lastEndedCampfireId == widget.conversationId) {
      // The host ended the room elsewhere. Leave immediately on every
      // participant's device; do not wait for a participant refresh or for
      // the local user to press Leave.
      unawaited(_close(notifyServer: false));
      return;
    }
    _participantRefreshDebounce?.cancel();
    _participantRefreshDebounce = Timer(const Duration(milliseconds: 180), () {
      unawaited(_refreshCampfireParticipants());
    });
  }

  void _onCampfireEvent(Map<String, dynamic> event) {
    if (!mounted || _cleaningUp || widget.conversationType != 'space') return;
    final type = event['type']?.toString();
    final spaceId =
        (event['spaceId'] ?? event['space_id'] ?? event['campfireId'])
            ?.toString();
    if (spaceId != null &&
        spaceId.isNotEmpty &&
        spaceId != widget.conversationId) {
      return;
    }
    if (type == 'campfire_ended') {
      unawaited(_close(notifyServer: false));
      return;
    }
    if (type == 'campfire_participants_changed' ||
        type == 'campfire_speaker_requested') {
      _participantRefreshDebounce?.cancel();
      _participantRefreshDebounce = Timer(const Duration(milliseconds: 60), () {
        unawaited(_refreshCampfireParticipants());
      });
    }
  }

  Future<void> _refreshCampfireParticipants() async {
    if (_participantRefreshInFlight || _cleaningUp) return;
    _participantRefreshInFlight = true;
    try {
      final participants = await context
          .read<MessagingApiService>()
          .getCampfireParticipants(widget.conversationId);
      final previousById = {
        for (final participant in _spaceParticipants)
          participant.id: participant,
      };
      final stableParticipants = participants
          .map((participant) {
            final previous = previousById[participant.id];
            if (previous?.avatarUrl != null &&
                participant.avatarUrl != previous!.avatarUrl) {
              return SpaceParticipant(
                id: participant.id,
                name: participant.name,
                role: participant.role,
                muted: participant.muted,
                isOwner: participant.isOwner,
                isSelf: participant.isSelf,
                speakerRequested: participant.speakerRequested,
                avatarUrl: previous.avatarUrl,
                isPlus: participant.isPlus,
                isPioneer: participant.isPioneer,
              );
            }
            return participant;
          })
          .toList(growable: false);
      final changed =
          stableParticipants.length != _spaceParticipants.length ||
          stableParticipants.asMap().entries.any((entry) {
            final old = _spaceParticipants.length > entry.key
                ? _spaceParticipants[entry.key]
                : null;
            final next = entry.value;
            return old == null ||
                old.id != next.id ||
                old.role != next.role ||
                old.muted != next.muted ||
                old.speakerRequested != next.speakerRequested ||
                old.avatarUrl != next.avatarUrl ||
                old.name != next.name;
          });
      if (mounted && changed) {
        setState(() => _spaceParticipants = stableParticipants);
      }
      await _enforceCampfireAudioState(stableParticipants);
    } catch (_) {
      // The active call remains usable if a participant refresh is delayed.
    } finally {
      _participantRefreshInFlight = false;
    }
  }

  bool _canCampfireSpeak(SpaceParticipant? participant) {
    if (participant == null) return false;
    return participant.isOwner ||
        participant.role == 'host' ||
        participant.role == 'cohost' ||
        participant.role == 'speaker';
  }

  bool _campfireMicUpdating = false;

  Future<void> _enforceCampfireAudioState(
    List<SpaceParticipant> participants,
  ) async {
    if (_cleaningUp) return;
    final self = participants.where((item) => item.isSelf).firstOrNull;
    if (self == null) {
      // A participant snapshot can briefly omit the local user while the
      // socket/API catches up. Do not tear down a live Campfire on one
      // transient response; only leave after consecutive confirmed misses.
      _missingSelfRefreshes++;
      if (_missingSelfRefreshes < 2) return;
      await _close(notifyServer: false);
      return;
    }
    _missingSelfRefreshes = 0;
    if (_campfireMicUpdating) return;
    // A listener should not keep an outbound stream alive after losing the
    // speaking seat. Muting is enough for an admitted speaker, but removing
    // the stream saves audience-side RTC credit when moderation demotes them.
    if (!_canCampfireSpeak(self) && _publishedStreamId != null) {
      try {
        await ZegoExpressEngine.instance.stopPublishingStream();
      } catch (_) {}
      _publishedStreamId = null;
      _campfireCanPublish = false;
    }
    // Server moderation may mute, but a refresh must never open a user's mic.
    final mustMute = !_canCampfireSpeak(self) || self.muted;
    if (mustMute && _audioEnabled && _engineCreated) {
      await ZegoExpressEngine.instance.mutePublishStreamAudio(true);
      if (mounted && !_cleaningUp) setState(() => _audioEnabled = false);
    }
  }

  Future<void> _connect() async {
    if (_connecting || _started || _cleaningUp) return;
    _connecting = true;
    _connectionCompleted = Completer<void>();
    final apiClient = context.read<ApiClient>();
    final messagingApi = context.read<MessagingApiService>();
    // Resolve the remote identity before presenting the outgoing call card so
    // it never flashes a generic label while the call is being placed.
    await _loadCallNames(messagingApi);
    String? activeRoomId;
    try {
      await _requestCallPermissions();
      if (widget.conversationType == 'space') {
        final participants = await messagingApi.getCampfireParticipants(
          widget.conversationId,
        );
        if (mounted) setState(() => _spaceParticipants = participants);
        final self = participants.where((item) => item.isSelf).firstOrNull;
        final canSpeak = _canCampfireSpeak(self);
        // The server marks hosts as unmuted when they join and listeners as
        // muted. Mirror that authoritative state here. Previously every
        // Campfire entered with a locally-muted publisher, so the sound-level
        // flame moved (the microphone was being captured) while nobody else
        // could hear the host or an admitted speaker.
        _audioEnabled = canSpeak && self?.muted != true;
        _campfireCanPublish = canSpeak;
        _videoEnabled = _videoCallActive && canSpeak;
      }
      final s =
          widget.initialSession ??
          await RealtimeCallService(apiClient).start(
            roomId: _roomId,
            contextType: widget.conversationType,
            conversationId: widget.conversationId,
            mode: widget.mode,
            callId: widget.initialCallId,
          );
      activeRoomId = s.roomId;
      _campfireL3Enabled =
          widget.conversationType == 'space' && s.campfireL3Enabled;
      if (widget.conversationType == 'space' && !_campfireL3Enabled) {
        throw StateError(
          'This Campfire requires ZEGOCLOUD L3 live streaming and is not enabled.',
        );
      }
      _callId = s.callId ?? widget.initialCallId;
      if (_terminalCallIds.contains(_callId)) {
        unawaited(_close(notifyServer: false));
        return;
      }
      if (s.appId == 0) {
        throw StateError('Realtime calling is not configured on the server.');
      }
      if (_cleaningUp) return;
      await _media.create(s);
      ZegoExpressEngine
          .onPublisherStateUpdate = (streamID, state, errorCode, extendedData) {
        debugPrint(
          '[Campfire][publish] stream=$streamID state=$state error=$errorCode data=$extendedData',
        );
      };
      ZegoExpressEngine
          .onPlayerStateUpdate = (streamID, state, errorCode, extendedData) {
        debugPrint(
          '[Campfire][play] stream=$streamID state=$state error=$errorCode data=$extendedData',
        );
      };
      ZegoExpressEngine.onAudioRouteChange = (route) {
        if (!mounted || _cleaningUp) return;
        setState(() {
          _audioRoute = route;
          _speakerEnabled = route == ZegoAudioRoute.Speaker;
        });
      };
      ZegoExpressEngine.onRoomStreamUpdate =
          (roomId, updateType, streamList, extendedData) async {
            if (roomId != s.roomId || _cleaningUp || !mounted) return;
            for (final stream in streamList) {
              if (updateType == ZegoUpdateType.Add) {
                _remoteJoined = true;
                unawaited(_owner.stopRingback());
                _answerTimeout?.cancel();
                if (_remoteStreams.add(stream.streamID)) {
                  // The stream update includes the publisher's current
                  // metadata. Read the initial mute flag here as well as in
                  // onRoomStreamExtraInfoUpdate; otherwise a video call can
                  // miss a friend's already-muted state when the listener
                  // joins after that metadata was published.
                  _setRemoteMuteFromExtraInfo(
                    stream.streamID,
                    stream.extraInfo,
                  );
                  // Once a second remote stream arrives, every mounted call
                  // view must use the multi-party presentation. This also
                  // covers a direct call that was upgraded while it was open.
                  if (_remoteStreams.length > 1 && !_multiPartyMode) {
                    _multiPartyMode = true;
                  }
                  // Switch the presentation immediately when a direct call
                  // is upgraded. Waiting for a video surface (or profile
                  // lookup) leaves voice calls stuck on the two-person view.
                  if (mounted && !_cleaningUp) setState(() {});
                  unawaited(_loadStreamProfile(stream.streamID));
                  try {
                    if (_videoCallActive) {
                      final view = await ZegoExpressEngine.instance
                          .createCanvasView((viewID) {
                            if (_cleaningUp || !_engineCreated) return;
                            unawaited(
                              ZegoExpressEngine.instance.startPlayingStream(
                                stream.streamID,
                                canvas: _callCanvas(viewID),
                                config: _playerConfigForStream(),
                              ),
                            );
                          });
                      if (mounted && !_cleaningUp && view != null) {
                        setState(() {
                          _remoteVideoViews[stream.streamID] = view;
                          _showLocalMain = false;
                        });
                      }
                    } else {
                      await ZegoExpressEngine.instance.startPlayingStream(
                        stream.streamID,
                        config: _playerConfigForStream(),
                      );
                      if (mounted) setState(() {});
                    }
                  } catch (error, stackTrace) {
                    debugPrint(
                      '[Campfire][play] start failed stream=${stream.streamID}: $error\n$stackTrace',
                    );
                  }
                }
              } else if (updateType == ZegoUpdateType.Delete &&
                  _remoteStreams.remove(stream.streamID)) {
                try {
                  await ZegoExpressEngine.instance.stopPlayingStream(
                    stream.streamID,
                  );
                } catch (_) {}
                if (mounted) {
                  setState(() {
                    _remoteVideoViews.remove(stream.streamID);
                    if (_remoteVideoViews.isEmpty) _showLocalMain = false;
                  });
                }
              }
            }
          };
      if (_cleaningUp) return;
      await _media.join(s);
      if (_cleaningUp) return;
      // Zego exposes 0-100 local/remote levels at a lightweight interval.
      // These drive only the visual speaking treatment; they are never sent
      // to the server or persisted.
      ZegoExpressEngine.onCapturedSoundLevelUpdate = (level) {
        if (!mounted || _cleaningUp) return;
        _pendingLocalSoundLevel = level.clamp(0, 100) / 100;
        _scheduleSoundLevelFrame();
      };
      ZegoExpressEngine.onRemoteSoundLevelUpdate = (levels) {
        if (!mounted || _cleaningUp) return;
        for (final entry in levels.entries) {
          _pendingRemoteSoundLevels[entry.key] =
              entry.value.clamp(0, 100) / 100;
        }
        _scheduleSoundLevelFrame();
      };
      ZegoExpressEngine.onRoomStreamExtraInfoUpdate = (roomId, streams) {
        if (!mounted || _cleaningUp || roomId != s.roomId) return;
        setState(() {
          for (final stream in streams) {
            _setRemoteMuteFromExtraInfo(stream.streamID, stream.extraInfo);
          }
        });
      };
      ZegoExpressEngine.onIMRecvCustomCommand = (roomId, fromUser, command) {
        if (!mounted || _cleaningUp || roomId != s.roomId) return;
        try {
          final data = jsonDecode(command);
          if (data is! Map) return;
          if (data['type'] == 'call_reaction') {
            final emoji = data['emoji']?.toString();
            if (emoji == null || emoji.isEmpty) return;
            final reactorId = fromUser.userID.toString();
            _spaceReactionTimers[reactorId]?.cancel();
            if (mounted) {
              setState(() => _spaceReactions[reactorId] = emoji);
              _spaceReactionTimers[reactorId] = Timer(
                const Duration(seconds: 3),
                () {
                  if (mounted) {
                    setState(() => _spaceReactions.remove(reactorId));
                  }
                  _spaceReactionTimers.remove(reactorId);
                },
              );
            }
            return;
          }
          if (data['type'] != 'mute_participant') return;
          if (data['streamId'] != _publishedStreamId) return;
          final muted = data['muted'] == true;
          unawaited(() async {
            await ZegoExpressEngine.instance.mutePublishStreamAudio(muted);
            await ZegoExpressEngine.instance.setStreamExtraInfo(
              jsonEncode({'muted': muted}),
            );
            if (mounted && !_cleaningUp) setState(() => _audioEnabled = !muted);
          }());
        } catch (_) {}
      };
      await ZegoExpressEngine.instance.startSoundLevelMonitor(
        config: ZegoSoundLevelConfig(100, true),
      );
      await ZegoExpressEngine.instance.setAudioRouteToSpeaker(_speakerEnabled);
      try {
        _audioRoute = await ZegoExpressEngine.instance.getAudioRouteType();
        _speakerEnabled = _audioRoute == ZegoAudioRoute.Speaker;
      } catch (_) {
        // Route detection is unavailable on some platforms; retain the
        // requested speaker/earpiece state as the fallback label.
      }
      await ZegoExpressEngine.instance.enableCamera(_videoEnabled);
      await ZegoExpressEngine.instance.mutePublishStreamAudio(!_audioEnabled);
      await ZegoExpressEngine.instance.mutePublishStreamVideo(!_videoEnabled);
      if (_videoEnabled) {
        final localView = await ZegoExpressEngine.instance.createCanvasView((
          viewID,
        ) {
          _localViewId = viewID;
          unawaited(
            ZegoExpressEngine.instance.startPreview(
              canvas: _callCanvas(viewID),
            ),
          );
        });
        if (mounted) setState(() => _localVideoView = localView);
      }
      if (_cleaningUp) return;
      // In a Campfire, listeners are receive-only. Publishing a muted stream
      // for every listener unnecessarily consumes RTC media credit and is not
      // how a live-room audience should behave.
      if (widget.conversationType != 'space' || _campfireCanPublish) {
        _publishedStreamId = await _media.publish(s.userId);
        await ZegoExpressEngine.instance.setStreamExtraInfo(
          jsonEncode({'muted': !_audioEnabled}),
        );
      }
      if (_callId != null) {
        try {
          await RealtimeCallService(apiClient).updateStatus(_callId!, 'active');
        } catch (_) {}
      }
      if (mounted && !_cleaningUp) {
        setState(() {
          _started = true;
          _status = widget.conversationType == 'space'
              ? '${widget.mode == 'voice' ? 'Voice' : 'Video'} Campfire connected'
              : '${_videoCallActive ? 'Video' : 'Voice'} call connected';
        });
        _startAnswerTimeout();
      }
    } catch (e) {
      final failedCallId = _callId;
      // Ending a call while connection/setup is still in flight is a normal
      // race (especially when the native call sheet is dismissed). Do not
      // turn that intentional teardown into a visible API/setup error or
      // overwrite the closing state with "Call unavailable".
      if (_cleaningUp) return;
      if (failedCallId != null && widget.conversationType != 'space') {
        try {
          await RealtimeCallService(
            apiClient,
          ).updateStatus(failedCallId, 'failed');
        } catch (statusError) {
          debugPrint(
            'Call setup failed and server cleanup was not confirmed: '
            '$statusError',
          );
        }
      }
      try {
        await _cleanupZego(activeRoomId);
      } catch (cleanupError) {
        debugPrint('Call media cleanup failed: $cleanupError');
      }
      // Connection failures are displayed locally. Only an actual answer
      // timeout may classify the call as missed.
      if (mounted && !_cleaningUp) {
        setState(() {
          _error = e.toString().replaceFirst('Bad state: ', '');
          _status = 'Call unavailable';
        });
      }
    } finally {
      _connecting = false;
      _connectionCompleted?.complete();
    }
  }

  Future<void> _loadCallNames(MessagingApiService messagingApi) async {
    final currentUser = context.read<UserProvider>().user;
    final ownName = _displayNameOrWallet(
      currentUser?.displayName,
      currentUser?.username,
      currentUser?.walletAddress,
      fallback: 'You',
    );
    if (mounted) setState(() => _localDisplayName = ownName);

    try {
      if (widget.conversationType == 'direct' ||
          widget.conversationType == 'dm' ||
          widget.conversationType == 'conversation') {
        final other = await messagingApi.getOtherDirectUser(
          widget.conversationId,
        );
        if (mounted) {
          setState(() {
            _remoteDisplayName = _displayNameOrWallet(
              other.displayName,
              other.username,
              other.walletAddress,
              fallback: _shortWallet(other.walletAddress),
            );
            _remoteAvatarUrl = other.profileUrl;
          });
        }
      } else if (widget.conversationType == 'group' ||
          widget.conversationType == 'channel') {
        final group = widget.conversationType == 'group'
            ? await messagingApi.getGroup(widget.conversationId)
            : null;
        if (mounted && group?.name?.trim().isNotEmpty == true) {
          setState(() => _remoteDisplayName = group!.name!.trim());
        }
        try {
          final members = widget.conversationType == 'group'
              ? await messagingApi.getGroupMembers(widget.conversationId)
              : await messagingApi.getChannelMembers(widget.conversationId);
          for (final member in members) {
            final id = (member['user_id'] ?? member['userId'] ?? member['id'])
                ?.toString();
            if (id != null && id.isNotEmpty) {
              _callParticipantProfiles[id] = member;
            }
          }
        } catch (_) {
          // The call remains usable when member profile data is delayed.
        }
      } else if (mounted) {
        setState(() => _remoteDisplayName = 'Campfire');
      }
    } catch (_) {
      // Calling remains usable if profile data is temporarily unavailable.
    }
  }

  String _displayNameOrWallet(
    String? displayName,
    String? username,
    String? walletAddress, {
    required String fallback,
  }) {
    bool usable(String? value) {
      final normalized = value?.trim();
      if (normalized == null || normalized.isEmpty) return false;
      return !const {
        'participant',
        'caller',
        'callee',
        'user',
        'griot user',
        'griot contact',
      }.contains(normalized.toLowerCase());
    }

    final name = displayName?.trim();
    if (usable(name)) return name!;
    final handle = username?.trim();
    if (usable(handle)) {
      final value = handle!;
      return value.startsWith('@') ? value : '@$value';
    }
    final wallet = walletAddress?.trim() ?? '';
    if (wallet.length > 10) {
      return '${wallet.substring(0, 3)}…${wallet.substring(wallet.length - 3)}';
    }
    return wallet.isEmpty ? fallback : wallet;
  }

  String _shortWallet(String? wallet) {
    final value = wallet?.trim() ?? '';
    if (value.length > 6) {
      return '${value.substring(0, 3)}…${value.substring(value.length - 3)}';
    }
    return value.isEmpty ? 'Griot user' : value;
  }

  String _remoteCallLabel() {
    final value = _remoteDisplayName.trim();
    if (value.isNotEmpty && value.toLowerCase() != 'griot user') return value;
    final stream = _remoteStreams.isEmpty ? null : _remoteStreams.first;
    if (stream != null) return _participantNameFromStream(stream, 1);
    return value.isEmpty || value.toLowerCase() == 'griot user'
        ? 'Calling…'
        : value;
  }

  bool get _remoteParticipantMuted {
    if (_remoteStreams.isEmpty) return false;
    return _remoteMuted[_remoteStreams.first] ?? false;
  }

  Future<void> _requestCallPermissions() async {
    final requested = <Permission>[Permission.microphone];
    // Campfire video starts with the camera disabled until the participant
    // role is loaded. Request camera permission up front for video rooms so
    // approved speakers can publish immediately, just like voice rooms.
    final cameraNeeded =
        _videoEnabled ||
        (widget.conversationType == 'space' && widget.mode == 'video');
    if (cameraNeeded) requested.add(Permission.camera);

    final result = await requested.request();
    final microphone = result[Permission.microphone];
    final camera = result[Permission.camera];
    final microphoneGranted = microphone?.isGranted == true;
    final cameraGranted = !cameraNeeded || camera?.isGranted == true;

    if (microphoneGranted && cameraGranted) return;

    final permanentlyDenied =
        microphone?.isPermanentlyDenied == true ||
        (cameraNeeded && camera?.isPermanentlyDenied == true);
    throw StateError(
      permanentlyDenied
          ? 'Enable microphone${cameraNeeded ? ' and camera' : ''} access in Settings to join the call.'
          : 'Microphone${cameraNeeded ? ' and camera' : ''} permission is required to join the call.',
    );
  }

  Future<void> _toggleAudio() async {
    if (!_started || _cleaningUp || _campfireMicUpdating) return;
    final messaging = context.read<MessagingApiService>();
    final next = !_audioEnabled;
    SpaceParticipant? campfireSelf;
    _campfireMicUpdating = true;
    try {
      if (widget.conversationType == 'space') {
        final participants = await messaging.getCampfireParticipants(
          widget.conversationId,
        );
        campfireSelf = participants.where((item) => item.isSelf).firstOrNull;
        if (!_canCampfireSpeak(campfireSelf)) {
          throw StateError('Raise your hand to request speaking permission.');
        }
        await messaging.moderateCampfireParticipant(
          campfireId: widget.conversationId,
          userId: campfireSelf!.id,
          action: next ? 'unmute' : 'mute',
        );
      }
      if (_cleaningUp || !_engineCreated) return;
      if (widget.conversationType == 'space' &&
          next &&
          _publishedStreamId == null) {
        _publishedStreamId = await _media.publish(campfireSelf!.id);
        _campfireCanPublish = true;
      }
      await ZegoExpressEngine.instance.mutePublishStreamAudio(!next);
      await ZegoExpressEngine.instance.setStreamExtraInfo(
        jsonEncode({'muted': !next}),
      );
      if (mounted) setState(() => _audioEnabled = next);
    } catch (error) {
      if (mounted && !_cleaningUp) {
        NotificationService.showPush(
          context,
          title: 'Microphone unchanged',
          message: '$error',
          icon: Icons.mic_off_rounded,
        );
      }
    } finally {
      _campfireMicUpdating = false;
      if (widget.conversationType == 'space' && mounted && !_cleaningUp) {
        await _refreshCampfireParticipants();
      }
    }
  }

  void _setRemoteMuteFromExtraInfo(String streamId, String extraInfo) {
    if (streamId.isEmpty || extraInfo.isEmpty) return;
    try {
      final data = jsonDecode(extraInfo);
      if (data is Map && data['muted'] is bool) {
        _remoteMuted[streamId] = data['muted'] as bool;
      }
    } catch (_) {
      // Stream metadata can contain provider-specific JSON. Ignore entries
      // that do not carry our mute flag.
    }
  }

  Future<void> _toggleSpeaker() async {
    if (!_engineCreated || _cleaningUp) return;
    final next = !_speakerEnabled;
    try {
      await ZegoExpressEngine.instance.setAudioRouteToSpeaker(next);
      if (mounted && !_cleaningUp) {
        final route = await ZegoExpressEngine.instance.getAudioRouteType();
        setState(() {
          _audioRoute = route;
          _speakerEnabled = route == ZegoAudioRoute.Speaker;
        });
      }
    } catch (error) {
      if (mounted) {
        _showCallNotice(
          'Audio output unchanged',
          'Could not change audio output: $error',
          icon: Icons.volume_off_rounded,
        );
      }
    }
  }

  Future<void> _switchCamera() async {
    if (!_started || !_videoEnabled) return;
    _usingFrontCamera = !_usingFrontCamera;
    try {
      await ZegoExpressEngine.instance.useFrontCamera(_usingFrontCamera);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        _showCallNotice(
          'Camera unchanged',
          'Could not switch camera: $error',
          icon: Icons.videocam_off_rounded,
        );
      }
    }
  }

  Future<void> _requestToSpeak() async {
    final self = _spaceParticipants.where((item) => item.isSelf).firstOrNull;
    final raised = self?.speakerRequested != true;
    try {
      await context.read<MessagingApiService>().requestCampfireSpeaker(
        widget.conversationId,
        raised: raised,
      );
      if (!mounted || _cleaningUp) return;
      // Update the control optimistically so the action immediately changes
      // from Raise hand to Lower hand (or back) while the realtime snapshot
      // catches up.
      setState(() {
        _spaceParticipants = _spaceParticipants
            .map(
              (participant) => participant.isSelf
                  ? participant.copyWith(speakerRequested: raised)
                  : participant,
            )
            .toList(growable: false);
      });
      await _refreshCampfireParticipants();
      if (!mounted || _cleaningUp) return;
      NotificationService.showPush(
        context,
        title: raised ? 'Request sent' : 'Hand lowered',
        message: raised
            ? 'The host has been notified.'
            : 'Your speaking request was withdrawn.',
        icon: Icons.pan_tool_outlined,
      );
    } catch (error) {
      if (mounted && !_cleaningUp) {
        NotificationService.showPush(
          context,
          title: 'Request failed',
          message: '$error',
          icon: Icons.error_outline,
        );
      }
    }
  }

  Future<void> _showCallReactions() async {
    if (!_started || _cleaningUp) return;
    final emoji = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => _CallReactionPicker(
        recent: _recentCallReactions,
        onSelected: (value) => Navigator.pop(sheetContext, value),
      ),
    );
    if (emoji == null || !_started || _cleaningUp) return;
    _recentCallReactions.remove(emoji);
    _recentCallReactions.insert(0, emoji);
    if (_recentCallReactions.length > 8) _recentCallReactions.removeLast();
    try {
      await ZegoExpressEngine.instance.sendCustomCommand(
        _roomId,
        jsonEncode({'type': 'call_reaction', 'emoji': emoji}),
        const [],
      );
      if (mounted) {
        // Zego does not echo commands back to the sender, so render the
        // sender's own reaction locally using the same card treatment.
        final self = _spaceParticipants
            .where((item) => item.isSelf)
            .firstOrNull;
        final reactorId = self?.id ?? _publishedStreamId;
        if (reactorId != null && reactorId.isNotEmpty) {
          _spaceReactionTimers[reactorId]?.cancel();
          setState(() => _spaceReactions[reactorId] = emoji);
          _spaceReactionTimers[reactorId] = Timer(
            const Duration(seconds: 3),
            () {
              if (mounted) setState(() => _spaceReactions.remove(reactorId));
              _spaceReactionTimers.remove(reactorId);
            },
          );
        }
      }
    } catch (error) {
      debugPrint('Call reaction failed: $error');
    }
  }

  Future<void> _toggleVideo() async {
    if (!_started) return;
    if (widget.conversationType == 'space') {
      final participants = await context
          .read<MessagingApiService>()
          .getCampfireParticipants(widget.conversationId);
      final self = participants.where((item) => item.isSelf).firstOrNull;
      if (!_canCampfireSpeak(self) || self?.muted == true) {
        if (mounted) {
          _showCallNotice(
            'Video unavailable',
            'Only approved speakers can turn on video.',
            icon: Icons.videocam_off_rounded,
          );
        }
        return;
      }
    }
    final next = !_videoEnabled;
    if (next) {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        if (mounted) {
          _showCallNotice(
            'Camera permission required',
            'Allow camera access to turn on video.',
            icon: Icons.videocam_off_rounded,
          );
        }
        return;
      }
    }
    try {
      await ZegoExpressEngine.instance.enableCamera(next);
      await ZegoExpressEngine.instance.mutePublishStreamVideo(!next);
      if (next) {
        _videoCallActive = true;
        await _ensureLocalPreview();
        for (final streamId in _remoteStreams) {
          await _ensureRemoteVideoView(streamId);
        }
      } else if (_localVideoView != null) {
        await ZegoExpressEngine.instance.stopPreview();
      }
      if (mounted) setState(() => _videoEnabled = next);
    } catch (error) {
      if (mounted) {
        _showCallNotice(
          'Camera unchanged',
          'Could not change camera state: $error',
          icon: Icons.videocam_off_rounded,
        );
      }
    }
  }

  Future<void> _ensureLocalPreview() async {
    if (!_engineCreated) return;
    if (_localVideoView != null && _localViewId != null) {
      await ZegoExpressEngine.instance.startPreview(
        canvas: _callCanvas(_localViewId!),
      );
      return;
    }
    final localView = await ZegoExpressEngine.instance.createCanvasView((
      viewID,
    ) {
      _localViewId = viewID;
      unawaited(
        ZegoExpressEngine.instance.startPreview(canvas: _callCanvas(viewID)),
      );
    });
    if (mounted) setState(() => _localVideoView = localView);
  }

  Future<void> _ensureRemoteVideoView(String streamId) async {
    if (!_engineCreated || _remoteVideoViews.containsKey(streamId)) return;
    try {
      await ZegoExpressEngine.instance.stopPlayingStream(streamId);
    } catch (_) {}
    final view = await ZegoExpressEngine.instance.createCanvasView((viewID) {
      unawaited(
        ZegoExpressEngine.instance.startPlayingStream(
          streamId,
          canvas: _callCanvas(viewID),
          config: _playerConfigForStream(),
        ),
      );
    });
    if (mounted && view != null) {
      setState(() {
        _remoteVideoViews[streamId] = view;
        _showLocalMain = false;
      });
    }
  }

  void _swapVideoLayout() {
    if (_remoteVideoViews.isEmpty || _localVideoView == null) return;
    setState(() => _showLocalMain = !_showLocalMain);
  }

  Future<void> _shareCallLink() async {
    if (_sharingLink) return;
    setState(() => _sharingLink = true);
    final apiClient = context.read<ApiClient>();
    try {
      final link = await RealtimeCallService(apiClient).createLink(
        roomId: _roomId,
        contextType: widget.conversationType,
        conversationId: widget.conversationId,
        mode: _videoCallActive ? 'video' : 'voice',
      );
      await SharePlus.instance.share(
        ShareParams(text: 'Join my Griot call: $link'),
      );
    } catch (e) {
      if (mounted) {
        _showCallNotice(
          'Call link unavailable',
          'Could not create call link: $e',
          icon: Icons.link_off_rounded,
        );
      }
    }
    if (mounted) setState(() => _sharingLink = false);
  }

  Future<void> _invitePeople() async {
    final callId = _callId;
    if (callId == null || !mounted) return;
    final selected = await FriendSelectorSheet.show(
      context,
      title: 'Add people or retry ringing',
      disabledIds: [context.read<UserProvider>().user?.id ?? ''],
    );
    if (!mounted || selected == null || selected.isEmpty) return;
    try {
      final invited = await RealtimeCallService(context.read<ApiClient>())
          .inviteParticipants(
            callId: callId,
            userIds: selected.map((user) => user.id).toList(),
          );
      if (!mounted) return;
      // The invite upgrades this existing session; do not wait for a route
      // recreation or for the invitee's first media frame to change layout.
      if (invited.isNotEmpty && !_multiPartyMode) {
        setState(() => _multiPartyMode = true);
      }
      // The invite response contains IDs, not presentation data. Resolve the
      // profiles now so the upgraded grid uses the same name/avatar hierarchy
      // as the rest of the app instead of generic participant labels.
      unawaited(_loadParticipantProfiles(invited));
      _showCallNotice(
        invited.isEmpty ? 'Already invited' : 'Invitation sent',
        invited.isEmpty
            ? 'Those people are already in this call.'
            : 'The call is ringing them now. Select them here again to ring them again if they missed it.',
        icon: invited.isEmpty
            ? Icons.people_alt_outlined
            : Icons.person_add_alt_1_rounded,
      );
    } catch (error) {
      if (!mounted) return;
      _showCallNotice(
        'Invitation failed',
        'Could not invite people: $error',
        icon: Icons.person_add_disabled_rounded,
      );
    }
  }

  Future<void> _requestMuteParticipant(String streamId) async {
    if (_cleaningUp || !_started || streamId.isEmpty) return;
    final targetId =
        _profileForStream(streamId)?['id']?.toString() ??
        _streamOwnerId(streamId);
    if (targetId == null || targetId.isEmpty) return;
    final muted = !(_remoteMuted[streamId] ?? false);
    try {
      await ZegoExpressEngine.instance.sendCustomCommand(
        _roomId,
        jsonEncode({
          'type': 'mute_participant',
          'streamId': streamId,
          'muted': muted,
        }),
        [ZegoUser(targetId, targetId)],
      );
    } catch (error) {
      if (mounted) {
        _showCallNotice(
          'Microphone unchanged',
          'Could not change microphone: $error',
          icon: Icons.mic_off_rounded,
        );
      }
    }
  }

  String? _streamOwnerId(String streamId) {
    final parts = streamId.split('-');
    if (parts.length < 3 || parts.first != 'griot') return null;
    return parts.sublist(1, parts.length - 1).join('-');
  }

  Future<void> _loadParticipantProfiles(Iterable<String> ids) async {
    final userApi = context.read<UserProvider>().userApiService;
    final pending = ids
        .map((id) => id.trim())
        .where(
          (id) => id.isNotEmpty && !_callParticipantProfiles.containsKey(id),
        )
        .toSet();
    if (pending.isEmpty) return;
    await Future.wait(
      pending.map((id) async {
        try {
          final user = await userApi.getUserById(id);
          _callParticipantProfiles[id] = {
            'id': user.id,
            'display_name': user.displayName,
            'username': user.username,
            'wallet_address': user.walletAddress,
            'avatar_url': user.avatarUrl,
          };
        } catch (_) {
          // Stream rendering remains available with the wallet fallback.
        }
      }),
    );
    if (mounted && !_cleaningUp) setState(() {});
  }

  /// Coalesce the SDK's high-frequency sound callbacks into a small number of
  /// visual frames. Sound levels only drive the speaking/flame treatment, so
  /// rebuilding the whole call screen for every callback causes unnecessary
  /// flicker and battery use without improving the UI.
  void _scheduleSoundLevelFrame() {
    if (_soundLevelFrameTimer != null || !mounted || _cleaningUp) return;
    _soundLevelFrameTimer = Timer(const Duration(milliseconds: 80), () {
      _soundLevelFrameTimer = null;
      if (!mounted || _cleaningUp) return;
      final local = _pendingLocalSoundLevel;
      final remote = Map<String, double>.from(_pendingRemoteSoundLevels);
      _pendingLocalSoundLevel = null;
      _pendingRemoteSoundLevels.clear();
      if (local == null && remote.isEmpty) return;
      setState(() {
        if (local != null) _localSoundLevel = local;
        _remoteSoundLevels.addAll(remote);
      });
    });
  }

  Future<void> _loadStreamProfile(String streamId) async {
    final profile = _profileForStream(streamId);
    if (profile != null) return;
    final parts = streamId.split('-');
    if (parts.length < 3 || parts.first != 'griot') return;
    final id = parts.sublist(1, parts.length - 1).join('-');
    await _loadParticipantProfiles([id]);
  }

  Future<void> _showSpaceControls() async {
    final api = context.read<MessagingApiService>();
    List<SpaceParticipant> participants;
    try {
      participants = await api.getCampfireParticipants(widget.conversationId);
    } catch (error) {
      if (mounted) {
        _showCallNotice(
          'Participants unavailable',
          'Could not load participants: $error',
          icon: Icons.people_alt_outlined,
        );
      }
      return;
    }
    if (!mounted) return;
    var busy = false;
    var selectedFilter = 'all';
    var dialogActive = true;
    StateSetter? updateSheet;
    final searchController = TextEditingController();
    final eventSubscription = context
        .read<MessagingProvider>()
        .campfireEventStream
        .listen((event) async {
          if (!dialogActive) return;
          final type = event['type']?.toString();
          final spaceId =
              (event['spaceId'] ?? event['space_id'] ?? event['campfireId'])
                  ?.toString();
          if (spaceId != null && spaceId != widget.conversationId) {
            return;
          }
          if (type != 'campfire_participants_changed' &&
              type != 'campfire_speaker_requested') {
            return;
          }
          try {
            final fresh = await api.getCampfireParticipants(
              widget.conversationId,
            );
            if (!dialogActive) return;
            participants = fresh;
            updateSheet?.call(() {});
            if (mounted) setState(() => _spaceParticipants = fresh);
          } catch (_) {
            // The next event or the explicit refresh action can reconcile it.
          }
        });
    _spaceControlsOpen = true;
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          updateSheet = setSheetState;
          final self = participants.where((item) => item.isSelf).firstOrNull;
          final canModerate = self?.role == 'host' || self?.role == 'cohost';
          final isOwner = self?.isOwner == true || self?.role == 'host';
          final stageCount = participants.where((item) {
            return item.isOwner ||
                item.role == 'host' ||
                item.role == 'cohost' ||
                item.role == 'speaker';
          }).length;
          final stageFull = stageCount >= _maxCampfireStageSeats;
          final orderedParticipants = [...participants]
            ..sort((a, b) {
              int rank(SpaceParticipant value) {
                if (value.isOwner || value.role == 'host') return 0;
                if (value.role == 'cohost' || value.role == 'speaker') return 1;
                return 2;
              }

              return rank(a).compareTo(rank(b));
            });
          final query = searchController.text.trim().toLowerCase();
          final filteredParticipants = orderedParticipants.where((person) {
            final matchesFilter = switch (selectedFilter) {
              'requests' =>
                person.speakerRequested && person.role == 'listener',
              'cohosts' => person.role == 'cohost',
              'speakers' => person.role == 'speaker' || person.role == 'host',
              'listeners' => person.role == 'listener',
              _ => true,
            };
            return matchesFilter &&
                (query.isEmpty || person.name.toLowerCase().contains(query));
          }).toList();
          final requestedParticipants = filteredParticipants
              .where(
                (person) =>
                    person.speakerRequested && person.role == 'listener',
              )
              .toList();
          final otherParticipants = filteredParticipants
              .where((person) => !requestedParticipants.contains(person))
              .toList();
          final hasRequests = requestedParticipants.isNotEmpty;
          final viewportSize = MediaQuery.sizeOf(context);
          final displayParticipants = selectedFilter == 'requests'
              ? requestedParticipants
              : hasRequests
              ? [...requestedParticipants, ...otherParticipants]
              : filteredParticipants;
          final showAllHeader = hasRequests && selectedFilter != 'requests';

          Future<void> refresh() async {
            setSheetState(() => busy = true);
            try {
              participants = await api.getCampfireParticipants(
                widget.conversationId,
              );
              if (mounted) setState(() => _spaceParticipants = participants);
            } finally {
              if (context.mounted) setSheetState(() => busy = false);
            }
          }

          Future<void> moderate(
            SpaceParticipant participant,
            String action,
          ) async {
            setSheetState(() => busy = true);
            try {
              await api.moderateCampfireParticipant(
                campfireId: widget.conversationId,
                userId: participant.id,
                action: action,
              );
              await refresh();
            } catch (error) {
              if (context.mounted) {
                _showCallNotice(
                  'Action failed',
                  '$error',
                  icon: Icons.error_outline_rounded,
                );
              }
              if (context.mounted) setSheetState(() => busy = false);
            }
          }

          return Dialog.fullscreen(
            child: SizedBox(
              width: viewportSize.width,
              height: viewportSize.height,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Back to Campfire',
                            icon: const Icon(Icons.arrow_back_rounded),
                            onPressed: () {
                              dialogActive = false;
                              updateSheet = null;
                              unawaited(eventSubscription.cancel());
                              if (context.mounted) Navigator.of(context).pop();
                            },
                          ),
                          const Expanded(
                            child: Text(
                              'Guests',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (isOwner)
                            IconButton(
                              tooltip: 'Put Out Campfire',
                              icon: const Icon(Icons.stop_circle_outlined),
                              onPressed: busy
                                  ? null
                                  : () async {
                                      dialogActive = false;
                                      updateSheet = null;
                                      unawaited(eventSubscription.cancel());
                                      if (sheetContext.mounted) {
                                        Navigator.pop(sheetContext);
                                      }
                                      await _endCampfireForEveryone();
                                    },
                            ),
                        ],
                      ),
                      Text(
                        '${participants.length} joined',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Stage $stageCount/$_maxCampfireStageSeats seats',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: stageFull
                              ? Theme.of(context).colorScheme.error
                              : null,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: searchController,
                        onChanged: (_) => setSheetState(() {}),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search guests',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    searchController.clear();
                                    setSheetState(() {});
                                  },
                                ),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final filter in const [
                              ('all', 'All'),
                              ('requests', 'Requests'),
                              ('cohosts', 'Co-hosts'),
                              ('speakers', 'Speakers'),
                              ('listeners', 'Listeners'),
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(filter.$2),
                                  selected: selectedFilter == filter.$1,
                                  onSelected: (_) => setSheetState(
                                    () => selectedFilter = filter.$1,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: false,
                          padding: const EdgeInsets.only(top: 8),
                          itemCount:
                              displayParticipants.length +
                              (hasRequests ? 1 : 0) +
                              (showAllHeader ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (hasRequests && index == 0) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                                child: Text(
                                  'Requests to speak',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              );
                            }
                            final allHeaderIndex =
                                requestedParticipants.length + 1;
                            if (showAllHeader && index == allHeaderIndex) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                                child: Text(
                                  'All guests',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              );
                            }
                            var participantIndex =
                                index - (hasRequests ? 1 : 0);
                            if (showAllHeader && index > allHeaderIndex) {
                              participantIndex -= 1;
                            }
                            final participant =
                                displayParticipants[participantIndex];
                            final role = participant.role == 'cohost'
                                ? 'Co-host'
                                : participant.role == 'host'
                                ? 'Host'
                                : participant.role == 'speaker'
                                ? 'Speaker'
                                : 'Listener';
                            final canAct =
                                canModerate &&
                                !participant.isSelf &&
                                !participant.isOwner &&
                                participant.role != 'host' &&
                                (isOwner || participant.role != 'cohost');
                            return GriotBrandedContainer(
                              padding: EdgeInsets.zero,
                              borderRadius: 16,
                              child: Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 4,
                                  ),
                                  onTap: () => _openCampfireParticipantProfile(
                                    participant,
                                  ),
                                  leading: CircleAvatar(
                                    radius: 22,
                                    backgroundImage:
                                        participant.avatarUrl != null &&
                                            participant.avatarUrl!
                                                .trim()
                                                .isNotEmpty
                                        ? NetworkImage(participant.avatarUrl!)
                                        : null,
                                    child:
                                        participant.avatarUrl == null ||
                                            participant.avatarUrl!
                                                .trim()
                                                .isEmpty
                                        ? Text(
                                            participant.name.isEmpty
                                                ? '?'
                                                : participant.name[0]
                                                      .toUpperCase(),
                                          )
                                        : null,
                                  ),
                                  title: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _compactParticipantName(
                                            participant.isSelf
                                                ? '${_participantDisplayName(participant)} (You)'
                                                : _participantDisplayName(
                                                    participant,
                                                  ),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (participant.isPlus) ...[
                                        const SizedBox(width: 3),
                                        const GriotPlusBadge(
                                          isPlus: true,
                                          compact: true,
                                        ),
                                      ],
                                      if (participant.isPioneer) ...[
                                        const SizedBox(width: 3),
                                        const GriotPioneerBadge(compact: true),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${participant.muted ? 'Muted · ' : ''}$role',
                                  ),
                                  trailing: canAct
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (participant.speakerRequested)
                                              FilledButton(
                                                onPressed: busy || stageFull
                                                    ? null
                                                    : () => moderate(
                                                        participant,
                                                        'approve_speaker',
                                                      ),
                                                style: FilledButton.styleFrom(
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                      ),
                                                ),
                                                child: Text(
                                                  stageFull
                                                      ? 'Stage full'
                                                      : 'Make speaker',
                                                ),
                                              ),
                                            PopupMenuButton<String>(
                                              onSelected: busy
                                                  ? null
                                                  : (action) => moderate(
                                                      participant,
                                                      action,
                                                    ),
                                              itemBuilder: (_) => [
                                                if (!participant
                                                        .speakerRequested &&
                                                    participant.role ==
                                                        'listener')
                                                  PopupMenuItem(
                                                    value: 'approve_speaker',
                                                    enabled: !stageFull,
                                                    child: Text(
                                                      stageFull
                                                          ? 'Stage full'
                                                          : 'Make speaker',
                                                    ),
                                                  ),
                                                if (isOwner)
                                                  PopupMenuItem(
                                                    value:
                                                        participant.role ==
                                                            'cohost'
                                                        ? 'demote'
                                                        : 'promote',
                                                    enabled:
                                                        participant.role !=
                                                            'listener' ||
                                                        !stageFull,
                                                    child: Text(
                                                      participant.role ==
                                                              'cohost'
                                                          ? 'Remove co-host'
                                                          : participant.role ==
                                                                    'listener' &&
                                                                stageFull
                                                          ? 'Stage full'
                                                          : 'Make co-host',
                                                    ),
                                                  ),
                                                if (participant.role ==
                                                    'speaker')
                                                  const PopupMenuItem(
                                                    value: 'revoke_speaker',
                                                    child: Text(
                                                      'Remove speaking permission',
                                                    ),
                                                  ),
                                                if (!participant.muted &&
                                                    participant.role !=
                                                        'listener')
                                                  const PopupMenuItem(
                                                    value: 'mute',
                                                    child: Text('Mute'),
                                                  ),
                                                const PopupMenuItem(
                                                  value: 'remove',
                                                  child: Text(
                                                    'Remove from Campfire',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        )
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (isOwner) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onError,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: busy
                                ? null
                                : () async {
                                    dialogActive = false;
                                    updateSheet = null;
                                    unawaited(eventSubscription.cancel());
                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext);
                                    }
                                    await _endCampfireForEveryone();
                                  },
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: const Text('End Campfire'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    _spaceControlsOpen = false;
    dialogActive = false;
    await eventSubscription.cancel();
    // Reconcile the main Campfire screen after Guests closes. This guarantees
    // the host mic state and newly promoted speaker are visible immediately,
    // even if the final moderation event arrived while the dialog was closing.
    if (mounted && !_cleaningUp) {
      await _refreshCampfireParticipants();
      // Closing Guests changes presentation only. The persistent media
      // session handles its connection independently of this panel.
    }
    // Let the fullscreen dialog finish its route removal before disposing
    // the controller still referenced by the outgoing TextField frame.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    searchController.dispose();
  }

  Future<void> _close({bool notifyServer = true}) async {
    if (_cleaningUp) return;
    _cleaningUp = true;
    _started = false;
    _answerTimeout?.cancel();
    _participantRefreshTimer?.cancel();
    _participantRefreshDebounce?.cancel();
    await _owner.end(
      api: context.read<ApiClient>(),
      messaging: context.read<MessagingApiService>(),
      connecting: _connectionCompleted?.future,
      callId: () => _callId,
      notifyServer: notifyServer,
      timedOut: _timedOut,
    );
  }

  Future<void> _cleanupZego(String? roomId) async {
    try {
      await ZegoExpressEngine.instance.stopSoundLevelMonitor();
    } catch (_) {}
    ZegoExpressEngine.onCapturedSoundLevelUpdate = null;
    ZegoExpressEngine.onRemoteSoundLevelUpdate = null;
    ZegoExpressEngine.onRoomStreamExtraInfoUpdate = null;
    ZegoExpressEngine.onIMRecvCustomCommand = null;
    _remoteSoundLevels.clear();
    _pendingLocalSoundLevel = null;
    _pendingRemoteSoundLevels.clear();
    _soundLevelFrameTimer?.cancel();
    _soundLevelFrameTimer = null;
    _remoteMuted.clear();
    await _media.close();
    _remoteVideoViews.clear();
    _localViewId = null;
  }

  @override
  void dispose() {
    _messagingProvider?.removeListener(_onCampfireRevision);
    _participantRefreshDebounce?.cancel();
    _participantRefreshTimer?.cancel();
    _answerTimeout?.cancel();
    _soundLevelFrameTimer?.cancel();
    _soundLevelFrameTimer = null;
    for (final timer in _spaceReactionTimers.values) {
      timer.cancel();
    }
    _spaceReactionTimers.clear();
    // The app host removes this view only after explicit/remote cleanup.
    // Widget disposal never writes a terminal status to the server.
    super.dispose();
  }

  void _startAnswerTimeout() {
    if (_answerTimeout != null || _remoteJoined) return;
    if (widget.conversationType != 'direct' &&
        widget.conversationType != 'dm' &&
        widget.conversationType != 'conversation') {
      return;
    }
    _answerTimeout = Timer(const Duration(seconds: 45), () {
      if (!mounted || _cleaningUp || _remoteJoined) return;
      _timedOut = true;
      _status = 'No answer';
      unawaited(_close());
    });
  }

  bool get _canShareCallLink =>
      _multiPartyMode ||
      (widget.conversationType != 'direct' && widget.conversationType != 'dm');

  String get _callExitLabel {
    if (widget.conversationType == 'space') {
      return _isCampfireOwner ? 'End Campfire' : 'Leave Campfire';
    }
    if (widget.conversationType == 'group' ||
        widget.conversationType == 'channel') {
      return 'Leave group call';
    }
    // Public invite calls have no owner in the app. Every participant simply
    // joins or leaves; never present an “End call” action for this flow.
    if (widget.conversationType == 'public') return 'Leave call';
    return 'End call';
  }

  Future<void> _handleCampfireExit() => _close();

  Future<void> _endCampfireForEveryone() async {
    if (widget.conversationType != 'space') {
      await _close();
      return;
    }
    final choice = await showGriotChoiceDialog(
      context,
      title: 'Leave or end Campfire?',
      message:
          'Leave keeps the Campfire open for others. End disconnects everyone.',
      choices: [('Leave', 'leave'), ('End for everyone', 'end')],
    );
    if (!mounted || _cleaningUp || choice == null) return;
    if (choice == 'leave') {
      await _handleCampfireExit();
      return;
    }
    try {
      await context.read<MessagingApiService>().endCampfire(
        widget.conversationId,
      );
      await _close(notifyServer: false);
    } catch (error) {
      if (mounted && !_cleaningUp) {
        final message = '$error'.toLowerCase();
        // The server may already have closed the room (another participant,
        // timeout, or a duplicate end request). Treat these as successful
        // teardown and never show a raw API error over the call screen.
        if (message.contains('not found') ||
            message.contains('already ended') ||
            message.contains('already closed') ||
            message.contains('no longer active') ||
            message.contains('404') ||
            message.contains('409') ||
            message.contains('410')) {
          await _close(notifyServer: false);
          return;
        }
        NotificationService.showPush(
          context,
          title: 'Could not end Campfire',
          message: 'You are still connected. Please try again.',
          icon: Icons.error_outline,
        );
      }
    }
  }

  void _minimizeCall() {
    if (!mounted || _cleaningUp) return;
    _owner.minimize();
  }

  void _showCallNotice(
    String title,
    String message, {
    IconData icon = Icons.info_outline_rounded,
  }) {
    if (!mounted || _cleaningUp) return;
    NotificationService.showPush(
      context,
      title: title,
      message: message,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_spaceControlsOpen) _minimizeCall();
      },
      child: GradientScaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Minimize call',
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            onPressed: _minimizeCall,
          ),
          title: Text(
            widget.conversationType == 'space'
                ? _campfireTitle
                : (_videoCallActive ? 'Video call' : 'Voice call'),
          ),
          centerTitle: true,
          backgroundColor: c.surface,
          elevation: 0,
          actions: [
            if (_started && _canShareCallLink)
              IconButton(
                tooltip: 'Share call link',
                onPressed: _sharingLink ? null : _shareCallLink,
                icon: const Icon(Icons.link_rounded),
              ),
            if (widget.conversationType != 'space')
              IconButton(
                tooltip: 'Add people or retry ringing',
                onPressed: _invitePeople,
                icon: const Icon(Icons.person_add_alt_1_rounded),
              ),
            if (widget.conversationType == 'space')
              IconButton(
                tooltip: 'Participants and controls',
                onPressed: _showSpaceControls,
                icon: const Icon(Icons.people_alt_outlined),
              ),
          ],
        ),
        child: Center(
          child: _cleaningUp
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                )
              : _videoCallActive
              ? _buildVideoCallBody(c)
              : _buildVoiceCallBody(c),
        ),
      ),
    );
  }

  Widget _buildVoiceCallBody(ColorScheme colors) {
    if (widget.conversationType == 'space') {
      return _buildCampfireVoiceBody(colors);
    }
    if (_isMultiPartyCall) {
      return _buildGroupVoiceBody(colors);
    }
    final title = widget.conversationType == 'space'
        ? 'Voice Campfire'
        : _remoteCallLabel();
    final subtitle = _started ? _status : 'Connecting securely';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      child: Column(
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: GriotBrandedContainer(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
              borderRadius: 30,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _CallStatusPill(
                      label: _started ? 'BURNING' : 'CONNECTING',
                      colors: colors,
                      live: _started,
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.primary.withValues(alpha: .55),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: .22),
                                blurRadius: 28,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 66,
                            backgroundColor: colors.primary.withValues(
                              alpha: .16,
                            ),
                            foregroundColor: colors.primary,
                            backgroundImage:
                                _remoteAvatarUrl != null &&
                                    _remoteAvatarUrl!.isNotEmpty
                                ? NetworkImage(_remoteAvatarUrl!)
                                : null,
                            child:
                                _remoteAvatarUrl == null ||
                                    _remoteAvatarUrl!.isEmpty
                                ? const Icon(Icons.graphic_eq_rounded, size: 54)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _AudioInputShimmer(
                          // A live microphone should not animate while the
                          // speaker is silent. This keeps the indicator tied
                          // to the actual input level instead of breathing at
                          // a fixed/random cadence.
                          active:
                              _started &&
                              _audioEnabled &&
                              _localSoundLevel > .025,
                          color: colors.primary,
                          intensity: _localSoundLevel,
                        ),
                        if (_remoteParticipantMuted) ...[
                          const SizedBox(height: 8),
                          _MutedCallIndicator(colors: colors),
                        ],
                        if (widget.conversationType == 'space' &&
                            _spaceParticipants.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          _buildCampfireParticipantGrid(colors),
                        ],
                        const SizedBox(height: 24),
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.error),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_started)
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                child: _buildCallControls(colors),
              ),
            ),
          const SizedBox(height: 10),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _isCampfireOwner
                  ? _endCampfireForEveryone
                  : _handleCampfireExit,
              icon: const Icon(Icons.call_end_rounded),
              label: Text(_callExitLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupVoiceBody(ColorScheme colors) {
    final remoteIds = _remoteStreams.toList()
      ..sort(
        (a, b) =>
            (_remoteSoundLevels[b] ?? 0).compareTo(_remoteSoundLevels[a] ?? 0),
      );
    // Keep the local participant in the same ranking as remote participants
    // after a direct call is upgraded, so the active speakers occupy the
    // first cards instead of always pinning the local user at index zero.
    final participantOrder = <String?>[null, ...remoteIds]
      ..sort((a, b) {
        bool micIsOn(String? streamId) => streamId == null
            ? _audioEnabled
            : !(_remoteMuted[streamId] ?? false);
        final aMic = micIsOn(a);
        final bMic = micIsOn(b);
        if (aMic != bMic) return bMic ? 1 : -1;
        final aLevel = a == null
            ? _localSoundLevel
            : (_remoteSoundLevels[a] ?? 0);
        final bLevel = b == null
            ? _localSoundLevel
            : (_remoteSoundLevels[b] ?? 0);
        return bLevel.compareTo(aLevel);
      });
    final total = participantOrder.length;
    final participantTiles = List<Widget>.generate(total, (index) {
      final streamId = participantOrder[index];
      final isLocal = streamId == null;
      final name = isLocal
          ? 'You'
          : _participantNameFromStream(streamId, index);
      final profile = streamId == null ? null : _profileForStream(streamId);
      return _voiceParticipantCard(
        colors,
        name,
        isLocal: isLocal,
        soundLevel: isLocal
            ? _localSoundLevel
            : (_remoteSoundLevels[streamId] ?? 0),
        speaking: isLocal
            ? _audioEnabled && _localSoundLevel > 0.04
            : !(_remoteMuted[streamId] ?? false) &&
                  (_remoteSoundLevels[streamId] ?? 0) > 0.04,
        muted: isLocal ? !_audioEnabled : (_remoteMuted[streamId] ?? false),
        onLongPress: isLocal ? null : () => _requestMuteParticipant(streamId),
        avatarUrl: isLocal
            ? context.read<UserProvider>().user?.avatarUrl
            : (_avatarUrlFromProfile(profile) ??
                  (index == 1 ? _remoteAvatarUrl : null)),
      );
    });
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: Column(
        children: [
          Expanded(
            child: GriotBrandedContainer(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              borderRadius: 30,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 82),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _multiPartyMode || _remoteDisplayName.isEmpty
                                    ? 'Group call'
                                    : _remoteCallLabel(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Text(
                              '$total ${total == 1 ? 'participant' : 'participants'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = switch (participantTiles.length) {
                                0 || 1 => 1,
                                2 || 3 || 4 => 2,
                                _ => constraints.maxWidth >= 680 ? 3 : 2,
                              };
                              final rows = <List<Widget>>[];
                              for (
                                var index = 0;
                                index < participantTiles.length;
                                index += columns
                              ) {
                                rows.add(
                                  participantTiles.sublist(
                                    index,
                                    (index + columns).clamp(
                                      0,
                                      participantTiles.length,
                                    ),
                                  ),
                                );
                              }
                              return ListView.separated(
                                padding: const EdgeInsets.fromLTRB(2, 2, 2, 16),
                                physics: const BouncingScrollPhysics(),
                                itemCount: rows.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, rowIndex) {
                                  final row = rows[rowIndex];
                                  return SizedBox(
                                    height: columns == 1
                                        ? 220
                                        : columns == 2
                                        ? 190
                                        : 170,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        for (
                                          var tileIndex = 0;
                                          tileIndex < row.length;
                                          tileIndex++
                                        ) ...[
                                          if (tileIndex > 0)
                                            const SizedBox(width: 10),
                                          Expanded(child: row[tileIndex]),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _status,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (_started)
                    Positioned(
                      left: 28,
                      right: 28,
                      bottom: 14,
                      child: Material(
                        elevation: 10,
                        color: colors.surface.withValues(alpha: 0.97),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                            color: colors.outlineVariant.withValues(alpha: 0.7),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 9),
                          child: _buildCallControls(colors, compact: true),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _isCampfireOwner
                  ? _endCampfireForEveryone
                  : _handleCampfireExit,
              icon: const Icon(Icons.call_end_rounded),
              label: Text(_callExitLabel),
            ),
          ),
        ],
      ),
    );
  }

  String _participantNameFromStream(String streamId, int index) {
    final profile = _profileForStream(streamId);
    final profileName = _displayNameOrWallet(
      profile?['display_name']?.toString() ??
          profile?['displayName']?.toString(),
      profile?['username']?.toString(),
      profile?['wallet_address']?.toString() ??
          profile?['walletAddress']?.toString(),
      fallback: '',
    );
    if (profileName.isNotEmpty) return profileName;
    final parts = streamId.split('-');
    if (parts.length >= 3 && parts[0] == 'griot') {
      final id = parts.sublist(1, parts.length - 1).join('-');
      if (id.isNotEmpty) {
        return _shortWallet(id);
      }
    }
    return 'Participant $index';
  }

  String? _avatarUrlFromProfile(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    final nested = profile['profile'];
    final nestedProfile = nested is Map
        ? Map<String, dynamic>.from(nested)
        : const <String, dynamic>{};
    final value =
        profile['avatar_url'] ??
        profile['avatarUrl'] ??
        profile['profile_url'] ??
        profile['profileUrl'] ??
        profile['image_url'] ??
        profile['imageUrl'] ??
        nestedProfile['avatar_url'] ??
        nestedProfile['avatarUrl'] ??
        nestedProfile['profile_url'] ??
        nestedProfile['profileUrl'];
    final url = value?.toString().trim();
    return url == null || url.isEmpty ? null : url;
  }

  Map<String, dynamic>? _profileForStream(String streamId) {
    final parts = streamId.split('-');
    if (parts.length < 3 || parts.first != 'griot') return null;
    final id = parts.sublist(1, parts.length - 1).join('-');
    return _callParticipantProfiles[id];
  }

  Widget _voiceParticipantCard(
    ColorScheme colors,
    String name, {
    required bool isLocal,
    bool speaking = false,
    double soundLevel = 0,
    bool muted = false,
    VoidCallback? onLongPress,
    String? avatarUrl,
  }) {
    return _SpeakingRing(
      active: speaking,
      intensity: soundLevel,
      accentColor: colors.primary,
      fireEffect: false,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: .42),
            borderRadius: BorderRadius.circular(18),
            border: Border(
              top: BorderSide(
                color: colors.primary.withValues(alpha: .6),
                width: 1.2,
              ),
              bottom: BorderSide(
                color: colors.primary.withValues(alpha: .6),
                width: 1.2,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: .14),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colors.primary.withValues(alpha: .16),
                  child: avatarUrl != null && avatarUrl.trim().isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: avatarUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) =>
                                _avatarFallback(colors, name),
                          ),
                        )
                      : _avatarFallback(colors, name),
                ),
                const SizedBox(height: 8),
                Text(
                  isLocal ? '$name (You)' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Icon(
                  !muted ? Icons.mic_rounded : Icons.mic_off_rounded,
                  size: 16,
                  color: muted ? colors.error : colors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCampfireVoiceBody(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 22),
      child: Column(
        children: [
          Expanded(
            child: GriotBrandedContainer(
              padding: EdgeInsets.zero,
              borderRadius: 28,
              child: Stack(
                children: [
                  // Campfire controls stay visible so listeners can always
                  // mute, react, raise a hand, or leave without tapping the
                  // participant surface first.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 16, 10, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _campfireTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${_spaceParticipants.length} joined',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colors.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            _CallStatusPill(
                              label: _started ? 'BURNING' : 'CONNECTING',
                              colors: colors,
                              live: _started,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _spaceParticipants.isEmpty
                              ? Center(
                                  child: Text(
                                    'Waiting for participants…',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                )
                              : SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  // Keep the last audience row above the
                                  // floating controls instead of hiding it.
                                  padding: const EdgeInsets.only(bottom: 112),
                                  child: _buildCampfireParticipantGrid(colors),
                                ),
                        ),
                      ],
                    ),
                  ),
                  if (_started)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 10,
                      child: GriotBrandedContainer(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
                        borderRadius: 18,
                        child: _buildCallControls(colors, compact: true),
                      ),
                    ),
                  if (widget.conversationType == 'space')
                    Positioned(
                      right: 18,
                      bottom: 104,
                      child: _buildCampfireExitFab(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _isCampfireOwner {
    final self = _spaceParticipants.where((item) => item.isSelf).firstOrNull;
    return self?.isOwner == true || self?.role == 'host';
  }

  Widget _buildCampfireExitFab() {
    final colors = Theme.of(context).colorScheme;
    return FloatingActionButton(
      heroTag: null,
      tooltip: _isCampfireOwner ? 'End Campfire' : 'Leave Campfire',
      onPressed: _isCampfireOwner
          ? _endCampfireForEveryone
          : _handleCampfireExit,
      backgroundColor: colors.primary,
      foregroundColor: colors.onPrimary,
      child: Icon(
        _isCampfireOwner ? Icons.call_end_rounded : Icons.exit_to_app_rounded,
      ),
    );
  }

  Widget _buildCampfireParticipantGrid(ColorScheme colors) {
    final participants = [..._spaceParticipants];
    final stage = participants
        .where(
          (p) =>
              p.isOwner ||
              p.role == 'host' ||
              p.role == 'cohost' ||
              p.role == 'speaker',
        )
        .toList();
    final listeners = participants.where((p) => !stage.contains(p)).toList();
    // A Campfire can have a large audience. Rendering hundreds of avatar
    // cards (and recalculating sound state for each one on every audio tick)
    // makes the call view jank and can exhaust memory on mobile. Keep the
    // stage complete, but virtualize the audience presentation with a
    // bounded preview; the participant controls screen remains the place to
    // manage the full list.
    const maxListenerPreview = 24;
    final visibleListeners = listeners.length > maxListenerPreview
        ? listeners.take(maxListenerPreview).toList()
        : listeners;
    final hiddenListenerCount = listeners.length - visibleListeners.length;

    Widget section(String title, List<SpaceParticipant> people) {
      if (people.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: people.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                // Keep the compact, stage-style layout used by modern social
                // audio rooms. The surrounding participant viewport scrolls
                // when a Campfire has more people than fit on screen.
                // Keep three participants visible per row while preserving
                // enough width for an avatar, name, role, and mic state.
                // Tight spacing keeps the stage from feeling vertically
                // stretched when several speakers are present.
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 8,
                // A fixed extent gives the name, role, mute state, and
                // moderation affordance room to breathe. The old .78 ratio
                // produced the visible 7px overflow on narrow phones.
                // Stage and audience cards intentionally share one extent so
                // every row aligns as a regular three-column grid.
                mainAxisExtent: 168,
              ),
              itemBuilder: (context, index) {
                final participant = people[index];
                final avatarUrl = participant.avatarUrl?.trim();
                final reaction = _spaceReactions[participant.id];
                final role = participant.isOwner || participant.role == 'host'
                    ? 'Host'
                    : participant.role == 'cohost'
                    ? 'Co-host'
                    : participant.role == 'speaker'
                    ? 'Speaker'
                    : 'Listener';
                final participantSoundLevel = participant.isSelf
                    ? _localSoundLevel
                    : _remoteSoundLevels.entries
                          .map(
                            (entry) =>
                                _streamBelongsToParticipant(
                                  entry.key,
                                  participant,
                                )
                                ? entry.value
                                : 0.0,
                          )
                          .fold<double>(0, math.max);
                final isStageParticipant = participant.role != 'listener';
                // Keep a subtle stage animation visible, while real mic input
                // raises its intensity when sound-level events arrive.
                final participantSpeaking =
                    _started && !participant.muted && isStageParticipant;
                final flameIntensity = participantSpeaking
                    ? math.max(.12, participantSoundLevel)
                    : 0.0;
                return _SpeakingRing(
                  active: participantSpeaking,
                  accentColor: colors.primary,
                  fireEffect: true,
                  intensity: flameIntensity,
                  child: SizedBox.expand(
                    child: Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.none,
                      children: [
                        GriotBrandedContainer(
                          padding: EdgeInsets.zero,
                          borderRadius: 16,
                          blurSigma: 0,
                          // The fire/speaking overlay is clipped inside this
                          // card, while the normal Griot border remains visible
                          // even when the participant is quiet.
                          showBorder: true,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () =>
                                  _openCampfireParticipantProfile(participant),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 12,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        CircleAvatar(
                                          radius: 39,
                                          backgroundColor: colors.primary
                                              .withValues(alpha: .16),
                                          child:
                                              avatarUrl != null &&
                                                  avatarUrl.isNotEmpty
                                              ? ClipOval(
                                                  child: Image.network(
                                                    avatarUrl,
                                                    width: 76,
                                                    height: 76,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, _, _) =>
                                                        _avatarFallback(
                                                          colors,
                                                          participant.name,
                                                        ),
                                                  ),
                                                )
                                              : _avatarFallback(
                                                  colors,
                                                  participant.name,
                                                ),
                                        ),
                                        if (participant.speakerRequested)
                                          Positioned(
                                            left: -3,
                                            top: -3,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: colors.tertiaryContainer,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  3,
                                                ),
                                                child: Icon(
                                                  Icons.front_hand_rounded,
                                                  size: 14,
                                                  color: colors
                                                      .onTertiaryContainer,
                                                ),
                                              ),
                                            ),
                                          ),
                                        Positioned(
                                          right: -3,
                                          bottom: -2,
                                          child: Icon(
                                            (participant.muted ||
                                                    participant.role ==
                                                        'listener')
                                                ? Icons.mic_off_rounded
                                                : Icons.mic_rounded,
                                            size: 16,
                                            color:
                                                (participant.muted ||
                                                    participant.role ==
                                                        'listener')
                                                ? colors.error
                                                : colors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _compactParticipantName(
                                              participant.isSelf
                                                  ? 'You'
                                                  : _participantDisplayName(
                                                      participant,
                                                    ),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        if (participant.isPlus) ...[
                                          const SizedBox(width: 2),
                                          const GriotPlusBadge(
                                            isPlus: true,
                                            compact: true,
                                          ),
                                        ],
                                        if (participant.isPioneer) ...[
                                          const SizedBox(width: 2),
                                          const GriotPioneerBadge(
                                            compact: true,
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      role,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (reaction != null)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: _CallReactionBubble(
                              emoji: reaction,
                              colors: colors,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        section('On stage · ${stage.length} speakers', stage),
        if (stage.isNotEmpty && listeners.isNotEmpty) const SizedBox(height: 8),
        section('Audience · ${listeners.length} listeners', visibleListeners),
        if (hiddenListenerCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '+$hiddenListenerCount more listeners — open Participants to view all',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _avatarFallback(ColorScheme colors, String name) {
    return Text(
      name.isEmpty ? '?' : name[0].toUpperCase(),
      style: TextStyle(
        color: colors.onPrimaryContainer,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  String _compactParticipantName(String name) {
    final value = name.trim();
    if (value.length <= 18) return value.isEmpty ? 'Griot user' : value;
    return '${value.substring(0, 17).trimRight()}…';
  }

  String _participantDisplayName(SpaceParticipant participant) {
    final value = participant.name.trim();
    final generic =
        value.isEmpty ||
        {
          'griot user',
          'griot contact',
          'participant',
          'user',
        }.contains(value.toLowerCase());
    final looksLikeWallet =
        value.length >= 12 &&
        (value.startsWith('0x') || RegExp(r'^[a-fA-F0-9]+$').hasMatch(value));
    if (!generic && !looksLikeWallet) return value;
    final id = participant.id.trim();
    final source = looksLikeWallet ? value : id;
    if (source.length > 6) {
      return '${source.substring(0, 3)}…${source.substring(source.length - 3)}';
    }
    return id.isEmpty ? 'Griot user' : id;
  }

  void _openCampfireParticipantProfile(SpaceParticipant participant) {
    if (!mounted || participant.id.trim().isEmpty) return;
    _owner.minimize();
    AppRouter.router.push(
      '/user/profile',
      extra: UserModel(
        id: participant.id,
        walletAddress: participant.id,
        displayName: participant.name.trim().isEmpty
            ? 'Griot user'
            : participant.name.trim(),
        avatarUrl: participant.avatarUrl,
      ),
    );
  }

  Widget _buildVideoCallBody(ColorScheme colors) {
    final remoteViews = _remoteVideoViews.values.toList();
    if (_isMultiPartyCall || widget.conversationType == 'space') {
      return _buildGroupVideoGrid(colors, remoteViews);
    }
    final remoteView = remoteViews.isEmpty ? null : remoteViews.first;
    final remoteStreamId = _remoteVideoViews.isEmpty
        ? null
        : _remoteVideoViews.keys.first;
    final remoteMuted =
        remoteStreamId != null && (_remoteMuted[remoteStreamId] ?? false);
    final hasBothVideos = remoteView != null && _localVideoView != null;
    final mainView = hasBothVideos
        ? (_showLocalMain ? _localVideoView : remoteView)
        : (remoteView ?? _localVideoView);
    final thumbnailView = hasBothVideos
        ? (_showLocalMain ? remoteView : _localVideoView)
        : null;
    final mainLabel = hasBothVideos
        ? (_showLocalMain ? _localDisplayName : _remoteCallLabel())
        : (remoteView != null ? _remoteCallLabel() : _localDisplayName);
    final thumbnailLabel = _showLocalMain
        ? _remoteCallLabel()
        : _localDisplayName;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      setState(() => _showVideoControls = !_showVideoControls),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (mainView != null)
                        Positioned.fill(child: _coverVideo(mainView))
                      else
                        Center(
                          child: Text(
                            _started
                                ? 'Waiting for the other camera…'
                                : _status,
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ),
                      // A subtle branded wash keeps the native video surface
                      // integrated with the rest of Griot without obscuring it.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: .34),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: .42),
                                ],
                                stops: const [0, .42, 1],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 18,
                        right: 18,
                        child: _CallStatusPill(
                          label: _started ? 'LIVE' : 'CONNECTING',
                          colors: colors,
                          live: _started,
                        ),
                      ),
                      // Keep the other participant's identity and the leave
                      // action in the video chrome so the media surface stays
                      // unobstructed and the action is always discoverable.
                      if (widget.conversationType != 'space')
                        Positioned(
                          top: 16,
                          left: 16,
                          child: _VideoLabel(
                            label: _remoteCallLabel(),
                            colors: colors,
                          ),
                        ),
                      if (remoteMuted)
                        Positioned(
                          top: 56,
                          left: 16,
                          child: _MutedCallIndicator(colors: colors),
                        ),
                      if (widget.conversationType == 'space')
                        Positioned(
                          left: 16,
                          bottom: 16,
                          child: _VideoLabel(label: mainLabel, colors: colors),
                        ),
                      if (thumbnailView != null)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          top: _thumbnailTop,
                          right: _thumbnailRight,
                          bottom: _thumbnailBottom,
                          left: _thumbnailLeft,
                          width: 118,
                          height: 168,
                          child: Tooltip(
                            message: 'Tap to swap • Drag to move',
                            child: GestureDetector(
                              onTap: _swapVideoLayout,
                              onPanUpdate: (details) {
                                setState(() {
                                  _thumbnailDragOffset = Offset(
                                    (_thumbnailDragOffset.dx + details.delta.dx)
                                        .clamp(-150.0, 150.0),
                                    (_thumbnailDragOffset.dy + details.delta.dy)
                                        .clamp(-260.0, 260.0),
                                  );
                                });
                              },
                              onPanEnd: _onThumbnailDragEnd,
                              child: Transform.translate(
                                offset: _thumbnailDragOffset,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black54,
                                        blurRadius: 16,
                                        offset: Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Positioned.fill(
                                          child: _coverVideo(thumbnailView),
                                        ),
                                        Positioned(
                                          left: 8,
                                          bottom: 8,
                                          child: _VideoLabel(
                                            label: thumbnailLabel,
                                            colors: colors,
                                            compact: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_showVideoControls)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 14,
                          child: AnimatedOpacity(
                            opacity: _showVideoControls ? 1 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                                child: _buildCallControls(colors),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (widget.conversationType != 'space') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: _handleCampfireExit,
                icon: const Icon(Icons.call_end_rounded),
                label: const Text('End call'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupVideoGrid(ColorScheme colors, List<Widget> remoteViews) {
    final tiles = <Widget>[];
    if (_localVideoView != null) {
      final self = widget.conversationType == 'space'
          ? _spaceParticipants.where((item) => item.isSelf).firstOrNull
          : null;
      tiles.add(
        _videoTile(
          colors,
          _localVideoView!,
          _localDisplayName,
          true,
          subtitle: self == null ? null : _campfireRoleLabel(self),
          speakerRequested: self?.speakerRequested == true,
          muted: !_audioEnabled,
          speaking: _audioEnabled,
          soundLevel: widget.conversationType == 'space' ? _localSoundLevel : 0,
        ),
      );
    }
    final remoteIds = _remoteVideoViews.keys.toList(growable: false);
    for (var index = 0; index < remoteViews.length; index++) {
      final streamId = index < remoteIds.length ? remoteIds[index] : null;
      final campfireParticipant =
          streamId == null || widget.conversationType != 'space'
          ? null
          : _spaceParticipantForStream(streamId);
      tiles.add(
        _videoTile(
          colors,
          remoteViews[index],
          streamId == null
              ? 'Participant ${index + 1}'
              : campfireParticipant == null
              ? _participantNameFromStream(streamId, index + 1)
              : _participantDisplayName(campfireParticipant),
          false,
          subtitle: campfireParticipant == null
              ? null
              : _campfireRoleLabel(campfireParticipant),
          speakerRequested: campfireParticipant?.speakerRequested == true,
          muted:
              campfireParticipant?.muted ??
              (streamId == null ? false : (_remoteMuted[streamId] ?? false)),
          speaking: campfireParticipant == null
              ? true
              : !campfireParticipant.muted,
          soundLevel: widget.conversationType == 'space' && streamId != null
              ? (_remoteSoundLevels[streamId] ?? 0)
              : 0,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Use a row layout instead of a fixed GridView.  This lets
                // the final participant in a 3-person call span the width,
                // keeps four participants in a balanced 2x2 layout, and
                // switches to three columns only when the available surface
                // is wide enough for comfortable video tiles.
                final columns = switch (tiles.length) {
                  0 || 1 => 1,
                  2 || 3 || 4 => 2,
                  _ => constraints.maxWidth >= 680 ? 3 : 2,
                };
                final rows = <List<Widget>>[];
                for (var index = 0; index < tiles.length; index += columns) {
                  rows.add(
                    tiles.sublist(
                      index,
                      (index + columns).clamp(0, tiles.length),
                    ),
                  );
                }
                return Scrollbar(
                  thumbVisibility: rows.length > 1,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(right: 4),
                    physics: const BouncingScrollPhysics(),
                    itemCount: rows.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, rowIndex) {
                      final row = rows[rowIndex];
                      return AspectRatio(
                        // A single tile gets a wider presentation, while
                        // multi-tile rows preserve a consistent card shape.
                        aspectRatio: row.length == 1
                            ? 1.55
                            : columns == 3
                            ? 1.55
                            : 1.28,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (
                              var tileIndex = 0;
                              tileIndex < row.length;
                              tileIndex++
                            ) ...[
                              if (tileIndex > 0) const SizedBox(width: 10),
                              Expanded(child: row[tileIndex]),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildCallControls(colors),
          const SizedBox(height: 10),
          if (widget.conversationType != 'space') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: _handleCampfireExit,
                icon: const Icon(Icons.call_end_rounded),
                label: const Text('End call'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  SpaceParticipant? _spaceParticipantForStream(String streamId) {
    final profile = _profileForStream(streamId);
    final profileId =
        (profile?['id'] ?? profile?['user_id'] ?? profile?['userId'])
            ?.toString();
    if (profileId != null) {
      for (final participant in _spaceParticipants) {
        if (participant.id == profileId) return participant;
      }
    }
    final parts = streamId.split('-');
    if (parts.length < 3 || parts.first != 'griot') return null;
    final id = parts.sublist(1, parts.length - 1).join('-');
    for (final participant in _spaceParticipants) {
      if (participant.id == id) return participant;
    }
    return null;
  }

  bool _streamBelongsToParticipant(
    String streamId,
    SpaceParticipant participant,
  ) {
    if (streamId == participant.id) return true;
    final participantId = participant.id.trim();
    if (participantId.isNotEmpty && streamId.contains(participantId)) {
      return true;
    }
    return _spaceParticipantForStream(streamId)?.id == participant.id;
  }

  String _campfireRoleLabel(SpaceParticipant participant) {
    if (participant.isOwner || participant.role == 'host') return 'Host';
    if (participant.role == 'cohost') return 'Co-host';
    if (participant.role == 'speaker') return 'Speaker';
    return 'Listener';
  }

  Widget _videoTile(
    ColorScheme colors,
    Widget view,
    String label,
    bool local, {
    String? subtitle,
    bool speakerRequested = false,
    bool muted = false,
    bool speaking = false,
    double soundLevel = 0,
  }) {
    return _SpeakingRing(
      active: speaking,
      intensity: soundLevel,
      fireEffect: false,
      child: GriotBrandedContainer(
        padding: EdgeInsets.zero,
        borderRadius: 22,
        blurSigma: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _coverVideo(view),
              if (speaking)
                Positioned(
                  top: 10,
                  right: muted ? 54 : 10,
                  child: _AudioInputShimmer(
                    active: true,
                    color: Colors.white,
                    intensity: soundLevel,
                    width: 64,
                    height: 18,
                  ),
                ),
              if (speakerRequested)
                Positioned(
                  top: 10,
                  left: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.tertiaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Icon(
                        Icons.front_hand_rounded,
                        size: 16,
                        color: colors.onTertiaryContainer,
                      ),
                    ),
                  ),
                ),
              if (muted)
                Positioned(
                  top: 10,
                  right: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.mic_off_rounded,
                        size: 16,
                        color: colors.onError,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _VideoLabel(
                      label: local ? '$label (You)' : label,
                      colors: colors,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .52),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          child: Text(
                            subtitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double? get _thumbnailTop => switch (_thumbnailCorner) {
    _VideoThumbnailCorner.topLeft || _VideoThumbnailCorner.topRight => 18,
    _ => null,
  };

  double? get _thumbnailBottom => switch (_thumbnailCorner) {
    _VideoThumbnailCorner.bottomLeft || _VideoThumbnailCorner.bottomRight => 18,
    _ => null,
  };

  double? get _thumbnailLeft => switch (_thumbnailCorner) {
    _VideoThumbnailCorner.topLeft || _VideoThumbnailCorner.bottomLeft => 18,
    _ => null,
  };

  double? get _thumbnailRight => switch (_thumbnailCorner) {
    _VideoThumbnailCorner.topRight || _VideoThumbnailCorner.bottomRight => 18,
    _ => null,
  };

  void _onThumbnailDragEnd(DragEndDetails details) {
    // Project a short distance in the direction of the release. This makes a
    // quick flick feel natural while still allowing a slow drag to settle.
    final velocity = details.velocity.pixelsPerSecond;
    final projected = Offset(
      _thumbnailDragOffset.dx + velocity.dx.clamp(-900.0, 900.0) * 0.08,
      _thumbnailDragOffset.dy + velocity.dy.clamp(-900.0, 900.0) * 0.08,
    );
    final left = projected.dx < -24
        ? true
        : projected.dx > 24
        ? false
        : _thumbnailCorner.isLeft;
    final top = projected.dy < -24
        ? true
        : projected.dy > 24
        ? false
        : _thumbnailCorner.isTop;
    setState(() {
      _thumbnailCorner = switch ((top, left)) {
        (true, true) => _VideoThumbnailCorner.topLeft,
        (true, false) => _VideoThumbnailCorner.topRight,
        (false, true) => _VideoThumbnailCorner.bottomLeft,
        (false, false) => _VideoThumbnailCorner.bottomRight,
      };
      _thumbnailDragOffset = Offset.zero;
    });
  }

  Widget _buildCallControls(ColorScheme colors, {bool compact = false}) {
    final self = _spaceParticipants.where((item) => item.isSelf).firstOrNull;
    final canSpeak =
        widget.conversationType != 'space' ||
        self?.isOwner == true ||
        self?.role == 'host' ||
        self?.role == 'cohost' ||
        self?.role == 'speaker';
    final controls = <Widget>[];
    controls.add(
      _CallControl(
        icon: switch (_audioRoute) {
          ZegoAudioRoute.Speaker => Icons.volume_up_rounded,
          ZegoAudioRoute.Headphone ||
          ZegoAudioRoute.Bluetooth ||
          ZegoAudioRoute.ExternalUSB ||
          ZegoAudioRoute.AirPlay => Icons.headphones_rounded,
          ZegoAudioRoute.Receiver => Icons.hearing_rounded,
        },
        label: switch (_audioRoute) {
          ZegoAudioRoute.Speaker => 'Speaker on',
          ZegoAudioRoute.Headphone => 'Headphones',
          ZegoAudioRoute.Bluetooth => 'Bluetooth',
          ZegoAudioRoute.ExternalUSB => 'USB audio',
          ZegoAudioRoute.AirPlay => 'AirPlay',
          ZegoAudioRoute.Receiver => 'Earpiece',
        },
        onPressed: _toggleSpeaker,
        compact: compact,
      ),
    );
    if (widget.conversationType == 'space') {
      controls.add(
        _CallControl(
          icon: Icons.emoji_emotions_outlined,
          label: 'React',
          onPressed: _showCallReactions,
          compact: compact,
        ),
      );
    }
    if (canSpeak) {
      controls.add(
        _CallControl(
          icon: _audioEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
          label: _audioEnabled ? 'Mute' : 'Unmute',
          onPressed: _toggleAudio,
          compact: compact,
        ),
      );
    } else if (widget.conversationType == 'space') {
      final handRaised = self?.speakerRequested == true;
      controls.add(
        _CallControl(
          icon: handRaised ? Icons.pan_tool_rounded : Icons.pan_tool_outlined,
          label: handRaised ? 'Lower hand' : 'Raise hand',
          foregroundColor: handRaised ? colors.tertiary : null,
          onPressed: _requestToSpeak,
          compact: compact,
        ),
      );
    }
    if (widget.conversationType != 'space' || (canSpeak && _videoCallActive)) {
      controls.addAll([
        _CallControl(
          icon: _videoEnabled
              ? Icons.videocam_rounded
              : Icons.videocam_off_rounded,
          label: _videoEnabled ? 'Camera off' : 'Camera on',
          onPressed: _toggleVideo,
          compact: compact,
        ),
        if (_videoEnabled)
          _CallControl(
            icon: Icons.flip_camera_ios_rounded,
            label: 'Switch camera',
            onPressed: _switchCamera,
            compact: compact,
          ),
      ]);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          // Keep the speaker/reaction/mic controls visually separated. The
          // previous 4px compact gap made the buttons read as one crowded
          // control, especially on Campfire cards.
          spacing: compact ? 20 : 24,
          runSpacing: compact ? 10 : 14,
          children: controls,
        ),
      ),
    );
  }

  /// Configures Zego's native surface to fit the masked call canvas without
  /// cropping the camera frame. A Flutter scale transform cannot reliably
  /// resize a platform view on every device.
  ZegoCanvas _callCanvas(int viewId) => ZegoCanvas(
    viewId,
    viewMode: ZegoViewMode.AspectFill,
    backgroundColor: 0x000000,
  );

  Widget _coverVideo(Widget video) => ClipRect(child: video);
}

class _CallReactionBubble extends StatelessWidget {
  final String emoji;
  final ColorScheme colors;

  const _CallReactionBubble({required this.emoji, required this.colors});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: colors.surface,
      shape: BoxShape.circle,
      border: Border.all(color: colors.primary.withValues(alpha: .7)),
      boxShadow: [
        BoxShadow(
          color: colors.shadow.withValues(alpha: .25),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(7),
      child: Text(emoji, style: const TextStyle(fontSize: 22)),
    ),
  );
}

class _VideoLabel extends StatelessWidget {
  final String label;
  final ColorScheme colors;
  final bool compact;

  const _VideoLabel({
    required this.label,
    required this.colors,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 10 : 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MutedCallIndicator extends StatelessWidget {
  final ColorScheme colors;

  const _MutedCallIndicator({required this.colors});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.error.withValues(alpha: 0.42)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_off_rounded, size: 15, color: colors.error),
            const SizedBox(width: 5),
            Text(
              'Muted',
              style: TextStyle(
                color: colors.error,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallStatusPill extends StatelessWidget {
  final String label;
  final ColorScheme colors;
  final bool live;

  const _CallStatusPill({
    required this.label,
    required this.colors,
    required this.live,
  });

  @override
  Widget build(BuildContext context) {
    final accent = live ? const Color(0xFF48D597) : colors.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: .6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: .8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small, non-metering visual cue that gives callers immediate feedback
/// that their microphone is active. The bars deliberately breathe through
/// different heights to suggest both quiet and loud speech without exposing
/// raw microphone data or implying a calibrated volume meter.
class _AudioInputShimmer extends StatefulWidget {
  const _AudioInputShimmer({
    required this.active,
    required this.color,
    this.width = 112,
    this.height = 24,
    this.intensity = 0,
  });

  final bool active;
  final Color color;
  final double width;
  final double height;
  final double intensity;

  @override
  State<_AudioInputShimmer> createState() => _AudioInputShimmerState();
}

class _AudioInputShimmerState extends State<_AudioInputShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _AudioInputShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const levels = <double>[.3, .58, .9, .5, .78, .42, .68];
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(levels.length, (index) {
              final phase = (_controller.value + index * .16) * math.pi * 2;
              final input = widget.intensity.clamp(0.0, 1.0);
              final pulse = widget.active
                  ? .18 +
                        input * .72 +
                        ((math.sin(phase) + 1) / 2) * (.08 + input * .22)
                  : .18;
              final barHeight = math.max(
                3.0,
                widget.height * levels[index] * pulse,
              );
              return Container(
                width: widget.width < 80 ? 3 : 5,
                height: barHeight,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: widget.color.withValues(
                    alpha: widget.active ? .88 : .28,
                  ),
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: widget.active
                      ? [
                          BoxShadow(
                            color: widget.color.withValues(alpha: .22),
                            blurRadius: 5,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _SpeakingRing extends StatefulWidget {
  final Widget child;
  final bool active;
  final Color? accentColor;
  final double intensity;
  final bool fireEffect;

  const _SpeakingRing({
    required this.child,
    required this.active,
    this.accentColor,
    this.intensity = 0,
    this.fireEffect = false,
  });

  @override
  State<_SpeakingRing> createState() => _SpeakingRingState();
}

class _SpeakingRingState extends State<_SpeakingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _SpeakingRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return Material(
        color: Colors.transparent,
        elevation: widget.fireEffect ? 4 : 0,
        shadowColor: Colors.black.withValues(alpha: .22),
        borderRadius: BorderRadius.circular(16),
        child: widget.child,
      );
    }
    final color = widget.accentColor ?? Theme.of(context).colorScheme.primary;
    return ClipRRect(
      // Keep the animated border, glow, and flame overlay inside the same
      // bounds as the participant card. Previously the animated spread
      // painted into the next grid cell and made cards look mis-sized.
      borderRadius: BorderRadius.circular(16),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: .68), width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                child ?? const SizedBox.shrink(),
                if (widget.fireEffect)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 28 + (widget.intensity.clamp(0.0, 1.0) * 96),
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: .55,
                        child: CustomPaint(
                          painter: _FlameOverlayPainter(
                            progress: _controller.value,
                            intensity: widget.intensity,
                            flameColors: const [
                              Color(0xFFE53935),
                              Color(0xFFFF6D00),
                              Color(0xFFFFC107),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

class _FlameOverlayPainter extends CustomPainter {
  const _FlameOverlayPainter({
    required this.progress,
    required this.intensity,
    required this.flameColors,
  });

  final double progress;
  final double intensity;
  final List<Color> flameColors;

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= .01) return;
    final strength = (.24 + intensity * .58).clamp(.24, .85);
    final base = size.height;
    const tongues = [
      (x: .08, width: .15, height: .22, phase: .08),
      (x: .27, width: .22, height: .36, phase: .34),
      (x: .50, width: .28, height: .52, phase: .66),
      (x: .73, width: .22, height: .38, phase: .92),
      (x: .92, width: .15, height: .24, phase: .2),
    ];
    for (var index = 0; index < tongues.length; index++) {
      final tongue = tongues[index];
      final sway =
          math.sin((progress + tongue.phase) * math.pi * 2) * size.width * .025;
      final center = size.width * tongue.x + sway;
      final width = size.width * tongue.width;
      final height = size.height * tongue.height * (.75 + intensity * .6);
      final paint = Paint()
        ..color = flameColors[index % flameColors.length].withValues(
          alpha: strength,
        );
      final path = Path()
        ..moveTo(center - width / 2, base)
        ..cubicTo(
          center - width * .55,
          base - height * .3,
          center - width * .15,
          base - height * .58,
          center,
          base - height,
        )
        ..cubicTo(
          center + width * .18,
          base - height * .58,
          center + width * .58,
          base - height * .28,
          center + width / 2,
          base,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FlameOverlayPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.intensity != intensity;
}

class _CallReactionPicker extends StatefulWidget {
  final List<String> recent;
  final ValueChanged<String> onSelected;

  const _CallReactionPicker({required this.recent, required this.onSelected});

  @override
  State<_CallReactionPicker> createState() => _CallReactionPickerState();
}

class _CallReactionPickerState extends State<_CallReactionPicker> {
  final _searchController = TextEditingController();
  String _query = '';

  List<String> get _filtered {
    if (_query.trim().isEmpty) return _CallScreenState._callReactionLibrary;
    // Emoji do not have a universal searchable name without a large bundled
    // dictionary; searching the visible list still provides a predictable
    // keyboard-friendly filter and keeps the picker lightweight.
    return _CallScreenState._callReactionLibrary
        .where((emoji) => emoji.contains(_query.trim()))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'React in the call',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search or use your keyboard',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: colors.outlineVariant),
                ),
              ),
            ),
            if (_query.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => widget.onSelected(_query.trim()),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: .35),
                    ),
                  ),
                  child: Text('Use “${_query.trim()}” as your reaction'),
                ),
              ),
            ],
            if (_query.isEmpty && widget.recent.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Recently used',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.recent.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, index) => _emojiButton(widget.recent[index]),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 230,
              child: GridView.builder(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: _filtered.length,
                itemBuilder: (_, index) => _emojiButton(_filtered[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emojiButton(String emoji) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => widget.onSelected(emoji),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
    );
  }
}

class _CallControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? foregroundColor;
  final bool compact;
  const _CallControl({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.foregroundColor,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: colors.primary.withValues(alpha: .62),
            width: 1.2,
          ),
        ),
        child: IconButton.filledTonal(
          onPressed: onPressed,
          icon: Icon(icon, size: 22),
          style: IconButton.styleFrom(
            minimumSize: Size.square(compact ? 48 : 54),
            backgroundColor: colors.surfaceContainerHighest.withValues(
              alpha: .82,
            ),
            foregroundColor: foregroundColor ?? colors.onSurface,
            shape: const CircleBorder(),
          ),
        ),
      ),
    );
  }
}
