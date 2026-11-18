import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/services/notification_service.dart';
import 'package:image/image.dart' as img;
import 'package:video_trimmer/video_trimmer.dart';

Future<String> _squareGifWorker(Map<String, dynamic> args) async {
  final sourcePath = args['sourcePath'] as String;
  final horizontal = (args['horizontal'] as num).toDouble();
  final vertical = (args['vertical'] as num).toDouble();
  final decoded = await img.decodeGifFile(sourcePath);
  if (decoded == null) throw Exception('GIF could not be decoded');
  final side = decoded.width < decoded.height ? decoded.width : decoded.height;
  final square = img.copyCrop(
    decoded,
    x: ((decoded.width - side) * horizontal).round(),
    y: ((decoded.height - side) * vertical).round(),
    width: side,
    height: side,
  );
  for (var i = 0; i < square.frames.length; i++) {
    square.frames[i].frameDuration = decoded.frames[i].frameDuration;
  }
  square.loopCount = 0;
  final outputPath =
      '${sourcePath.substring(0, sourcePath.length - 4)}_square.gif';
  if (!await img.encodeGifFile(
    outputPath,
    square,
    samplingFactor: 1,
    ditherScanOrder: img.DitherScanOrder.serpentine,
  )) {
    throw Exception('Square GIF could not be written');
  }
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
  static const _maxStickerDuration = Duration(milliseconds: 1500);
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
      await _trimmer.saveTrimmedVideo(
        startValue: _start,
        endValue: _end,
        outputType: OutputType.gif,
        fpsGIF: 15,
        scaleGIF: 720,
        qualityGIF: 95,
        onSave: (outputPath) {
          if (outputPath == null || outputPath.isEmpty) return;
          if (mounted) setState(() => _saveStage = 'Framing animated sticker…');
          unawaited(_squareGif(outputPath));
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      NotificationService.showError(
        context,
        'Could not create the sticker clip.',
      );
    }
  }

  Future<void> _squareGif(String sourcePath) async {
    try {
      final outputPath = await compute(_squareGifWorker, {
        'sourcePath': sourcePath,
        'horizontal': _cropHorizontal,
        'vertical': _cropVertical,
      });
      final original = File(sourcePath);
      if (original.existsSync()) await original.delete();
      if (!mounted) return;
      setState(() => _saveProgress = 1);
      Navigator.of(context).pop(outputPath);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      NotificationService.showError(context, 'Could not frame the sticker.');
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
                'Up to 1.5 seconds · drag to frame · double-tap to reset',
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
