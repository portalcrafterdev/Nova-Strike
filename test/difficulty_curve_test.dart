import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/levels/boss_catalog.dart';
import 'package:novastrike/levels/level_generator.dart';
import 'package:novastrike/levels/difficulty_curve.dart';
import 'package:novastrike/levels/level_spec.dart';

void main() {
  group('level structure', () {
    test('chapters are fifteen levels long', () {
      expect(Tuning.chapterOf(1), 1);
      expect(Tuning.chapterOf(15), 1);
      expect(Tuning.chapterOf(16), 2);
      expect(Tuning.chapterOf(1500), 100);
      expect(Tuning.totalChapters, 100);
    });

    test('the fourteenth level is elite and the fifteenth is a boss', () {
      expect(Tuning.kindOf(1), LevelKind.normal);
      expect(Tuning.kindOf(13), LevelKind.normal);
      expect(Tuning.kindOf(14), LevelKind.elite);
      expect(Tuning.kindOf(15), LevelKind.boss);
      expect(Tuning.kindOf(29), LevelKind.elite);
      expect(Tuning.kindOf(30), LevelKind.boss);
      expect(Tuning.kindOf(1500), LevelKind.boss);
    });
  });

  group('the curve', () {
    test('enemy hit points climb with the level', () {
      final early = Tuning.enemyHp(10, 1, 1);
      final late = Tuning.enemyHp(10, 1000, 1);
      expect(late, greaterThan(early));
      expect(early, closeTo(10 * (1 + Tuning.hpPerLevel), 0.001));
    });

    test('rate of fire is capped', () {
      expect(
        Tuning.enemyFireRateMultiplier(1500),
        closeTo(Tuning.fireRateCap, 0.001),
      );
    });

    test('the level number never makes anything faster', () {
      // The one thing that must never climb. A level may carry a twist that
      // changes the pace, and an elite wave still arrives quicker, but neither
      // of those has anything to do with how far into the game the player is.
      // If the level number leaks into the pace at all, this catches it.
      for (var level = 1; level <= Tuning.totalLevels; level++) {
        final spec = LevelGenerator.build(level);
        final elite = spec.kind == LevelKind.elite
            ? Tuning.eliteSpeedMultiplier
            : 1.0;

        expect(
          spec.enemySpeedMultiplier,
          closeTo(ModifierTuning.speedFactor(spec.modifier) * elite, 0.0001),
          reason: 'level $level moves at a pace of its own',
        );
        expect(
          spec.bulletSpeedMultiplier,
          closeTo(ModifierTuning.bulletSpeedFactor(spec.modifier), 0.0001),
          reason: 'level $level fires at a speed of its own',
        );
      }
    });

    test('a boss that comes back around is tougher but no faster', () {
      final first = BossCatalog.build(15);
      final later = BossCatalog.build(15 + 15 * Tuning.bossArchetypeCount);

      expect(later.archetype, first.archetype);
      expect(later.maxHp, greaterThan(first.maxHp));
      expect(later.moveSpeed, closeTo(first.moveSpeed, 0.001));
    });

    test('every fifth level is a relief level, but never a boss level', () {
      expect(Tuning.isReliefLevel(5), isTrue);
      expect(Tuning.isReliefLevel(10), isTrue);
      expect(Tuning.isReliefLevel(15), isFalse);
      expect(Tuning.isReliefLevel(4), isFalse);
      expect(Tuning.isReliefLevel(1500), isFalse);
    });

    test('a relief level steps the multipliers back', () {
      final before = Tuning.enemyHpMultiplier(4);
      final relief = Tuning.enemyHpMultiplier(5);
      expect(relief, lessThan(before));
      expect(
        relief,
        closeTo(
          (1 + Tuning.hpPerLevel * 5) *
              Tuning.reliefFactor *
              Tuning.earlyFactor(5),
          0.001,
        ),
      );
    });

    test('coin rewards grow and scale with the level kind', () {
      expect(Tuning.coinReward(1, LevelKind.normal), Tuning.baseCoinReward);
      expect(
        Tuning.coinReward(100, LevelKind.normal),
        Tuning.baseCoinReward + 20,
      );
      expect(
        Tuning.coinReward(100, LevelKind.boss),
        greaterThan(Tuning.coinReward(100, LevelKind.normal)),
      );
      expect(
        Tuning.coinReward(100, LevelKind.elite),
        greaterThan(Tuning.coinReward(100, LevelKind.normal)),
      );
    });

    test('boss hit points grow when an archetype repeats', () {
      final first = Tuning.bossHp(15, 0);
      final repeat = Tuning.bossHp(15, 1);
      expect(repeat, greaterThan(first));
    });
  });

  group('upgrades', () {
    test('cost rises geometrically', () {
      expect(Tuning.upgradeCost(0), Tuning.upgradeBaseCost);
      for (var tier = 1; tier < Tuning.upgradeMaxTier; tier++) {
        expect(
          Tuning.upgradeCost(tier),
          greaterThan(Tuning.upgradeCost(tier - 1)),
        );
      }
    });
  });
}
