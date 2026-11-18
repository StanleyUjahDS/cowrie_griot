import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/services/notification_service.dart';
import 'package:image/image.dart' as img;
import 'package:get_thumbnail_video/index.dart' show ImageFormat;
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:video_trimmer/video_trimmer.dart';

Future<String> _encodeAnimatedPngWorker(Map<String, dynamic> args) async {
  final frames = (args['frames'] as List).cast<Uint8List>();
  final horizontal = (args['horizontal'] as num).toDouble();
  final vertical = (args['vertical'] as num).toDouble();
  final decodedFrames = <img.Image>[];
  for (final bytes in frames) {
    final frame = img.decodeImage(bytes);
    if (frame == null) continue;
    final side = frame.width < frame.height ? frame.width : frame.height;
    final cropped = img.copyCrop(
      frame,
      x: ((frame.width - side) * horizontal).round(),
      y: ((frame.height - side) * vertical).round(),
      width: side,
      height: side,
    );
    cropped.frameDuration = 80;
    decodedFrames.add(cropped);
  }
  if (decodedFrames.isEmpty) {
    throw Exception('Sticker frames could not be decoded');
  }
  final animated = img.Image.from(decodedFrames.first);
  animated.loopCount = 0;
  for (final frame in decodedFrames.skip(1)) {
    animated.addFrame(frame);
  }
  final outputPath =
      '${Directory.systemTemp.path}/griot_sticker_${DateTime.now().microsecondsSinceEpoch}.png';
  final bytes = img.encodePng(animated, level: 6);
  await File(outputPath).writeAsBytes(bytes, flush: true);
  return outputPath;
}

/// Native trim editor for video stickers. The exported clip is what is stored
/// locally and uploaded, so the original long video never becomes a sticker.
class StickerVideoEditor extends StatefulWidget {
  final File file;

  const StickerVideoEditor({super.key, required this.file});

  static Future<String?> show(BuildContext context, File file) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StickerVideoEditor(file: file),
    );
  }

  @override
  State<StickerVideoEditor> createState() => _StickerVideoEditorState();
}

class _StickerVideoEditorState extends State<StickerVideoEditor> {
  static const _maxStickerDuration = Duration(milliseconds: 3000);
  static const _stickerFrameIntervalMs = 80;
  static const _maxStickerFrames = 38;
  final Trimmer _trimmer = Trimmer();
  double _start = 0;
  double _end = 1500;
  bool _loading = true;
  bool _saving = false;
  bool _playing = false;
  double _cropHorizontal = .5;
  double _cropVertical = .5;
  double _saveProgress = 0;
  String _saveStage = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _trimmer.loadVideo(videoFile: widget.file);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveProgress = .08;
      _saveStage = 'Preparing sticker…';
    });
    try {
      final frameBytes = <Uint8List>[];
      for (
        var timeMs = _start.toInt();
        timeMs <= _end.toInt() && frameBytes.length < _maxStickerFrames;
        timeMs += _stickerFrameIntervalMs
      ) {
        frameBytes.add(
          await VideoThumbnail.thumbnailData(
            video: widget.file.path,
            imageFormat: ImageFormat.PNG,
            maxWidth: 512,
            timeMs: timeMs,
            quality: 100,
          ),
        );
      }
      if (mounted) setState(() => _saveStage = 'Encoding full-colour sticker…');
      final outputPath = await compute(_encodeAnimatedPngWorker, {
        'frames': frameBytes,
        'horizontal': _cropHorizontal,
        'vertical': _cropVertical,
      });
      if (!mounted) return;
      setState(() => _saveProgress = 1);
      Navigator.of(context).pop(outputPath);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      NotificationService.showError(
        context,
        'Could not create the sticker clip.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Trim video sticker',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Center(
                        child: GestureDetector(
                          onDoubleTap: () => setState(() {
                            _cropHorizontal = .5;
                            _cropVertical = .5;
                          }),
                          onPanUpdate: (details) => setState(() {
                            _cropHorizontal =
                                (_cropHorizontal + details.delta.dx / 260)
                                    .clamp(0.0, 1.0);
                            _cropVertical =
                                (_cropVertical + details.delta.dy / 260).clamp(
                                  0.0,
                                  1.0,
                                );
                          }),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final side = constraints.biggest.shortestSide;
                              final controller = _trimmer.videoPlayerController;
                              final aspect = controller?.value.aspectRatio ?? 1;
                              final videoWidth = aspect >= 1
                                  ? side * aspect
                                  : side;
                              final videoHeight = aspect >= 1
                                  ? side
                                  : side / aspect;
                              final overflowX = (videoWidth - side).clamp(
                                0.0,
                                double.infinity,
                              );
                              final overflowY = (videoHeight - side).clamp(
                                0.0,
                                double.infinity,
                              );
                              return AspectRatio(
                                aspectRatio: 1,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRect(
                                        child: Transform.translate(
                                          offset: Offset(
                                            -overflowX * _cropHorizontal,
                                            -overflowY * _cropVertical,
                                          ),
                                          child: Align(
                                            alignment: Alignment.topLeft,
                                            child: SizedBox(
                                              width: videoWidth,
                                              height: videoHeight,
                                              child: VideoViewer(
                                                trimmer: _trimmer,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      IgnorePointer(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: colors.primary.withValues(
                                                alpha: .7,
                                              ),
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_saving)
                                        ColoredBox(
                                          color: Colors.black.withValues(
                                            alpha: .58,
                                          ),
                                          child: Center(
                                            child: Padding(
                                              padding: const EdgeInsets.all(20),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  CircularProgressIndicator(
                                                    value: _saveProgress > 0
                                                        ? _saveProgress
                                                        : null,
                                                    color: colors.primary,
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    _saveStage,
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  SizedBox(
                                                    width: 180,
                                                    child:
                                                        LinearProgressIndicator(
                                                          value:
                                                              _saveProgress > 0
                                                              ? _saveProgress
                                                              : null,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
              ),
              TrimViewer(
                trimmer: _trimmer,
                viewerHeight: 56,
                viewerWidth: MediaQuery.sizeOf(context).width,
                maxVideoLength: _maxStickerDuration,
                onChangeStart: (value) => _start = value,
                onChangeEnd: (value) => _end = value,
                onChangePlaybackState: (value) {
                  if (mounted) setState(() => _playing = value);
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Up to 3 seconds · drag to frame · double-tap to reset',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: _loading
                        ? null
                        : () async {
                            final playing = await _trimmer.videoPlaybackControl(
                              startValue: _start,
                              endValue: _end,
                            );
                            if (mounted) setState(() => _playing = playing);
                          },
                    icon: Icon(
                      _playing
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_filled_rounded,
                      size: 34,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _loading || _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('Use sticker'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
