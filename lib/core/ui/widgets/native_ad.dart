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
    final colorScheme = theme.colorScheme;
    
    // Check if theme has changed
    if (_lastBrightness != theme.brightness || _lastPrimaryColor != colorScheme.primary) {
      _lastBrightness = theme.brightness;
      _lastPrimaryColor = colorScheme.primary;
      
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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    _nativeAd = NativeAd(
      adUnitId: AppConfig.nativeAdUnitId,
      request: const AdRequest(),
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
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: colorScheme.surface,
        cornerRadius: 0.0, // Set to 0 to prevent native-side clipping of assets at corners
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: colorScheme.onPrimary,
          backgroundColor: colorScheme.primary,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: colorScheme.onSurface,
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: colorScheme.onSurfaceVariant,
          style: NativeTemplateFontStyle.normal,
          size: 10.0, // Smallest possible to ensure it stays inside the box
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: colorScheme.onSurfaceVariant,
          style: NativeTemplateFontStyle.normal,
          size: 10.0, // Smallest possible to ensure it stays inside the box
        ),
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

    // Height 340dp is the "Premium" height for Medium templates on Android.
    const double adHeight = 340;

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
      child: Stack(
        children: [
          // Nice Background Card
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: borderColor,
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
            ),
          ),
          
          // The Ad (Unclipped safety layer)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(12), 
              child: AdWidget(ad: _nativeAd!),
            ),
          ),
        ],
      ),
    );
  }
}
