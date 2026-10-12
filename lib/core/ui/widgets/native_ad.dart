import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../config/app_config.dart';
import '../../services/ad_service.dart';

class GriotNativeAd extends StatefulWidget {
  /// Compact keeps the native ad card suitable for dense grids such as Game
  /// Center. The default remains the full-size feed placement used elsewhere.
  final bool compact;
  final double? height;

  const GriotNativeAd({super.key, this.compact = false, this.height});

  @override
  State<GriotNativeAd> createState() => _GriotNativeAdState();
}

class _GriotNativeAdState extends State<GriotNativeAd> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;

  // Track theme properties to detect changes
  Brightness? _lastBrightness;
  Color? _lastPrimaryColor;
  Color? _lastSurfaceColor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Check if theme has changed
    if (_lastBrightness != theme.brightness ||
        _lastPrimaryColor != colorScheme.primary ||
        _lastSurfaceColor != colorScheme.surface) {
      _lastBrightness = theme.brightness;
      _lastPrimaryColor = colorScheme.primary;
      _lastSurfaceColor = colorScheme.surface;

      // Theme changed, reload the ad with new colors
      _loadAd(force: true);
    }
  }

  @override
  void initState() {
    super.initState();
    AdService.instance.addListener(_onAdsReady);
  }

  void _onAdsReady() {
    if (!mounted || !AdService.instance.canRequestAds || _nativeAd != null) {
      return;
    }
    _loadAd();
  }

  void _loadAd({bool force = false}) {
    if (!AdService.instance.canRequestAds) return;

    if (_nativeAd != null && !force) return;

    if (force) {
      _nativeAd?.dispose();
      _nativeAd = null;
      _isLoaded = false;
    }

    final colorScheme = Theme.of(context).colorScheme;

    _nativeAd = NativeAd(
      adUnitId: AppConfig.nativeAdUnitId,
      factoryId: 'griot_native_ad',
      request: const AdRequest(),
      nativeAdOptions: NativeAdOptions(
        // Game Center ads have enough room for a proper media preview. Asking
        // for square-only media can return a very short/letterboxed video and
        // leaves the native card looking mostly empty, so allow video ratios
        // on the compact placement as well.
        mediaAspectRatio: MediaAspectRatio.any,
      ),
      customOptions: {
        'compact': widget.compact,
        'primary': colorScheme.primary.toARGB32(),
        'onPrimary': colorScheme.onPrimary.toARGB32(),
        'surface': colorScheme.surface.toARGB32(),
        'onSurface': colorScheme.onSurface.toARGB32(),
        'onSurfaceVariant': colorScheme.onSurfaceVariant.toARGB32(),
      },
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('NativeAd loaded. Response: ${ad.responseInfo}');
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('NativeAd failed to load: $error');
        },
        onAdImpression: (ad) {
          debugPrint('NativeAd impression. Response: ${ad.responseInfo}');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    AdService.instance.removeListener(_onAdsReady);
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdService.instance.canRequestAds) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color borderColor = colorScheme.outline.withValues(
      alpha: isDark ? 0.20 : 0.12,
    );

    // The compact placement intentionally matches the Game Center tile
    // footprint; the regular placement keeps the existing feed size.
    final adHeight = widget.height ?? (widget.compact ? 248.0 : 350.0);
    final radius = widget.compact ? 18.0 : 24.0;
    final margin = widget.compact
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 10);

    // Placeholder/Loading state
    if (!_isLoaded || _nativeAd == null) {
      return Container(
        height: adHeight,
        margin: margin,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    // THE PREMIUM COMPLIANCE STACK:
    // 1. Background Card with Nice Border and Shadow.
    // 2. Exact padding to ensure AdWidget stays within bounds.
    return Container(
      margin: margin,
      height: adHeight,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: isDark ? 0.24 : 0.14),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: EdgeInsets.all(widget.compact ? 8 : 12),
          child: AdWidget(ad: _nativeAd!),
        ),
      ),
    );
  }
}
