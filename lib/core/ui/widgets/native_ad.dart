import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../config/app_config.dart';
import '../../services/ad_service.dart';

class GriotNativeAd extends StatefulWidget {
  const GriotNativeAd({
    super.key,
    this.compact = false,
    this.height,
    this.embedded,
    this.cardBuilder,
  });
  final bool compact;
  final double? height;
  final bool? embedded;
  final Widget Function(BuildContext, Widget)? cardBuilder;
  @override
  State<GriotNativeAd> createState() => _GriotNativeAdState();
}

class _GriotNativeAdState extends State<GriotNativeAd> {
  NativeAd? _ad;
  bool _loaded = false;
  Brightness? _themeBrightness;
  Timer? _retryTimer;
  @override
  void initState() {
    super.initState();
    AdService.instance.addListener(_refresh);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_themeBrightness != null && _themeBrightness != brightness) {
      _retryTimer?.cancel();
      _ad?.dispose();
      _ad = null;
      _loaded = false;
    }
    _themeBrightness = brightness;
    _refresh();
  }

  void _refresh() {
    if (!mounted || !AdService.instance.canRequestAds || _ad != null) return;
    final colors = Theme.of(context).colorScheme;
    final ad = NativeAd(
      adUnitId: AppConfig.nativeAdUnitId,
      factoryId: 'griot_native_ad',
      request: const AdRequest(),
      customOptions: <String, Object>{
        'compact': widget.compact,
        'primary': colors.primary.toARGB32(),
        'onPrimary': colors.onPrimary.toARGB32(),
        'surface': colors.surface.toARGB32(),
        'onSurface': colors.onSurface.toARGB32(),
        'onSurfaceVariant': colors.onSurfaceVariant.toARGB32(),
      },
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          _retryTimer?.cancel();
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _ad = null;
              _loaded = false;
            });
            _scheduleRetry();
          }
        },
      ),
    );
    setState(() => _ad = ad);
    ad.load();
  }

  void _scheduleRetry() {
    if (!mounted || !AdService.instance.canRequestAds) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 20), () {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    AdService.instance.removeListener(_refresh);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!AdService.instance.canRequestAds || ad == null || !_loaded) {
      return const SizedBox.shrink();
    }
    final height = widget.height ?? (widget.compact ? 248.0 : 350.0);
    final content = SizedBox(
      height: height,
      width: double.infinity,
      child: AdWidget(ad: ad),
    );
    if (widget.cardBuilder != null) {
      return widget.cardBuilder!(context, content);
    }
    if (widget.embedded == true) return content;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.compact ? 18 : 24),
      child: content,
    );
  }
}
