import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/game/components/power_up.dart';
import 'package:novastrike/game/effects/debris.dart';
import 'package:novastrike/game/render/sprite.dart';
import 'package:novastrike/theme/palette.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

const _a = Color(0xFFFF0000);
const _b = Color(0xFF00FF00);

/// Everything that flies at the player, which all has to face the player.
Map<String, Sprite2D> _enemies() => {
  'scout': Sprites.scout(body: _a, trim: _b),
  'darter': Sprites.darter(body: _a, trim: _b),
  'kamikaze': Sprites.kamikaze(body: _a, trim: _b),
};

Map<String, Sprite2D> _allSprites() => {
  'ship': Sprites.ship(hull: _a, hullDark: _b, accent: _a),
  'ship with a full rack': Sprites.ship(
    hull: _a,
    hullDark: _b,
    accent: _a,
    pods: true,
    canards: true,
    podColor: _b,
  ),
  'weak point': Sprites.weakPoint(hull: _a, hullDark: _b, core: _a, radius: 13),
  ..._enemies(),
  'gunner': Sprites.gunner(body: _a, trim: _b),
  'bomber': Sprites.bomber(body: _a, trim: _b),
  'shielder': Sprites.shielder(body: _a, trim: _b),
  'splitter': Sprites.splitter(body: _a, trim: _b),
  'turret': Sprites.turret(body: _a, trim: _b),
  'missile': Sprites.missile(body: _a, trim: _b, accent: _a),
  'shell': Sprites.shell(body: _a, trim: _b, accent: _a),
  'gem': Sprites.gem(body: _a, trim: _b),
  'capital': Sprites.capital(
    hull: _a,
    hullDark: _b,
    core: _a,
    glow: _b,
    width: 60,
    depth: 40,
  ),
  'asteroid 0': Sprites.asteroid(body: _a, trim: _b, seed: 0),
  'asteroid 1': Sprites.asteroid(body: _a, trim: _b, seed: 1),
  'asteroid 2': Sprites.asteroid(body: _a, trim: _b, seed: 2),
  'asteroid 3': Sprites.asteroid(body: _a, trim: _b, seed: 3),
};

void main() {
  group('sprite', () {
    test('every part is a shape that can actually be filled', () {
      _allSprites().forEach((name, sprite) {
        expect(sprite.parts, isNotEmpty, reason: '$name has nothing in it');
        for (final part in sprite.parts) {
          expect(
            part.points.length,
            greaterThanOrEqualTo(3),
            reason: '$name has a part with fewer than three corners',
          );
          expect(
            _area(part.points),
            greaterThan(0.5),
            reason: '$name has a part with no area, so it draws as nothing',
          );
        }
      });
    });

    test('nothing is so small on screen that it reads as a speck', () {
      _allSprites().forEach((name, sprite) {
        expect(
          sprite.bounds.shortestSide,
          greaterThan(4),
          reason: '$name is too small to make out',
        );
      });
    });

    test('the player points up the lane and the enemies point back at them', () {
      // The shapes are all authored nose forward and turned round by a facing
      // of -1. Getting that flip wrong is invisible in a still and glaring in
      // play, so it is pinned here: the nose is the end that reaches furthest
      // from the middle of the hull.
      expect(
        _pointsUpScreen(Sprites.ship(hull: _a, hullDark: _b, accent: _a)),
        isTrue,
        reason: 'the player ship is flying backwards',
      );
      expect(
        _pointsUpScreen(Sprites.missile(body: _a, trim: _b, accent: _a)),
        isTrue,
        reason: 'the missiles are flying backwards',
      );
      _enemies().forEach((name, sprite) {
        expect(
          _pointsUpScreen(sprite),
          isFalse,
          reason: '$name is flying away from the player',
        );
      });
    });

    test('a hull is built from the parts it is meant to have', () {
      // A wing either side as one plate, the stabilisers, the fuselage, the
      // canopy and the exhaust. If a part goes missing this is what notices.
      expect(Sprites.ship(hull: _a, hullDark: _b, accent: _a).parts.length, 5);
      expect(Sprites.scout(body: _a, trim: _b).parts.length, 5);
    });

    test('a bought ordnance rack shows up on the hull', () {
      final plain = Sprites.ship(hull: _a, hullDark: _b, accent: _a);
      final racked = Sprites.ship(
        hull: _a,
        hullDark: _b,
        accent: _a,
        pods: true,
        canards: true,
        podColor: _b,
      );
      expect(racked.parts.length, greaterThan(plain.parts.length));
    });

    test('a wreck is capped no matter how many corners the hull has', () {
      final hull = Sprites.ship(hull: _a, hullDark: _b, accent: _a);
      var wedges = 0;
      for (final part in hull.parts) {
        wedges += part.points.length;
      }
      expect(wedges, greaterThan(Metrics.debrisMaxPieces));

      final wreck = Debris(source: hull, origin: Vector3.zero());
      expect(wreck.pieceCount, Metrics.debrisMaxPieces);
    });

    test('nothing is painted a colour that vanishes against space', () {
      // A flat sprite has no shading to fall back on, so a fill close to the
      // background is simply invisible in play. That is the one art fault a
      // unit test can catch.
      final sprites = <String, Sprite2D>{
        ..._allSprites(),
        'coin': Sprites.gem(body: Palette.coin, trim: Palette.uiAccentWarm),
        for (final type in PowerUpType.values)
          'gem ${type.name}': Sprites.gem(
            body: type.color,
            trim: Palette.pickupTrim(type.color),
          ),
      };

      sprites.forEach((name, sprite) {
        for (final part in sprite.parts) {
          expect(
            _luminance(part.fill),
            greaterThan(_minLuminance),
            reason: '$name has a part that disappears against the background',
          );
        }
      });
    });
  });
}

/// Whether a hull's nose points up the screen rather than down it.
///
/// The nose is the corner sitting on the centre line furthest from the middle,
/// which is the one place on an airframe that is a point rather than an edge.
/// The whole bounding box will not do: a missile's fins reach further behind it
/// than its nose reaches in front.
bool _pointsUpScreen(Sprite2D sprite) {
  var nose = 0.0;
  for (final part in sprite.parts) {
    for (final point in part.points) {
      if (point.dx.abs() < 1 && point.dy.abs() > nose.abs()) {
        nose = point.dy;
      }
    }
  }
  return nose < 0;
}

/// Twice the area of a polygon, by the shoelace sum.
double _area(List<Offset> points) {
  var sum = 0.0;
  for (var i = 0; i < points.length; i++) {
    final a = points[i];
    final b = points[(i + 1) % points.length];
    sum += a.dx * b.dy - b.dx * a.dy;
  }
  return sum.abs();
}

/// The dimmest a fill may be and still be seen against the background.
const double _minLuminance = 0.045;

/// Perceived brightness of a colour, on the usual weighting.
double _luminance(Color color) =>
    color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722;
