import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../../../core/services/notification_service.dart';
import 'video_player_widget.dart';

class FullscreenMediaViewer extends StatelessWidget {
  final String url;
  final bool isVideo;

  const FullscreenMediaViewer({
    super.key,
    required this.url,
    this.isVideo = false,
  });

  static void show(BuildContext context, String url, {bool isVideo = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullscreenMediaViewer(url: url, isVideo: isVideo),
      ),
    );
  }

  Future<void> _download(BuildContext context) async {
    if (url.startsWith('file')) {
      NotificationService.showInfo(context, 'Media is already on your device.');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Downloading...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Media download failed with status ${response.statusCode}',
        );
      }
      final directory = Platform.isAndroid
          ? await getExternalStorageDirectory() ??
                await getApplicationDocumentsDirectory()
          : await getApplicationDocumentsDirectory();

      final filename =
          'griot_${DateTime.now().millisecondsSinceEpoch}${path.extension(Uri.parse(url).path)}';
      final file = File(path.join(directory.path, filename));
      await file.writeAsBytes(response.bodyBytes);

      if (context.mounted) {
        NotificationService.showSuccess(
          context,
          'Image downloaded. Choose where to save or share it.',
        );
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
      }
    } catch (e) {
      if (context.mounted) {
        NotificationService.showError(context, 'Download failed');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocal = url.startsWith('/') || url.startsWith('file://');
    final cleanUrl = url.replaceFirst('file://', '');

    if (kDebugMode) {
      debugPrint('FullscreenMediaViewer: local=$isLocal, video=$isVideo');
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: () => _download(context),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: () {
              if (isLocal) {
                SharePlus.instance.share(ShareParams(files: [XFile(cleanUrl)]));
              } else {
                SharePlus.instance.share(ShareParams(text: url));
              }
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: isVideo
              ? ChatVideoPlayer(url: url, isMe: false)
              : isLocal
              ? Image.file(
                  File(cleanUrl),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                )
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
