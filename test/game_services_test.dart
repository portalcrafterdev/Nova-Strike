import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/services/game_services_backend.dart';
import 'package:novastrike/services/game_services_controller.dart';
import 'package:novastrike/services/play_ids.dart';
import 'package:novastrike/state/player_progress.dart';
import 'package:novastrike/state/save_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A filled in id table, standing in for one pasted out of a console.
const PlayIds _filled = PlayIds(
  highestLevel: LeaderboardId(android: 'a_level', ios: 'i_level'),
  totalStars: LeaderboardId(android: 'a_stars', ios: 'i_stars'),
  firstFlight: AchievementId(android: 'a_first', ios: 'i_first'),
  bossSlayer: AchievementId(android: 'a_boss', ios: 'i_boss'),
  perfectRun: AchievementId(android: 'a_perfect', ios: 'i_perfect'),
  centurion: AchievementId(android: 'a_100', ios: 'i_100'),
  starCollector: AchievementId(android: 'a_starcol', ios: 'i_starcol'),
);

/// A store that records what it was asked to do and answers however the test
/// tells it to.
class FakeStore implements GameServicesBackend {
  bool signedIn = false;
  bool signInSucceeds = true;
  Object? throws;
  bool hangs = false;

  final List<String> calls = <String>[];
  final Map<String, int> scores = <String, int>{};
  final List<String> unlocked = <String>[];

  Future<T> _answer<T>(String call, T value) async {
    calls.add(call);
    if (hangs) {
      // Never completes, which is what a store that has gone quiet looks like.
      return Completer<T>().future;
    }
    final error = throws;
    if (error != null) {
      throw error;
    }
    return value;
  }

  @override
  Future<bool> isSignedIn() => _answer('isSignedIn', signedIn);

  @override
  Future<bool> signIn() async {
    final ok = await _answer('signIn', signInSucceeds);
    signedIn = ok;
    return ok;
  }

  @override
  Future<String?> playerName() => _answer('playerName', 'Ace');

  @override
  Future<void> submitScore({
    required String leaderboardId,
    required int value,
  }) async {
    await _answer('submitScore:$leaderboardId', null);
    scores[leaderboardId] = value;
  }

  @override
  Future<void> unlock({required String achievementId}) async {
    await _answer('unlock:$achievementId', null);
    unlocked.add(achievementId);
  }

  @override
  Future<void> showLeaderboards({String? leaderboardId}) =>
      _answer('showLeaderboards:${leaderboardId ?? 'all'}', null);

  @override
  Future<void> showAchievements() => _answer('showAchievements', null);
}

Future<PlayerProgress> _progress() async {
  final save = SaveService();
  await save.init();
  return PlayerProgress(save)..load();
}

