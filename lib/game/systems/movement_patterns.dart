import 'dart:math' as math;

import '../../levels/difficulty_curve.dart';
import '../../levels/level_spec.dart';

/// A velocity in world units per second.
class Velocity3 {
  const Velocity3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  static const Velocity3 zero = Velocity3(0, 0, 0);
}

/// A spawn offset inside a formation.
///
/// The game is flat, so the y offset is folded into the lane when the wave is
/// created rather than lifting anything out of the plane.
class SpawnSlot {
  const SpawnSlot(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;
}

/// Pure functions describing how enemies fly and how a wave is arranged.
///
/// The world is right handed with z running away from the camera, so an enemy
/// closing on the player has a negative z velocity. Nothing here touches Flame
/// or the camera, so every path can be tested by feeding it numbers.
class MovementPatterns {
  const MovementPatterns._();

  /// Velocity for an enemy at time [t] seconds after it spawned.
  ///
  /// [approach] is the unit vector the wave entered along, [holdDepth] is
  /// where hovering families settle, and the target values are the player
  /// position for the diving families.
  static Velocity3 velocity(
    MovementPattern pattern, {
    required double t,
    required double speed,
    required double phase,
    required double x,
    required double y,
    required double z,
    required double approachX,
    required double approachY,
    required double approachZ,
    required double holdDepth,
    required double targetX,
    required double targetY,
    required double targetZ,
  }) {
    switch (pattern) {
      case MovementPattern.straight:
        return Velocity3(approachX * speed, 0, approachZ * speed);

      case MovementPattern.sine:
        final lateral =
            math.sin(t * MoveTuning.sineFrequency + phase) *
            MoveTuning.sineAmplitude *
            speed;
        return Velocity3(approachX * speed + lateral, 0, approachZ * speed);

      case MovementPattern.zigzag:
        final wave = math.sin(t * MoveTuning.zigzagFrequency + phase);
        final lateral =
            (wave >= 0 ? 1 : -1) * MoveTuning.zigzagAmplitude * speed;
        return Velocity3(approachX * speed + lateral, 0, approachZ * speed);

      case MovementPattern.hover:
        if (z > holdDepth) {
          return Velocity3(approachX * speed, 0, approachZ * speed);
        }
        final strafe =
            math.cos(t * MoveTuning.hoverStrafeFrequency + phase) *
            speed *
            MoveTuning.hoverStrafeSpeed;
        // Weaves, but keeps coming. Holding station forever put the whole wave
        // across the top of the screen where the player could simply wait.
        return Velocity3(strafe, 0, -speed * MoveTuning.hoverCloseSpeed);

      case MovementPattern.swoop:
        final angle = t * MoveTuning.swoopFrequency + phase;
        return Velocity3(
          math.sin(angle) * speed * MoveTuning.swoopLateral,
          0,
          approachZ * speed + math.cos(angle * 1.3) * speed * 0.45,
        );

      case MovementPattern.orbit:
        final angle = t * MoveTuning.orbitAngularSpeed + phase;
        return Velocity3(
          -math.sin(angle) * speed,
          0,
          math.cos(angle) * speed * 0.6 +
              approachZ * speed * MoveTuning.orbitDrift * 2,
        );

      case MovementPattern.dive:
        final dx = targetX - x;
        final dy = targetY - y;
        final dz = targetZ - z;
        final length = math.sqrt(dx * dx + dy * dy + dz * dz);
        final factor = math.min(
          1 + t * MoveTuning.diveAcceleration,
          MoveTuning.diveMaxFactor,
        );
        if (length < 0.001) {
          return Velocity3(0, 0, -speed * factor);
        }
        final scale = speed * factor / length;
        return Velocity3(dx * scale, dy * scale, dz * scale);

      case MovementPattern.hold:
        if (z > holdDepth) {
          final rate = speed == 0 ? 90.0 : speed;
          return Velocity3(0, 0, -rate);
        }
        return Velocity3.zero;

      case MovementPattern.flank:
        // Runs the lane down past the player, swings wide, then comes back up
        // it. The player has to watch behind them, which nothing else in the
        // game asks of them.
        if (z > targetZ - MoveTuning.flankOvershoot) {
          return Velocity3(
            approachX * speed * 0.4,
            0,
            -speed * MoveTuning.flankRunSpeed,
          );
        }
        final swingDone = t > MoveTuning.flankTurnTime;
        if (!swingDone) {
          final side = phase >= 0 ? 1.0 : -1.0;
          return Velocity3(side * speed * MoveTuning.flankSwing, 0, 0);
        }
        return Velocity3(
          (targetX - x).sign * speed * MoveTuning.flankReturnAim,
          0,
          speed * MoveTuning.flankReturnSpeed,
        );

      case MovementPattern.snipe:
        // Sits out at the edge of the lane and never closes. It is not
        // dangerous on its own. It is dangerous because dealing with it means
        // leaving the middle.
        if (z > MoveTuning.snipeDepth) {
          return Velocity3(0, 0, -speed);
        }
        final side = phase >= 0 ? 1.0 : -1.0;
        final target = side * MoveTuning.snipeOffset;
        final drift = (target - x).clamp(-1.0, 1.0);
        return Velocity3(
          drift * speed * MoveTuning.snipeDrift,
          0,
          math.sin(t * MoveTuning.snipeBobRate + phase) *
              speed *
              MoveTuning.snipeBob,
        );

      case MovementPattern.screen:
        // Holds a line further out than anything else, so it has to be shot
        // through rather than gone around.
        if (z > MoveTuning.screenDepth) {
          return Velocity3(0, 0, -speed);
        }
        return Velocity3(
          math.cos(t * MoveTuning.screenSweepRate + phase) *
              speed *
              MoveTuning.screenSweep,
          0,
          0,
        );
    }
  }

