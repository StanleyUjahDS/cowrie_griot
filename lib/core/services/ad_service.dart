import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/app_config.dart';

class AdService extends ChangeNotifier {
  AdService._internal();
  static final AdService instance = AdService._internal();

  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;

  /// Loads a rewarded ad.
  void loadRewardedAd() {
    if (_isRewardedAdLoading || _rewardedAd != null) return;

    _isRewardedAdLoading = true;
    notifyListeners();

    RewardedAd.load(
      adUnitId: AppConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('RewardedAd loaded.');
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
          notifyListeners();
          
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              notifyListeners();
              loadRewardedAd(); // Preload next
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
              notifyListeners();
              loadRewardedAd(); // Try again
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('RewardedAd failed to load: $error');
          _isRewardedAdLoading = false;
          _rewardedAd = null;
          notifyListeners();
        },
      ),
    );
  }

  /// Shows the rewarded ad if available.
  /// [onRewardEarned] is called if the user watches the ad to the end.
  void showRewardedAd({required Function(RewardItem reward) onRewardEarned}) {
    if (_rewardedAd == null) {
      debugPrint('Warning: Attempted to show rewarded ad before it was loaded.');
      loadRewardedAd(); // Try loading for next time
      return;
    }

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        onRewardEarned(reward);
      },
    );
  }

  bool get isRewardedAdAvailable => _rewardedAd != null;
}
