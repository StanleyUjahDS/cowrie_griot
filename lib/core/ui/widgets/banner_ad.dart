import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../config/app_config.dart';

class GriotBannerAd extends StatefulWidget {
  const GriotBannerAd({super.key});

  @override
  State<GriotBannerAd> createState() => _GriotBannerAdState();
}

class _GriotBannerAdState extends State<GriotBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (!AppConfig.adsEnabled) return;

    _bannerAd = BannerAd(
      adUnitId: AppConfig.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
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
          debugPrint('BannerAd failed to load: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.adsEnabled) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Dedicated Region for Ad Consistency
    // This prevents UI jumping and ensures ads look the same everywhere.
    return Container(
      width: double.infinity,
      height: 60, // Fixed dedicated height for standard banners
      margin: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: isDark ? 0.3 : 0.5),
        border: Border.symmetric(
          horizontal: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: _isLoaded && _bannerAd != null
          ? SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            )
          : Icon(
              Icons.ads_click_rounded,
              color: colorScheme.onSurface.withValues(alpha: 0.05),
              size: 20,
            ),
    );
  }
}
