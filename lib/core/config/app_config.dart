import 'dart:io';

class AppConfig {
  // ==========================================================
  // ADMOB CONFIGURATION
  // ==========================================================

  // Replace these with your actual App IDs from AdMob console
  static String get admobAppId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-8432805167625659~8945820754';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-8432805167625659~7687795586';
    }
    return '';
  }

  // Replace these with your actual Ad Unit IDs from AdMob console
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Android Test Banner
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // iOS Test Banner
    }
    return '';
  }

  // Replace these with your actual Rewarded Ad Unit IDs from AdMob console
  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; // Android Test Rewarded
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; // iOS Test Rewarded
    }
    return '';
  }

  // Replace these with your actual Native Ad Unit IDs from AdMob console
  static String get nativeAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/2247696110'; // Android Test Native
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/3986624511'; // iOS Test Native
    }
    return '';
  }
}
