import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ad_ids.dart';
import 'ads_backend.dart';

/// Owns every ad the game shows, and every rule about when it may show one.
///
/// Three placements, chosen so none of them lands on a player who is trying to
/// play:
///
///   Banner. Menu screens only. Never over the play area. A bullet hell needs
///   the whole screen and a steady frame time, and a web view animating behind
///   the action costs both.
///
///   Interstitial. After a level is cleared, and not after every one. Never on
///   retry and never on the game over sheet, because the build document is
///   explicit that retry is instant with no ad gate, and it is right: friction
///   at the moment of failure is what makes people close the game for good.
///
///   Rewarded. Offered, never imposed. The player taps it to double the coins
///   they just earned, and the reward is paid only when AdMob says they
///   actually watched it.
///
/// Nothing here throws and nothing here blocks. An ad that fails to load is a
/// normal outcome, not an error, and the game carries on without it.
class AdsController extends ChangeNotifier {
  AdsController({AdsBackend? backend, AdIds? ids})
    : backend = backend ?? MobileAdsBackend(),
      ids = ids ?? AdIds.live;

  /// Levels cleared between interstitials.
  ///
  /// One, so every move to the next level carries an ad. This was three, which
  /// meant most level changes passed in silence and the placement looked
  /// broken from the outside.
  static const int levelsBetweenInterstitials = 1;

  /// No interstitial before this level, whatever the count says.
  ///
  /// One, meaning no exemption. Left as a named number rather than deleted,
  /// because giving the opening levels a clear run is the first thing worth
  /// trying if players start dropping out early.
  static const int interstitialFromLevel = 1;

  /// The least time between two interstitials.
  ///
  /// Not pacing, a guard. Starting a run and clearing a level are separate
  /// events and both show an ad, so without this a player who quits to the
  /// menu and taps PLAY again gets two inside a few seconds.
  static const Duration interstitialGap = Duration(seconds: 45);

  /// How long a background load is given before the caller stops waiting.
  static const Duration loadTimeout = Duration(seconds: 10);

  /// How long a load is given when one is wanted right now.
  ///
  /// Shorter than [loadTimeout], because a player is sitting in front of the
  /// level complete sheet waiting for the next level. Missing the ad costs one
  /// impression. Making them stare at a dead button costs more than that.
  static const Duration topUpTimeout = Duration(seconds: 4);

  /// What watching a rewarded ad multiplies the level's coins by.
  static const int rewardCoinMultiplier = 2;

  final AdsBackend backend;
  final AdIds ids;

  bool _ready = false;
  bool _interstitialReady = false;
  bool _rewardedReady = false;
  bool _loadingRewarded = false;
  bool _showing = false;
  int _clearedSinceAd = 0;
  DateTime? _lastInterstitial;

  /// Whether the plugin came up. False until [init] finishes, and false for
  /// good on a platform with no ads.
  bool get isReady => _ready;

  /// Whether a rewarded ad is loaded and can be offered right now.
  bool get canOfferReward => _ready && _rewardedReady;

  /// Whether a full screen ad is on screen. The game pauses on this.
  bool get isShowing => _showing;

  /// Whether this build is wired to Google's test units.
  bool get isTest => ids.isTest;

  /// The banner unit for this build. The banner widget loads its own ad,
  /// because a banner is a view and has to belong to the widget showing it.
  String get bannerUnitId => ids.banner;

  /// Starts the plugin and puts the first two full screen ads on the shelf.
  ///
  /// Safe to call before the first frame and safe to not await.
  Future<void> init() async {
    if (!backend.isSupported) {
      return;
    }
    final ok = await _guard(() async {
      await backend.initialize();
      return true;
    }, fallback: false);
    if (!(ok ?? false)) {
      return;
    }
    _ready = true;
    notifyListeners();
    unawaited(_fillInterstitial());
    unawaited(_fillRewarded());
  }

  /// Whether clearing [level] has earned an interstitial.
  ///
  /// Pure, and separate from showing one, so the rules can be tested without a
  /// plugin. [now] is passed in so a test does not have to wait two minutes.
  /// Deliberately says nothing about whether an ad has finished loading. That
  /// is a supply question and it is answered at the moment of showing, by
  /// fetching one if the shelf is empty. Folding it in here made every second
  /// level change skip its ad, because the replacement was still in flight
  /// from the level change before it.
  bool shouldShowInterstitialAfter(int level, {DateTime? now}) {
    if (!_ready || _showing) {
      return false;
    }
    if (level < interstitialFromLevel) {
      return false;
    }
    if (_clearedSinceAd < levelsBetweenInterstitials) {
      return false;
    }
    final last = _lastInterstitial;
    if (last != null &&
        (now ?? DateTime.now()).difference(last) < interstitialGap) {
      return false;
    }
    return true;
  }

