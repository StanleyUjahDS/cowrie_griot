import 'package:flutter/material.dart';
import 'package:audio_session/audio_session.dart';
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
  AudioSession? _session;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _init();
  }

  Future<void> _init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _session = session;

      final rawUrl = widget.url.trim();
      final uri = Uri.tryParse(rawUrl);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        await _player.setAudioSource(AudioSource.uri(uri));
      } else {
        final String cleanPath = rawUrl.replaceFirst('file://', '');
        if (cleanPath.isEmpty) {
          throw const FormatException('Audio URL is empty');
        }
        await _player.setFilePath(cleanPath);
      }
      await _player.setVolume(1.0);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading audio: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _play() async {
    try {
      final active = await _session?.setActive(true) ?? true;
      if (!active) throw StateError('Audio output is unavailable');
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    } catch (e) {
      debugPrint('Error playing audio: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _reload();
    }
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
    await _player.stop();
    await _init();
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
    final color =
        widget.activeColor ??
        (widget.isMe ? Colors.white : colorScheme.primary);

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
                    valueColor: AlwaysStoppedAnimation<Color>(
                      color.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : _hasError
              ? IconButton(
                  icon: Icon(Icons.refresh_rounded, color: color),
                  iconSize: 30,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _reload,
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            color.withValues(alpha: 0.5),
                          ),
                        ),
                      );
                    } else if (playing != true) {
                      return IconButton(
                        icon: Icon(Icons.play_arrow_rounded, color: color),
                        iconSize: 32,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _play,
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
                        onPressed: _play,
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
