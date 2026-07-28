import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/game/systems/bullet_patterns.dart';
import 'package:novastrike/game/systems/movement_patterns.dart';
import 'package:novastrike/levels/difficulty_curve.dart';
import 'package:novastrike/levels/level_spec.dart';

double speedOf(Shot shot) {
  return math.sqrt(
    shot.velocityX * shot.velocityX +
        shot.velocityY * shot.velocityY +
        shot.velocityZ * shot.velocityZ,
  );
}

void main() {
  group('bullet patterns', () {
    List<Shot> fire(BulletPattern pattern, {double phase = 0}) {
      // The shooter is down the lane, the player is at the origin, so the aim
      // vector points back toward the camera.
      return BulletPatterns.shotsFor(
        pattern,
        aimX: 0,
        aimY: 0,
        aimZ: -400,
        speed: 200,
        phase: phase,
      );
    }

    test('every pattern produces shots except none', () {
      for (final pattern in BulletPattern.values) {
        final shots = fire(pattern);
        if (pattern == BulletPattern.none) {
          expect(shots, isEmpty);
        } else {
          expect(shots, isNotEmpty, reason: '$pattern produced no shots');
        }
      }
    });

    test('aimed fire travels toward the player', () {
      // The ring patterns are deliberately not aimed: they fire all the way
      // around the shooter, so some arms leave up the lane by design.
      const rings = {BulletPattern.ringBurst, BulletPattern.spiralShot};
      for (final pattern in BulletPattern.values) {
        if (pattern == BulletPattern.none || rings.contains(pattern)) {
          continue;
        }
        for (final shot in fire(pattern)) {
          expect(
            shot.velocityZ,
            lessThan(0),
            reason: '$pattern fired away from the player',
          );
        }
      }
    });

    test('a ring still puts an arm on the player', () {
      for (final pattern in [
        BulletPattern.ringBurst,
        BulletPattern.spiralShot,
      ]) {
        final shots = fire(pattern);
        expect(
          shots.where((shot) => shot.velocityZ < 0),
          isNotEmpty,
          reason: '$pattern never fired anything toward the player',
        );
      }
    });

    test('an aimed shot flies straight down the lane at full speed', () {
      final shot = fire(BulletPattern.aimedSingle).single;
      expect(shot.velocityZ, closeTo(-200, 0.001));
      expect(shot.velocityX, closeTo(0, 0.001));
      expect(speedOf(shot), closeTo(200, 0.001));
    });

    test('a spread fans out to both sides', () {
      final shots = fire(BulletPattern.spread3);
      expect(shots.length, 3);
      expect(shots[1].velocityX, closeTo(0, 0.001));
      expect(shots.first.velocityX * shots.last.velocityX, lessThan(0));
    });

    test('a ring burst opens evenly around the aim', () {
      final shots = fire(BulletPattern.ringBurst);
      expect(shots.length, BulletTuning.ringCount);
      final first = speedOf(shots.first);
      for (final shot in shots) {
        expect(speedOf(shot), closeTo(first, 0.001));
      }
      // Opposite arms of the ring cancel out.
      var sumX = 0.0;
      var sumZ = 0.0;
      for (final shot in shots) {
        sumX += shot.velocityX;
        sumZ += shot.velocityZ;
      }
      expect(sumX, closeTo(0, 0.001));
      expect(sumZ, closeTo(0, 0.001));
    });

    test('a spiral advances with the shooter clock', () {
      final first = fire(BulletPattern.spiralShot).first;
      final later = fire(BulletPattern.spiralShot, phase: 1).first;
      expect(first.velocityX, isNot(closeTo(later.velocityX, 0.01)));
    });

    test('only the aimed burst fires more than once per cycle', () {
      for (final pattern in BulletPattern.values) {
        final expected = pattern == BulletPattern.aimedBurst3
            ? BulletTuning.burstCount
            : 1;
        expect(BulletPatterns.burstCount(pattern), expected);
      }
    });

    test('the player fires up the lane, one stream per upgrade', () {
      final plain = BulletPatterns.playerShots(
        streams: 2,
        spread: false,
        speed: 600,
        streamOffset: 9,
      );
      expect(plain.length, 2);
      for (final shot in plain) {
        expect(shot.velocityZ, closeTo(600, 0.001));
        expect(shot.velocityY, closeTo(0, 0.001));
      }
      expect(plain.first.offsetX, isNot(closeTo(plain.last.offsetX, 0.01)));

      final spread = BulletPatterns.playerShots(
        streams: 2,
        spread: true,
        speed: 600,
        streamOffset: 9,
      );
      expect(spread.length, 5);
    });
  });

  group('movement patterns', () {
    Velocity3 sample(
      MovementPattern pattern, {
      double t = 0.5,
      double z = 500,
    }) {
      return MovementPatterns.velocity(
        pattern,
        t: t,
        speed: 100,
        phase: 0.3,
        x: 10,
        y: 5,
        z: z,
        approachX: 0,
        approachY: 0,
        approachZ: -1,
        holdDepth: 300,
        targetX: 0,
        targetY: 0,
        targetZ: 0,
      );
    }

    test('straight movement closes on the player', () {
      final velocity = sample(MovementPattern.straight);
      expect(velocity.x, closeTo(0, 0.001));
      expect(velocity.z, closeTo(-100, 0.001));
    });

    test('sine and zigzag add sideways travel', () {
      expect(sample(MovementPattern.sine).x.abs(), greaterThan(0));
      expect(sample(MovementPattern.zigzag).x.abs(), greaterThan(0));
    });

    test('hovering families weave, but they never stop closing', () {
      final approach = sample(MovementPattern.hover, z: 600);
      final arrived = sample(MovementPattern.hover, z: 200);

      expect(approach.z, lessThan(0));
      // The whole point of the change: it slows down when it arrives, it does
      // not park. A wave that holds station across the top of the screen is a
      // wave the player waits out rather than fights.
      expect(arrived.z, lessThan(0));
      expect(arrived.z.abs(), lessThan(approach.z.abs()));
    });

    test('turrets stop once they reach their station', () {
      final holding = sample(MovementPattern.hold, z: 200);
      expect(holding.x, 0);
      expect(holding.z, 0);
    });

    test('divers accelerate toward the player', () {
      final early = sample(MovementPattern.dive, t: 0);
      final late = sample(MovementPattern.dive, t: 4);
      expect(late.z.abs(), greaterThan(early.z.abs()));
      expect(late.z.abs(), lessThanOrEqualTo(100 * MoveTuning.diveMaxFactor));
    });

    test('every formation lays out one slot per enemy', () {
      for (final formation in Formation.values) {
        for (final count in [1, 2, 5, 12]) {
          final slots = MovementPatterns.formationSlots(formation, count);
          expect(slots.length, count, reason: '$formation with $count');
          for (final slot in slots) {
            expect(slot.x.isFinite, isTrue);
            expect(slot.y.isFinite, isTrue);
            expect(slot.z.isFinite, isTrue);
          }
        }
      }
    });

    test('every entry direction closes on the player', () {
      for (final side in EntrySide.values) {
        expect(MovementPatterns.entryDirection(side).z, lessThan(0));
      }
      expect(MovementPatterns.entryDirection(EntrySide.left).x, greaterThan(0));
      expect(MovementPatterns.entryDirection(EntrySide.right).x, lessThan(0));
    });
  });
}
