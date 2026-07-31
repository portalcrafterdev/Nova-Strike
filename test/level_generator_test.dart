import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/levels/difficulty_curve.dart';
import 'package:novastrike/levels/enemy_catalog.dart';
import 'package:novastrike/levels/level_generator.dart';
import 'package:novastrike/levels/level_spec.dart';

void main() {
  group('every level in the game', () {
    test('generates with at least one wave and non-zero enemy hit points', () {
      for (var level = 1; level <= Tuning.totalLevels; level++) {
        final spec = LevelGenerator.generate(level);

        expect(spec.number, level, reason: 'level $level has the wrong number');
        expect(spec.waves, isNotEmpty, reason: 'level $level has no waves');
        expect(
          spec.enemyHpMultiplier,
          greaterThan(0),
          reason: 'level $level has zero enemy hit points',
        );
        expect(spec.enemySpeedMultiplier, greaterThan(0));
        expect(spec.enemyFireRateMultiplier, greaterThan(0));
        expect(spec.bulletSpeedMultiplier, greaterThan(0));
        expect(spec.coinReward, greaterThan(0));
        expect(spec.musicTrack, isNotEmpty);

        for (final wave in spec.waves) {
          expect(
            wave.count,
            greaterThan(0),
            reason: 'level $level has an empty wave',
          );
          expect(EnemyCatalog.of(wave.type).baseHp, greaterThan(0));
        }
      }
    });

    test('boss levels carry a boss and nothing else does', () {
      for (var level = 1; level <= Tuning.totalLevels; level++) {
        final spec = LevelGenerator.generate(level);
        if (level % Tuning.levelsPerChapter == 0) {
          expect(spec.kind, LevelKind.boss, reason: 'level $level');
          expect(spec.boss, isNotNull, reason: 'level $level');
          expect(spec.boss!.maxHp, greaterThan(0));
          expect(spec.boss!.phasePatterns.length, 3);
          expect(spec.musicTrack, 'boss');
        } else {
          expect(spec.boss, isNull, reason: 'level $level');
        }
      }
    });

    test('only uses enemies unlocked by its chapter', () {
      for (var level = 1; level <= Tuning.totalLevels; level++) {
        final spec = LevelGenerator.generate(level);
        final unlocked = EnemyCatalog.unlockedIn(spec.chapter);
        for (final wave in spec.waves) {
          expect(
            unlocked,
            contains(wave.type),
            reason: 'level $level uses ${wave.type} before it unlocks',
          );
        }
      }
    });
  });

  group('determinism', () {
    test('the same level number always produces the same level', () {
      for (final level in [1, 7, 15, 42, 200, 733, 1000, 1499, 1500]) {
        final first = LevelGenerator.generate(level);
        final second = LevelGenerator.generate(level);

        expect(first.waves.length, second.waves.length);
        for (var i = 0; i < first.waves.length; i++) {
          expect(first.waves[i].type, second.waves[i].type);
          expect(first.waves[i].count, second.waves[i].count);
          expect(first.waves[i].formation, second.waves[i].formation);
          expect(first.waves[i].entry, second.waves[i].entry);
          expect(first.waves[i].movement, second.waves[i].movement);
          expect(first.waves[i].bullets, second.waves[i].bullets);
          expect(first.waves[i].spawnDelay, second.waves[i].spawnDelay);
        }
      }
    });

    test('neighbouring levels are not identical', () {
      final a = LevelGenerator.build(400);
      final b = LevelGenerator.build(401);
      final different =
          a.waves.length != b.waves.length ||
          a.waves.first.type != b.waves.first.type ||
          a.waves.first.count != b.waves.first.count ||
          a.waves.first.formation != b.waves.first.formation;
      expect(different, isTrue);
    });
  });

  group('handcrafted levels', () {
    test('level 1 is one slow wave with no enemy fire', () {
      final spec = LevelGenerator.generate(1);
      expect(spec.waves.length, 1);
      expect(spec.waves.single.bullets, BulletPattern.none);
      expect(spec.enemySpeedMultiplier, lessThan(1));
    });

    test('the opening levels ramp without ever outrunning the curve', () {
      final later = LevelGenerator.generate(20);
      var previousHp = 0.0;
      for (var level = 1; level <= 8; level++) {
        final spec = LevelGenerator.generate(level);
        expect(
          spec.enemyHpMultiplier,
          lessThan(later.enemyHpMultiplier),
          reason: 'level $level is tougher than level 20',
        );
        expect(spec.enemySpeedMultiplier, lessThanOrEqualTo(1.1));
        if (level != 5) {
          // Level 5 is the relief level, so it is allowed to step back.
          expect(spec.enemyHpMultiplier, greaterThan(previousHp));
        }
        previousHp = spec.enemyHpMultiplier;
      }
    });

    test('every hundredth level is a set piece with a gem', () {
      for (var level = 100; level <= Tuning.totalLevels; level += 100) {
        final spec = LevelGenerator.generate(level);
        expect(spec.waves.length, greaterThanOrEqualTo(3));
        expect(
          spec.waves.any((wave) => wave.dropsPowerUp),
          isTrue,
          reason: 'set piece $level drops no gem',
        );
      }
    });
  });

  test('wave counts grow through the early game', () {
    expect(Tuning.waveCount(1), 2);
    expect(Tuning.waveCount(60), 3);
    expect(Tuning.waveCount(120), 4);
    expect(Tuning.waveCount(180), 5);
    expect(Tuning.waveCount(240), Tuning.maxWaveCount);
    expect(Tuning.waveCount(1500), Tuning.maxWaveCount);
  });

  group('levels do not repeat themselves', () {
    test('the early game keeps introducing enemies', () {
      int typesBy(int level) =>
          EnemyCatalog.unlockedIn(Tuning.chapterOf(level)).length;

      expect(typesBy(15), 1);
      expect(typesBy(16), 2);
      expect(typesBy(31), 3);
      expect(typesBy(46), 4);
      expect(typesBy(76), 5);
      expect(typesBy(151), 8);
    });

    test('twists are spread across the levels that carry them', () {
      final seen = <LevelModifier, int>{};
      for (var level = 9; level <= 200; level++) {
        final spec = LevelGenerator.generate(level);
        seen[spec.modifier] = (seen[spec.modifier] ?? 0) + 1;
      }
      for (final modifier in LevelModifier.values) {
        expect(
          seen[modifier] ?? 0,
          greaterThan(3),
          reason: '$modifier barely ever comes up',
        );
      }
    });

    test('an objective level never carries a twist as well', () {
      // Survival, escort and gate levels already change the rules. Level 39
      // used to be a survival level under BARRAGE, which asked the player to
      // learn two new things at once in chapter 3.
      var objectives = 0;
      for (var level = 1; level <= Tuning.totalLevels; level++) {
        final spec = LevelGenerator.generate(level);
        switch (spec.kind) {
          case LevelKind.survival:
          case LevelKind.escort:
          case LevelKind.gate:
          case LevelKind.boss:
            objectives++;
            expect(
              spec.modifier,
              LevelModifier.none,
              reason:
                  'level $level stacks ${spec.modifier.label} '
                  'on top of a ${spec.kind.name} level',
            );
          case LevelKind.normal:
          case LevelKind.elite:
            break;
        }
      }
      expect(objectives, greaterThan(100));
    });

    test('the tutorial levels stay plain', () {
      for (var level = 1; level < ModifierTuning.firstModifiedLevel; level++) {
        expect(LevelGenerator.generate(level).modifier, LevelModifier.none);
      }
    });

    test('a twist actually changes how a level plays', () {
      for (var level = 9; level <= 400; level++) {
        final spec = LevelGenerator.generate(level);
        switch (spec.modifier) {
          case LevelModifier.swarm:
            expect(spec.enemyCount, greaterThan(4));
          case LevelModifier.armoured:
            expect(spec.enemySpeedMultiplier, lessThan(spec.enemyHpMultiplier));
          case LevelModifier.none:
          case LevelModifier.vanguard:
          case LevelModifier.swift:
          case LevelModifier.barrage:
            break;
        }
      }
    });

    test('neighbouring levels differ in more than hit points', () {
      var different = 0;
      for (var level = 9; level <= 100; level++) {
        final a = LevelGenerator.generate(level);
        final b = LevelGenerator.generate(level + 1);
        if (a.modifier != b.modifier ||
            a.enemyCount != b.enemyCount ||
            a.waves.first.type != b.waves.first.type ||
            a.waves.first.formation != b.waves.first.formation) {
          different++;
        }
      }
      expect(different, greaterThan(80));
    });
  });
}
