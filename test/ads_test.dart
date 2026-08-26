import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/ads/ad_ids.dart';
import 'package:novastrike/ads/ads_backend.dart';
import 'package:novastrike/ads/ads_controller.dart';

/// A backend that always has an ad ready and counts what it was asked to show.
class _FakeAds extends AdsBackend {
  int interstitialsShown = 0;
  int rewardedShown = 0;
  bool rewardEarned = true;

  @override
  bool get isSupported => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> loadInterstitial(String unitId) async => true;

  @override
  Future<bool> showInterstitial() async {
    interstitialsShown++;
    return true;
  }

  @override
  Future<bool> loadRewarded(String unitId) async => true;

  @override
  Future<bool> showRewarded() async {
    rewardedShown++;
    return rewardEarned;
  }
}

const AdIds _testIds = AdIds(
  appId: 'app',
  banner: 'banner',
  interstitial: 'interstitial',
  rewarded: 'rewarded',
);

/// An initialised controller with its first ads on the shelf.
///
/// [AdsController.init] deliberately does not wait for the first loads, so
/// that the menu is never held up by one. That means a caller cannot assume an
/// ad is ready the instant init returns, and neither can this.
// ignore: library_private_types_in_public_api
Future<AdsController> ready(_FakeAds backend) async {
  final ads = AdsController(backend: backend, ids: _testIds);
  await ads.init();
  for (var turn = 0; turn < 10 && !ads.canOfferReward; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
  return ads;
}

void main() {
  group('which units a build serves', () {
    // The one that matters. Running the game on your own phone and tapping
    // your own live banner is how AdMob accounts get suspended for invalid
    // traffic, and it is exactly what happens while checking a layout.
    test('a debug build never serves the live units', () {
      for (final android in [true, false]) {
        final ids = AdIds.forPlatform(android: android, release: false);
        expect(ids.isTest, isTrue);
        expect(ids.banner, isNot(AdIds.androidLive.banner));
        expect(ids.interstitial, isNot(AdIds.androidLive.interstitial));
        expect(ids.rewarded, isNot(AdIds.androidLive.rewarded));
      }
    });

    test('a release build on Android serves the real units', () {
      final ids = AdIds.forPlatform(android: true, release: true);
      expect(ids.isTest, isFalse);
      expect(ids.appId, AdIds.androidLive.appId);
      expect(ids.banner, AdIds.androidLive.banner);
      expect(ids.interstitial, AdIds.androidLive.interstitial);
      expect(ids.rewarded, AdIds.androidLive.rewarded);
    });

    test('a store with no ids yet falls back to test units', () {
      // iOS has no AdMob app registered. Asking AdMob for PASTE_ID_HERE would
      // fail on every call, so the build serves test units instead.
      expect(AdIds.iosLive.isConfigured, isFalse);
      final ids = AdIds.forPlatform(android: false, release: true);
      expect(ids.isTest, isTrue);
    });

    test('the live Android units are the ones the account was given', () {
      expect(AdIds.androidLive.isConfigured, isTrue);
      expect(AdIds.androidLive.appId, 'ca-app-pub-8244651657160773~9818123144');
      expect(
        AdIds.androidLive.banner,
        'ca-app-pub-8244651657160773/4842902133',
      );
      expect(
        AdIds.androidLive.interstitial,
        'ca-app-pub-8244651657160773/5445537360',
      );
      expect(
        AdIds.androidLive.rewarded,
        'ca-app-pub-8244651657160773/1846922339',
      );
    });
  });

  group('when an interstitial may appear', () {
    test('one on every move to the next level', () async {
      final backend = _FakeAds();
      final ads = await ready(backend);
      var now = DateTime(2026);
      for (var level = 1; level <= 12; level++) {
        // A level takes longer than the guard, so the guard is not what is
        // being measured here.
        now = now.add(AdsController.interstitialGap * 2);
        await ads.onLevelCleared(level, now: now);
      }
      expect(
        backend.interstitialsShown,
        12,
        reason: 'a level change passed without an ad',
      );
    });

    test('one on the way into a run from the menu', () async {
      final backend = _FakeAds();
      final ads = await ready(backend);
      expect(await ads.onGameStart(now: DateTime(2026)), isTrue);
      expect(backend.interstitialsShown, 1);
    });

    test('starting a run does not need any levels cleared first', () async {
      // The level counter and the start of a run are separate events. A fresh
      // install tapping PLAY has cleared nothing, and must still see one.
      final backend = _FakeAds();
      final ads = await ready(backend);
      await ads.onGameStart(now: DateTime(2026));
      expect(backend.interstitialsShown, 1);
    });

    test('not twice inside the gap however many levels are cleared', () async {
      final backend = _FakeAds();
      final ads = await ready(backend);
      final start = DateTime(2026);
      for (var level = 10; level < 30; level++) {
        // Twenty short levels back to back, all within the gap.
        await ads.onLevelCleared(
          level,
          now: start.add(const Duration(seconds: 5)),
        );
      }
      expect(
        backend.interstitialsShown,
        1,
        reason: 'a fast player was shown ads back to back',
      );
    });

    test('quitting to the menu and starting again does not stack two', () async {
      // Clear a level, take the ad, back out to the menu, tap PLAY. Without
      // the guard that is two full screen ads in about four seconds.
      final backend = _FakeAds();
      final ads = await ready(backend);
      final start = DateTime(2026);
      expect(await ads.onLevelCleared(9, now: start), isTrue);
      expect(
        await ads.onGameStart(now: start.add(const Duration(seconds: 4))),
        isFalse,
      );
      expect(backend.interstitialsShown, 1);
    });

    test('nothing shows before the plugin is up', () async {
      final backend = _FakeAds();
      final ads = AdsController(backend: backend, ids: _testIds);
      for (var level = 10; level < 20; level++) {
        await ads.onLevelCleared(level);
      }
      expect(backend.interstitialsShown, 0);
    });

    test('an unsupported platform stays quiet', () async {
      final ads = AdsController(
        backend: const NoAdsBackend(),
        ids: _testIds,
      );
      await ads.init();
      expect(ads.isReady, isFalse);
      expect(ads.canOfferReward, isFalse);
      expect(await ads.onLevelCleared(50), isFalse);
      expect(await ads.showRewarded(), isFalse);
    });
  });

  group('the rewarded ad', () {
    test('pays out only when the player actually watched it', () async {
      final backend = _FakeAds()..rewardEarned = false;
      final ads = await ready(backend);
      expect(ads.canOfferReward, isTrue);
      expect(
        await ads.showRewarded(),
        isFalse,
        reason: 'coins were paid for an ad that was skipped',
      );
      expect(backend.rewardedShown, 1);
    });

    test('pays out when it was watched', () async {
      final backend = _FakeAds();
      final ads = await ready(backend);
      expect(await ads.showRewarded(), isTrue);
    });

    test('is not offered again until another one has loaded', () async {
      final backend = _FakeAds();
      final ads = await ready(backend);
      await ads.showRewarded();
      // The fake reloads instantly. What matters is that the spent one was
      // cleared rather than shown twice.
      expect(backend.rewardedShown, 1);
    });
  });

  test('a backend that throws never reaches the caller', () async {
    final ads = AdsController(backend: _BrokenAds(), ids: _testIds);
    await ads.init();
    expect(ads.isReady, isFalse);
    expect(await ads.onLevelCleared(50), isFalse);
    expect(await ads.showRewarded(), isFalse);
  });
}

class _BrokenAds extends AdsBackend {
  @override
  bool get isSupported => true;

  @override
  Future<void> initialize() async => throw StateError('no ads today');

  @override
  Future<bool> loadInterstitial(String unitId) async =>
      throw StateError('no ads today');

  @override
  Future<bool> showInterstitial() async => throw StateError('no ads today');

  @override
  Future<bool> loadRewarded(String unitId) async =>
      throw StateError('no ads today');

  @override
  Future<bool> showRewarded() async => throw StateError('no ads today');
}
