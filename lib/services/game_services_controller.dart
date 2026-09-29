import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../levels/level_spec.dart';
import '../state/achievement_catalog.dart';
import '../state/player_progress.dart';
import '../state/save_service.dart';
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
    this.save,
    PlayIds? ids,
    TargetPlatform? platform,
  }) : ids = ids ?? PlayIds.live,
       _platform = platform ?? defaultTargetPlatform {
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

  final GameServicesBackend backend;

  /// Where the disconnected choice is written down.
  ///
  /// Optional, because most of this class has nothing to remember between
  /// runs and every test of the rest would otherwise have to build a save.
  /// Without one, a disconnect lasts until the game is closed.
  final SaveService? save;

  /// The board and badge ids this controller reports to.
  final PlayIds ids;
  final TargetPlatform _platform;

  GameServicesStatus _status = GameServicesStatus.unsupported;
  String? _playerName;
  String? _lastError;
  PlayerProgress? _watched;
  bool _disconnected = false;

  /// The last values pushed, so a notify that only moved coins does not fire
  /// two calls at the store for nothing.
  int _sentLevel = 0;
  int _sentStars = 0;
  final Set<String> _sentBadges = <String>{};
  final Map<String, int> _sentSteps = <String, int>{};

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

  /// Whether the player has told the game to stop using the store.
  ///
  /// Distinct from being signed out. Signed out is where everybody starts and
  /// where a cancelled sign in leaves you, and the game is free to connect on
  /// the next launch. This is a decision, and it is honoured until the player
  /// signs in again on purpose.
  bool get isDisconnected => _disconnected;

  /// Whether the boards and badges have real ids yet.
  ///
  /// Deliberately separate from [status]. Signing in needs nothing from this
  /// table, so a game that has an account but no boards yet can still show the
  /// player who they are signed in as. Only submission needs the ids, and
  /// submitting to a placeholder would fail once per level, quietly, forever.
  bool get idsConfigured => ids.configuredFor(android: isAndroid);

  /// Whether the badges have real ids. Judged apart from the boards, because
  /// the two are set up in the console as separate jobs and whichever is ready
  /// first should start working.
  bool get badgesConfigured =>
      ids.achievementsConfiguredFor(android: isAndroid);

  bool get boardsConfigured =>
      ids.leaderboardsConfiguredFor(android: isAndroid);

  /// Whether one board exists in the console yet.
  bool hasBoard(LeaderboardId board) => PlayIds.ready(_idOfBoard(board));

  bool get canSubmitBadges => isSignedIn && badgesConfigured;

  bool get canSubmitScores => isSignedIn && boardsConfigured;

  /// The only state in which pushing a score is worth the call.
  bool get canSubmit => isSignedIn && idsConfigured;

  /// Works out where things stand without ever putting a sheet in front of the
  /// player. Safe to call before the first frame.
  Future<void> init() async {
    if (!isSupported) {
      _set(GameServicesStatus.unsupported);
      return;
    }
    // Checked before anything reaches the store. Play Games version 2 signs
    // the player back in by itself, so asking it first and then deciding would
    // mean a disconnected player is connected again for as long as it takes to
    // read a preference, which is long enough to push a score.
    _disconnected = save?.loadStoreDisconnected() ?? false;
    if (_disconnected) {
      _set(GameServicesStatus.signedOut);
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

  /// Stops the game using the store, and remembers that it was asked to.
  ///
  /// This is as far as a game is allowed to go. Play Games Services version 2
  /// has no sign out call at all, and Game Center's account belongs to the
  /// system rather than to any one game, so neither store can be made to
  /// forget the player from in here. What this can do, and does, is stop the
  /// game connecting: nothing is submitted, no name is shown, and the next
  /// launch does not reach for the store. Signing the Google account itself
  /// out is done in the Play Games app, and the wording the player is shown
  /// before this runs says so rather than promising something it cannot do.
  ///
  /// Everything already sent stays sent. There is no call to take a score off
  /// a leaderboard, and a badge cannot be locked again.
  Future<void> disconnect() async {
    if (!isSupported) {
      return;
    }
    _disconnected = true;
    _playerName = null;
    _lastError = null;
    // The high water marks go with it. They exist to stop the same number
    // being sent twice in one session, and holding them across a disconnect
    // would mean everything earned while away is silently never reported
    // after signing back in.
    _sentLevel = 0;
    _sentStars = 0;
    _sentBadges.clear();
    _sentSteps.clear();
    _set(GameServicesStatus.signedOut);
    await save?.saveStoreDisconnected(true);
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
    if (progress == null || !isSignedIn) {
      return;
    }

    // Each board and each badge is judged on its own id. Nothing here is
    // gated on the whole table being filled in, because the console is worked
    // through one item at a time and whatever already has an id should be
    // working while the rest is still being created.

    // The ladder is reported from the medium run, so three settings do not
    // turn one board into three unrelated ones. The number sent is the last
    // level cleared, not the next one unlocked.
    final cleared = progress.highestLevelIn(Difficulty.medium) - 1;
    if (cleared > _sentLevel && await _submit(ids.highestLevel, cleared)) {
      _sentLevel = cleared;
    }

    // Stars across every setting, matching what the badges count. Reading the
    // current setting alone made the board and the achievement bar disagree
    // the moment a player switched to hard.
    final stars = progress.starsEverywhere;
    if (stars > _sentStars && await _submit(ids.totalStars, stars)) {
      _sentStars = stars;
    }

    await _reportBadges(progress);
  }

  /// Pushes every badge in the catalogue that has moved.
  ///
  /// Counting badges report an absolute step count rather than a delta,
  /// because the count lives on disk and a delta would be sent again every
  /// time the player signed in.
  Future<void> _reportBadges(PlayerProgress progress) async {
    for (final badge in AchievementCatalog.all) {
      final id = ids.achievementIdFor(badge.id, android: isAndroid);
      if (!PlayIds.ready(id)) {
        continue;
      }
      if (badge.isIncremental) {
        final steps = badge.progressIn(progress);
        if (steps <= (_sentSteps[badge.id] ?? 0)) {
          continue;
        }
        _sentSteps[badge.id] = steps;
        await _guard(
          () => backend.setSteps(achievementId: id, steps: steps),
          fallback: null,
        );
      } else if (badge.earnedBy(progress)) {
        if (!_sentBadges.add(id)) {
          continue;
        }
        await _guard(() => backend.unlock(achievementId: id), fallback: null);
      }
    }
  }

  /// Which badges the current save has earned.
  ///
  /// Worked out from the save rather than from the moment a level ends, so a
  /// player who was signed out when they earned one still gets it the first
  /// time they sign in.
  List<AchievementDef> earnedBadges(PlayerProgress progress) =>
      AchievementCatalog.earnedIn(progress);

  String _idOfBoard(LeaderboardId board) =>
      isAndroid ? board.android : board.ios;

  /// Pushes one score, reporting whether it actually landed.
  ///
  /// False for a board with no id, and false for a call that threw or timed
  /// out. The caller leaves its marker alone in both cases, so a score lost to
  /// a dropped connection is offered again on the next level rather than being
  /// counted as sent and never mentioned to the store again.
  Future<bool> _submit(LeaderboardId board, int value) async {
    final id = _idOfBoard(board);
    if (!PlayIds.ready(id)) {
      return false;
    }
    final sent = await _guard(() async {
      await backend.submitScore(leaderboardId: id, value: value);
      return true;
    }, fallback: false);
    return sent ?? false;
  }

  Future<void> _afterSignIn() async {
    final name = await _guard(() => backend.playerName(), fallback: null);
    _set(GameServicesStatus.signedIn);
    _playerName = name;
    notifyListeners();
    // Signing in on purpose revokes an earlier disconnect. Cleared here rather
    // than when the button is pressed, so backing out of the store's sheet
    // leaves the earlier choice standing instead of quietly undoing it.
    if (_disconnected) {
      _disconnected = false;
      await save?.saveStoreDisconnected(false);
    }
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
