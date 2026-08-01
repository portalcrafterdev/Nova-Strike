import 'dart:math';

import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../levels/difficulty_curve.dart';
import '../../levels/enemy_catalog.dart';
import '../../levels/level_spec.dart';
import '../components/enemy_ship.dart';
import '../nova_game.dart';
import '../world/play_area.dart';
import 'movement_patterns.dart';

/// Turns wave data into components.
///
/// This is the only place that knows how a [WaveSpec] becomes enemies in the
/// world: it reads the catalog for base stats, applies the level multipliers,
/// and lays the wave out in its formation far down the lane.
class Spawner {
  Spawner(this.game, this.spec);

  final NovaGame game;
  final LevelSpec spec;

  final Random _rng = Random(1);

  /// Spawns every enemy in a wave and returns them.
  List<EnemyShip> spawnWave(WaveSpec wave) {
    final stats = EnemyCatalog.of(wave.type);
    final slots = MovementPatterns.formationSlots(wave.formation, wave.count);
    final anchor = PlayArea.entryAnchor(wave.entry);
    final approach = MovementPatterns.entryDirection(wave.entry);

    final hp = stats.baseHp * spec.enemyHpMultiplier;
    final speed = stats.baseSpeed * spec.enemySpeedMultiplier;
    final fireInterval = stats.fireInterval <= 0
        ? 0.0
        : stats.fireInterval / spec.enemyFireRateMultiplier;
    final bulletSpeed =
        Tuning.baseEnemyBulletSpeed * spec.bulletSpeedMultiplier;

    final spawned = <EnemyShip>[];
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final spawn = Vector3(
        _clampSpawnX(anchor.x + slot.x, wave.entry, stats.hitRadius),
        0,
        anchor.z + slot.z + slot.y,
      );
      final enemy = EnemyShip()
        ..configure(
          stats: stats,
          movement: wave.movement,
          bullets: wave.bullets,
          hp: hp,
          speed: speed,
          fireInterval: fireInterval,
          bulletSpeed: bulletSpeed,
          spawn: spawn,
          approachX: approach.x,
          approachY: approach.y,
          approachZ: approach.z,
          phase: _rng.nextDouble() * pi * 2,
          holdDepth: PlayArea.holdDepth + (i % 3) * 40,
          dropsPowerUp: wave.dropsPowerUp && i == slots.length - 1,
        );
      spawned.add(enemy);
      game.world.add(enemy);
    }
    return spawned;
  }

  /// Waves coming straight down the lane are kept inside it, while waves from
  /// a side start outside it on purpose and sweep in.
  double _clampSpawnX(double x, EntrySide side, double margin) {
    if (side != EntrySide.top) {
      return x;
    }
    return PlayArea.clampX(x, margin);
  }
}