  /// Where each enemy of a wave sits relative to the formation anchor.
  static List<SpawnSlot> formationSlots(Formation formation, int count) {
    final slots = <SpawnSlot>[];
    final centre = (count - 1) / 2.0;

    switch (formation) {
      case Formation.line:
        for (var i = 0; i < count; i++) {
          slots.add(SpawnSlot((i - centre) * FormationTuning.spacing, 0, 0));
        }

      case Formation.vee:
        for (var i = 0; i < count; i++) {
          final offset = i - centre;
          slots.add(
            SpawnSlot(
              offset * FormationTuning.spacing,
              0,
              offset.abs() * FormationTuning.depth,
            ),
          );
        }

      case Formation.arc:
        for (var i = 0; i < count; i++) {
          final angle = count == 1
              ? 0.0
              : (i / (count - 1) - 0.5) * FormationTuning.arcSweep;
          slots.add(
            SpawnSlot(
              math.sin(angle) * FormationTuning.arcRadius,
              math.cos(angle) * FormationTuning.arcRadius * 0.25 -
                  FormationTuning.arcRadius * 0.2,
              (1 - math.cos(angle)) * FormationTuning.arcRadius,
            ),
          );
        }

      case Formation.column:
        for (var i = 0; i < count; i++) {
          slots.add(SpawnSlot(0, 0, i * FormationTuning.depth));
        }

      case Formation.pincer:
        for (var i = 0; i < count; i++) {
          final side = i.isEven ? -1 : 1;
          final rank = i ~/ 2;
          slots.add(
            SpawnSlot(
              side * FormationTuning.pincerGap / 2,
              0,
              rank * FormationTuning.depth,
            ),
          );
        }

      case Formation.sweep:
        for (var i = 0; i < count; i++) {
          final offset = i - centre;
          slots.add(
            SpawnSlot(
              offset * FormationTuning.spacing,
              offset * FormationTuning.spacing * FormationTuning.sweepSlope,
              offset.abs() * FormationTuning.depth * 0.5,
            ),
          );
        }

      case Formation.spiral:
        for (var i = 0; i < count; i++) {
          final angle = i * FormationTuning.spiralTurn;
          final radius = FormationTuning.spiralRadius * (1 + i * 0.35);
          slots.add(
            SpawnSlot(
              math.cos(angle) * radius,
              math.sin(angle) * radius * 0.6,
              i * FormationTuning.depth * 0.6,
            ),
          );
        }
    }
    return slots;
  }

  /// Unit vector of travel for an entry side.
  static Velocity3 entryDirection(EntrySide side) {
    switch (side) {
      case EntrySide.top:
        return const Velocity3(0, 0, -1);
      case EntrySide.left:
        return const Velocity3(0.55, 0, -0.83);
      case EntrySide.right:
        return const Velocity3(-0.55, 0, -0.83);
    }
  }
}
