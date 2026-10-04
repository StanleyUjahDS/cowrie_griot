import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/app_config.dart';

enum RewardedAdResult {
  rewarded,
  dismissed,
  failedToShow,
  unavailable,
  disabled,
}

class AdService extends ChangeNotifier {
  AdService._internal();
  static final AdService instance = AdService._internal();

  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;
  Timer? _retryTimer;
  int _retryAttempt = 0;

  /// Initializes the ads SDK only when ads have been enabled for this build.
  Future<void> initialize() async {
    if (!AppConfig.adsEnabled) return;

    // Keep Ad Inspector available on the registered development devices.
    // These IDs are only applied to debug/profile builds; release builds use
    // the normal production request configuration.
    if (kDebugMode || kProfileMode) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: <String>[
            'b36fb7f5-cca7-4f57-b76f-a7d8f2fb500b', // Pixel 7 Pro Advertising ID
            '4d313a79b92adca39dcedc95ab09a99f', // iPhone
          ],
        ),
      );
    }

    late final InitializationStatus status;
    try {
      status = await MobileAds.instance.initialize();
    } catch (error, stackTrace) {
      debugPrint('Mobile Ads initialization failed: $error\n$stackTrace');
      return;
    }
    // This is intentionally logged in debug builds: it is the quickest way to
    // confirm that the Unity adapter was bundled and initialized on a device.
    // A successful adapter initialization does not, by itself, guarantee a
    // Unity impression; the Ad Inspector/waterfall still has to be checked.
    for (final entry in status.adapterStatuses.entries) {
      debugPrint(
        'Ads adapter ${entry.key}: ${entry.value.state.name} '
        '(latency ${entry.value.latency}ms, ${entry.value.description})',
      );
    }
    loadRewardedAd();
  }

  /// Opens Google's Ad Inspector on a real test device.  The inspector shows
  /// the mediation adapters, waterfall, and the adapter that actually filled.
  void openAdInspector() {
    if (!AppConfig.adsEnabled) return;
    MobileAds.instance.openAdInspector((error) {
      if (error != null) {
        debugPrint(
          'Ad Inspector error: code=${error.code ?? '-'} '
          'domain=${error.domain ?? '-'} message=${error.message ?? '-'}',
        );
      } else {
        debugPrint('Ad Inspector closed normally.');
      }
    });
  }

  /// Loads a rewarded ad.
  void loadRewardedAd() {
    if (!AppConfig.adsEnabled) return;
    if (_isRewardedAdLoading || _rewardedAd != null) return;

    _isRewardedAdLoading = true;
    notifyListeners();

    RewardedAd.load(
      adUnitId: AppConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _retryAttempt = 0;
          debugPrint('RewardedAd loaded. Response: ${ad.responseInfo}');
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
          _scheduleRewardedRetry();
        },
      ),
    );
  }

  /// Shows the rewarded ad if available and reports how the flow ended.
  ///
  /// The reward callback is deliberately resolved only after the ad is
  /// dismissed, so callers cannot start mining while the fullscreen ad is
  /// still active or mistake a dismissal for a completed reward.
  Future<RewardedAdResult> showRewardedAd() async {
    if (!AppConfig.adsEnabled) {
      debugPrint('Rewarded ads are disabled for this build.');
      return RewardedAdResult.disabled;
    }

    final ad = _rewardedAd;
    if (ad == null) {
      debugPrint(
        'Warning: Attempted to show rewarded ad before it was loaded.',
      );
      loadRewardedAd(); // Try loading for next time
      return RewardedAdResult.unavailable;
    }

    final result = Completer<RewardedAdResult>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (dismissedAd) {
        dismissedAd.dispose();
        if (identical(_rewardedAd, ad)) _rewardedAd = null;
        notifyListeners();
        loadRewardedAd();
        if (!result.isCompleted) {
          result.complete(
            earned ? RewardedAdResult.rewarded : RewardedAdResult.dismissed,
          );
        }
      },
      onAdFailedToShowFullScreenContent: (failedAd, error) {
        debugPrint('RewardedAd failed to show: $error');
        failedAd.dispose();
        if (identical(_rewardedAd, ad)) _rewardedAd = null;
        notifyListeners();
        loadRewardedAd();
        if (!result.isCompleted) result.complete(RewardedAdResult.failedToShow);
      },
      onAdImpression: (ad) {
        debugPrint('RewardedAd impression. Response: ${ad.responseInfo}');
      },
    );

    try {
      _rewardedAd = null;
      notifyListeners();
      ad.show(
        onUserEarnedReward: (AdWithoutView adWithoutView, RewardItem reward) {
          earned = true;
        },
      );
    } catch (error) {
      debugPrint('RewardedAd could not be shown: $error');
      ad.dispose();
      if (!result.isCompleted) result.complete(RewardedAdResult.failedToShow);
      loadRewardedAd();
    }

    return result.future;
  }

  bool get isRewardedAdAvailable => _rewardedAd != null;

  void _scheduleRewardedRetry() {
    if (!AppConfig.adsEnabled || _retryTimer?.isActive == true) return;
    final delay = Duration(seconds: 1 << (_retryAttempt.clamp(0, 5)));
    _retryAttempt++;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      loadRewardedAd();
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _rewardedAd?.dispose();
    super.dispose();
  }
}
