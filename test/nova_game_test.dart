import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/audio/audio_controller.dart';
import 'package:novastrike/game/components/bullet.dart';
import 'package:novastrike/game/components/boss.dart';
import 'package:novastrike/game/components/enemy_ship.dart';
import 'package:novastrike/game/components/flak_shell.dart';
import 'package:novastrike/game/components/missile.dart';
import 'package:novastrike/game/components/obstacle.dart';
import 'package:novastrike/game/components/coin.dart';
import 'package:novastrike/game/components/power_up.dart';
import 'package:novastrike/game/effects/debris.dart';
import 'package:novastrike/theme/palette.dart';
import 'package:novastrike/game/nova_game.dart';
import 'package:novastrike/game/render/camera.dart';
import 'package:novastrike/game/render/sprite_renderer.dart';
import 'package:novastrike/game/world/parallax_bg.dart';
import 'package:novastrike/game/systems/spawner.dart';
import 'package:novastrike/game/world/play_area.dart';
import 'package:novastrike/levels/level_spec.dart';
import 'package:novastrike/levels/difficulty_curve.dart';
import 'package:novastrike/levels/level_generator.dart';
import 'package:novastrike/state/player_progress.dart';
import 'package:novastrike/state/save_service.dart';
import 'package:novastrike/state/ship_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs the game loop for [seconds] of game time.
///
/// Each frame yields to the event loop, because Flame finishes loading a
/// component on a microtask and a synchronous loop would never let it run.
Future<void> tick(NovaGame game, double seconds, {double step = 1 / 60}) async {
  var elapsed = 0.0;
  while (elapsed < seconds) {
    game.update(step);
    await Future<void>.delayed(Duration.zero);
    elapsed += step;
  }
}

/// Runs the loop for [seconds], destroying every enemy the moment it arrives.
///
/// A level holds a floor of [RunnerTuning.minLevelDuration] and keeps sending
/// waves until it is reached, so a test that wants to watch a level finish has
/// to keep clearing the lane for that long rather than killing one wave and
/// waiting for a sheet that is not coming.
Future<void> clearingTick(NovaGame game, double seconds) async {
  const step = 1 / 60;
  var elapsed = 0.0;
  while (elapsed < seconds) {
    for (final enemy in game.world.children.query<EnemyShip>().toList()) {
      enemy.destroy(byPlayer: true);
    }
    game.update(step);
    await Future<void>.delayed(Duration.zero);
    elapsed += step;
  }
}

/// Long enough for a level to clear its floor and play its run home.
final double _throughLevel =
    RunnerTuning.minLevelDuration +
    RunnerTuning.bonusRunDuration +
    RunnerTuning.warpDuration +
    4;

/// The first level of a given kind, so an objective test never hard codes a
/// number that a tuning change could move.
int levelOfKind(LevelKind kind) {
  for (var level = Tuning.objectiveFirstLevel; level <= 400; level++) {
    if (Tuning.kindOf(level) == kind) {
      return level;
    }
  }
  throw StateError('no level found of kind ${kind.name}');
}

NovaGame buildEndless(int level) => buildGame(level, endless: true);

