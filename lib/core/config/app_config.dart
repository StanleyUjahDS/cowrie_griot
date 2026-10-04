import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConfig {
  /// Ads are always enabled. Debug/Profile builds use Google's test units;
  /// Release builds use the production AdMob units below.
  static const bool adsEnabled = true;

  static bool get _useTestAds => kDebugMode || kProfileMode;

  // ==========================================================
  // ADMOB CONFIGURATION
  // ==========================================================

  // Replace these with your actual App IDs from AdMob console
  static String get admobAppId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-8536613969303259~8291757202';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-8536613969303259~7689121976';
    }
    return '';
  }

  // Replace these with your actual Ad Unit IDs from AdMob console
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return _useTestAds
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-8536613969303259/3650636169';
    } else if (Platform.isIOS) {
      return _useTestAds
          ? 'ca-app-pub-3940256099942544/2934735716'
          : 'ca-app-pub-8536613969303259/6999688388';
    }
    return '';
  }

  // Replace these with your actual Rewarded Ad Unit IDs from AdMob console
  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return _useTestAds
          ? 'ca-app-pub-3940256099942544/5224354917'
          : 'ca-app-pub-8536613969303259/7599065597';
    } else if (Platform.isIOS) {
      return _useTestAds
          ? 'ca-app-pub-3940256099942544/1712485313'
          : 'ca-app-pub-8536613969303259/5146046664';
    }
    return '';
  }

  // Replace these with your actual Native Ad Unit IDs from AdMob console
  static String get nativeAdUnitId {
    if (Platform.isAndroid) {
      return _useTestAds
          ? 'ca-app-pub-3940256099942544/2247696110'
          : 'ca-app-pub-8536613969303259/7226084945';
    } else if (Platform.isIOS) {
      return _useTestAds
          ? 'ca-app-pub-3940256099942544/3986624511'
          : 'ca-app-pub-8536613969303259/9504588911';
    }
    return '';
  }
}
