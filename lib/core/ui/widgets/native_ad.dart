import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../config/app_config.dart';

class GriotNativeAd extends StatefulWidget {
  const GriotNativeAd({super.key});

  @override
  State<GriotNativeAd> createState() => _GriotNativeAdState();
}

class _GriotNativeAdState extends State<GriotNativeAd> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  
  // Track theme properties to detect changes
  Brightness? _lastBrightness;
  Color? _lastPrimaryColor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    final theme = Theme.of(context);
    
    // Check if theme has changed
    if (_lastBrightness != theme.brightness || _lastPrimaryColor != theme.colorScheme.primary) {
      _lastBrightness = theme.brightness;
      _lastPrimaryColor = theme.colorScheme.primary;
      
      // Theme changed, reload the ad with new colors
      _loadAd(force: true);
    }
  }

  void _loadAd({bool force = false}) {
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
      customOptions: {
        'primary': colorScheme.primary.toARGB32(),
        'onPrimary': colorScheme.onPrimary.toARGB32(),
        'surface': colorScheme.surface.toARGB32(),
        'onSurface': colorScheme.onSurface.toARGB32(),
        'onSurfaceVariant': colorScheme.onSurfaceVariant.toARGB32(),
      },
      listener: NativeAdListener(
        onAdLoaded: (ad) {
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
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color borderColor = colorScheme.outline.withValues(alpha: isDark ? 0.20 : 0.12);

    // Height 360dp provides more room for Medium templates to avoid "outside box" errors
    const double adHeight = 360;

    // Placeholder/Loading state
    if (!_isLoaded || _nativeAd == null) {
      return Container(
        height: adHeight,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // THE PREMIUM COMPLIANCE STACK:
    // 1. Background Card with Nice Border and Shadow.
    // 2. Large 12pt padding to ensure NO AdMob assets are near the border.
    // 3. AdWidget remains unclipped by parent boundaries.
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      height: adHeight,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: isDark ? 0.20 : 0.12),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12), 
          child: AdWidget(ad: _nativeAd!),
        ),
      ),
    );
  }
}