NovaGame buildGame(int level, {bool endless = false}) {
  final save = SaveService();
  final progress = PlayerProgress(save);
  final audio = AudioController(save);
  final game = NovaGame(
    audio: audio,
    progress: progress,
    levelNumber: level,
    endless: endless,
  );
  // The overlays are registered by GameWidget in the app, so a headless test
  // has to register stand ins before the game asks for them.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  group('a level running', () {
    testWithGame<NovaGame>(
      'starts with a player, a runner and full lives',
      () => buildGame(1),
      (game) async {
        await game.ready();

        expect(game.status, GameStatus.playing);
        expect(game.spec.number, 1);
        expect(game.player.isMounted, isTrue);
        expect(game.lives, Tuning.playerLives);
        expect(game.livesNotifier.value, Tuning.playerLives);
      },
    );

    testWithGame<NovaGame>(
      'spawns the first wave and fires on its own',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, 3);

        expect(game.world.children.query<EnemyShip>(), isNotEmpty);
        expect(game.world.children.query<Bullet>(), isNotEmpty);
        expect(game.waveNotifier.value.current, greaterThan(0));
      },
    );

    testWithGame<NovaGame>(
      'a hovering wave keeps coming instead of parking across the top',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, 3);

        final enemy = game.world.children.query<EnemyShip>().first
          ..movement = MovementPattern.hover
          ..position.setValues(0, 0, PlayArea.holdDepth - 10)
          // Tough enough to survive the player's own auto fire for the two
          // seconds this watches it for.
          ..hp = 100000;
        final start = enemy.position.z;
        await tick(game, 2);

        // It weaves on the way in, but it arrives. Holding station forever put
        // the whole wave where the player could simply wait it out.
        expect(
          enemy.position.z,
          lessThan(start - 20),
          reason: 'a hovering enemy is still sitting where it stopped',
        );
      },
    );

    testWithGame<NovaGame>(
      'kills enemies with player bullets and scores them',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, 3);

        final enemy = game.world.children.query<EnemyShip>().first;
        enemy.takeDamage(enemy.hp + 1, fromFront: false);
        await tick(game, 0.1);

        expect(game.score, greaterThan(0));
        expect(enemy.isMounted, isFalse);
      },
    );

    testWithGame<NovaGame>(
      'ends the run when the last life is lost',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, 1);

        for (var i = 0; i < Tuning.playerLives; i++) {
          game.onPlayerHit();
        }

        expect(game.lives, 0);
        expect(game.status, GameStatus.failed);
        expect(game.overlays.isActive(NovaGame.gameOverOverlay), isTrue);
      },
    );

    testWithGame<NovaGame>(
      'caps the number of bullets on screen',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, 12);

        expect(
          game.world.children.query<Bullet>().length,
          lessThanOrEqualTo(Tuning.maxActiveBullets),
        );
      },
    );

    // Level 14 is the first elite swarm, flying straight past the player.
    // Levels 33 and 47 send their waves in from the sides, and 90 fires
    // bursts. Between them they used to produce shots leaving the wing or the
    // tail of a hull that points the other way, up to 96 degrees off the nose,
    // which read as a mistake rather than as a threat.
    for (final level in [14, 33, 47, 90]) {
      testWithGame<NovaGame>(
        'every shot on level $level leaves the nose, not the wing',
        () => buildGame(level),
        (game) async {
          await game.ready();

          var checked = 0;
          var worst = 0.0;
          for (var frame = 0; frame < 60 * 10; frame++) {
            game.update(1 / 60);
            await Future<void>.delayed(Duration.zero);

            for (final bullet in game.world.children.query<Bullet>()) {
              if (bullet.owner != BulletOwner.enemy) {
                continue;
              }
              checked++;
              // Every hull points down the lane, so this is the angle between
              // the shot and the way the ship that fired it is facing.
              final off =
                  math.atan2(bullet.velocity.x, -bullet.velocity.z).abs() *
                  180 /
                  math.pi;
              if (off > worst) {
                worst = off;
              }
            }
          }

          expect(checked, greaterThan(0), reason: 'nothing fired at all');
          expect(
            worst,
            lessThanOrEqualTo(56),
            reason: 'a shot left $worst degrees off the nose',
          );
        },
      );
    }

    testWithGame<NovaGame>(
      'the ship stays pointed up the lane however hard it is thrown about',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, 1);

        final camera = GameCamera(
          viewportWidth: Metrics.worldWidth,
          viewportHeight: Metrics.worldHeight,
        );
        final renderer = SpriteRenderer(camera);

        // The hull used to lean into a turn. On a flat top down sprite that
        // came out as the nose swinging away from straight up the lane, which
        // is not where the guns fire.
        for (final target in [-260.0, 260.0, -260.0]) {
          game.player.aimAt(Vector3(target, 0, PlayArea.playerDepth));
          await tick(game, 0.35);

          final spy = _CanvasSpy();
          game.player.paint(spy, renderer, camera);
          expect(
            spy.turns,
            isEmpty,
            reason:
                'the ship is drawn at an angle while sliding toward $target',
          );
        }
      },
    );

    testWithGame<NovaGame>(
      'everything the player fires flies straight up the lane',
      // Level 30 has every weapon unlocked, and the spread gem is forced on,
      // so this covers the cannon, the wing pods, the railgun and the gem at
      // once. Each of those used to fan out at an angle, which put diagonal
      // streaks either side of the ship.
      () => buildGame(30),
      (game) async {
        await game.ready();
        game.player.applyPowerUp(PowerUpType.spread);
        game.player.applyPowerUp(PowerUpType.doubleShot);

        var checked = 0;
        for (var frame = 0; frame < 60 * 8; frame++) {
          game.update(1 / 60);
          await Future<void>.delayed(Duration.zero);

          for (final bullet in game.world.children.query<Bullet>()) {
            if (bullet.owner != BulletOwner.player) {
              continue;
            }
            checked++;
            expect(
              bullet.velocity.x.abs(),
              lessThan(0.001),
              reason: 'a player shot is drifting sideways',
            );
            expect(
              bullet.velocity.z,
              greaterThan(0),
              reason: 'a player shot is not going up the lane',
            );
          }
        }

        expect(checked, greaterThan(0), reason: 'the ship never fired');
      },
    );

    testWithGame<NovaGame>(
      'the star field is made of stars, never of scratches',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, 1);

        final field = game.world.children.query<ParallaxBackground>().first;
        final camera = GameCamera(
          viewportWidth: Metrics.worldWidth,
          viewportHeight: Metrics.worldHeight,
        );
        final renderer = SpriteRenderer(camera);

        // Both at rest and at full warp. The near layer used to be stretched
        // into a line, which did not read as a fast star, it read as a white
        // scratch on the screen.
        for (final warp in [0.0, 1.0]) {
          game.warpFactor = warp;
          final spy = _CanvasSpy();
          field.paint(spy, renderer, camera);

          expect(
            spy.circles,
            greaterThan(0),
            reason: 'the field drew no stars at warp $warp',
          );
          expect(
            spy.lines,
            0,
            reason: 'the field drew a star as a line at warp $warp',
          );
        }
      },
    );
  });

  group('finishing a level', () {
    testWithGame<NovaGame>(
      'clears the level once every wave is gone and unlocks the next',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, 2);

        // The lane is kept clear for the whole level rather than emptied once.
        // A level runs to its floor now, so killing the first wave and waiting
        // only means standing in front of the next one.
        await clearingTick(game, _throughLevel);

        expect(game.status, GameStatus.complete);
        expect(game.overlays.isActive(NovaGame.levelCompleteOverlay), isTrue);
        expect(game.progress.highestLevelUnlocked, 2);
        expect(game.earnedStars, greaterThanOrEqualTo(2));
      },
    );

    testWithGame<NovaGame>(
      'retry puts the same level back immediately',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, 1);
        game.onPlayerHit();
        game.failLevel();

        await game.retry();
        await tick(game, 0.2);

        expect(game.status, GameStatus.playing);
        expect(game.levelNumber, 1);
        expect(game.lives, Tuning.playerLives);
        expect(game.overlays.isActive(NovaGame.gameOverOverlay), isFalse);
      },
    );

    testWithGame<NovaGame>(
      'pausing stops the run and resuming picks it back up',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, 1);

        game.pauseGame();
        expect(game.status, GameStatus.paused);
        expect(game.overlays.isActive(NovaGame.pauseOverlay), isTrue);

        game.resumeGame();
        expect(game.status, GameStatus.playing);
        expect(game.overlays.isActive(NovaGame.pauseOverlay), isFalse);
      },
    );
  });

  group('a boss level', () {
    testWithGame<NovaGame>(
      'sends the boss in after the escort and shows its health',
      () => buildGame(15),
      (game) async {
        await game.ready();
        expect(game.spec.isBoss, isTrue);
        expect(game.spec.boss, isNotNull);

        // The boss waits behind the escort until only its own share of the
        // clock is left, so the escort has to be fought through rather than
        // cleared once.
        await clearingTick(
          game,
          RunnerTuning.minLevelDuration - RunnerTuning.bossFightAllowance + 6,
        );

        final bosses = game.world.children.query<Boss>();
        expect(bosses, hasLength(1));
        expect(game.bossNameNotifier.value, game.spec.boss!.name);
        // The bar is up and reading. The ship is firing all the while, so the
        // boss may already have taken a little damage by now.
        expect(game.bossHealthNotifier.value, greaterThan(0));
        expect(game.bossHealthNotifier.value, lessThanOrEqualTo(1));
      },
    );

    testWithGame<NovaGame>(
      'protects the core until the pods and the shield are gone',
      () => buildGame(60),
      (game) async {
        await game.ready();
        final spec = game.spec.boss!;
        final boss = Boss(spec);
        await game.world.add(boss);
        await tick(game, 3);

        final startHp = boss.hp;
        boss.takeDamage(50, at: boss.position);
        if (spec.hasShieldArc || spec.weakPoints > 0) {
          expect(boss.hp, startHp);
        }

        boss.shieldHp = 0;
        for (final pod in boss.pods.toList()) {
          pod.takeDamage(pod.hp + 1);
        }
        await tick(game, 0.2);

        boss.takeDamage(50, at: boss.position);
        expect(boss.hp, lessThan(startHp));
      },
    );
  });

  group('power-ups', () {
    testWithGame<NovaGame>(
      'are picked up by flying into them and expire on their own',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, 0.5);

        await game.world.add(
          PowerUp(
            type: PowerUpType.shield,
            spawn: game.player.position.clone(),
          ),
        );
        await tick(game, 0.2);

        expect(game.player.hasPowerUp(PowerUpType.shield), isTrue);
        expect(game.powerUpsNotifier.value, contains(PowerUpType.shield));

        await tick(game, game.progress.powerUpDuration + 0.5);
        expect(game.player.hasPowerUp(PowerUpType.shield), isFalse);
      },
    );

    testWithGame<NovaGame>(
      'a shield eats the next hit instead of a life',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, 0.5);
        game.player.applyPowerUp(PowerUpType.shield);

        game.player.takeHit();

        expect(game.lives, Tuning.playerLives);
        expect(game.player.hasPowerUp(PowerUpType.shield), isFalse);
      },
    );
  });

  group('waves entering from a side', () {
    testWithGame<NovaGame>(
      'survive the frames they spend outside the play area',
      () => buildGame(1),
      (game) async {
        await game.ready();

        final spawner = Spawner(game, game.spec);
        final spawned = spawner.spawnWave(
          const WaveSpec(
            type: EnemyType.scout,
            count: 6,
            formation: Formation.pincer,
            entry: EntrySide.left,
            movement: MovementPattern.straight,
            bullets: BulletPattern.none,
            spawnDelay: 0,
          ),
        );
        expect(spawned, hasLength(6));

        await tick(game, 1.5);

        final alive = game.world.children
            .query<EnemyShip>()
            .where(spawned.contains)
            .length;
        expect(alive, 6, reason: 'side entries were culled before arriving');
      },
    );

    testWithGame<NovaGame>(
      'are still cleared once they fly off the far side',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, 2.5);
        expect(game.world.children.query<EnemyShip>(), isNotEmpty);

        for (final enemy in game.enemies.toList()) {
          enemy.position.setValues(0, 0, 400);
        }
        await tick(game, 0.1);

        // Flown past the lens and out of the fight.
        for (final enemy in game.enemies.toList()) {
          enemy.position.setValues(0, 0, PlayArea.despawnDepth - 50);
        }
        await tick(game, 0.2);

        expect(game.world.children.query<EnemyShip>(), isEmpty);
      },
    );
  });

  group('shooting a boss', () {
    testWithGame<NovaGame>(
      'takes health off the bar when a bullet lands on the hull',
      () => buildGame(15),
      (game) async {
        await game.ready();
        final boss = Boss(game.spec.boss!);
        await game.world.add(boss);
        await tick(game, Tuning.bossEntryDuration + 0.5);

        final startHp = boss.hp;
        game.bullets.spawn(
          game.world,
          spawn: Vector3(
            boss.position.x,
            boss.position.y,
            boss.position.z - 160,
          ),
          velocityX: 0,
          velocityY: 0,
          velocityZ: 400,
          owner: BulletOwner.player,
          damage: 30,
        );
        await tick(game, 0.6);

        expect(boss.hp, lessThan(startHp));
        expect(game.bossHealthNotifier.value, lessThan(1));
      },
    );

    testWithGame<NovaGame>(
      'wears down under the auto fire of a ship parked below it',
      () => buildGame(15),
      (game) async {
        await game.ready();
        final boss = Boss(game.spec.boss!);
        await game.world.add(boss);
        await tick(game, Tuning.bossEntryDuration + 0.5);

        final startHp = boss.hp;
        game.player.aimAt(Vector3(boss.position.x, 0, PlayArea.playerDepth));
        await tick(game, 2.5);

        expect(
          boss.hp,
          lessThan(startHp),
          reason: 'the ship shot at the boss and nothing happened',
        );
      },
    );

    testWithGame<NovaGame>(
      'ignores fire while it is still flying in',
      () => buildGame(15),
      (game) async {
        await game.ready();
        final boss = Boss(game.spec.boss!);
        await game.world.add(boss);
        await tick(game, 0.2);

        boss.takeDamage(50, at: boss.position);
        expect(boss.hp, boss.spec.maxHp);
      },
    );
  });

  group('level twists', () {
    testWithGame<NovaGame>('reach the heads up display', () => buildGame(17), (
      game,
    ) async {
      await game.ready();
      expect(game.modifierNotifier.value, game.spec.modifier.label);
    });

    testWithGame<NovaGame>(
      'follow the level when it changes',
      () => buildGame(9),
      (game) async {
        await game.ready();
        for (var level = 9; level <= 24; level++) {
          await game.startLevel(level);
          expect(
            game.modifierNotifier.value,
            game.spec.modifier.label,
            reason: 'level $level shows the wrong twist',
          );
        }
      },
    );
  });

  group('shooting down enemy fire', () {
    testWithGame<NovaGame>(
      'a player shot cancels an enemy shot and is spent doing it',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, 2.5);

        game.bullets.spawn(
          game.world,
          spawn: Vector3(0, 0, 250),
          velocityX: 0,
          velocityY: 0,
          velocityZ: -200,
          owner: BulletOwner.enemy,
          damage: 1,
        );
        game.bullets.spawn(
          game.world,
          spawn: Vector3(0, 0, 240),
          velocityX: 0,
          velocityY: 0,
          velocityZ: 620,
          owner: BulletOwner.player,
          damage: 3,
        );
        await tick(game, 0.05);

        expect(
          game.bullets.active.where((b) => b.owner == BulletOwner.enemy),
          isEmpty,
          reason: 'the enemy shot survived a hit from the player',
        );
      },
    );

    testWithGame<NovaGame>(
      'a pair closing at full speed cannot pass through each other',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, 2.5);

        // One frame of travel puts each bullet well past the other, which is
        // the case a test against current positions alone would miss.
        game.bullets.spawn(
          game.world,
          spawn: Vector3(0, 0, 300),
          velocityX: 0,
          velocityY: 0,
          velocityZ: -2400,
          owner: BulletOwner.enemy,
          damage: 1,
        );
        game.bullets.spawn(
          game.world,
          spawn: Vector3(0, 0, 240),
          velocityX: 0,
          velocityY: 0,
          velocityZ: 2400,
          owner: BulletOwner.player,
          damage: 3,
        );
        await tick(game, 2 / 60);

        expect(
          game.bullets.active.where((b) => b.owner == BulletOwner.enemy),
          isEmpty,
          reason: 'the two shots flew straight through each other',
        );
      },
    );

    testWithGame<NovaGame>(
      'a shot that misses by a margin carries on to the enemy behind it',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, 2.5);
        expect(game.enemies, isNotEmpty);

        final enemy = game.enemies.first;
        enemy.position.setValues(0, 0, 300);
        final startHp = enemy.hp;

        game.bullets.spawn(
          game.world,
          spawn: Vector3(40, 0, 260),
          velocityX: 0,
          velocityY: 0,
          velocityZ: -200,
          owner: BulletOwner.enemy,
          damage: 1,
        );
        game.bullets.spawn(
          game.world,
          spawn: Vector3(0, 0, 250),
          velocityX: 0,
          velocityY: 0,
          velocityZ: 2400,
          owner: BulletOwner.player,
          damage: 3,
        );
        await tick(game, 0.05);

        expect(
          enemy.isMounted ? enemy.hp : -1,
          lessThan(startHp),
          reason: 'a shot passing well clear of enemy fire was eaten anyway',
        );
      },
    );
  });

  group("hit detection", () {
    testWithGame<NovaGame>(
      'a fast bullet cannot skip over a small enemy between frames',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, 2.5);
        expect(game.enemies, isNotEmpty);

        final enemy = game.enemies.first;
        enemy.position.setValues(0, 0, 240);
        final startHp = enemy.hp;

        // Fast enough to land well past the enemy in a single step, which is
        // exactly the case that used to sail straight through it.
        game.bullets.spawn(
          game.world,
          spawn: Vector3(0, 0, 225),
          velocityX: 0,
          velocityY: 0,
          velocityZ: 2400,
          owner: BulletOwner.player,
          damage: 3,
        );
        await tick(game, 0.05);

        expect(
          enemy.isMounted ? enemy.hp : -1,
          lessThan(startHp),
          reason: 'the bullet passed straight through the enemy',
        );
      },
    );

    testWithGame<NovaGame>(
      'ordinary auto fire still clears a wave',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, 2.5);
        final before = game.enemies.length;
        expect(before, greaterThan(0));

        // Line the wave up with the ship and let the auto fire work.
        for (final enemy in game.enemies) {
          enemy.position.x = game.player.position.x;
          enemy.position.y = game.player.position.y;
        }
        await tick(game, 4);

        expect(game.score, greaterThan(0));
      },
    );
  });

  group('secondary weapons', () {
    testWithGame<NovaGame>(
      'the ship launches missiles on its own once they are fitted',
      () => buildGame(Tuning.missileFirstLevel),
      (game) async {
        await game.ready();
        await tick(game, Tuning.missileInterval + 0.2);

        expect(
          game.missiles,
          isNotEmpty,
          reason: 'no missile left the rail without the player asking',
        );
      },
    );

    testWithGame<NovaGame>(
      'the tutorial levels carry no ordnance',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, Tuning.railInterval + 0.5);

        expect(game.missiles, isEmpty);
        expect(
          game.bullets.active.where((b) => b.heavy),
          isEmpty,
          reason: 'level 1 should be the drag and the cannon, nothing else',
        );
      },
    );

    testWithGame<NovaGame>(
      'a missile steers onto an enemy and blows it up',
      () => buildGame(Tuning.missileFirstLevel),
      (game) async {
        await game.ready();
        await tick(game, 2.5);
        expect(game.enemies, isNotEmpty);

        // One enemy, parked off to the side so only a homing weapon reaches it.
        final enemy = game.enemies.first;
        for (final other in List.of(game.enemies)) {
          if (other != enemy) {
            other.removeFromParent();
          }
        }
        enemy.position.setValues(70, 0, 260);
        enemy.hp = 1;

        await tick(game, Tuning.missileInterval + 1.6);

        expect(
          enemy.isMounted,
          isFalse,
          reason: 'the missile never found a target it was pointed at',
        );
      },
    );

    testWithGame<NovaGame>(
      'a blast hurts everything standing near what it hit',
      () => buildGame(Tuning.missileFirstLevel),
      (game) async {
        await game.ready();
        await tick(game, 2.5);
        expect(game.enemies.length, greaterThan(1));

        final target = game.enemies.first;
        final neighbour = game.enemies[1];
        target.position.setValues(0, 0, 300);
        neighbour.position.setValues(Tuning.missileSplashRadius * 0.4, 0, 300);
        final neighbourHp = neighbour.hp;

        game.world.add(
          Missile(spawn: Vector3(0, 0, 240), damage: Tuning.missileDamage),
        );
        await tick(game, 0.6);

        expect(
          neighbour.isMounted ? neighbour.hp : -1,
          lessThan(neighbourHp),
          reason: 'the blast only touched what the missile actually hit',
        );
      },
    );

    testWithGame<NovaGame>(
      'the railgun lance runs through a whole column of enemies',
      () => buildGame(Tuning.railFirstLevel),
      (game) async {
        await game.ready();
        await tick(game, 2.5);
        expect(game.enemies.length, greaterThan(1));

        final ship = game.player;
        final first = game.enemies.first;
        final second = game.enemies[1];
        first.position.setValues(ship.position.x, ship.position.y, 300);
        second.position.setValues(ship.position.x, ship.position.y, 420);
        final firstHp = first.hp;
        final secondHp = second.hp;

        game.bullets.spawn(
          game.world,
          spawn: Vector3(ship.position.x, ship.position.y, 250),
          velocityX: 0,
          velocityY: 0,
          velocityZ: Tuning.railSpeed,
          owner: BulletOwner.player,
          damage: Tuning.railDamage,
          piercing: true,
          heavy: true,
        );
        await tick(game, 0.3);

        expect(first.isMounted ? first.hp : -1, lessThan(firstHp));
        expect(
          second.isMounted ? second.hp : -1,
          lessThan(secondHp),
          reason: 'the lance stopped at the first thing it touched',
        );
      },
    );

    testWithGame<NovaGame>(
      'ordnance tiers make the rack fire faster and hit harder',
      () => buildGame(1),
      (game) async {
        await game.ready();
        final base = game.progress.missileInterval;
        final baseDamage = game.progress.missileDamage;

        await game.progress.addCoins(9999);
        expect(game.progress.buyUpgrade(UpgradeId.ordnance), isTrue);

        expect(game.progress.missileInterval, lessThan(base));
        expect(game.progress.missileDamage, greaterThan(baseDamage));
      },
    );

    testWithGame<NovaGame>(
      'the proximity fuse sets a shell off beside a ship',
      () => buildGame(Tuning.flakFirstLevel),
      (game) async {
        await game.ready();
        await tick(game, 2.5);
        expect(game.enemies, isNotEmpty);

        final enemy = game.enemies.first;
        for (final other in List.of(game.enemies)) {
          if (other != enemy) {
            other.removeFromParent();
          }
        }
        enemy.position.setValues(0, 0, 320);
        final hp = enemy.hp;

        game.world.add(
          FlakShell(spawn: Vector3(0, 0, 280), damage: Tuning.flakDamage),
        );
        await tick(game, 0.5);

        expect(
          enemy.isMounted ? enemy.hp : -1,
          lessThan(hp),
          reason: 'the shell flew straight past a ship it should have fused on',
        );
      },
    );

    testWithGame<NovaGame>(
      'a flak burst takes incoming fire out of the pocket with it',
      () => buildGame(Tuning.flakFirstLevel),
      (game) async {
        await game.ready();
        await tick(game, 2.5);

        // An empty lane, so nothing can refill the pocket mid test.
        for (final enemy in List.of(game.enemies)) {
          enemy.removeFromParent();
        }
        // And a clean board, so only the shots this test parks are counted.
        game.bullets.clear();
        await tick(game, 0.1);

        for (var i = -1; i <= 1; i++) {
          game.bullets.spawn(
            game.world,
            spawn: Vector3(i * 10.0, 0, 300),
            velocityX: 0,
            velocityY: 0,
            velocityZ: 0,
            owner: BulletOwner.enemy,
            damage: 1,
          );
        }
        expect(
          game.bullets.active.where((b) => b.owner == BulletOwner.enemy).length,
          3,
        );

        final shell = FlakShell(
          spawn: Vector3(0, 0, 300),
          damage: Tuning.flakDamage,
        );
        game.world.add(shell);
        await tick(game, 1 / 60);
        shell.burst();
        await tick(game, 2 / 60);

        expect(
          game.bullets.active.where((b) => b.owner == BulletOwner.enemy),
          isEmpty,
          reason: 'the burst left incoming fire standing in the pocket',
        );
      },
    );

    testWithGame<NovaGame>(
      'the ship fires flak on its own once it is fitted',
      () => buildGame(Tuning.flakFirstLevel),
      (game) async {
        await game.ready();
        var seen = false;
        for (var i = 0; i < (Tuning.flakInterval + 0.4) * 60; i++) {
          game.update(1 / 60);
          await Future<void>.delayed(Duration.zero);
          seen = seen || game.world.children.whereType<FlakShell>().isNotEmpty;
        }
        expect(seen, isTrue, reason: 'no shell ever left the cannon');
      },
    );

    testWithGame<NovaGame>(
      'the wing pods put fire out to either side of the lane',
      () => buildGame(Tuning.podFirstLevel),
      (game) async {
        await game.ready();
        game.player.position.setValues(0, 0, 0);
        await tick(game, Tuning.podInterval + 0.2);

        // Wide of the cannon, but running parallel to it. The pods used to
        // splay outward, which put two permanent diagonals either side of the
        // ship. The coverage now comes from where they sit, not where they
        // point.
        final wide = game.bullets.active.where(
          (bullet) =>
              bullet.owner == BulletOwner.player &&
              bullet.position.x.abs() > Tuning.podOffset * 0.8,
        );
        expect(
          wide.length,
          greaterThanOrEqualTo(2),
          reason: 'the pods are firing from the middle like the cannon',
        );
        expect(
          wide.any((bullet) => bullet.position.x < 0),
          isTrue,
          reason: 'both pods should fire, not just one',
        );
        for (final bullet in wide) {
          expect(
            bullet.velocity.x.abs(),
            lessThan(0.001),
            reason: 'a pod shot is angled rather than straight',
          );
        }
      },
    );

    testWithGame<NovaGame>(
      'the arc coil reaches something no gun on the ship points at',
      () => buildGame(Tuning.arcFirstLevel),
      (game) async {
        await game.ready();
        await tick(game, 1.5);
        expect(game.enemies, isNotEmpty);

        final enemy = game.enemies.first;
        for (final other in List.of(game.enemies)) {
          if (other != enemy) {
            other.removeFromParent();
          }
        }
        // Behind the ship. Every other weapon fires up the lane, so anything
        // that happens back here can only have been the coil.
        final hp = enemy.hp;
        for (var i = 0; i < (Tuning.arcInterval + 0.5) * 60; i++) {
          enemy.position.setValues(0, 0, -40);
          game.update(1 / 60);
          await Future<void>.delayed(Duration.zero);
        }

        expect(enemy.isMounted ? enemy.hp : -1, lessThan(hp));
      },
    );

    testWithGame<NovaGame>(
      'the coil does not reach past its own range',
      () => buildGame(Tuning.arcFirstLevel),
      (game) async {
        await game.ready();
        await tick(game, 1.5);
        expect(game.enemies, isNotEmpty);

        final enemy = game.enemies.first;
        for (final other in List.of(game.enemies)) {
          if (other != enemy) {
            other.removeFromParent();
          }
        }
        final hp = enemy.hp;
        // Behind the ship and out to the side: further off than the coil can
        // reach, but still well inside the lane so nothing culls it.
        for (var i = 0; i < (Tuning.arcInterval + 0.5) * 60; i++) {
          enemy.position.setValues(110, 0, -70);
          game.update(1 / 60);
          await Future<void>.delayed(Duration.zero);
        }

        expect(enemy.isMounted, isTrue);
        expect(enemy.hp, hp);
      },
    );

    test('every weapon announces itself on the level it is fitted', () {
      final announced = <String>{};
      for (var level = 1; level <= Tuning.totalLevels; level++) {
        final label = Tuning.armamentAt(level);
        if (label.isEmpty) {
          continue;
        }
        expect(
          announced.add(label),
          isTrue,
          reason: '$label is announced more than once',
        );
      }
      expect(announced.length, 5);
      expect(Tuning.armamentAt(2), isEmpty);
    });

    testWithGame<NovaGame>(
      'an ordnance tier improves every weapon on the rack',
      () => buildGame(1),
      (game) async {
        await game.ready();
        final progress = game.progress;
        final before = [
          progress.flakInterval,
          progress.podInterval,
          progress.arcInterval,
        ];
        final beforeDamage = [
          progress.flakDamage,
          progress.podDamage,
          progress.arcDamage,
        ];

        await progress.addCoins(9999);
        expect(progress.buyUpgrade(UpgradeId.ordnance), isTrue);

        expect(progress.flakInterval, lessThan(before[0]));
        expect(progress.podInterval, lessThan(before[1]));
        expect(progress.arcInterval, lessThan(before[2]));
        expect(progress.flakDamage, greaterThan(beforeDamage[0]));
        expect(progress.podDamage, greaterThan(beforeDamage[1]));
        expect(progress.arcDamage, greaterThan(beforeDamage[2]));
      },
    );
  });

  group('impact', () {
    testWithGame<NovaGame>(
      'a dead ship leaves its own hull behind in pieces',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, 2.5);
        expect(game.enemies, isNotEmpty);

        game.enemies.first.destroy(byPlayer: true);
        await tick(game, 0.05);

        expect(
          game.world.children.query<Debris>(),
          isNotEmpty,
          reason: 'the wreck was a puff of particles and nothing else',
        );
      },
    );

    testWithGame<NovaGame>('wreckage clears itself up', () => buildGame(1), (
      game,
    ) async {
      await game.ready();
      await tick(game, 2.5);
      game.enemies.first.destroy(byPlayer: true);
      await tick(game, Metrics.debrisLifespan + 0.3);

      expect(game.world.children.query<Debris>(), isEmpty);
    });

    testWithGame<NovaGame>(
      'losing a life freezes the world for a beat',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, 1);
        expect(game.world.timeScale, 1);

        game.player.takeHit();
        game.update(1 / 60);

        expect(
          game.world.timeScale,
          lessThan(1),
          reason: 'the hit landed without the world noticing',
        );
      },
    );

    testWithGame<NovaGame>(
      'the freeze lets go on its own',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, 1);
        game.player.takeHit();
        await tick(game, Metrics.hitStopPlayer + 0.2);

        expect(game.world.timeScale, 1);
      },
    );

    testWithGame<NovaGame>(
      'a scout popping never freezes the world',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, 2.5);
        final scout = game.enemies.firstWhere(
          (enemy) => enemy.stats.baseHp < Tuning.hitStopHpThreshold,
        );

        scout.destroy(byPlayer: true);
        game.update(1 / 60);

        expect(
          game.world.timeScale,
          1,
          reason: 'the game would stutter on every kill in a wave',
        );
      },
    );
  });

  group('the run home', () {
    testWithGame<NovaGame>(
      'a won level runs a victory lap before the sheet',
      () => buildGame(1),
      (game) async {
        await game.ready();
        // Fought all the way to the floor, because that is when a level is
        // allowed to start its run home.
        await clearingTick(game, RunnerTuning.minLevelDuration + 3);

        expect(game.runner.isOutro, isTrue);
        expect(
          game.status,
          GameStatus.playing,
          reason: 'the sheet appeared before the lap had run',
        );
      },
    );

    testWithGame<NovaGame>(
      'the lap pays out coins that do not count against the star',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await tick(game, 2);
        for (final enemy in List.of(game.enemies)) {
          enemy.destroy(byPlayer: true);
        }
        final spawnedBefore = game.coinsSpawned;
        await tick(game, 3);

        expect(game.world.children.query<CoinPickup>(), isNotEmpty);
        expect(
          game.coinsSpawned,
          spawnedBefore,
          reason:
              'bonus coins were counted against the collect every coin star',
        );
      },
    );

    testWithGame<NovaGame>(
      'nothing is left in the lane to kill the player after they have won',
      () => buildGame(12),
      (game) async {
        await game.ready();
        // Level 12 runs more than one wave, so keep clearing until the runner
        // says the level is won.
        for (var i = 0; i < 40 && !game.runner.isOutro; i++) {
          await tick(game, 1);
          for (final enemy in List.of(game.enemies)) {
            enemy.destroy(byPlayer: true);
          }
        }
        await tick(game, 2);

        expect(game.runner.isOutro, isTrue);
        expect(game.obstacles, isEmpty);
        expect(
          game.bullets.active.where((b) => b.owner == BulletOwner.enemy),
          isEmpty,
        );
      },
    );

    testWithGame<NovaGame>(
      'the warp runs and then hands over to the sheet',
      () => buildGame(1),
      (game) async {
        await game.ready();
        await clearingTick(game, RunnerTuning.minLevelDuration + 1);

        // Part way through the warp the field is streaming and the ship is
        // pulling away down the lane.
        await tick(game, 2 + RunnerTuning.bonusRunDuration);
        expect(game.warpFactor, greaterThan(0));
        expect(game.player.position.z, greaterThan(PlayArea.playerDepth));

        await tick(game, RunnerTuning.warpDuration + 0.5);
        expect(game.status, GameStatus.complete);
        expect(game.warpFactor, 0);
      },
    );
  });

  group('ships', () {
    testWithGame<NovaGame>(
      'the hull the player chose changes what the ship can do',
      () => buildGame(1),
      (game) async {
        await game.ready();
        final progress = game.progress;
        final baseInterval = progress.fireInterval;
        final baseDamage = progress.bulletDamage;

        await progress.addCoins(99999);
        expect(await progress.buyShip(ShipId.interceptor), isTrue);
        await progress.selectShip(ShipId.interceptor);

        expect(progress.fireInterval, lessThan(baseInterval));
        expect(
          progress.bulletDamage,
          lessThan(baseDamage),
          reason: 'the interceptor is meant to trade damage for rate',
        );

        await progress.buyShip(ShipId.bulwark);
        await progress.selectShip(ShipId.bulwark);
        expect(progress.bulletDamage, greaterThan(baseDamage));
        expect(progress.lives, greaterThan(Tuning.playerLives));

        await progress.selectShip(ShipCatalog.starter);
      },
    );

    testWithGame<NovaGame>(
      'a hull that has not been bought cannot be flown',
      () => buildGame(1),
      (game) async {
        await game.ready();
        final progress = game.progress;
        await progress.resetProgress();

        await progress.selectShip(ShipId.bulwark);
        expect(progress.shipId, ShipCatalog.starter);
      },
    );
  });

  group('endless', () {
    testWithGame<NovaGame>(
      'a finished level rolls into the next without a sheet',
      () => buildEndless(1),
      (game) async {
        await game.ready();
        await clearingTick(game, _throughLevel);

        expect(game.levelNumber, 2);
        expect(game.status, GameStatus.playing);
        expect(
          game.overlays.isActive(NovaGame.levelCompleteOverlay),
          isFalse,
          reason: 'an endless run should never stop for a sheet',
        );
        expect(game.endlessScore, greaterThan(0));
      },
    );

    testWithGame<NovaGame>(
      'lives carry across levels rather than being handed back',
      () => buildEndless(1),
      (game) async {
        await game.ready();
        await tick(game, 1);
        game.onPlayerHit();
        final left = game.lives;

        await game.startLevel(2, carryOver: true);
        expect(game.lives, left);
      },
    );

    testWithGame<NovaGame>(
      'the run ends when the lives do, and the score is banked',
      () => buildEndless(1),
      (game) async {
        await game.ready();
        await tick(game, 1);
        game.endlessScore = 500;

        for (var i = 0; i < 10; i++) {
          game.onPlayerHit();
        }

        expect(game.status, GameStatus.failed);
        expect(game.progress.endlessBest, greaterThanOrEqualTo(500));
      },
    );
  });

  group('objective levels', () {
    test('every kind turns up in the first few hundred levels', () {
      final seen = <LevelKind>{};
      for (var level = 1; level <= 200; level++) {
        seen.add(Tuning.kindOf(level));
      }
      expect(seen, contains(LevelKind.survival));
      expect(seen, contains(LevelKind.escort));
      expect(seen, contains(LevelKind.gate));
    });

    test('the tutorial levels are always plain', () {
      for (var level = 1; level < Tuning.objectiveFirstLevel; level++) {
        expect(
          Tuning.kindOf(level),
          anyOf(LevelKind.normal, LevelKind.elite, LevelKind.boss),
          reason: 'level $level should not be an objective level',
        );
      }
    });

    testWithGame<NovaGame>(
      'a survival level runs on a clock instead of a wave list',
      () => buildGame(levelOfKind(LevelKind.survival)),
      (game) async {
        await game.ready();
        await tick(game, 2);

        expect(game.spec.kind, LevelKind.survival);
        expect(game.objectiveNotifier.value, 'SURVIVE');
        expect(game.survivalNotifier.value, greaterThan(0));
        expect(
          game.survivalNotifier.value,
          lessThan(Tuning.survivalDuration),
          reason: 'the clock is not running down',
        );
      },
    );

    testWithGame<NovaGame>(
      'an escort level sends a freighter across the lane',
      () => buildGame(levelOfKind(LevelKind.escort)),
      (game) async {
        await game.ready();
        await tick(game, 2);

        expect(game.freighter, isNotNull);
        expect(game.escortNotifier.value, greaterThan(0));

        final freighter = game.freighter!;
        final before = freighter.position.z;
        await tick(game, 1);
        expect(freighter.position.z, lessThan(before));
      },
    );

    testWithGame<NovaGame>(
      'losing the freighter loses the level',
      () => buildGame(levelOfKind(LevelKind.escort)),
      (game) async {
        await game.ready();
        await tick(game, 2);
        game.freighter!.destroy();
        await tick(game, 0.5);

        expect(game.status, GameStatus.failed);
      },
    );

    testWithGame<NovaGame>(
      'a gate level opens a gate once the waves are done',
      () => buildGame(levelOfKind(LevelKind.gate)),
      (game) async {
        await game.ready();
        // The ring is held back until the level has reached its floor, so this
        // fights through the waves that fill that time rather than waiting on
        // the first lull.
        for (var i = 0; i < 60 && game.gate == null; i++) {
          await clearingTick(game, 1);
        }

        expect(game.gate, isNotNull);
        expect(
          game.runner.isOutro,
          isFalse,
          reason: 'the level ended without the player flying through',
        );

        // Fly into it, which is the only way a gate level finishes. The ship
        // is flown there rather than teleported, because easing toward a
        // target is what it actually does.
        game.player.aimAt(
          Vector3(0, 0, Tuning.gateRestDepth - Tuning.playerTouchOffsetZ),
        );
        await tick(game, 2);

        expect(game.runner.isOutro, isTrue);
      },
    );
  });

  group('accessibility', () {
    testWithGame<NovaGame>(
      'reduce shake holds the camera still',
      () => buildGame(1),
      (game) async {
        await game.ready();
        game.shake.reduced = true;
        game.shake.shake(Metrics.shakeAmplitudeLarge, 1);
        expect(game.shake.isShaking, isFalse);

        game.shake.reduced = false;
        game.shake.shake(Metrics.shakeAmplitudeLarge, 1);
        expect(game.shake.isShaking, isTrue);
      },
    );
  });

  group("obstacles", () {
    testWithGame<NovaGame>(
      'drift into the lane on levels that have a debris field',
      () => buildGame(_levelWithObstacles()),
      (game) async {
        await game.ready();
        expect(game.spec.hasObstacles, isTrue);

        // A rock crosses the whole lane in a few seconds, so this watches for
        // one arriving rather than looking once after the fact.
        var seen = false;
        for (var i = 0; i < (game.spec.obstacleRate * 2 + 1) * 60; i++) {
          game.update(1 / 60);
          await Future<void>.delayed(Duration.zero);
          seen = seen || game.obstacles.isNotEmpty;
        }
        expect(seen, isTrue);
      },
    );

    testWithGame<NovaGame>(
      'break apart under fire and pay out for it',
      () => buildGame(_levelWithObstacles()),
      (game) async {
        await game.ready();
        final rock = Obstacle(spawn: Vector3(0, 0, 400), hp: 20, shape: 1);
        await game.world.add(rock);
        await tick(game, 0.05);

        final score = game.score;
        rock.takeDamage(rock.hp + 1);
        await tick(game, 0.1);

        expect(rock.isMounted, isFalse);
        expect(game.score, greaterThan(score));
      },
    );

    testWithGame<NovaGame>(
      'stop a bullet the same way an enemy does',
      () => buildGame(_levelWithObstacles()),
      (game) async {
        await game.ready();
        final rock = Obstacle(spawn: Vector3(0, 0, 300), hp: 40, shape: 2);
        await game.world.add(rock);
        await tick(game, 0.05);
        final startHp = rock.hp;

        game.bullets.spawn(
          game.world,
          spawn: Vector3(0, 0, 260),
          velocityX: 0,
          velocityY: 0,
          velocityZ: 1600,
          owner: BulletOwner.player,
          damage: 4,
        );
        await tick(game, 0.1);

        expect(rock.isMounted ? rock.hp : -1, lessThan(startHp));
      },
    );

    testWithGame<NovaGame>(
      'never appear in the tutorial levels',
      () => buildGame(1),
      (game) async {
        await game.ready();
        expect(game.spec.hasObstacles, isFalse);
        await tick(game, 6);
        expect(game.obstacles, isEmpty);
      },
    );
  });
}

/// The first level that carries a debris field, so the tests do not have to
/// guess at one.
int _levelWithObstacles() {
  for (var level = Tuning.obstacleFirstLevel; level <= 200; level++) {
    if (LevelGenerator.generate(level).hasObstacles) {
      return level;
    }
  }
  throw StateError('no level generates a debris field');
}

/// Counts what a component actually draws.
///
/// Everything the game paints goes through a canvas, so asking the canvas is
/// the only way to assert on a shape without comparing images. Only the two
/// calls under test are implemented; the rest fall through to nothing.
class _CanvasSpy implements Canvas {
  int circles = 0;
  int lines = 0;

  /// Every turn asked of the canvas, in radians. The renderer only calls this
  /// when a sprite is drawn at an angle, so an empty list means upright.
  final List<double> turns = [];

  @override
  void drawCircle(Offset c, double radius, Paint paint) => circles++;

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => lines++;

  @override
  void rotate(double radians) => turns.add(radians);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
