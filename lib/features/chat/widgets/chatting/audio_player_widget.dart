import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String url;
  final bool isMe;
  final Color? activeColor;

  const AudioPlayerWidget({
    super.key,
    required this.url,
    required this.isMe,
    this.activeColor,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _player;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _init();
  }

  Future<void> _init() async {
    try {
      if (widget.url.startsWith('http')) {
        await _player.setUrl(widget.url);
      } else {
        final String cleanPath = widget.url.replaceFirst('file://', '');
        await _player.setFilePath(cleanPath);
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading audio: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = widget.activeColor ?? (widget.isMe ? Colors.white : colorScheme.primary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          _isLoading
              ? SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color.withValues(alpha: 0.5)),
                  ),
                )
              : StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (context, snapshot) {
                    final playerState = snapshot.data;
                    final processingState = playerState?.processingState;
                    final playing = playerState?.playing;

                    if (processingState == ProcessingState.loading ||
                        processingState == ProcessingState.buffering) {
                      return SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(color.withValues(alpha: 0.5)),
                        ),
                      );
                    } else if (playing != true) {
                      return IconButton(
                        icon: Icon(Icons.play_arrow_rounded, color: color),
                        iconSize: 32,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _player.play,
                      );
                    } else if (processingState != ProcessingState.completed) {
                      return IconButton(
                        icon: Icon(Icons.pause_rounded, color: color),
                        iconSize: 32,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _player.pause,
                      );
                    } else {
                      return IconButton(
                        icon: Icon(Icons.replay_rounded, color: color),
                        iconSize: 32,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _player.seek(Duration.zero),
                      );
                    }
                  },
                ),
          const SizedBox(width: 8),
          Expanded(
            child: StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                return StreamBuilder<Duration?>(
                  stream: _player.durationStream,
                  builder: (context, snapshot) {
                    final duration = snapshot.data ?? Duration.zero;
                    return ProgressBar(
                      progress: position,
                      total: duration,
                      buffered: _player.bufferedPosition,
                      onSeek: (duration) {
                        _player.seek(duration);
                      },
                      barHeight: 3,
                      baseBarColor: color.withValues(alpha: 0.2),
                      bufferedBarColor: color.withValues(alpha: 0.1),
                      progressBarColor: color,
                      thumbColor: color,
                      thumbRadius: 6,
                      timeLabelTextStyle: theme.textTheme.labelSmall?.copyWith(
                        color: color.withValues(alpha: 0.7),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      timeLabelPadding: 4,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
