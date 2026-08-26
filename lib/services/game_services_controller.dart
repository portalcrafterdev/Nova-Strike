import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../levels/difficulty_curve.dart';
import '../levels/level_spec.dart';
import '../state/player_progress.dart';
import 'game_services_backend.dart';
import 'play_ids.dart';

/// Where the player stands with Google Play Games or Apple Game Center.
enum GameServicesStatus {
  /// Neither store is here. Desktop, web, and every test that does not ask for
  /// a platform land on this.
  unsupported,

  /// There is a store, but nobody is signed in.
  signedOut,

  /// The store's own sign in sheet is up.
  signingIn,

  signedIn,

  /// A call came back with an error. [GameServicesController.lastError] says
  /// what it was.
  failed,
}

/// Owns the player's link to Google Play Games and Apple Game Center.
///
/// It is the only thing in the game that talks to either store. Two rules run
/// through all of it. Nothing here may throw, because a store being down or a
/// player being signed out is a normal Tuesday and must never take the game
/// with it. And nothing here may block a screen, because sign in can sit
/// waiting on a sheet the player never dismisses.
///
/// Scores are not pushed by the level code. This listens to [PlayerProgress]
/// and submits when the numbers it cares about actually move, so there is one
/// path to the leaderboards whether a level was finished, a star was improved
/// on a replay, or the player signed in long after earning any of it.
class GameServicesController extends ChangeNotifier {
  GameServicesController({
    this.backend = const StoreGameServices(),
    this.ids = PlayIds.live,
    TargetPlatform? platform,
  }) : _platform = platform ?? defaultTargetPlatform {
    // Settled here rather than left until [init] finishes, because the answer
    // needs nothing outside this process and a screen built on the first frame
    // would otherwise be told there is no store on the phone at all.
    _status = isSupported
        ? GameServicesStatus.signedOut
        : GameServicesStatus.unsupported;
  }

  /// How long any one call is given before it counts as a failure.
  ///
  /// The plugin's signed in check waits on a stream that never completes when
  /// the store is not set up, so without this the first screen would hang on a
  /// future that is never going to arrive.
  static const Duration callTimeout = Duration(seconds: 10);

  /// How long the sign in sheet is given. Longer than the rest, because the
  /// player may be creating an account or choosing between two of them.
  static const Duration signInTimeout = Duration(seconds: 90);

  /// Levels cleared for the long haul badge.
  static const int centurionLevel = 100;

  /// Stars collected for the completionist badge.
  static const int starCollectorStars = 100;

  final GameServicesBackend backend;

  /// The board and badge ids this controller reports to.
  final PlayIds ids;
  final TargetPlatform _platform;

  GameServicesStatus _status = GameServicesStatus.unsupported;
  String? _playerName;
  String? _lastError;
  PlayerProgress? _watched;

  /// The last values pushed, so a notify that only moved coins does not fire
  /// two calls at the store for nothing.
  int _sentLevel = 0;
  int _sentStars = 0;
  final Set<String> _sentBadges = <String>{};

  GameServicesStatus get status => _status;
  String? get playerName => _playerName;
  String? get lastError => _lastError;

  bool get isAndroid => _platform == TargetPlatform.android;

  /// Whether this platform has a store to talk to at all.
  bool get isSupported =>
      _platform == TargetPlatform.android || _platform == TargetPlatform.iOS;

  /// The name of the service on this platform, for anything the player reads.
  String get serviceName => isAndroid ? 'Google Play Games' : 'Game Center';

  bool get isSignedIn => _status == GameServicesStatus.signedIn;

  /// Whether the boards and badges have real ids yet.
  ///
  /// Deliberately separate from [status]. Signing in needs nothing from this
  /// table, so a game that has an account but no boards yet can still show the
  /// player who they are signed in as. Only submission needs the ids, and
  /// submitting to a placeholder would fail once per level, quietly, forever.
  bool get idsConfigured => ids.configuredFor(android: isAndroid);

  /// The only state in which pushing a score is worth the call.
  bool get canSubmit => isSignedIn && idsConfigured;

  /// Works out where things stand without ever putting a sheet in front of the
  /// player. Safe to call before the first frame.
  Future<void> init() async {
    if (!isSupported) {
      _set(GameServicesStatus.unsupported);
      return;
    }
    final signedIn = await _guard(() => backend.isSignedIn(), fallback: false);
    if (signedIn ?? false) {
      await _afterSignIn();
    } else {
      _set(GameServicesStatus.signedOut);
    }
  }

  /// Opens the store's own sign in flow. Returns whether it ended signed in.
  Future<bool> signIn() async {
    if (_status == GameServicesStatus.signingIn) {
      return false;
    }
    if (!isSupported) {
      return false;
    }
    _set(GameServicesStatus.signingIn);
    final ok = await _guard(
      () => backend.signIn(),
      fallback: false,
      timeout: signInTimeout,
    );
    if (ok ?? false) {
      await _afterSignIn();
      return true;
    }
    // Backing out of the sheet leaves the player signed out, not broken, so
    // this only reads as a failure when something actually went wrong.
    final error = _lastError;
    if (error == null) {
      _set(GameServicesStatus.signedOut);
    } else {
      _set(GameServicesStatus.failed, error: error);
    }
    return false;
  }

