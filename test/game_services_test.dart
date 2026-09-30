import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/services/game_services_backend.dart';
import 'package:novastrike/services/game_services_controller.dart';
import 'package:novastrike/services/play_ids.dart';
import 'package:novastrike/state/achievement_catalog.dart';
import 'package:novastrike/state/player_progress.dart';
import 'package:novastrike/state/save_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A filled in id table, standing in for one pasted out of a console.
///
/// Built from the catalogue so it cannot drift out of step with it: a badge
/// added there is filled in here without another edit.
final PlayIds _filled = PlayIds(
  highestLevel: const LeaderboardId(
    name: 'Levels Cleared',
    android: 'a_level',
    ios: 'i_level',
  ),
  totalStars: const LeaderboardId(
    name: 'Stars Collected',
    android: 'a_stars',
    ios: 'i_stars',
  ),
  achievementIds: {
    for (final badge in AchievementCatalog.all)
      badge.id: AchievementId(
        android: 'a_${badge.id}',
        ios: 'i_${badge.id}',
      ),
  },
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
  final Map<String, int> steps = <String, int>{};

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
  Future<void> setSteps({
    required String achievementId,
    required int steps,
  }) async {
    await _answer('setSteps:$achievementId', null);
    this.steps[achievementId] = steps;
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
  PlayIds? ids,
  SaveService? save,
  TargetPlatform platform = TargetPlatform.android,
}) {
  return GameServicesController(
    backend: store,
    ids: ids ?? _filled,
    save: save,
    platform: platform,
  );
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

  test('a part built console reports everything that has an id', () async {
    // Boards and badges are created in the console one at a time, so some
    // done and some not is the normal middle of the job rather than an edge
    // case. Anything gated on the whole table being filled would report
    // nothing until the very last id was pasted in.
    final store = FakeStore();
    final progress = await _progress();
    final games = _controller(store, ids: PlayIds.live)..watch(progress);
    expect(await games.signIn(), isTrue);

    await progress.completeLevel(level: 1, stars: 3, coinsEarned: 0);
    await games.report();

    final levels = PlayIds.live.highestLevel.android;
    expect(
      store.scores.keys,
      contains(levels),
      reason: 'the board that has an id did not get its score',
    );
    expect(
      store.scores.keys,
      isNot(contains(PlayIds.unset)),
      reason: 'a score went to a board called PASTE_ID_HERE',
    );
    expect(
      store.unlocked,
      isNotEmpty,
      reason: 'the imported badges are sitting unused',
    );
  });

  test('a board with no id is left alone', () async {
    final store = FakeStore();
    final progress = await _progress();
    final noStars = PlayIds(
      highestLevel: _filled.highestLevel,
      totalStars: const LeaderboardId(
        name: 'Stars Collected',
        android: PlayIds.unset,
        ios: PlayIds.unset,
      ),
      achievementIds: _filled.achievementIds,
    );
    final games = _controller(store, ids: noStars)..watch(progress);
    await games.signIn();

    await progress.completeLevel(level: 1, stars: 3, coinsEarned: 0);
    await games.report();

    expect(store.scores.keys, contains('a_level'));
    expect(
      store.scores.keys,
      isNot(contains(PlayIds.unset)),
      reason: 'a score was pushed at a board called PASTE_ID_HERE',
    );
  });

  test('a score lost to a dropped connection is sent again later', () async {
    // The marker that stops the same score being pushed twice must not move
    // for a submission that never landed. Otherwise one failed call means the
    // store never hears that number again, and the board sits behind until
    // the player happens to beat it.
    final store = FakeStore();
    final progress = await _progress();
    final games = _controller(store)..watch(progress);
    // Signed in first, then the connection goes. Setting it to throw up front
    // would only fail the sign in, and report would never run at all.
    await games.signIn();
    store.throws = PlatformException(code: 'network');

    await progress.completeLevel(level: 1, stars: 3, coinsEarned: 0);
    await games.report();
    expect(store.scores, isEmpty, reason: 'the store was down');

    // The connection comes back. Nothing about the save has changed, so the
    // only reason to call again is that the first attempt was not counted.
    store.throws = null;
    await games.report();
    expect(
      store.scores['a_level'],
      1,
      reason: 'a score lost to one failed call is never offered again',
    );
    expect(store.scores['a_stars'], 3);
  });

  test('the shipped Android table is complete and has no duplicates', () {
    // Two failures this catches, both of which look like nothing at runtime.
    // A slug typed wrong reads as a missing id, so that one badge never
    // unlocks for anybody while the rest work. And a copied and pasted id
    // sends two different things to the same place, so one of them silently
    // never gets its own entry.
    final seen = <String, String>{};

    for (final board in PlayIds.live.leaderboards) {
      expect(
        PlayIds.ready(board.android),
        isTrue,
        reason: '${board.name} has no Android id',
      );
      expect(
        seen.containsKey(board.android),
        isFalse,
        reason: '${board.name} shares an id with ${seen[board.android]}',
      );
      seen[board.android] = board.name;
    }

    for (final badge in AchievementCatalog.all) {
      final id = PlayIds.live.achievementIdFor(badge.id, android: true);
      expect(
        PlayIds.ready(id),
        isTrue,
        reason: '${badge.id} has no Android id, so it can never unlock',
      );
      expect(
        seen.containsKey(id),
        isFalse,
        reason: '${badge.id} shares an id with ${seen[id]}',
      );
      seen[id] = badge.id;
    }

    expect(
      PlayIds.androidAchievements.keys.toSet(),
      AchievementCatalog.all.map((b) => b.id).toSet(),
      reason: 'the id table and the catalogue name different badges',
    );
    expect(
      PlayIds.live.configuredFor(android: true),
      isTrue,
      reason: 'the Android side is not fully wired up',
    );
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

    expect(store.unlocked, contains('a_first_flight'));
    expect(store.unlocked, contains('a_chapter_closed'));
    expect(store.unlocked, contains('a_three_star_pilot'));
    // A hundred levels and a hundred stars are still a long way off.
    expect(store.unlocked, isNot(contains('a_centurion')));
    expect(store.unlocked, isNot(contains('a_star_hoarder')));
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
      store.unlocked.where((id) => id == 'a_first_flight').length,
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
    expect(store.unlocked, contains('i_first_flight'));
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

  test('disconnecting stops anything else being sent', () async {
    final store = FakeStore();
    final progress = await _progress();
    final games = _controller(store)..watch(progress);
    expect(await games.signIn(), isTrue);
    expect(games.canSubmit, isTrue);

    await games.disconnect();

    expect(games.isDisconnected, isTrue);
    expect(games.isSignedIn, isFalse);
    expect(games.status, GameServicesStatus.signedOut);
    expect(games.playerName, isNull);
    expect(games.canSubmit, isFalse);

    store.calls.clear();
    await progress.completeLevel(level: 4, stars: 3, coinsEarned: 0);
    await games.report();
    expect(
      store.calls,
      isEmpty,
      reason: 'it kept reporting after being disconnected',
    );
  });

  test('a disconnect survives a restart', () async {
    // The point of the whole feature. Play Games Services version 2 signs the
    // player back in by itself on launch and gives a game no way to sign them
    // out, so a disconnect held only in memory would last until the app was
    // closed and then quietly undo itself. Nothing else here would notice:
    // the player would simply find themselves connected again.
    final save = SaveService();
    await save.init();

    final first = _controller(FakeStore()..signedIn = true, save: save);
    await first.init();
    expect(first.isSignedIn, isTrue);
    await first.disconnect();

    // A new controller over the same save, which is what the next launch is.
    // The store still says the player is signed in, as it will.
    final store = FakeStore()..signedIn = true;
    final second = _controller(store, save: save);
    await second.init();

    expect(second.isDisconnected, isTrue);
    expect(second.status, GameServicesStatus.signedOut);
    expect(
      store.calls,
      isEmpty,
      reason: 'it reached for the store before checking it was allowed to',
    );
  });

  test('signing in again reconnects and says where the player stands', () async {
    final save = SaveService();
    await save.init();
    final progress = await _progress();
    final store = FakeStore();
    final games = _controller(store, save: save)..watch(progress);

    expect(await games.signIn(), isTrue);
    await progress.completeLevel(level: 4, stars: 3, coinsEarned: 0);
    await games.report();
    expect(store.scores['a_level'], 4);

    await games.disconnect();
    store.scores.clear();

    // Nothing at all happens while away, so the only thing that could make
    // the board move on reconnecting is the reconnection itself.
    expect(await games.signIn(), isTrue);
    expect(games.isDisconnected, isFalse);
    expect(save.loadStoreDisconnected(), isFalse);

    // The number goes up again even though it has not changed since this
    // controller last sent it. The markers that stop a number being sent
    // twice are only true of the connection they were built against, and the
    // account on the other end of this one may not be the account that got
    // the first submission. Holding them across a disconnect would mean a
    // player who reconnects on a different account never appears on the board
    // at all until they happen to clear another level.
    expect(
      store.scores['a_level'],
      4,
      reason: 'reconnecting left the board holding nothing',
    );
  });

  test('backing out of the sheet leaves the disconnect standing', () async {
    // Tapping sign in is not the same as signing in. If the store's own sheet
    // is dismissed, the player is exactly where they were, and treating the
    // tap alone as a change of mind would reconnect them on the next launch
    // without them ever having agreed to it.
    final save = SaveService();
    await save.init();
    final store = FakeStore();
    final games = _controller(store, save: save);

    expect(await games.signIn(), isTrue);
    await games.disconnect();

    store.signInSucceeds = false;
    expect(await games.signIn(), isFalse);

    expect(games.isDisconnected, isTrue);
    expect(save.loadStoreDisconnected(), isTrue);
  });
}
