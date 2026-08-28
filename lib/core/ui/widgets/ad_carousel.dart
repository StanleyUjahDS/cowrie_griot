import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
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
  final Duration autoSwipeDuration;

  const GriotAdCarousel({
    super.key,
    required this.items,
    this.height = 420,
    this.autoSwipeDuration = const Duration(seconds: 6),
  });

  @override
  State<GriotAdCarousel> createState() => _GriotAdCarouselState();
}

class _GriotAdCarouselState extends State<GriotAdCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.86);
  final Map<int, NativeAd> _loadedAds = {};
  final Set<int> _loadingIndices = {};
  Timer? _autoSwipeTimer;

  // Track theme properties to detect changes
  Brightness? _lastBrightness;
  Color? _lastPrimaryColor;
  Color? _lastSurfaceColor;

  @override
  void initState() {
    super.initState();
    _startAutoSwipe();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Check if theme has changed to reload ads with new colors
    if (_lastBrightness != theme.brightness || 
        _lastPrimaryColor != colorScheme.primary ||
        _lastSurfaceColor != colorScheme.surface) {
      _lastBrightness = theme.brightness;
      _lastPrimaryColor = colorScheme.primary;
      _lastSurfaceColor = colorScheme.surface;
      
      // Dispose and clear existing ads so they reload with new theme colors
      for (var ad in _loadedAds.values) {
        ad.dispose();
      }
      _loadedAds.clear();
      _loadingIndices.clear();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _stopAutoSwipe();
    _pageController.dispose();
    for (var ad in _loadedAds.values) {
      ad.dispose();
    }
    super.dispose();
  }

  void _startAutoSwipe() {
    _autoSwipeTimer?.cancel();
    _autoSwipeTimer = Timer.periodic(widget.autoSwipeDuration, (timer) {
      if (_pageController.hasClients && widget.items.isNotEmpty) {
        final nextPage = (_pageController.page?.toInt() ?? 0) + 1;
        _pageController.animateToPage(
          nextPage % widget.items.length,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _stopAutoSwipe() {
    _autoSwipeTimer?.cancel();
  }

  void _loadAd(int index) {
    if (_loadedAds.containsKey(index) || _loadingIndices.contains(index)) return;

    final colorScheme = Theme.of(context).colorScheme;

    NativeAd(
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
    ).load();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: GestureDetector(
        onPanDown: (_) => _stopAutoSwipe(),
        onPanCancel: () => _startAutoSwipe(),
        onPanEnd: (_) => _startAutoSwipe(),
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
      ),
    );
  }

  Widget _buildAdSlide(int index) {
    final ad = _loadedAds[index];
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: isDark ? 0.24 : 0.14),
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
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16), 
          child: ad != null
              ? AdWidget(ad: ad)
              : const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
        ),
      ),
    );
  }

  Widget _buildFeatureSlide(CarouselItem item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withValues(alpha: 0.92),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
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
                      'assets/cowrie_images/Cowrie5.png',
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.subtitle ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
    );
  }
}
