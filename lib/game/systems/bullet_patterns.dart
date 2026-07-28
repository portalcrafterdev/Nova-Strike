import 'dart:math' as math;

import '../../levels/difficulty_curve.dart';
import '../../levels/level_spec.dart';

/// One bullet about to be fired, in plain numbers.
///
/// The spawner turns these into components. Keeping the maths free of Flame
/// and of the camera means every pattern can be tested without a game loop.
class Shot {
  const Shot({
    required this.offsetX,
    required this.offsetY,
    required this.offsetZ,
    required this.velocityX,
    required this.velocityY,
    required this.velocityZ,
    this.waveAmplitude = 0,
    this.waveFrequency = 0,
  });

  /// Spawn offset from the firing point, in world units.
  final double offsetX;
  final double offsetY;
  final double offsetZ;

  /// Travel velocity in world units per second.
  final double velocityX;
  final double velocityY;
  final double velocityZ;

  /// Sideways oscillation applied by the bullet as it travels.
  final double waveAmplitude;
  final double waveFrequency;
}

/// Pure functions that turn a [BulletPattern] into a list of [Shot]s.
///
/// This file owns the shape of every attack. It holds no state, so the same
/// inputs always produce the same shots.
class BulletPatterns {
  const BulletPatterns._();

  /// Shots produced by one trigger of [pattern].
  ///
  /// The aim vector points from the shooter toward the player and does not
  /// need to be normalised.
  static List<Shot> shotsFor(
    BulletPattern pattern, {
    required double aimX,
    required double aimY,
    required double aimZ,
    required double speed,
    double phase = 0,
    int burstIndex = 0,
  }) {
    final length = math.sqrt(aimX * aimX + aimY * aimY + aimZ * aimZ);
    final dirX = length < 0.001 ? 0.0 : aimX / length;
    final dirY = length < 0.001 ? 0.0 : aimY / length;
    final dirZ = length < 0.001 ? -1.0 : aimZ / length;

    switch (pattern) {
      case BulletPattern.none:
        return const <Shot>[];

      case BulletPattern.aimedSingle:
        return [_along(dirX, dirY, dirZ, speed)];

      case BulletPattern.spread3:
        return [
          _yawed(dirX, dirY, dirZ, speed, -BulletTuning.spreadAngle),
          _along(dirX, dirY, dirZ, speed),
          _yawed(dirX, dirY, dirZ, speed, BulletTuning.spreadAngle),
        ];

      case BulletPattern.waveShot:
        final shot = _along(dirX, dirY, dirZ, speed);
        return [
          Shot(
            offsetX: shot.offsetX,
            offsetY: shot.offsetY,
            offsetZ: shot.offsetZ,
            velocityX: shot.velocityX,
            velocityY: shot.velocityY,
            velocityZ: shot.velocityZ,
            waveAmplitude: BulletTuning.waveAmplitude,
            waveFrequency: BulletTuning.waveFrequency,
          ),
        ];

      case BulletPattern.ringBurst:
        return _ring(
          dirX,
          dirY,
          dirZ,
          speed,
          BulletTuning.ringCount,
          phase * BulletTuning.spiralAngularStep,
        );

      case BulletPattern.aimedBurst3:
        // One shot per trigger. The shooter repeats the trigger, so the burst
        // walks a little with each shot.
        final drift = (burstIndex - 1) * BulletTuning.spreadAngle * 0.4;
        return [_yawed(dirX, dirY, dirZ, speed, drift)];

      case BulletPattern.spiralShot:
        return _ring(
          dirX,
          dirY,
          dirZ,
          speed,
          BulletTuning.spiralArms,
          phase * BulletTuning.spiralAngularStep,
        );
    }
  }

  /// How many times a pattern triggers per firing cycle.
  static int burstCount(BulletPattern pattern) {
    return pattern == BulletPattern.aimedBurst3 ? BulletTuning.burstCount : 1;
  }

  /// Gap between the shots of a burst, in seconds.
  static double burstInterval(BulletPattern pattern) {
    return pattern == BulletPattern.aimedBurst3
        ? BulletTuning.burstInterval
        : 0;
  }

  /// Shots for the player, which always fly straight down the lane.
  ///
  /// [streams] comes from upgrades and the double shot gem, [spread] is true
  /// while the spread gem is running.
  static List<Shot> playerShots({
    required int streams,
    required bool spread,
    required double speed,
    required double streamOffset,
  }) {
    final shots = <Shot>[];
    if (spread) {
      for (var i = -1; i <= 1; i++) {
        shots.add(
          Shot(
            offsetX: 0,
            offsetY: 0,
            offsetZ: BulletTuning.muzzleOffset,
            velocityX: math.sin(i * Tuning.spreadAngle) * speed,
            velocityY: 0,
            velocityZ: math.cos(i * Tuning.spreadAngle) * speed,
          ),
        );
      }
    }
    final count = math.max(1, streams);
    final start = -(count - 1) / 2.0;
    for (var i = 0; i < count; i++) {
      shots.add(
        Shot(
          offsetX: (start + i) * streamOffset,
          offsetY: 0,
          offsetZ: BulletTuning.muzzleOffset,
          velocityX: 0,
          velocityY: 0,
          velocityZ: speed,
        ),
      );
    }
    return shots;
  }

  /// The two wing pod bolts, angled out to either side.
  ///
  /// The main cannon only ever covers the column straight ahead of the ship.
  /// These cover the ground either side of it, which is where anything holding
  /// station at the edge of the lane sits.
  static List<Shot> podShots({
    required double angle,
    required double offset,
    required double speed,
  }) {
    return [
      for (final side in const [-1.0, 1.0])
        Shot(
          offsetX: side * offset,
          offsetY: 0,
          offsetZ: BulletTuning.muzzleOffset,
          velocityX: math.sin(side * angle) * speed,
          velocityY: 0,
          velocityZ: math.cos(angle) * speed,
        ),
    ];
  }

  static Shot _along(double dx, double dy, double dz, double speed) {
    return Shot(
      offsetX: dx * BulletTuning.muzzleOffset,
      offsetY: dy * BulletTuning.muzzleOffset,
      offsetZ: dz * BulletTuning.muzzleOffset,
      velocityX: dx * speed,
      velocityY: dy * speed,
      velocityZ: dz * speed,
    );
  }

  /// The aim direction turned about the vertical axis.
  static Shot _yawed(
    double dx,
    double dy,
    double dz,
    double speed,
    double angle,
  ) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    return _along(dx * cos + dz * sin, dy, dz * cos - dx * sin, speed);
  }

  /// Shots spread evenly all the way around the shooter.
  ///
  /// The game is flat, so a ring is a ring in the plane the player can see:
  /// every arm leaves at the same speed and opposite arms cancel. The aim
  /// direction is deliberately ignored, because a ring that leans is a fan.
  static List<Shot> _ring(
    double dx,
    double dy,
    double dz,
    double speed,
    int count,
    double offset,
  ) {
    final shots = <Shot>[];
    final step = math.pi * 2 / count;
    for (var i = 0; i < count; i++) {
      final angle = offset + step * i;
      final armX = math.sin(angle);
      final armZ = -math.cos(angle);
      shots.add(
        Shot(
          offsetX: armX * BulletTuning.muzzleOffset,
          offsetY: 0,
          offsetZ: armZ * BulletTuning.muzzleOffset,
          velocityX: armX * speed,
          velocityY: 0,
          velocityZ: armZ * speed,
        ),
      );
    }
    return shots;
  }
}
