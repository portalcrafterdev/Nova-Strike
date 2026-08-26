import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// The seam between the game's ad policy and the AdMob plugin.
///
/// Everything that touches the plugin lives behind this. The rules about when
/// an ad may appear are worth testing and the plugin cannot run in a test, so
/// the two are kept apart.
abstract class AdsBackend {
  const AdsBackend();

  /// Whether this build can serve ads at all. False on desktop and in tests.
  bool get isSupported;

  Future<void> initialize();

  /// Fetches one interstitial and holds it. True once it is ready to show.
  Future<bool> loadInterstitial(String unitId);

  /// Shows the held interstitial and returns when the player dismisses it.
  /// False if there was nothing to show.
  Future<bool> showInterstitial();

  Future<bool> loadRewarded(String unitId);

  /// Shows the held rewarded ad. True only if the player watched enough of it
  /// to earn the reward, which is the only thing the caller may pay out on.
  Future<bool> showRewarded();
}

/// A backend that serves nothing, for tests and for any platform with no ads.
///
/// Named rather than left as a null check so a screen under test is exercising
/// the same code path a phone with no network takes.
class NoAdsBackend extends AdsBackend {
  const NoAdsBackend();

  @override
  bool get isSupported => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> loadInterstitial(String unitId) async => false;

  @override
  Future<bool> showInterstitial() async => false;

  @override
  Future<bool> loadRewarded(String unitId) async => false;

  @override
  Future<bool> showRewarded() async => false;
}

/// The real one, talking to AdMob.
///
/// Every full screen ad is loaded ahead of the moment it is wanted, because a
/// load takes seconds and a game that freezes on a black screen after a level
/// has already lost the player it was trying to monetise.
class MobileAdsBackend extends AdsBackend {
  MobileAdsBackend();

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;

  @override
  bool get isSupported => true;

  @override
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  @override
  Future<bool> loadInterstitial(String unitId) {
    if (_interstitial != null) {
      return Future.value(true);
    }
    final ready = Completer<bool>();
    InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _complete(ready, true);
        },
        onAdFailedToLoad: (error) => _complete(ready, false),
      ),
    );
    return ready.future;
  }

  @override
  Future<bool> showInterstitial() {
    final ad = _interstitial;
    if (ad == null) {
      return Future.value(false);
    }
    _interstitial = null;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _complete(done, true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _complete(done, false);
      },
    );
    ad.show();
    return done.future;
  }

  @override
  Future<bool> loadRewarded(String unitId) {
    if (_rewarded != null) {
      return Future.value(true);
    }
    final ready = Completer<bool>();
    RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _complete(ready, true);
        },
        onAdFailedToLoad: (error) => _complete(ready, false),
      ),
    );
    return ready.future;
  }

  @override
  Future<bool> showRewarded() {
    final ad = _rewarded;
    if (ad == null) {
      return Future.value(false);
    }
    _rewarded = null;
    final done = Completer<bool>();
    // Set before showing. The reward arrives while the ad is still up, and the
    // dismissal that settles this future comes after it.
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _complete(done, earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _complete(done, false);
      },
    );
    ad.show(
      onUserEarnedReward: (ad, reward) {
        earned = true;
      },
    );
    return done.future;
  }

  /// AdMob can call back more than once for the same ad. Completing a settled
  /// completer throws, and it would throw from inside a plugin callback where
  /// nothing is there to catch it.
  static void _complete(Completer<bool> completer, bool value) {
    if (!completer.isCompleted) {
      completer.complete(value);
    }
  }
}
