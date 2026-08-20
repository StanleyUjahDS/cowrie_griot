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
        // Switching back to SMALL template to save space.
        templateType: TemplateType.small,
        mainBackgroundColor: colorScheme.surface,
        cornerRadius: 0.0, // Let Flutter handle the card corners for safety
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: colorScheme.onPrimary,
          backgroundColor: colorScheme.primary,
          style: NativeTemplateFontStyle.bold,
          size: 15.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: colorScheme.onSurface,
          style: NativeTemplateFontStyle.bold,
          size: 15.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: colorScheme.onSurfaceVariant,
          style: NativeTemplateFontStyle.normal,
          size: 12.0, // Reduced to prevent "Advertiser outside box" error
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: colorScheme.onSurfaceVariant,
          style: NativeTemplateFontStyle.normal,
          size: 12.0, // Reduced to prevent "Advertiser outside box" error
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

    // COMPACT Height: 155dp is the "Sweet Spot" for the small template.
    // It passes the 120x120 MediaView requirement without taking too much space.
    const double adHeight = 155;

    // Placeholder/Loading state
    if (!_isLoaded || _nativeAd == null) {
      return Container(
        height: adHeight,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Icon(
            Icons.ads_click_rounded,
            color: colorScheme.onSurface.withValues(alpha: 0.05),
            size: 32,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      height: adHeight,
      child: Stack(
        children: [
          // Background Card
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: borderColor,
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
          
          // The Ad (Unclipped safety zone)
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(8), // Padding to keep assets away from borders
              child: AdWidget(ad: _nativeAd!),
            ),
          ),
        ],
      ),
    );
  }
}
