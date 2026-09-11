import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/chat_message.dart';

import 'audio_player_widget.dart';
import 'video_player_widget.dart';

class MediaPreviewSheet extends StatefulWidget {
  final String filePath;
  final MessageType type;
  final Future<void> Function(String caption) onSend;

  const MediaPreviewSheet({
    super.key,
    required this.filePath,
    required this.type,
    required this.onSend,
  });

  static Future<void> show(
    BuildContext context, {
    required String filePath,
    required MessageType type,
    required Future<void> Function(String caption) onSend,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          MediaPreviewSheet(filePath: filePath, type: type, onSend: onSend),
    );
  }

  @override
  State<MediaPreviewSheet> createState() => _MediaPreviewSheetState();
}

class _MediaPreviewSheetState extends State<MediaPreviewSheet> {
  late final TextEditingController _captionController;


  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final caption = _captionController.text.trim();
    
    // 1. Close keyboard and modal IMMEDIATELY for optimistic feel
    FocusScope.of(context).unfocus();
    Navigator.pop(context);

    // 2. Trigger the send callback without blocking the UI
    // The provider handles optimistic updates and error reporting.
    try {
      unawaited(widget.onSend(caption));
    } catch (e) {
      debugPrint('MediaPreviewSheet: Background send failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isImage = widget.type == MessageType.image;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(
              color: colors.primary.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Preview',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: isImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.file(
                        File(widget.filePath),
                        fit: BoxFit.contain,
                      ),
                    )
                  : widget.type == MessageType.video
                      ? ChatVideoPlayer(url: widget.filePath, isMe: false)
                      : widget.type == MessageType.voice ||
                              widget.type == MessageType.audio
                          ? Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: AudioPlayerWidget(
                                url: widget.filePath,
                                isMe: false,
                                activeColor: colors.primary,
                              ),
                            )
                          : Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.insert_drive_file_rounded,
                                    size: 52,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    File(widget.filePath).uri.pathSegments.last,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _captionController,
              maxLength: 1000,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Add a caption (optional)',
                filled: true,
                fillColor: colors.onSurface.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _handleSend,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text(
                      'Send',
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
