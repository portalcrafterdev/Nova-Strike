// How a chapter introduces the enemy it unlocks.
//
// Level 16 opens chapter 2, which unlocks the darter and the three way spread.
// The generator was free to fill every wave with both and then add a modifier,
// and it did: two darter waves, both firing spreads, with swarm on top. On easy
// it put an average of 8 enemy bullets in the air against 3.1 on the elite
// level before it and 0.9 on the boss. The first level a player meets a new
// enemy on was the hardest level in the chapter.
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/audio/audio_controller.dart';
import 'package:novastrike/game/components/bullet.dart';
import 'package:novastrike/game/nova_game.dart';
import 'package:novastrike/levels/enemy_catalog.dart';
import 'package:novastrike/levels/difficulty_curve.dart';
import 'package:novastrike/levels/level_generator.dart';
import 'package:novastrike/levels/level_spec.dart';
import 'package:novastrike/state/player_progress.dart';
import 'package:novastrike/state/save_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mean enemy bullets in the air on level 14 easy, the elite level directly
/// before the one that introduces the darter.
///
/// A recorded measurement rather than a live one. Only the game that
/// testWithGame builds is ever driven far enough to reach playing status, so a
/// second level cannot be measured alongside the first in the same test. If
/// level 14 is ever retuned this needs taking again, and the comment above the
/// file says how.
const double elitePressureBefore = 3.1;

/// A game sitting on [level] at [difficulty], with the overlays stubbed.
NovaGame gameAt(int level, Difficulty difficulty) {
  final save = SaveService();
  final game = NovaGame(
    audio: AudioController(save),
    progress: PlayerProgress(save),
    levelNumber: level,
  );
  for (final name in const [
    NovaGame.hudOverlay,
    NovaGame.pauseOverlay,
    NovaGame.gameOverOverlay,
    NovaGame.levelCompleteOverlay,
  ]) {
    game.overlays.addEntry(name, (_, _) => const SizedBox.shrink());
  }
  return game;
}

/// Average enemy bullets in the air over [seconds] of the level.
///
/// The player is left alone rather than driven, so this measures what the
/// level throws rather than how well anyone dodges it.
Future<double> meanEnemyFire(NovaGame game, {double seconds = 40}) async {
  const step = 1 / 60;
  var total = 0.0;
  var samples = 0;
  for (var i = 0; i < seconds * 60; i++) {
    game.update(step);
    await Future<void>.delayed(Duration.zero);
    if (i % 6 == 0) {
      total += game.world.children
          .query<Bullet>()
          .where((b) => b.owner == BulletOwner.enemy && b.isMounted)
          .length;
      samples++;
    }
    if (game.status != GameStatus.playing) {
      break;
    }
  }
  return samples == 0 ? 0 : total / samples;
}

/// Every level that opens a chapter which unlocks an enemy family.
List<int> debutLevels() {
  final levels = <int>[];
  for (var chapter = 2; chapter <= Tuning.totalChapters; chapter++) {
    if (EnemyCatalog.newIn(chapter).isNotEmpty) {
      levels.add((chapter - 1) * Tuning.levelsPerChapter + 1);
    }
  }
  return levels;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  test('the schedule still introduces enemies after chapter one', () {
    // If this ever empties, every test below passes by doing nothing.
    expect(debutLevels(), isNotEmpty);
    expect(debutLevels().first, 16);
  });

  group('a level that introduces an enemy', () {
    for (final level in debutLevels()) {
      final chapter = Tuning.chapterOf(level);
      final fresh = EnemyCatalog.newIn(chapter);

      test('level $level shows ${fresh.map((t) => t.name).join(', ')} '
          'once, at the end', () {
        final spec = LevelGenerator.generate(level);
        final types = spec.waves.map((w) => w.type).toList();

        expect(
          types.where(fresh.contains).length,
          1,
          reason:
              'level $level is made of an enemy the player has never seen, '
              'rather than introducing it',
        );
        expect(
          fresh.contains(types.last),
          isTrue,
          reason: 'the new enemy is not the wave the level builds toward',
        );
        for (final type in types.take(types.length - 1)) {
          expect(
            EnemyCatalog.of(type).unlockChapter,
            lessThan(chapter),
            reason: 'level $level opens with something the player has not met',
          );
        }
      });

      test('level $level carries no twist on top', () {
        // A new enemy is enough to be learning at once.
        expect(
          LevelGenerator.generate(level).modifier,
          LevelModifier.none,
          reason: 'level $level teaches an enemy and a modifier together',
        );
      });
    }
  });

  testWithGame<NovaGame>(
    'level 16 on easy is not harder than the level before it',
    () => gameAt(16, Difficulty.easy),
    (game) async {
      // The one the player actually reported. Measured in the running game
      // rather than read off the spec, because what matters is the fire that
      // ends up in the air, not the multiplier that produced it.
      await game.ready();
      game.spec = LevelGenerator.generate(16, difficulty: Difficulty.easy);
      final debut = await meanEnemyFire(game);

      expect(
        debut,
        greaterThan(0),
        reason: 'nothing was measured, so this proves nothing',
      );
      expect(
        debut,
        lessThanOrEqualTo(elitePressureBefore),
        reason:
            'level 16 puts ${debut.toStringAsFixed(1)} enemy bullets in the '
            'air, against $elitePressureBefore on the elite level before it, '
            'so the level that introduces the darter is the harder of the two',
      );
    },
  );
}
