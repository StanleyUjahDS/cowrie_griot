import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/deep_link_service.dart';

/// Handles a public Griot URL when the platform delivers it directly to the
/// app router instead of through app_links.
///
/// This is primarily a safety net for cold starts and Flutter web. Normal
/// mobile universal/app-link launches are still handled by DeepLinkService.
class PublicDeepLinkRecoveryScreen extends StatefulWidget {
  final Uri uri;

  const PublicDeepLinkRecoveryScreen({super.key, required this.uri});

  static bool supports(Uri uri) {
    final path = _normalizeUri(uri).path.toLowerCase();
    return path == '/join' ||
        path == '/plus' ||
        path.startsWith('/profile/') ||
        path.startsWith('/channel/') ||
        path.startsWith('/circle/') ||
        path.startsWith('/group/');
  }

  static Uri _normalizeUri(Uri uri) {
    if (uri.scheme.toLowerCase() != 'griot') return uri;

    final host = uri.host.toLowerCase();
    const supportedHosts = {
      'join',
      'plus',
      'profile',
      'group',
      'circle',
      'channel',
    };
    if (!supportedHosts.contains(host)) return uri;

    final path = host == 'join' || host == 'plus'
        ? '/$host'
        : '/$host${uri.path}';
    return Uri(
      scheme: 'https',
      host: 'griot.network',
      path: path,
      query: uri.hasQuery ? uri.query : null,
    );
  }

  @override
  State<PublicDeepLinkRecoveryScreen> createState() =>
      _PublicDeepLinkRecoveryScreenState();
}

class _PublicDeepLinkRecoveryScreenState
    extends State<PublicDeepLinkRecoveryScreen> {
  bool _started = false;
  Timer? _recoveryTimer;

  Uri get _canonicalUri {
    final normalized = PublicDeepLinkRecoveryScreen._normalizeUri(widget.uri);
    return normalized.hasAuthority
        ? normalized
        : Uri(
            scheme: 'https',
            host: 'griot.network',
            path: normalized.path,
            query: normalized.hasQuery ? normalized.query : null,
          );
  }

  void _openLink() {
    _recoveryTimer?.cancel();

    _recoveryTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        unawaited(
          DeepLinkService.instance.handleUri(_canonicalUri, force: true),
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Give app_links first chance to consume a native cold-start URL. If it
      // arrived before the navigator was ready, this route deliberately
      // retries the same canonical URI instead of being suppressed as a
      // duplicate and spinning forever.
      _openLink();
    });
  }

  @override
  void dispose() {
    _recoveryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This route only exists as a cold-start handoff while DeepLinkService
    // resolves the URI. Keep it visually transparent so users never see a
    // second loading page between an external link and its destination.
    return const SizedBox.shrink();
  }
}
