import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../../providers/messaging_provider.dart';
import '../../models/chat_message.dart';
import '../../../../core/services/notification_service.dart';
import 'media_preview_sheet.dart';

class VoiceRecordingSheet extends StatefulWidget {
  final BuildContext hostContext;
  final String conversationId;
  final String? replyToMessageId;
  final Future<void> Function(String filePath, String caption)? onSend;

  const VoiceRecordingSheet({
    super.key,
    required this.hostContext,
    required this.conversationId,
    this.replyToMessageId,
    this.onSend,
  });

  static void show(
    BuildContext context, {
    required String conversationId,
    String? replyToMessageId,
    Future<void> Function(String filePath, String caption)? onSend,
  }) {
    final hostContext = context;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceRecordingSheet(
        hostContext: hostContext,
        conversationId: conversationId,
        replyToMessageId: replyToMessageId,
        onSend: onSend,
      ),
    );
  }

  @override
  State<VoiceRecordingSheet> createState() => _VoiceRecordingSheetState();
}

class _VoiceRecordingSheetState extends State<VoiceRecordingSheet>
    with SingleTickerProviderStateMixin {
  late AudioRecorder _audioRecorder;
  late AnimationController _animationController;
  Timer? _timer;
  int _recordDuration = 0;
  bool _isRecording = false;
  bool _isStarting = true;
  bool _isStopping = false;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordDuration++;
        });
      }
    });
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        const config = RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
          autoGain: true,
        );
        await _audioRecorder.start(config, path: path);

        if (!mounted) {
          await _audioRecorder.stop();
          return;
        }
        setState(() {
          _isStarting = false;
          _isRecording = true;
          _recordDuration = 0;
        });

        _startTimer();
        _animationController.repeat(reverse: true);

        if (Platform.isIOS || Platform.isAndroid) {
          HapticFeedback.mediumImpact();
        }
      } else {
        if (mounted) {
          NotificationService.showError(
            context,
            'Microphone permission is required.',
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
      if (mounted) {
        setState(() => _isStarting = false);
        NotificationService.showError(
          context,
          'Could not start the microphone. Please try again.',
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _stopAndSend() async {
    if (_isStarting || !_isRecording || _isStopping) return;
    setState(() => _isStopping = true);
    _timer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      if (path != null && mounted) {
        final probe = AudioPlayer();
        Duration? recordedDuration;
        try {
          recordedDuration = await probe.setFilePath(path);
        } finally {
          await probe.dispose();
        }

        if (recordedDuration == null ||
            recordedDuration < const Duration(milliseconds: 750)) {
          final file = File(path);
          if (await file.exists()) await file.delete();
          if (mounted) {
            NotificationService.showInfo(
              context,
              'That voice note was too short. Please record it again.',
            );
            setState(() {
              _isRecording = false;
              _isStopping = false;
            });
            _isClosing = true;
            Navigator.pop(context);
          }
          return;
        }

        if (!mounted) return;
        final hostContext = widget.hostContext;
        final conversationId = widget.conversationId;
        final replyToMessageId = widget.replyToMessageId;
        final onSend = widget.onSend;
        // Dismiss recording sheet first to keep the widget tree clean
        setState(() => _isRecording = false);
        _isClosing = true;
        Navigator.pop(context);

        // The recording-sheet context is invalid after pop. Reopen the preview
        // using the chat screen context that hosted this sheet.
        await Future<void>.delayed(Duration.zero);
        if (hostContext.mounted) {
          await MediaPreviewSheet.show(
            hostContext,
            filePath: path,
            type: MessageType.voice,
            onSend: (caption) async {
              if (onSend != null) {
                await onSend(path, caption);
                return;
              }
              await hostContext.read<MessagingProvider>().sendMediaMessage(
                conversationId: conversationId,
                filePath: path,
                type: MessageType.voice,
                content: caption.isEmpty ? null : caption,
                replyToMessageId: replyToMessageId,
              );
            },
          );
        }
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      if (mounted) {
        setState(() => _isStopping = false);
        NotificationService.showError(
          context,
          'Could not finish the voice note. Please try again.',
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    if (_isClosing) return;
    _timer?.cancel();
    try {
      final path = await _audioRecorder.isRecording()
          ? await _audioRecorder.stop()
          : null;
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
      if (mounted) {
        setState(() => _isRecording = false);
        _isClosing = true;
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error cancelling recording: $e');
      if (mounted) {
        _isClosing = true;
        Navigator.pop(context);
      }
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_isClosing) {
          unawaited(_cancelRecording());
        }
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(
              color: colorScheme.primary.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Recording Voice Message',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 40),
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.surface,
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.mic_rounded,
                    color: colorScheme.primary,
                    size: 40,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _formatDuration(_recordDuration),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: colorScheme.primary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isStarting
                  ? 'Starting microphone...'
                  : 'Recording in progress...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancelRecording,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(
                        color: colorScheme.error.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _isStarting || !_isRecording || _isStopping
                        ? null
                        : _stopAndSend,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _isStopping ? 'Preparing...' : 'Stop & Send',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