  Future<void> showLeaderboards({LeaderboardId? board}) async {
    if (!isSignedIn) {
      return;
    }
    await _guard(
      () => backend.showLeaderboards(
        leaderboardId: board == null ? null : _idOfBoard(board),
      ),
      fallback: null,
    );
  }

  Future<void> showAchievements() async {
    if (!isSignedIn) {
      return;
    }
    await _guard(() => backend.showAchievements(), fallback: null);
  }

  /// Follows [progress] and pushes whatever moves. Calling it twice replaces
  /// the first subscription rather than doubling it.
  void watch(PlayerProgress progress) {
    _watched?.removeListener(_onProgressChanged);
    _watched = progress..addListener(_onProgressChanged);
  }

  @override
  void dispose() {
    _watched?.removeListener(_onProgressChanged);
    super.dispose();
  }

  void _onProgressChanged() {
    // Deliberately not awaited. Progress is on disk by the time this runs, and
    // a slow store must never hold up the level complete sheet.
    unawaited(report());
  }

  /// Pushes anything the watched progress has moved past. Public so a test can
  /// drive it without waiting on a notification.
  Future<void> report() async {
    final progress = _watched;
    if (progress == null || !canSubmit) {
      return;
    }

    // The ladder is reported from the medium run, so three settings do not
    // turn one board into three unrelated ones. The number sent is the last
    // level cleared, not the next one unlocked.
    final cleared = progress.highestLevelIn(Difficulty.medium) - 1;
    if (cleared > _sentLevel) {
      _sentLevel = cleared;
      await _submit(ids.highestLevel, cleared);
    }

    final stars = progress.totalStars;
    if (stars > _sentStars) {
      _sentStars = stars;
      await _submit(ids.totalStars, stars);
    }

    for (final badge in earnedBadges(progress)) {
      await _unlock(badge);
    }
  }

  /// Which badges the current save has earned.
  ///
  /// Worked out from the save rather than from the moment a level ends, so a
  /// player who was signed out when they earned one still gets it the first
  /// time they sign in.
  Iterable<AchievementId> earnedBadges(PlayerProgress progress) sync* {
    final cleared = progress.highestLevelIn(Difficulty.medium) - 1;
    if (cleared >= 1) {
      yield ids.firstFlight;
    }
    if (cleared >= Tuning.levelsPerChapter) {
      yield ids.bossSlayer;
    }
    if (cleared >= centurionLevel) {
      yield ids.centurion;
    }
    if (progress.starsData.contains('${Tuning.starsPerLevel}')) {
      yield ids.perfectRun;
    }
    if (progress.totalStars >= starCollectorStars) {
      yield ids.starCollector;
    }
  }

  String _idOfBoard(LeaderboardId board) =>
      isAndroid ? board.android : board.ios;

  Future<void> _submit(LeaderboardId board, int value) async {
    await _guard(
      () => backend.submitScore(
        leaderboardId: _idOfBoard(board),
        value: value,
      ),
      fallback: null,
    );
  }

  Future<void> _unlock(AchievementId badge) async {
    final id = isAndroid ? badge.android : badge.ios;
    if (!_sentBadges.add(id)) {
      return;
    }
    await _guard(() => backend.unlock(achievementId: id), fallback: null);
  }

  Future<void> _afterSignIn() async {
    final name = await _guard(() => backend.playerName(), fallback: null);
    _set(GameServicesStatus.signedIn);
    _playerName = name;
    notifyListeners();
    await report();
  }

  /// Runs one call, swallowing anything it throws and anything it does not
  /// answer in time. Returns [fallback] when it fails.
  Future<T?> _guard<T>(
    Future<T> Function() call, {
    required T? fallback,
    Duration? timeout,
  }) async {
    try {
      final result = await call().timeout(timeout ?? callTimeout);
      _lastError = null;
      return result;
    } on TimeoutException {
      _lastError = '$serviceName did not answer';
      return fallback;
    } catch (error) {
      _lastError = readableError(error);
      return fallback;
    }
  }

  /// Turns a platform exception into something worth showing a player.
  ///
  /// Printed raw, one of these reads as PlatformException(failed_to_authent
  /// icate, , null, null), which tells whoever is holding the phone nothing at
  /// all. Worse, the plugin often leaves the message empty and puts the only
  /// real information in the code, so the code has to be translated rather
  /// than just unwrapped.
  static String readableError(Object error) {
    if (error is PlatformException) {
      final message = error.message?.trim() ?? '';
      if (message.isNotEmpty) {
        return message;
      }
      return meaningOf(error.code);
    }
    final text = error.toString();
    return text.length > 120 ? '${text.substring(0, 120)}...' : text;
  }

  /// Plain language for the codes the plugin actually returns.
  ///
  /// Every one of these is a setup problem rather than something the player
  /// did, so each says what to go and check.
  static String meaningOf(String code) {
    switch (code) {
      case 'failed_to_authenticate':
        return 'The store refused it. The game may not be set up in the '
            'console yet, or the key this build is signed with is not '
            'registered against it.';
      case 'not_authenticated':
        return 'Not signed in.';
      default:
        return 'The store returned $code.';
    }
  }

  void _set(GameServicesStatus status, {String? error}) {
    _status = status;
    if (status != GameServicesStatus.signedIn) {
      _playerName = null;
    }
    _lastError = error;
    notifyListeners();
  }
}
