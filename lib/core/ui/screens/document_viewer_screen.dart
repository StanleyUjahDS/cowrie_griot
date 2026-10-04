import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/notification_service.dart';

class DocumentViewerScreen extends StatefulWidget {
  final String url;
  final String title;

  const DocumentViewerScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  double _progress = 0;
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // For Android, we use Google Docs viewer for remote PDFs as InAppWebView doesn't support them natively.
    // For iOS, native InAppWebView is enough.
    String effectiveUrl = widget.url;
    final isLocal =
        widget.url.startsWith('/') || widget.url.startsWith('file://');

    if (isLocal) {
      final String cleanPath = widget.url.replaceFirst('file://', '');
      effectiveUrl = Uri.file(cleanPath).toString();
    } else if (Platform.isAndroid &&
        widget.url.startsWith('http') &&
        widget.url.toLowerCase().contains('.pdf')) {
      // Use Google Docs viewer as a fallback for Android remote PDFs
      effectiveUrl =
          'https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(widget.url)}';
    }

    final bool isDownloadable = !isLocal && widget.url.startsWith('http');
    final bool isPdf = widget.url.toLowerCase().contains('.pdf');

    return Scaffold(
      // Keep the document action anchored when another input/keyboard is
      // opened over this route.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          widget.title.isEmpty ? 'Document' : widget.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: colors.surface,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () => _shareDocument(),
          ),
          if (isDownloadable)
            IconButton(
              icon: const Icon(Icons.download_rounded),
              onPressed: () => _downloadDocument(),
            ),
        ],
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                ),
              )
            : null,
      ),
      body: Stack(
        children: [
          if (isLocal && isPdf && Platform.isAndroid)
            // Local PDFs on Android are notorious for not loading in WebView.
            // We provide a dedicated message and an external open button.
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 64,
                      color: colors.primary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Local PDF Preview',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'To view this local PDF on Android, please open it with your system viewer.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () => _openExternally(),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Open with System Viewer'),
                    ),
                  ],
                ),
              ),
            )
          else
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(effectiveUrl)),
              initialSettings: InAppWebViewSettings(
                supportZoom: true,
                useShouldOverrideUrlLoading: true,
                javaScriptEnabled: true,
                builtInZoomControls: true,
                displayZoomControls: false,
                allowFileAccess: true,
                allowContentAccess: true,
                allowFileAccessFromFileURLs: true,
                allowUniversalAccessFromFileURLs: true,
                userAgent:
                    'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1',
              ),
              onProgressChanged: (controller, progress) {
                setState(() {
                  _progress = progress / 100;
                });
              },
              onLoadStop: (controller, url) {
                setState(() {
                  _isLoading = false;
                });
              },
              onReceivedError: (controller, request, error) {
                debugPrint('DocumentViewer error: ${error.description}');
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
            ),
          if (_isLoading && !(isLocal && isPdf && Platform.isAndroid))
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Loading document...', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openExternally(),
        label: const Text('Open Externally'),
        icon: const Icon(Icons.open_in_new_rounded),
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
      ),
    );
  }

  Future<void> _openExternally() async {
    try {
      final String rawUrl = widget.url;
      final bool isLocal =
          rawUrl.startsWith('/') || rawUrl.startsWith('file://');

      Uri? uri;
      if (isLocal) {
        final cleanPath = rawUrl.replaceFirst('file://', '');
        uri = Uri.file(cleanPath);
      } else {
        uri = Uri.tryParse(rawUrl);
      }

      if (uri != null) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            NotificationService.showError(
              context,
              'No application found to open this file type.',
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Could not open file: $e');
      }
    }
  }

  Future<void> _shareDocument() async {
    if (widget.url.startsWith('file')) {
      final cleanPath = widget.url.replaceFirst('file://', '');
      await SharePlus.instance.share(ShareParams(files: [XFile(cleanPath)]));
    } else {
      await SharePlus.instance.share(ShareParams(text: widget.url));
    }
  }

  Future<void> _downloadDocument() async {
    if (widget.url.startsWith('file')) {
      NotificationService.showInfo(
        context,
        'Document is already on your device.',
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Downloading...')));

    try {
      final response = await http.get(Uri.parse(widget.url));
      final directory = Platform.isAndroid
          ? await getExternalStorageDirectory() ??
                await getApplicationDocumentsDirectory()
          : await getApplicationDocumentsDirectory();

      final filename = widget.title.isNotEmpty
          ? widget.title
          : 'document_${DateTime.now().millisecondsSinceEpoch}${path.extension(Uri.parse(widget.url).path)}';

      final file = File(path.join(directory.path, filename));
      await file.writeAsBytes(response.bodyBytes);

      if (mounted) {
        NotificationService.showSuccess(context, 'Saved to downloads');
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Download failed');
      }
    }
  }
}