GameServicesController _controller(
  FakeStore store, {
  PlayIds ids = _filled,
  TargetPlatform platform = TargetPlatform.android,
}) {
  return GameServicesController(backend: store, ids: ids, platform: platform);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('a platform with no store never calls one', () async {
    final store = FakeStore();
    final games = _controller(store, platform: TargetPlatform.windows);
    await games.init();

    expect(games.status, GameServicesStatus.unsupported);
    expect(games.isSupported, isFalse);
    expect(store.calls, isEmpty, reason: 'it reached for a store that is not there');
  });

  test('placeholder ids stop scores leaving the phone but not sign in',
      () async {
    // This is the state the game ships in until someone has been to the Play
    // Console. Signing in needs none of these ids, so it stays on offer, but
    // a score pushed at a board called PASTE_ID_HERE would fail once per
    // level, quietly, forever.
    final store = FakeStore();
    final progress = await _progress();
    final games = _controller(store, ids: PlayIds.live)..watch(progress);

    expect(games.idsConfigured, isFalse);
    expect(await games.signIn(), isTrue);
    expect(games.status, GameServicesStatus.signedIn);

    await progress.completeLevel(level: 1, stars: 3, coinsEarned: 0);
    await games.report();
    expect(store.scores, isEmpty, reason: 'it submitted to a placeholder id');
    expect(store.unlocked, isEmpty);
  });

  test('the shipped table is not accidentally half filled', () {
    // A table with some real ids and some placeholders would submit a few
    // scores and silently fail the rest. Either everything is set up or
    // nothing is.
    final android = PlayIds.live.configuredFor(android: true);
    final ios = PlayIds.live.configuredFor(android: false);
    for (final board in PlayIds.live.leaderboards) {
      expect(
        board.android == PlayIds.unset,
        !android,
        reason: 'one leaderboard disagrees with the rest of the Android table',
      );
      expect(board.ios == PlayIds.unset, !ios);
    }
    for (final badge in PlayIds.live.achievements) {
      expect(badge.android == PlayIds.unset, !android);
      expect(badge.ios == PlayIds.unset, !ios);
    }
  });

  test('signing in picks up the player name', () async {
    final store = FakeStore();
    final games = _controller(store);
    await games.init();
    expect(games.status, GameServicesStatus.signedOut);

    expect(await games.signIn(), isTrue);
    expect(games.status, GameServicesStatus.signedIn);
    expect(games.playerName, 'Ace');
  });

  test('backing out of the sign in sheet is not an error', () async {
    final store = FakeStore()..signInSucceeds = false;
    final games = _controller(store);
    await games.init();

    expect(await games.signIn(), isFalse);
    expect(games.status, GameServicesStatus.signedOut);
    expect(games.lastError, isNull);
  });

  test('a store that throws leaves the game running and says why', () async {
    final store = FakeStore()
      ..throws = PlatformException(
        code: '6',
        message: 'Sign in failed. Check your SHA-1.',
      );
    final games = _controller(store);

    await games.init();
    expect(games.status, GameServicesStatus.signedOut);

    expect(await games.signIn(), isFalse);
    expect(games.status, GameServicesStatus.failed);
    expect(
      games.lastError,
      contains('Check your SHA-1'),
      reason: 'the player is shown a raw exception dump',
    );
  });

  test('an exception with no message still says something useful', () async {
    // This is the one the plugin actually throws when a game has not been set
    // up in the console. It carries an empty message, so anything that only
    // unwraps the message shows the player
    // PlatformException(failed_to_authenticate, , null, null).
    final store = FakeStore()
      ..throws = PlatformException(code: 'failed_to_authenticate', message: '');
    final games = _controller(store);
    await games.signIn();

    expect(games.status, GameServicesStatus.failed);
    expect(games.lastError, isNot(contains('PlatformException')));
    expect(games.lastError, isNot(contains('null')));
    expect(games.lastError, contains('console'));
  });

  test('a store that never answers does not hang the game', () {
    fakeAsync((async) {
      final store = FakeStore()..hangs = true;
      final games = _controller(store);

      var settled = false;
      games.init().then((_) => settled = true);
      async.elapse(GameServicesController.callTimeout * 2);

      expect(settled, isTrue, reason: 'init is still waiting on the store');
      expect(games.status, GameServicesStatus.signedOut);
    });
  });

  test('nothing is submitted while signed out', () async {
    final store = FakeStore();
    final games = _controller(store)..watch(await _progress());
    await games.init();
    await games.report();

    expect(store.scores, isEmpty);
    expect(store.unlocked, isEmpty);
  });

  test('progress is submitted once, and again only when it moves', () async {
    final store = FakeStore();
    final progress = await _progress();
    final games = _controller(store)..watch(progress);
    await games.signIn();

    // Nothing cleared yet, so nothing to boast about.
    expect(store.scores, isEmpty);

    await progress.completeLevel(level: 1, stars: 2, coinsEarned: 10);
    await games.report();
    expect(store.scores['a_level'], 1);
    expect(store.scores['a_stars'], 2);

    // A second report with nothing new must not fire a single call.
    final before = store.calls.length;
    await games.report();
    expect(store.calls.length, before, reason: 'it resubmits an unchanged score');

    await progress.completeLevel(level: 2, stars: 3, coinsEarned: 10);
    await games.report();
    expect(store.scores['a_level'], 2);
    expect(store.scores['a_stars'], 5);
  });

  test('badges are worked out from the save, not from the moment earned',
      () async {
    // A player who cleared fifteen levels while signed out should collect the
    // badges the first time they sign in, not never.
    final store = FakeStore();
    final progress = await _progress();
    for (var level = 1; level <= 15; level++) {
      await progress.completeLevel(level: level, stars: 3, coinsEarned: 0);
    }

    final games = _controller(store)..watch(progress);
    await games.signIn();

    expect(store.unlocked, contains('a_first'));
    expect(store.unlocked, contains('a_boss'));
    expect(store.unlocked, contains('a_perfect'));
    // A hundred levels and a hundred stars are still a long way off.
    expect(store.unlocked, isNot(contains('a_100')));
    expect(store.unlocked, isNot(contains('a_starcol')));
  });

  test('a badge is only ever unlocked once', () async {
    final store = FakeStore();
    final progress = await _progress();
    final games = _controller(store)..watch(progress);
    await games.signIn();

    await progress.completeLevel(level: 1, stars: 1, coinsEarned: 0);
    await games.report();
    await games.report();
    await games.report();

    expect(
      store.unlocked.where((id) => id == 'a_first').length,
      1,
      reason: 'the same badge is pushed on every save',
    );
  });

  test('iOS reads the iOS column', () async {
    final store = FakeStore();
    final progress = await _progress();
    final games = _controller(store, platform: TargetPlatform.iOS)
      ..watch(progress);
    await games.signIn();
    await progress.completeLevel(level: 1, stars: 1, coinsEarned: 0);
    await games.report();

    expect(games.serviceName, 'Game Center');
    expect(store.scores.keys, contains('i_level'));
    expect(store.unlocked, contains('i_first'));
  });

  test('the sheets only open when there is something behind them', () async {
    final store = FakeStore();
    final games = _controller(store);
    await games.init();

    await games.showLeaderboards();
    await games.showAchievements();
    expect(
      store.calls.where((c) => c.startsWith('show')),
      isEmpty,
      reason: 'a signed out player was sent to an empty sheet',
    );

    await games.signIn();
    await games.showLeaderboards(board: _filled.totalStars);
    await games.showAchievements();
    expect(store.calls, contains('showLeaderboards:a_stars'));
    expect(store.calls, contains('showAchievements'));
  });
}
