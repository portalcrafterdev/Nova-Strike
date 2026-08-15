import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/levels/boss_catalog.dart';
import 'package:novastrike/levels/difficulty_curve.dart';
import 'package:novastrike/levels/enemy_catalog.dart';
import 'package:novastrike/levels/level_generator.dart';
import 'package:novastrike/levels/level_spec.dart';

/// Damage per second for a ship carrying the given upgrade tiers.
double dpsAt({required int fire, required int damage, required int count}) {
  final interval =
      Tuning.playerFireInterval / (1 + Tuning.fireRateUpgradeStep * fire);
  final perBullet =
      Tuning.playerBulletDamage * (1 + Tuning.damageUpgradeStep * damage);
  final streams = 1 + (count + 1) ~/ 2;
  return perBullet * streams / interval;
}

double get baseDps => dpsAt(fire: 0, damage: 0, count: 0);

double get maxedDps => dpsAt(
  fire: Tuning.upgradeMaxTier,
  damage: Tuning.upgradeMaxTier,
  count: Tuning.upgradeMaxTier,
);

/// Total hit points of a boss including its pods and its shield arc.
double bossPool(int level) {
  final spec = BossCatalog.build(level);
  return spec.maxHp *
      (1 +
          (spec.hasShieldArc ? Tuning.bossShieldHpFraction : 0) +
          Tuning.bossPodHpFraction * spec.weakPoints);
}

double enemyHp(EnemyType type, int level) {
  return EnemyCatalog.of(type).baseHp * Tuning.enemyHpMultiplier(level);
}

void main() {
  group('the opening levels are winnable by a beginner', () {
    test('a level 1 scout takes a couple of shots, not one and not five', () {
      // Level 1 is handcrafted, so its own multiplier is what matters here.
      final spec = LevelGenerator.generate(1);
      final hp =
          EnemyCatalog.of(EnemyType.scout).baseHp * spec.enemyHpMultiplier;
      final shots = hp / Tuning.playerBulletDamage;

      expect(shots, greaterThan(1), reason: 'one shot kills are a walkover');
      expect(shots, lessThanOrEqualTo(2), reason: 'too spongy for level 1');
    });

    test('level 1 sends no enemy fire at all', () {
      expect(
        Tuning.playerLives,
        greaterThanOrEqualTo(3),
        reason: 'a beginner needs room to make mistakes',
      );
    });

    test('the first boss is a fight, not a wall', () {
      final seconds = bossPool(15) / baseDps;
      expect(seconds, greaterThan(4), reason: 'too short to feel like a boss');
      expect(seconds, lessThan(25), reason: 'too long without upgrades');
    });
  });

  group('the last levels are hard but not impossible', () {
    test('upgrades are worth buying', () {
      expect(maxedDps / baseDps, greaterThan(8));
    });

    test('common enemies stay quick to kill with a maxed ship', () {
      expect(enemyHp(EnemyType.scout, 1500) / maxedDps, lessThan(1.0));
      expect(enemyHp(EnemyType.gunner, 1500) / maxedDps, lessThan(2.5));
      expect(enemyHp(EnemyType.turret, 1500) / maxedDps, lessThan(5.0));
    });

    test('the last boss is a long fight but a finishable one', () {
      final seconds = bossPool(1500) / maxedDps;
      expect(seconds, greaterThan(20), reason: 'the final boss should bite');
      expect(seconds, lessThan(60), reason: 'longer than this is a grind');
    });

    test('an unupgraded ship cannot brute force the last boss', () {
      expect(bossPool(1500) / baseDps, greaterThan(120));
    });
  });

  group('the curve rises without spiking', () {
    test('boss fights get longer chapter by chapter', () {
      var previous = 0.0;
      for (var level = 15; level <= 1500; level += 15) {
        final pool = bossPool(level);
        expect(pool, greaterThan(0));
        if (level > 15 && BossCatalog.build(level).archetype == 0) {
          expect(pool, greaterThan(previous));
        }
        if (BossCatalog.build(level).archetype == 0) {
          previous = pool;
        }
      }
    });

    test('no level makes a common enemy take longer than five seconds', () {
      for (var level = 1; level <= Tuning.totalLevels; level += 15) {
        final tier = (level ~/ 300).clamp(0, Tuning.upgradeMaxTier);
        final dps = dpsAt(fire: tier, damage: tier, count: tier);
        expect(
          enemyHp(EnemyType.scout, level) / dps,
          lessThan(5),
          reason: 'level $level takes too long to clear',
        );
      }
    });
  });
}
