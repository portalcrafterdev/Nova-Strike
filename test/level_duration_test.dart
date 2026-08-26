// Every level has to be worth loading a screen for.
//
// Measured before the floor existed, a normal level was over in nine to
// fourteen seconds and a gate level in eleven, for a player who cleared each
// wave the moment it arrived. These run the real loop with exactly that
// player: everything dies on the frame it mounts. Whatever they measure is the
// shortest the level can possibly be, because no upgrade kills faster than
// instantly.
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/game/components/boss.dart';
import 'package:novastrike/game/components/enemy_ship.dart';
import 'package:novastrike/game/nova_game.dart';
import 'package:novastrike/levels/difficulty_curve.dart';
import 'package:novastrike/levels/level_spec.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nova_game_test.dart' show buildGame, levelOfKind;

/// The requirement, written out rather than read from the tuning it checks.
///
/// Asserting against [RunnerTuning.minLevelDuration] would have made these
/// tests agree with whatever that constant said, including zero.
const double requiredSeconds = 30.0;

/// Runs [game] with a player who kills everything on arrival, and returns the
/// seconds of game time it took to stop being playable.
///
/// [giveUpAfter] is a runaway guard, not an expectation. A level that reaches
/// it has failed the test either way.
Future<double> shortestRun(NovaGame game, {double giveUpAfter = 120}) async {
  const step = 1 / 60;
  var elapsed = 0.0;
  while (game.status == GameStatus.playing && elapsed < giveUpAfter) {
    for (final enemy in List.of(game.world.children.query<EnemyShip>())) {
      enemy.removeFromParent();
    }
    for (final boss in List.of(game.world.children.query<Boss>())) {
      boss.takeDamage(1000000, at: boss.position.clone());
    }
    game.update(step);
    await Future<void>.delayed(Duration.zero);
    elapsed += step;
  }
  return elapsed;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  group('no level is over before it has been a level', () {
    // A spread across the hand tuned opening, the generated middle, an elite,
    // and the first boss. The tutorial levels are in here on purpose: they are
    // the shortest levels in the game and the easiest ones to leave behind.
    for (final level in const [1, 2, 5, 8, 12, 14, 15]) {
      testWithGame<NovaGame>('level $level', () => buildGame(level), (
        game,
      ) async {
        await game.ready();
        final seconds = await shortestRun(game);

        expect(
          game.status,
          GameStatus.complete,
          reason: 'level $level never finished',
        );
        expect(
          seconds,
          greaterThanOrEqualTo(requiredSeconds),
          reason:
              'level $level (${game.spec.kind.name}) is over in '
              '${seconds.toStringAsFixed(1)}s',
        );
      });
    }

    // The objective kinds each end on something other than a wave list: a
    // clock, a freighter crossing, a ring. Each one needs the floor for its
    // own reason, so each one is measured rather than assumed.
    for (final kind in const [
      LevelKind.survival,
      LevelKind.escort,
      LevelKind.gate,
    ]) {
      testWithGame<NovaGame>(
        'a ${kind.name} level',
        () => buildGame(levelOfKind(kind)),
        (game) async {
          await game.ready();
          final seconds = await shortestRun(game);

          expect(game.spec.kind, kind);
          expect(
            game.status,
            GameStatus.complete,
            reason: 'a ${kind.name} level never finished',
          );
          expect(
            seconds,
            greaterThanOrEqualTo(requiredSeconds),
            reason:
                'a ${kind.name} level is over in '
                '${seconds.toStringAsFixed(1)}s',
          );
        },
      );
    }
  });

  testWithGame<NovaGame>(
    'a level that runs long stops showing a total it cannot reach',
    () => buildGame(1),
    (game) async {
      // Level 1 is scripted for a single wave and now runs far past it. While
      // the display still had a denominator, that came out as wave 6 of 1.
      await game.ready();
      await shortestRun(game);

      final wave = game.waveNotifier.value;
      expect(
        wave.current,
        greaterThan(wave.total),
        reason: 'level 1 no longer runs past its scripted wave list',
      );
      expect(wave.total, game.spec.waves.length);
    },
  );

  testWithGame<NovaGame>(
    'the extra waves do not hand out extra power ups',
    () => buildGame(levelOfKind(LevelKind.elite)),
    (game) async {
      // An elite level promises one gem, from the last wave. Reusing that wave
      // to fill the clock would promise one per lap.
      await game.ready();
      final scripted = game.spec.waves.where((w) => w.dropsPowerUp).length;
      expect(scripted, 1, reason: 'an elite level no longer guarantees a gem');
    },
  );
}
