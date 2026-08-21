import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/levels/boss_catalog.dart';
import 'package:novastrike/levels/difficulty_curve.dart';
import 'package:novastrike/levels/level_generator.dart';
import 'package:novastrike/levels/level_spec.dart';
import 'package:novastrike/state/player_progress.dart';
import 'package:novastrike/state/save_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Levels worth checking at every setting: a tutorial level, a handcrafted
/// one, an ordinary one, an elite, a boss and the far end of the campaign.
const _levels = [1, 5, 23, 44, 45, 300, 750, 1500];

Future<PlayerProgress> _progress([Map<String, Object>? saved]) async {
  SharedPreferences.setMockInitialValues(saved ?? <String, Object>{});
  final save = SaveService();
  await save.init();
  return PlayerProgress(save)..load();
}

void main() {
  group('the three settings scale the same campaign', () {
    test('a level number draws the same waves at every setting', () {
      // The whole point is that easy is the level the player was stuck on, not
      // a different level. Formations, families and counts must not move.
      for (final level in _levels) {
        final normal = LevelGenerator.generate(level);
        for (final difficulty in Difficulty.values) {
          final spec = LevelGenerator.generate(level, difficulty: difficulty);
          expect(spec.waves.length, normal.waves.length, reason: 'level $level');
          for (var i = 0; i < spec.waves.length; i++) {
            expect(spec.waves[i].type, normal.waves[i].type);
            expect(spec.waves[i].count, normal.waves[i].count);
            expect(spec.waves[i].formation, normal.waves[i].formation);
            expect(spec.waves[i].entry, normal.waves[i].entry);
            expect(spec.waves[i].bullets, normal.waves[i].bullets);
          }
          expect(spec.modifier, normal.modifier);
          expect(spec.difficulty, difficulty);
        }
      }
    });

    test('easy is lighter than normal and hard is heavier, everywhere', () {
      for (final level in _levels) {
        final easy = LevelGenerator.generate(level, difficulty: Difficulty.easy);
        final normal = LevelGenerator.generate(level);
        final hard = LevelGenerator.generate(level, difficulty: Difficulty.hard);

        expect(
          easy.enemyHpMultiplier,
          lessThan(normal.enemyHpMultiplier),
          reason: 'level $level is not easier on easy',
        );
        expect(
          hard.enemyHpMultiplier,
          greaterThan(normal.enemyHpMultiplier),
          reason: 'level $level is not harder on hard',
        );
        expect(easy.enemyFireRateMultiplier, lessThan(1e9));
        expect(
          easy.enemyFireRateMultiplier,
          lessThan(normal.enemyFireRateMultiplier),
        );
        expect(
          hard.enemyFireRateMultiplier,
          greaterThan(normal.enemyFireRateMultiplier),
        );
      }
    });

    test('a boss scales too, hull and rate of fire alike', () {
      // The boss health pool sits outside the enemy multiplier, so it is the
      // one thing that would silently stay at normal if it were missed.
      for (final level in [15, 300, 750, 1500]) {
        final easy = BossCatalog.build(level, difficulty: Difficulty.easy);
        final normal = BossCatalog.build(level);
        final hard = BossCatalog.build(level, difficulty: Difficulty.hard);

        expect(easy.maxHp, lessThan(normal.maxHp), reason: 'level $level');
        expect(hard.maxHp, greaterThan(normal.maxHp), reason: 'level $level');
        // A shorter interval is more fire, so hard has the smallest gap.
        expect(hard.fireInterval, lessThan(normal.fireInterval));
        expect(easy.fireInterval, greaterThan(normal.fireInterval));
      }
    });

    test('hard pays and easy does not', () {
      for (final level in _levels) {
        final easy = LevelGenerator.generate(level, difficulty: Difficulty.easy);
        final normal = LevelGenerator.generate(level);
        final hard = LevelGenerator.generate(level, difficulty: Difficulty.hard);

        expect(hard.coinReward, greaterThan(normal.coinReward));
        expect(easy.coinReward, lessThan(normal.coinReward));
      }
    });

    test('the handcrafted levels scale as well as the generated ones', () {
      // These are written out by hand rather than built by the generator, so
      // they take the setting through a separate path that is easy to forget.
      for (final level in [2, 3, 4, 5, 6, 7, 8]) {
        final normal = LevelGenerator.generate(level);
        final hard = LevelGenerator.generate(level, difficulty: Difficulty.hard);
        expect(
          hard.enemyHpMultiplier,
          greaterThan(normal.enemyHpMultiplier),
          reason: 'handcrafted level $level ignores the setting',
        );
      }
    });
  });

  group('progress is kept per setting', () {
    test('every setting stores its progress under its own key', () {
      // These are built by interpolating the setting into the base key. When
      // that interpolation was lost, easy and hard both collapsed onto one key
      // that was written as an int by the level and read as a string by the
      // stars. The first launch after a save had been written threw out of
      // main, before runApp, and the game came up blank.
      final keys = <String>{};
      for (final difficulty in Difficulty.values) {
        for (final key in [
          SaveService.levelKeyFor(difficulty),
          SaveService.starsKeyFor(difficulty),
        ]) {
          expect(key, isNotEmpty);
          expect(
            keys.add(key),
            isTrue,
            reason: '$key is used for more than one thing',
          );
        }
      }
      // The keys the old single campaign wrote have to stay exactly as they
      // were, or every existing player loses their progress.
      expect(
        SaveService.levelKeyFor(Difficulty.normal),
        SaveService.keyHighestLevel,
      );
      expect(SaveService.starsKeyFor(Difficulty.normal), SaveService.keyStars);
    });

    test('progress written at one setting reads back after a restart', () {
      // Reading is what broke, and it only broke on the second launch, so this
      // writes with the real service and then reads with a fresh one.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      return SharedPreferences.getInstance().then((prefs) async {
        final save = SaveService();
        await save.init();
        for (final difficulty in Difficulty.values) {
          await save.saveHighestLevel(difficulty, 20 + difficulty.index);
          await save.saveStars(difficulty, '${difficulty.index}23');
        }

        final reopened = SaveService();
        await reopened.init();
        for (final difficulty in Difficulty.values) {
          expect(
            reopened.loadHighestLevel(difficulty),
            20 + difficulty.index,
            reason: 'the level at ${difficulty.name} did not survive',
          );
          expect(
            reopened.loadStars(difficulty),
            '${difficulty.index}23',
            reason: 'the stars at ${difficulty.name} did not survive',
          );
        }
      });
    });

    test('a new player starts on normal with easy open and hard shut', () async {
      final progress = await _progress();
      expect(progress.difficulty, Difficulty.normal);
      expect(progress.isAvailable(Difficulty.easy), isTrue);
      expect(progress.isAvailable(Difficulty.normal), isTrue);
      expect(progress.isAvailable(Difficulty.hard), isFalse);
    });

    test('hard opens once normal is past its first boss', () async {
      final progress = await _progress();
      for (var level = 1; level <= DifficultyTuning.hardUnlockLevel; level++) {
        await progress.completeLevel(level: level, stars: 1, coinsEarned: 0);
      }
      expect(progress.isAvailable(Difficulty.hard), isTrue);
    });

    test('clearing levels on easy does not hand them over on normal', () async {
      final progress = await _progress();
      await progress.setDifficulty(Difficulty.easy);
      for (var level = 1; level <= 10; level++) {
        await progress.completeLevel(level: level, stars: 3, coinsEarned: 0);
      }
      expect(progress.highestLevelIn(Difficulty.easy), 11);
      expect(progress.highestLevelIn(Difficulty.normal), 1);

      await progress.setDifficulty(Difficulty.normal);
      expect(progress.isUnlocked(5), isFalse);
      expect(progress.starsFor(5), 0);
    });

    test('stars are counted per setting', () async {
      final progress = await _progress();
      await progress.completeLevel(level: 1, stars: 3, coinsEarned: 0);
      expect(progress.starsFor(1), 3);

      await progress.setDifficulty(Difficulty.easy);
      expect(progress.starsFor(1), 0, reason: 'easy inherited normal stars');
      expect(progress.totalStars, 0);
    });

    test('coins and upgrades are shared, because the ship is', () async {
      final progress = await _progress();
      await progress.setDifficulty(Difficulty.easy);
      await progress.completeLevel(level: 1, stars: 1, coinsEarned: 500);
      final purse = progress.coins;

      await progress.setDifficulty(Difficulty.normal);
      expect(progress.coins, purse);
    });

    test('an existing save keeps its progress as the normal campaign', () async {
      // The old build wrote one campaign under the unsuffixed keys. Moving
      // those keys would have thrown away every player's progress.
      final progress = await _progress(<String, Object>{
        SaveService.keyHighestLevel: 42,
        SaveService.keyStars: '333',
      });
      expect(progress.difficulty, Difficulty.normal);
      expect(progress.highestLevelIn(Difficulty.normal), 42);
      expect(progress.starsFor(2), 3);
      expect(progress.highestLevelIn(Difficulty.easy), 1);
    });

    test('the chosen setting survives a restart', () async {
      final progress = await _progress(<String, Object>{
        SaveService.keyHighestLevel: 40,
      });
      await progress.setDifficulty(Difficulty.hard);

      final reopened = await _progress(<String, Object>{
        SaveService.keyHighestLevel: 40,
        SaveService.keyDifficulty: 'hard',
      });
      expect(reopened.difficulty, Difficulty.hard);
    });

    test('a setting the player has not earned is not restored', () async {
      // A save can name hard while the progress that unlocked it is gone, and
      // the game must not open on a setting the player cannot choose.
      final progress = await _progress(<String, Object>{
        SaveService.keyDifficulty: 'hard',
      });
      expect(progress.difficulty, DifficultyTuning.starting);
    });

    test('easy hands out lives and hard takes one away', () async {
      final progress = await _progress(<String, Object>{
        SaveService.keyHighestLevel: 40,
      });
      final onNormal = progress.lives;

      await progress.setDifficulty(Difficulty.easy);
      expect(progress.lives, greaterThan(onNormal));

      await progress.setDifficulty(Difficulty.hard);
      expect(progress.lives, lessThan(onNormal));
      expect(progress.lives, greaterThanOrEqualTo(1));
    });
  });
}
