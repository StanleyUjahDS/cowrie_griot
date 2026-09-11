import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:provider/provider.dart';
import '../../providers/messaging_provider.dart';
import '../../models/chat_message.dart';
import '../../../../core/services/notification_service.dart';
import 'media_preview_sheet.dart';

class VoiceRecordingSheet extends StatefulWidget {
  final String conversationId;
  final String? replyToMessageId;

  const VoiceRecordingSheet({
    super.key,
    required this.conversationId,
    this.replyToMessageId,
  });

  static void show(
    BuildContext context, {
    required String conversationId,
    String? replyToMessageId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VoiceRecordingSheet(
        conversationId: conversationId,
        replyToMessageId: replyToMessageId,
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
  // ignore: unused_field
  bool _isRecording = false;
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

        const config = RecordConfig();
        await _audioRecorder.start(config, path: path);

        setState(() {
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
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _stopAndSend() async {
    _timer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      if (path != null && mounted) {
        // Dismiss recording sheet first to keep the widget tree clean
        setState(() => _isRecording = false);
        _isClosing = true;
        Navigator.pop(context);

        // Then show the preview sheet
        if (mounted) {
          await MediaPreviewSheet.show(
            context,
            filePath: path,
            type: MessageType.voice,
            onSend: (caption) =>
                context.read<MessagingProvider>().sendMediaMessage(
                  conversationId: widget.conversationId,
                  filePath: path,
                  type: MessageType.voice,
                  content: caption.isEmpty ? null : caption,
                  replyToMessageId: widget.replyToMessageId,
                ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    try {
      final path = await _audioRecorder.stop();
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
              'Recording in progress...',
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
                    onPressed: _stopAndSend,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Stop & Send',
                      style: TextStyle(fontWeight: FontWeight.w700),
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