  /// Records that a level was cleared, and shows an interstitial if that has
  /// earned one. Returns whether an ad was shown.
  ///
  /// Called only from the level complete path. Retry and game over do not call
  /// it at all, so no counter can ever put an ad in front of a retry.
  Future<bool> onLevelCleared(int level, {DateTime? now}) async {
    _clearedSinceAd++;
    if (!shouldShowInterstitialAfter(level, now: now)) {
      return false;
    }
    return _showInterstitial(now: now);
  }

  /// Shows an interstitial on the way into a run from the menu.
  ///
  /// This is a start, not a retry. Retrying after losing the ship never comes
  /// through here, so the rule that failure is never taxed still holds.
  Future<bool> onGameStart({DateTime? now}) async {
    // The level count is not consulted. Starting a run is its own event and
    // the gap alone decides whether it has earned an ad.
    if (!_ready || _showing) {
      return false;
    }
    final last = _lastInterstitial;
    if (last != null &&
        (now ?? DateTime.now()).difference(last) < interstitialGap) {
      return false;
    }
    return _showInterstitial(now: now);
  }

  Future<bool> _showInterstitial({DateTime? now}) async {
    if (!_interstitialReady) {
      // The shelf is empty, most likely because the last one was spent a
      // moment ago. Wait briefly for a replacement rather than skipping.
      await _fillInterstitial(timeout: topUpTimeout);
    }
    if (!_interstitialReady) {
      return false;
    }
    final shown = await _showFullScreen(backend.showInterstitial);
    if (shown) {
      _clearedSinceAd = 0;
      _lastInterstitial = now ?? DateTime.now();
      _interstitialReady = false;
      unawaited(_fillInterstitial());
    }
    return shown;
  }

  /// Shows the rewarded ad. True only if the player earned the reward.
  Future<bool> showRewarded() async {
    if (!canOfferReward) {
      return false;
    }
    final earned = await _showFullScreen(backend.showRewarded);
    _rewardedReady = false;
    notifyListeners();
    unawaited(_fillRewarded());
    return earned;
  }

  Future<bool> _showFullScreen(Future<bool> Function() show) async {
    _showing = true;
    notifyListeners();
    // No timeout. This one is waiting on a person, and an ad the player is
    // still watching must not be declared failed underneath them.
    final result = await _guard(show, fallback: false, timeout: null);
    _showing = false;
    notifyListeners();
    return result ?? false;
  }

  Future<void> _fillInterstitial({Duration timeout = loadTimeout}) async {
    if (!_ready || _interstitialReady) {
      return;
    }
    final ok = await _guard(
      () => backend.loadInterstitial(ids.interstitial),
      fallback: false,
      timeout: timeout,
    );
    _interstitialReady = ok ?? false;
  }

  /// Makes sure a rewarded ad is on the shelf, retrying a load that failed.
  ///
  /// Called by any screen that is about to offer one, and by the game when the
  /// player reaches their last life. Without it a single failed load at start
  /// up, which is normal on a phone that has not found the network yet, left
  /// [canOfferReward] false for the rest of the session and the extra life
  /// could never be offered again.
  Future<void> prepareReward() async {
    await _fillRewarded(timeout: topUpTimeout);
  }

  Future<void> _fillRewarded({Duration timeout = loadTimeout}) async {
    if (!_ready || _rewardedReady || _loadingRewarded) {
      return;
    }
    // Guarded, because the sheet asking and the last life hook asking can
    // arrive together, and two loads in flight would leak one of the ads.
    _loadingRewarded = true;
    final ok = await _guard(
      () => backend.loadRewarded(ids.rewarded),
      fallback: false,
      timeout: timeout,
    );
    _loadingRewarded = false;
    _rewardedReady = ok ?? false;
    notifyListeners();
  }

  /// Runs one call and swallows whatever it does. No ad is worth taking the
  /// game down for.
  Future<T?> _guard<T>(
    Future<T> Function() call, {
    required T? fallback,
    Duration? timeout = loadTimeout,
  }) async {
    try {
      final future = call();
      return await (timeout == null ? future : future.timeout(timeout));
    } catch (_) {
      return fallback;
    }
  }
}
