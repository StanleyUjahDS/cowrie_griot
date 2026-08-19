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
    
    // If forcing a reload, dispose of the old ad first
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
        templateType: TemplateType.small,
        mainBackgroundColor: colorScheme.surface,
        cornerRadius: 16.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: colorScheme.onPrimary,
          backgroundColor: colorScheme.primary,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: colorScheme.onSurface,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: colorScheme.onSurfaceVariant,
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: colorScheme.onSurfaceVariant,
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
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
    if (!_isLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color borderColor = colorScheme.outline.withValues(
      alpha: isDark ? 0.20 : 0.12,
    );

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      height: 94, // Height for small template + padding
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: AdWidget(ad: _nativeAd!),
      ),
    );
  }
}
