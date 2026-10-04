import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ChatVideoPlayer extends StatefulWidget {
  final String url;
  final bool isMe;

  const ChatVideoPlayer({super.key, required this.url, required this.isMe});

  @override
  State<ChatVideoPlayer> createState() => _ChatVideoPlayerState();
}

class _ChatVideoPlayerState extends State<ChatVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadController();
  }

  Future<void> _loadController() async {
    if (widget.url.startsWith('http')) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    } else {
      final String cleanPath = widget.url.replaceFirst('file://', '');
      _controller = VideoPlayerController.file(File(cleanPath));
    }
    try {
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _initialized = true;
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading video: $e');
      if (mounted) {
        setState(() {
          _initialized = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant ChatVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      final oldController = _controller;
      setState(() {
        _initialized = false;
        _hasError = false;
      });
      oldController.dispose();
      _loadController();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: Icon(Icons.broken_image_outlined)),
      );
    }

    if (!_initialized) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          IconButton(
            icon: Icon(
              _controller.value.isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded,
              color: Colors.white.withValues(alpha: 0.8),
              size: 54,
            ),
            onPressed: () {
              setState(() {
                _controller.value.isPlaying
                    ? _controller.pause()
                    : _controller.play();
              });
            },
          ),
        ],
      ),
    );
  }
}
