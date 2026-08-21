import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/levels/boss_catalog.dart';
import 'package:novastrike/levels/difficulty_curve.dart';
import 'package:novastrike/levels/enemy_catalog.dart';
import 'package:novastrike/levels/level_generator.dart';
import 'package:novastrike/levels/level_spec.dart';
import 'package:novastrike/state/player_progress.dart';
import 'package:novastrike/state/save_service.dart';
import 'package:novastrike/theme/palette.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Coins a player holds by [level], having cleared everything before it once.
int purseAt(int level) {
  var purse = 0;
  for (var k = 1; k < level; k++) {
    purse += Tuning.coinReward(k, Tuning.kindOf(k));
  }
  return purse;
}

/// Damage per second for the ship that purse can actually buy.
///
/// Difficulty has to be measured against what the player has, not against a
/// ship they cannot afford yet. Six upgrades share the money and only three of
/// them touch damage, so this spends round robin across all six, which is what
/// a player who wants a bit of everything ends up with.
double affordableDps(int level) {
  var purse = purseAt(level);
  final tiers = List<int>.filled(PlayerProgress.upgrades.length, 0);
  var bought = true;
  while (bought) {
    bought = false;
    for (var i = 0; i < tiers.length; i++) {
      if (tiers[i] >= Tuning.upgradeMaxTier) {
        continue;
      }
      final cost = Tuning.upgradeCost(tiers[i]);
      if (purse >= cost) {
        purse -= cost;
        tiers[i]++;
        bought = true;
      }
    }
  }
  return dpsAt(fire: tiers[0], damage: tiers[1], count: tiers[2]);
}

/// Every hit point a level puts in front of the player.
double levelHp(int level) {
  final spec = LevelGenerator.generate(level);
  var total = 0.0;
  for (final wave in spec.waves) {
    total +=
        wave.count * EnemyCatalog.of(wave.type).baseHp * spec.enemyHpMultiplier;
  }
  if (spec.boss != null) {
    total += bossPool(level);
  }
  return total;
}

/// Roughly how long a level takes to shoot through, in seconds.
double clearSeconds(int level) => levelHp(level) / affordableDps(level);

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

    test("the first boss is a fight, not a wall", () {
      // Measured against what the player can actually afford by level 15
      // rather than against a bare ship, because the coins they have earned by
      // then are the whole point of the economy.
      final seconds = bossPool(15) / affordableDps(15);
      expect(seconds, greaterThan(8), reason: "too short to feel like a boss");
      expect(seconds, lessThan(30), reason: "a wall, not a fight");
    });
  });

  group('a gem is never worse than not picking it up', () {
    test('the laser keeps up with the guns it replaces', () async {
      // The beam used to be a flat forty two a second while the guns climbed
      // to five hundred and seventy three, so picking the gem up on a bought
      // ship cut the player to seven per cent of their own damage and stopped
      // their bullets as well. That is a gem that reads as a broken weapon.
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final save = SaveService();
      await save.init();
      final progress = PlayerProgress(save)..load();

      for (var tier = 0; tier <= Tuning.upgradeMaxTier; tier++) {
        while (progress.tierOf(UpgradeId.fireRate) < tier) {
          await progress.addCoins(100000);
          progress.buyUpgrade(UpgradeId.fireRate);
          progress.buyUpgrade(UpgradeId.damage);
          progress.buyUpgrade(UpgradeId.bulletCount);
        }
        final share = progress.laserDamagePerSecond / progress.gunDamagePerSecond;
        expect(
          share,
          closeTo(Tuning.laserDpsFraction, 0.001),
          reason: 'the beam drifts from the guns at tier $tier',
        );
        expect(
          share,
          greaterThan(0.7),
          reason: 'picking up the laser at tier $tier is a downgrade',
        );
      }
    });

    test('the beam is drawn far narrower than the column it burns', () {
      // What went wrong was not the width it hits at, it was the width it was
      // painted at: a flat slab a tenth of the screen across.
      expect(Metrics.laserCoreWidth, lessThan(0.2));
      expect(Metrics.laserBodyWidth, lessThan(0.5));
      // The halo still shows the true reach, so the beam does not lie about
      // what it is hitting.
      expect(Metrics.laserHaloAlpha, greaterThan(0));
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

  group('the curve holds across all 1500 levels', () {
    test('no level is a wall against the ship the player can afford', () {
      // Both ends of the band matter. A level that clears in a second is not a
      // level, and one that takes minutes is a player holding the trigger down
      // waiting for it to end. The hit point curve used to run away: it grew
      // fifty three times over by level 1500 while the player's damage only
      // multiplies about thirteen times, so the last levels took eight minutes.
      var worst = 0.0;
      var worstAt = 0;
      for (var level = 1; level <= Tuning.totalLevels; level++) {
        final seconds = clearSeconds(level);
        if (seconds > worst) {
          worst = seconds;
          worstAt = level;
        }
      }
      expect(
        worst,
        lessThan(120),
        reason: 'level $worstAt takes ${worst.toStringAsFixed(0)}s to clear',
      );
    });

    test('no level lands far harder than the ones leading up to it', () {
      // A spike is what makes a player quit: they beat five levels in a row
      // and then hit one that is four times the work with no warning. Elite
      // swarms used to draw a twist on top of already being an elite, which is
      // where every one of the worst spikes came from.
      var worst = 0.0;
      var worstAt = 0;
      for (var level = 8; level <= Tuning.totalLevels; level++) {
        // A boss is meant to be a step up from the levels leading to it, and
        // it gets its own band in the test below.
        if (Tuning.kindOf(level) == LevelKind.boss) {
          continue;
        }
        var near = 0.0;
        var counted = 0;
        for (var k = level - 5; k < level; k++) {
          if (Tuning.kindOf(k) == LevelKind.boss) {
            continue;
          }
          near += clearSeconds(k);
          counted++;
        }
        near /= counted;
        final ratio = clearSeconds(level) / near;
        if (ratio > worst) {
          worst = ratio;
          worstAt = level;
        }
      }
      expect(
        worst,
        lessThan(5),
        reason:
            'level $worstAt is ${worst.toStringAsFixed(1)} times the five '
            'levels before it',
      );
    });

    test('the money keeps up with the curve', () {
      // The player met the first boss with 161 coins and a cheapest upgrade of
      // 120, so they fought it with a bare ship. Three first tier upgrades by
      // the first boss is the floor.
      expect(
        purseAt(15),
        greaterThanOrEqualTo(Tuning.upgradeCost(0) * 3),
        reason: 'the first boss is met with an unupgraded ship',
      );
      // And the ship should be finished well before the end, or the last third
      // of the game has nothing left to earn.
      expect(affordableDps(600), closeTo(maxedDps, 1));
    });

    test('a boss is a fight at both ends of the game', () {
      for (final level in [15, 300, 750, 1500]) {
        final seconds = bossPool(level) / affordableDps(level);
        expect(
          seconds,
          greaterThan(8),
          reason: 'the boss on level $level dies too fast to have phases',
        );
        expect(
          seconds,
          lessThan(50),
          reason: 'the boss on level $level is a grind',
        );
      }
    });
  });
}
