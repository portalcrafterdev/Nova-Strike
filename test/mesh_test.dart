import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/game/components/power_up.dart';
import 'package:novastrike/game/effects/debris.dart';
import 'package:novastrike/game/render3d/mesh.dart';
import 'package:novastrike/theme/palette.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

const _a = Color(0xFFFF0000);
const _b = Color(0xFF00FF00);

Map<String, Mesh> _allMeshes() => {
  'ship': Meshes.ship(hull: _a, hullDark: _b, accent: _a),
  'ship with a full rack': Meshes.ship(
    hull: _a,
    hullDark: _b,
    accent: _a,
    pods: true,
    canards: true,
    podColor: _b,
  ),
  'weak point': Meshes.weakPoint(hull: _a, hullDark: _b, core: _a, radius: 13),
  'scout': Meshes.scout(body: _a, trim: _b),
  'darter': Meshes.darter(body: _a, trim: _b),
  'gunner': Meshes.gunner(body: _a, trim: _b),
  'bomber': Meshes.bomber(body: _a, trim: _b),
  'shielder': Meshes.shielder(body: _a, trim: _b),
  'splitter': Meshes.splitter(body: _a, trim: _b),
  'turret': Meshes.turret(body: _a, trim: _b),
  'kamikaze': Meshes.kamikaze(body: _a, trim: _b),
  'missile': Meshes.missile(body: _a, trim: _b, accent: _a),
  'shell': Meshes.shell(body: _a, trim: _b, accent: _a),
  'gem': Meshes.gem(body: _a, trim: _b),
  'capital': Meshes.capital(
    hull: _a,
    hullDark: _b,
    core: _a,
    glow: _b,
    width: 60,
    height: 22,
    depth: 40,
  ),
  'asteroid 0': Meshes.asteroid(body: _a, trim: _b, seed: 0),
  'asteroid 1': Meshes.asteroid(body: _a, trim: _b, seed: 1),
  'asteroid 2': Meshes.asteroid(body: _a, trim: _b, seed: 2),
  'asteroid 3': Meshes.asteroid(body: _a, trim: _b, seed: 3),
};

void main() {
  group('mesh', () {
    test('every model is wound so its faces point outward', () {
      _allMeshes().forEach((name, mesh) {
        // A surface wound inside out encloses a negative volume.
        var volume = 0.0;
        for (final face in mesh.faces) {
          volume += mesh.vertices[face.a].dot(
            mesh.vertices[face.b].cross(mesh.vertices[face.c]),
          );
        }
        expect(volume, greaterThan(0), reason: '$name is inside out');

        // Neighbours must walk their shared edge in opposite directions.
        final walked = <String>{};
        for (final face in mesh.faces) {
          for (final edge in [
            '${face.a}>${face.b}',
            '${face.b}>${face.c}',
            '${face.c}>${face.a}',
          ]) {
            expect(walked.add(edge), isTrue, reason: '$name repeats $edge');
          }
        }
      });
    });

    test('models are closed, so back faces can be hidden', () {
      _allMeshes().forEach((name, mesh) {
        expect(mesh.closed, isTrue, reason: '$name has a dangling edge');
      });
    });

    test('no model exceeds the renderer buffers', () {
      _allMeshes().forEach((name, mesh) {
        expect(mesh.vertices.length, lessThanOrEqualTo(96), reason: name);
        expect(mesh.triangleCount, lessThanOrEqualTo(160), reason: name);
      });
    });

    test('a hull is built from separate closed parts', () {
      // The airframe is a fuselage, two wings, two fins and a canopy. If a
      // part goes missing or gets welded into its neighbour, this is what
      // notices.
      final hull = Meshes.ship(hull: _a, hullDark: _b, accent: _a);
      expect(_partsOf(hull), 6);
      expect(_partsOf(Meshes.scout(body: _a, trim: _b)), 6);
    });

    test('a wreck is capped no matter how many faces the hull has', () {
      final hull = Meshes.ship(hull: _a, hullDark: _b, accent: _a);
      expect(hull.faces.length, greaterThan(Metrics.debrisMaxPieces));

      final wreck = Debris(source: hull, origin: Vector3.zero());
      expect(wreck.pieceCount, Metrics.debrisMaxPieces);
    });

    test('a bought ordnance rack shows up on the hull', () {
      final plain = Meshes.ship(hull: _a, hullDark: _b, accent: _a);
      final racked = Meshes.ship(
        hull: _a,
        hullDark: _b,
        accent: _a,
        pods: true,
        canards: true,
        podColor: _b,
      );
      expect(_partsOf(racked), greaterThan(_partsOf(plain)));
    });

    test('nothing is painted a colour that vanishes against space', () {
      // A face shaded toward the background rather than toward its own colour
      // is invisible in play, which is the one art fault a unit test can catch.
      final models = <String, Mesh>{
        ..._allMeshes(),
        'coin': Meshes.gem(body: Palette.coin, trim: Palette.uiAccentWarm),
        for (final type in PowerUpType.values)
          'gem ${type.name}': Meshes.gem(
            body: type.color,
            trim: Palette.pickupTrim(type.color),
          ),
      };

      models.forEach((name, mesh) {
        for (final face in mesh.faces) {
          expect(
            _luminance(face.color),
            greaterThan(_minLuminance),
            reason: '$name has a face that disappears against the background',
          );
        }
      });
    });
  });
}

/// How many separate closed shells a model is made of.
///
/// Two faces belong to the same part when they share a vertex, so this walks
/// the model with a union find and counts what is left.
int _partsOf(Mesh mesh) {
  final parent = List<int>.generate(mesh.vertices.length, (i) => i);

  int root(int i) {
    var node = i;
    while (parent[node] != node) {
      node = parent[node];
    }
    return node;
  }

  void join(int x, int y) {
    final rx = root(x);
    final ry = root(y);
    if (rx != ry) {
      parent[rx] = ry;
    }
  }

  for (final face in mesh.faces) {
    join(face.a, face.b);
    join(face.b, face.c);
  }
  return {for (var i = 0; i < parent.length; i++) root(i)}.length;
}

/// The dimmest a face may be and still be seen against the background.
const double _minLuminance = 0.045;

/// Perceived brightness of a colour, on the usual weighting.
double _luminance(Color color) =>
    color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722;
