import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';

enum CarouselItemType { ad, feature }

class CarouselItem {
  final CarouselItemType type;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onTap;

  CarouselItem({
    required this.type,
    this.title,
    this.subtitle,
    this.icon,
    this.onTap,
  });
}

class GriotAdCarousel extends StatefulWidget {
  final List<CarouselItem> items;
  final double height;

  const GriotAdCarousel({
    super.key,
    required this.items,
    this.height = 180,
  });

  @override
  State<GriotAdCarousel> createState() => _GriotAdCarouselState();
}

class _GriotAdCarouselState extends State<GriotAdCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  final Map<int, NativeAd> _loadedAds = {};
  final Set<int> _loadingIndices = {};

  @override
  void dispose() {
    _pageController.dispose();
    for (var ad in _loadedAds.values) {
      ad.dispose();
    }
    super.dispose();
  }

  void _loadAd(int index) {
    if (_loadedAds.containsKey(index) || _loadingIndices.contains(index)) return;

    _loadingIndices.add(index);
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    NativeAd(
      adUnitId: AppConfig.nativeAdUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _loadedAds[index] = ad as NativeAd;
            _loadingIndices.remove(index);
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _loadingIndices.remove(index);
          debugPrint('Carousel NativeAd at index $index failed: $error');
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        // Switching to MEDIUM template to comfortably pass the 120x120 MediaView requirement.
        // In Medium, the MediaView is at the top and scales to the full width (~350dp),
        // easily satisfying the video ad policy.
        templateType: TemplateType.medium,
        mainBackgroundColor: colorScheme.surface,
        cornerRadius: 0.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: colorScheme.onPrimary,
          backgroundColor: colorScheme.primary,
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: colorScheme.onSurface,
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: colorScheme.onSurfaceVariant,
          style: NativeTemplateFontStyle.normal,
          size: 11.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: colorScheme.onSurfaceVariant,
          style: NativeTemplateFontStyle.normal,
          size: 11.0,
        ),
      ),
    ).load();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.items.length,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final item = widget.items[index];
          
          if (item.type == CarouselItemType.ad) {
            _loadAd(index);
            return _buildAdSlide(index);
          }
          
          return _buildFeatureSlide(item);
        },
      ),
    );
  }

  Widget _buildAdSlide(int index) {
    final ad = _loadedAds[index];
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Stack(
        children: [
          // Background Card
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: isDark ? 0.2 : 0.12),
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
          
          // Ad Widget (UNCLIPPED to satisfy validator)
          // We use 0.5pt padding just to keep it off the very edge of the border.
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(0.5), 
              child: ad != null
                  ? AdWidget(ad: ad)
                  : const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureSlide(CarouselItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Stack(
        children: [
          // Background with Gradient & Pattern
          Positioned.fill(
            child: InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(22),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Branded Background Element (Subtle logo peek)
                    Positioned(
                      right: -30,
                      bottom: -20,
                      child: Opacity(
                        opacity: 0.12,
                        child: Image.asset(
                          'assets/cowrie_images/cowrie_stack.png',
                          width: 150,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    
                    // Content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'FEATURE',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  item.title ?? '',
                                  style: textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.subtitle ?? '',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              item.icon,
                              size: 28,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
