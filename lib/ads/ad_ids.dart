import 'package:flutter/foundation.dart';

/// The AdMob app and unit ids this game serves.
///
/// Two sets live here and only one is ever used. A debug or profile build gets
/// Google's public test units. A release build gets the real ones.
///
/// That split is not tidiness, it is the whole point. Ads are billed on the
/// belief that a real person chose to look at one, so AdMob watches for traffic
/// that does not fit and suspends accounts that produce it. The surest way to
/// produce it is to run your own game on your own phone and tap your own live
/// banner while checking it looks right, which is exactly what happens during
/// development. Test units render a real ad, load and fail the same way, and
/// pay nothing, so they can be tapped all day.
///
/// The consequence is worth stating plainly: what a debug build shows is a
/// Google test ad, and that is correct. The live ids only appear in a release
/// build.
class AdIds {
  const AdIds({
    required this.appId,
    required this.banner,
    required this.interstitial,
    required this.rewarded,
  });

  /// The app the units belong to. Android also needs this in its manifest and
  /// iOS in its Info.plist, where it is read before any Dart runs.
  final String appId;
  final String banner;
  final String interstitial;
  final String rewarded;

  /// What an id looks like before anyone has been to the AdMob console.
  static const String unset = 'PASTE_ID_HERE';

  /// The real units, from the AdMob account that owns this game.
  ///
  /// One AdMob app covers one store listing, so these are the Android ones.
  /// iOS needs its own app and its own three units created against the iOS
  /// bundle id, and an Android unit will not serve to an iOS build.
  static const AdIds androidLive = AdIds(
    appId: 'ca-app-pub-8244651657160773~9818123144',
    banner: 'ca-app-pub-8244651657160773/4842902133',
    interstitial: 'ca-app-pub-8244651657160773/5445537360',
    rewarded: 'ca-app-pub-8244651657160773/1846922339',
  );

  /// Waiting on an AdMob app registered against the iOS bundle id.
  static const AdIds iosLive = AdIds(
    appId: unset,
    banner: unset,
    interstitial: unset,
    rewarded: unset,
  );

  /// Google's own units, documented for exactly this use and safe to tap.
  static const AdIds androidTest = AdIds(
    appId: 'ca-app-pub-3940256099942544~3347511713',
    banner: 'ca-app-pub-3940256099942544/6300978111',
    interstitial: 'ca-app-pub-3940256099942544/1033173712',
    rewarded: 'ca-app-pub-3940256099942544/5224354917',
  );

  static const AdIds iosTest = AdIds(
    appId: 'ca-app-pub-3940256099942544~1458002511',
    banner: 'ca-app-pub-3940256099942544/2934735716',
    interstitial: 'ca-app-pub-3940256099942544/4411468910',
    rewarded: 'ca-app-pub-3940256099942544/1712485313',
  );

  /// The set this build should use.
  ///
  /// [release] is passed in rather than read here so a test can ask for either
  /// set without pretending to be a release build.
  static AdIds forPlatform({required bool android, required bool release}) {
    if (!release) {
      return android ? androidTest : iosTest;
    }
    final live = android ? androidLive : iosLive;
    // A store this game has not been registered with yet falls back to test
    // units rather than asking AdMob for an id it has never heard of. The
    // request would fail on every single call, and a player would see a hole
    // in the layout where an ad was meant to be.
    return live.isConfigured ? live : (android ? androidTest : iosTest);
  }

  /// The set this build is actually running, judged from the running binary.
  static AdIds get live => forPlatform(
    android: defaultTargetPlatform == TargetPlatform.android,
    release: kReleaseMode,
  );

  /// Whether every id here has been filled in.
  bool get isConfigured =>
      [appId, banner, interstitial, rewarded].every(
        (id) => id.isNotEmpty && id != unset,
      );

  /// Whether these are Google's test units rather than someone's real ones.
  ///
  /// Shown to nobody, but a test asserts on it, because the one failure that
  /// must never ship is a debug build wired to the live account.
  bool get isTest => appId == androidTest.appId || appId == iosTest.appId;
}
