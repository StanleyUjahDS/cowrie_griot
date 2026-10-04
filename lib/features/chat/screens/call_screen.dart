import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/ui/dialogs/griot_confirm_dialog.dart';
import '../../../core/router/app_router.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/ui/scaffolds/gradient_scaffold.dart';
import '../../../core/ui/widgets/griot_branded_container.dart';
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
  bool _usingFrontCamera = true;
  bool _isMirrored = true;
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
  List<SpaceParticipant> get _spaceParticipants => _owner.participants;
  set _spaceParticipants(List<SpaceParticipant> value) =>
      _owner.participants = value;
  _VideoThumbnailCorner _thumbnailCorner = _VideoThumbnailCorner.topRight;
  Offset _thumbnailDragOffset = Offset.zero;
  Timer? _answerTimeout;
  Timer? _participantRefreshDebounce;
  Timer? _participantRefreshTimer;
  int _campfireRevision = 0;
  MessagingProvider? _messagingProvider;
  bool _remoteJoined = false;
  bool _timedOut = false;
  bool _spaceControlsOpen = false;
  int _missingSelfRefreshes = 0;
  final Set<String> _terminalCallIds = {};
  Set<String> get _remoteStreams => _media.streams;
  late final String _roomId =
      widget.initialRoomId ??
      'griot-${widget.conversationType}-${widget.conversationId}';
  @override
  void initState() {
    super.initState();
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
          const Duration(seconds: 4),
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
    try {
      final participants = await context
          .read<MessagingApiService>()
          .getCampfireParticipants(widget.conversationId);
      final changed = participants.length != _spaceParticipants.length ||
          participants.asMap().entries.any((entry) {
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
      if (mounted && changed) setState(() => _spaceParticipants = participants);
      await _enforceCampfireAudioState(participants);
    } catch (_) {
      // The active call remains usable if a participant refresh is delayed.
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
        _audioEnabled = canSpeak && self?.muted != true;
        _videoEnabled = _videoCallActive && _audioEnabled;
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
      ZegoExpressEngine.onRoomStreamUpdate =
          (roomId, updateType, streamList, extendedData) async {
            if (roomId != s.roomId || _cleaningUp || !mounted) return;
            for (final stream in streamList) {
              if (updateType == ZegoUpdateType.Add) {
                _remoteJoined = true;
                _answerTimeout?.cancel();
                if (_remoteStreams.add(stream.streamID)) {
                  try {
                    if (_videoCallActive) {
                      final view = await ZegoExpressEngine.instance
                          .createCanvasView((viewID) {
                            if (_cleaningUp || !_engineCreated) return;
                            unawaited(
                              ZegoExpressEngine.instance.startPlayingStream(
                                stream.streamID,
                                canvas: _callCanvas(viewID),
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
                      );
                      if (mounted) setState(() {});
                    }
                  } catch (_) {}
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
      await _media.publish(s.userId);
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
      if (mounted) {
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
    if (value.length > 6)
      return '${value.substring(0, 3)}…${value.substring(value.length - 3)}';
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

  Future<void> _requestCallPermissions() async {
    final requested = <Permission>[Permission.microphone];
    if (_videoEnabled) requested.add(Permission.camera);

    final result = await requested.request();
    final microphone = result[Permission.microphone];
    final camera = result[Permission.camera];
    final microphoneGranted = microphone?.isGranted == true;
    final cameraGranted = !_videoEnabled || camera?.isGranted == true;

    if (microphoneGranted && cameraGranted) return;

    final permanentlyDenied =
        microphone?.isPermanentlyDenied == true ||
        (_videoEnabled && camera?.isPermanentlyDenied == true);
    throw StateError(
      permanentlyDenied
          ? 'Enable microphone${_videoEnabled ? ' and camera' : ''} access in Settings to join the call.'
          : 'Microphone${_videoEnabled ? ' and camera' : ''} permission is required to join the call.',
    );
  }

  Future<void> _toggleAudio() async {
    if (!_started || _cleaningUp || _campfireMicUpdating) return;
    final messaging = context.read<MessagingApiService>();
    final next = !_audioEnabled;
    _campfireMicUpdating = true;
    try {
      if (widget.conversationType == 'space') {
        final participants = await messaging.getCampfireParticipants(
          widget.conversationId,
        );
        final self = participants.where((item) => item.isSelf).firstOrNull;
        if (!_canCampfireSpeak(self)) {
          throw StateError('Raise your hand to request speaking permission.');
        }
        await messaging.moderateCampfireParticipant(
          campfireId: widget.conversationId,
          userId: self!.id,
          action: next ? 'unmute' : 'mute',
        );
      }
      if (_cleaningUp || !_engineCreated) return;
      await ZegoExpressEngine.instance.mutePublishStreamAudio(!next);
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

  Future<void> _requestToSpeak() async {
    final self = _spaceParticipants.where((item) => item.isSelf).firstOrNull;
    final raised = self?.speakerRequested != true;
    try {
      await context.read<MessagingApiService>().requestCampfireSpeaker(
        widget.conversationId,
        raised: raised,
      );
      if (!mounted || _cleaningUp) return;
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

  Future<void> _toggleVideo() async {
    if (!_started) return;
    if (widget.conversationType == 'space') {
      final participants = await context
          .read<MessagingApiService>()
          .getCampfireParticipants(widget.conversationId);
      final self = participants.where((item) => item.isSelf).firstOrNull;
      if (!_canCampfireSpeak(self) || self?.muted == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Only approved speakers can turn on video.'),
            ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission is required.')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not change camera state: $error')),
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

  Future<void> _switchCamera() async {
    if (!_started || !_videoEnabled) return;
    _usingFrontCamera = !_usingFrontCamera;
    try {
      await ZegoExpressEngine.instance.useFrontCamera(_usingFrontCamera);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not switch camera: $error')),
        );
      }
    }
  }

  Future<void> _toggleMirror() async {
    if (!_engineCreated || !_videoEnabled) return;
    final next = !_isMirrored;
    try {
      await ZegoExpressEngine.instance.setVideoMirrorMode(
        next
            ? ZegoVideoMirrorMode.OnlyPreviewMirror
            : ZegoVideoMirrorMode.NoMirror,
      );
      if (mounted) setState(() => _isMirrored = next);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not change mirror mode: $error')),
        );
      }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create call link: $e')),
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
      title: 'Add people to call',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            invited.isEmpty
                ? 'Those people are already invited.'
                : 'Call invitation sent.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not invite people: $error')),
      );
    }
  }

  Future<void> _showSpaceControls() async {
    final api = context.read<MessagingApiService>();
    List<SpaceParticipant> participants;
    try {
      participants = await api.getCampfireParticipants(widget.conversationId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load participants: $error')),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Action failed: $error')),
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
                                  title: Text(
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
                                  subtitle: Text(
                                    '${participant.muted ? 'Muted · ' : ''}$role',
                                  ),
                                  trailing: canAct
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (participant.speakerRequested)
                                              FilledButton(
                                                onPressed: busy
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
                                                child: const Text(
                                                  'Make speaker',
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
                                                  const PopupMenuItem(
                                                    value: 'approve_speaker',
                                                    child: Text('Make speaker'),
                                                  ),
                                                if (isOwner)
                                                  PopupMenuItem(
                                                    value:
                                                        participant.role ==
                                                            'cohost'
                                                        ? 'demote'
                                                        : 'promote',
                                                    child: Text(
                                                      participant.role ==
                                                              'cohost'
                                                          ? 'Remove co-host'
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
      widget.conversationType != 'direct' && widget.conversationType != 'dm';

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
                ? (widget.mode == 'video' ? 'Video Campfire' : 'Voice Campfire')
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
                tooltip: 'Add people to call',
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
    if (widget.conversationType == 'group' ||
        widget.conversationType == 'channel') {
      return _buildGroupVoiceBody(colors);
    }
    final title = widget.conversationType == 'space'
        ? 'Voice Campfire'
        : _remoteCallLabel();
    final subtitle = _started ? _status : 'Connecting securely';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
      child: Column(
        children: [
          if (_started && _canShareCallLink)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: _sharingLink ? null : _shareCallLink,
                icon: const Icon(Icons.link_rounded),
                label: Text(
                  _sharingLink ? 'Creating link…' : 'Share call link',
                ),
              ),
            ),
          if (_started && _canShareCallLink) const SizedBox(height: 10),
          Expanded(
            child: GriotBrandedContainer(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
              borderRadius: 30,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _CallStatusPill(
                      label: _started ? 'LIVE' : 'CONNECTING',
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
            GriotBrandedContainer(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
              borderRadius: 22,
              child: _buildCallControls(colors),
            ),
          const SizedBox(height: 10),
          if (_started && _canShareCallLink)
            FilledButton.tonalIcon(
              onPressed: _sharingLink ? null : _shareCallLink,
              icon: const Icon(Icons.link_rounded),
              label: Text(_sharingLink ? 'Creating link…' : 'Share call link'),
            ),
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
    final remoteIds = _remoteStreams.toList(growable: false);
    final total = remoteIds.length + 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
      child: Column(
        children: [
          Expanded(
            child: GriotBrandedContainer(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              borderRadius: 30,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _remoteDisplayName.isEmpty
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
                    child: GridView.builder(
                      padding: const EdgeInsets.all(2),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 190,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            mainAxisExtent: 156,
                          ),
                      itemCount: total,
                      itemBuilder: (context, index) {
                        final isLocal = index == 0;
                        final streamId = isLocal ? null : remoteIds[index - 1];
                        final name = isLocal
                            ? 'You'
                            : _participantNameFromStream(streamId!, index);
                        final profile = streamId == null
                            ? null
                            : _profileForStream(streamId);
                        return _voiceParticipantCard(
                          colors,
                          name,
                          isLocal: isLocal,
                          avatarUrl: isLocal
                              ? null
                              : (_avatarUrlFromProfile(profile) ??
                                    _remoteAvatarUrl),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_started)
            GriotBrandedContainer(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
              borderRadius: 22,
              child: _buildCallControls(colors),
            ),
          const SizedBox(height: 8),
          if (_started)
            FilledButton.tonalIcon(
              onPressed: _sharingLink ? null : _shareCallLink,
              icon: const Icon(Icons.link_rounded),
              label: Text(_sharingLink ? 'Creating link…' : 'Share call link'),
            ),
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
    final profileName =
        profile?['display_name'] ??
        profile?['displayName'] ??
        profile?['username'];
    if (profileName is String && profileName.trim().isNotEmpty) {
      return profileName.trim();
    }
    final parts = streamId.split('-');
    if (parts.length >= 3 && parts[0] == 'griot') {
      final id = parts.sublist(1, parts.length - 1).join('-');
      if (id.isNotEmpty) {
        return id.length > 6
            ? '${id.substring(0, 3)}…${id.substring(id.length - 3)}'
            : id;
      }
    }
    final wallet = profile?['wallet_address'] ?? profile?['walletAddress'];
    return _displayNameOrWallet(
      null,
      null,
      wallet?.toString(),
      fallback: 'Participant $index',
    );
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
    String? avatarUrl,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .4)),
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
                      child: Image.network(
                        avatarUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
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
              _audioEnabled || !isLocal
                  ? Icons.mic_rounded
                  : Icons.mic_off_rounded,
              size: 16,
              color: _audioEnabled || !isLocal ? colors.primary : colors.error,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampfireVoiceBody(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
      child: Column(
        children: [
          Expanded(
            child: GriotBrandedContainer(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              borderRadius: 30,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.mode == 'video'
                              ? 'Video Campfire'
                              : 'Voice Campfire',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        '${_spaceParticipants.length} joined',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Spacer(),
                      _CallStatusPill(
                        label: _started ? 'LIVE' : 'CONNECTING',
                        colors: colors,
                        live: _started,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _spaceParticipants.isEmpty
                        ? Center(
                            child: Text(
                              'Waiting for participants…',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          )
                        : Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.only(right: 4),
                              child: _buildCampfireParticipantGrid(colors),
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _audioEnabled ? 'You are speaking' : 'You are listening',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_started)
            GriotBrandedContainer(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
              borderRadius: 22,
              child: _buildCallControls(colors),
            ),
          const SizedBox(height: 8),
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

  bool get _isCampfireOwner {
    final self = _spaceParticipants.where((item) => item.isSelf).firstOrNull;
    return self?.isOwner == true || self?.role == 'host';
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

    Widget section(String title, List<SpaceParticipant> people) {
      if (people.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
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
                crossAxisCount: constraints.maxWidth < 360 ? 3 : 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                // A fixed extent gives the name, role, mute state, and
                // moderation affordance room to breathe. The old .78 ratio
                // produced the visible 7px overflow on narrow phones.
                mainAxisExtent: 128,
              ),
              itemBuilder: (context, index) {
                final participant = people[index];
                final role = participant.isOwner || participant.role == 'host'
                    ? 'Host'
                    : participant.role == 'cohost'
                    ? 'Co-host'
                    : participant.role == 'speaker'
                    ? 'Speaker'
                    : 'Listener';
                return GriotBrandedContainer(
                  padding: EdgeInsets.zero,
                  borderRadius: 16,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openCampfireParticipantProfile(participant),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 27,
                                  backgroundColor: colors.primary.withValues(
                                    alpha: .16,
                                  ),
                                  child:
                                      participant.avatarUrl != null &&
                                          participant.avatarUrl!
                                              .trim()
                                              .isNotEmpty
                                      ? ClipOval(
                                          child: Image.network(
                                            participant.avatarUrl!,
                                            width: 50,
                                            height: 50,
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
                                Positioned(
                                  right: -3,
                                  bottom: -2,
                                  child: Icon(
                                    (participant.muted ||
                                            participant.role == 'listener')
                                        ? Icons.mic_off_rounded
                                        : Icons.mic_rounded,
                                    size: 16,
                                    color:
                                        (participant.muted ||
                                            participant.role == 'listener')
                                        ? colors.error
                                        : colors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _compactParticipantName(
                                participant.isSelf
                                    ? 'You'
                                    : _participantDisplayName(participant),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              role,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
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
        section('On stage', stage),
        if (stage.isNotEmpty && listeners.isNotEmpty)
          const SizedBox(height: 14),
        section('Listeners', listeners),
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
    if (!generic) return value;
    final id = participant.id.trim();
    if (id.length > 6)
      return '${id.substring(0, 3)}…${id.substring(id.length - 3)}';
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
    if ((widget.conversationType == 'group' ||
            widget.conversationType == 'space') &&
        remoteViews.length + (_localVideoView == null ? 0 : 1) > 2) {
      return _buildGroupVideoGrid(colors, remoteViews);
    }
    final remoteView = remoteViews.isEmpty ? null : remoteViews.first;
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (mainView != null)
                      Positioned.fill(child: _coverVideo(mainView))
                    else
                      Center(
                        child: Text(
                          _started ? 'Waiting for the other camera…' : _status,
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
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: .56,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Padding(
                                            padding: EdgeInsets.all(6),
                                            child: Icon(
                                              Icons.swap_vert_rounded,
                                              size: 16,
                                              color: Colors.white,
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
                        ),
                      ),
                    if (_videoEnabled && _localVideoView != null)
                      Positioned(
                        top: 18,
                        left: 18,
                        child: IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(
                              alpha: .46,
                            ),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          tooltip: _isMirrored
                              ? 'Turn off mirror'
                              : 'Mirror my video',
                          onPressed: _toggleMirror,
                          icon: Icon(
                            _isMirrored
                                ? Icons.flip_rounded
                                : Icons.flip_camera_android_rounded,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GriotBrandedContainer(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
            borderRadius: 22,
            child: _buildCallControls(colors),
          ),
          const SizedBox(height: 8),
          if (_canShareCallLink)
            FilledButton.tonalIcon(
              onPressed: _sharingLink ? null : _shareCallLink,
              icon: const Icon(Icons.link_rounded),
              label: Text(_sharingLink ? 'Creating link…' : 'Share call link'),
            ),
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
              label: Text(
                widget.conversationType == 'space'
                    ? 'Leave Campfire'
                    : 'End call',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupVideoGrid(ColorScheme colors, List<Widget> remoteViews) {
    final tiles = <Widget>[];
    if (_localVideoView != null) {
      tiles.add(_videoTile(colors, _localVideoView!, _localDisplayName, true));
    }
    for (var index = 0; index < remoteViews.length; index++) {
      tiles.add(
        _videoTile(
          colors,
          remoteViews[index],
          'Participant ${index + 1}',
          false,
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
                final columns = constraints.maxWidth >= 680 ? 3 : 2;
                return Scrollbar(
                  thumbVisibility: tiles.length > columns,
                  child: GridView.builder(
                    padding: const EdgeInsets.only(right: 4),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent: columns == 3 ? 190 : 168,
                    ),
                    itemCount: tiles.length,
                    itemBuilder: (_, index) => tiles[index],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildCallControls(colors),
          const SizedBox(height: 10),
          if (_canShareCallLink)
            FilledButton.tonalIcon(
              onPressed: _sharingLink ? null : _shareCallLink,
              icon: const Icon(Icons.link_rounded),
              label: Text(_sharingLink ? 'Creating link…' : 'Share call link'),
            ),
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
              label: Text(_callExitLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _videoTile(ColorScheme colors, Widget view, String label, bool local) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _coverVideo(view),
          Positioned(
            left: 10,
            bottom: 10,
            child: _VideoLabel(
              label: local ? '$label (You)' : label,
              colors: colors,
            ),
          ),
        ],
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

  Widget _buildCallControls(ColorScheme colors) {
    final self = _spaceParticipants.where((item) => item.isSelf).firstOrNull;
    final canSpeak =
        widget.conversationType != 'space' ||
        self?.isOwner == true ||
        self?.role == 'host' ||
        self?.role == 'cohost' ||
        self?.role == 'speaker';
    final controls = <Widget>[];
    if (canSpeak) {
      controls.add(
        _CallControl(
          icon: _audioEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
          label: _audioEnabled ? 'Mute' : 'Unmute',
          onPressed: _toggleAudio,
        ),
      );
    } else if (widget.conversationType == 'space') {
      controls.add(
        _CallControl(
          icon: self?.speakerRequested == true
              ? Icons.back_hand_rounded
              : Icons.pan_tool_outlined,
          label: self?.speakerRequested == true ? 'Lower hand' : 'Raise hand',
          onPressed: _requestToSpeak,
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
        ),
        if (_videoEnabled)
          _CallControl(
            icon: Icons.flip_camera_ios_rounded,
            label: 'Switch camera',
            onPressed: _switchCamera,
          ),
      ]);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final control in controls)
              Expanded(child: Center(child: control)),
          ],
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

class _CallControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _CallControl({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        IconButton.filledTonal(
          onPressed: onPressed,
          icon: Icon(icon, size: 22),
          style: IconButton.styleFrom(
            minimumSize: const Size(52, 52),
            backgroundColor: colors.surfaceContainerHighest,
            foregroundColor: colors.onSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
              side: BorderSide(color: colors.outline.withValues(alpha: .18)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
