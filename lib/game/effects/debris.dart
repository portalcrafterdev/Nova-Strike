import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart' hide Vector3;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../theme/palette.dart';
import '../nova_game.dart';
import '../render/camera.dart';
import '../render/sprite.dart';
import '../render/sprite_renderer.dart';
import '../render/scene.dart';

/// What is left of a ship after it dies: its own hull, in pieces.
///
/// The sprite that was on screen a frame ago is cut into wedges and each one is
/// thrown outward, turning, in the colour it already had. Nothing new is
/// authored for this. A puff of particles says something happened; a hull
/// coming apart says what happened to it.
class Debris extends Component with Renderable, HasGameReference<NovaGame> {
  Debris({
    required Sprite2D source,
    required Vector3 origin,
    this.scale = 1,
    this.lifespan = Metrics.debrisLifespan,
    double spread = Metrics.debrisSpread,
    Vector3? inherited,
    int seed = 0,
  }) : _origin = origin.clone(),
       _shards = _shardsOf(source) {
    final rng = Random(seed == 0 ? source.parts.length * 31 : seed);
    for (var i = 0; i < _shards.pieces.length; i++) {
      final offset = _shards.offsets[i];

      // Each piece starts where it sat on the hull and leaves along the line
      // out from the middle, which is what makes the break read as a break
      // rather than a scatter.
      _positions.add(
        Vector3(
          origin.x + offset.dx * scale,
          origin.y,
          origin.z + offset.dy * scale,
        ),
      );

      final push = spread * (0.55 + rng.nextDouble() * 0.9);
      final length = offset.distance;
      final outX = length > 0.001 ? offset.dx / length : rng.nextDouble() - 0.5;
      final outZ = length > 0.001 ? offset.dy / length : rng.nextDouble() - 0.5;
      _velocities.add(
        Vector3(
          outX * push + (inherited?.x ?? 0) * Metrics.debrisInherit,
          0,
          outZ * push + (inherited?.z ?? 0) * Metrics.debrisInherit,
        ),
      );

      _angles.add(0);
      _spins.add((rng.nextDouble() * 2 - 1) * Metrics.debrisSpin);
    }
  }

  /// One wedge of a sprite taken on its own, plus where it sat on the hull.
  ///
  /// The pieces are cut once per sprite and shared by every wreck of it, so a
  /// screen full of dying scouts costs one set of wedges.
  static final Map<Sprite2D, _Shards> _cache = {};

  static _Shards _shardsOf(Sprite2D source) {
    return _cache.putIfAbsent(source, () {
      // Every part is fanned into wedges about its own middle. A wing comes
      // apart into slivers along its length, a drum into segments, which is
      // what a hull tearing rather than exploding looks like.
      final wedges = <_Wedge>[];
      for (final part in source.parts) {
        final points = part.points;
        if (points.length < 3) {
          continue;
        }
        var middle = Offset.zero;
        for (final point in points) {
          middle += point;
        }
        middle = middle / points.length.toDouble();

        for (var i = 0; i < points.length; i++) {
          final a = points[i];
          final b = points[(i + 1) % points.length];
          final centre = (middle + a + b) / 3;
          wedges.add(
            _Wedge(
              Sprite2D([
                SpritePart([
                  middle - centre,
                  a - centre,
                  b - centre,
                ], part.fill, outlined: false),
              ]),
              centre,
              _area(middle, a, b),
            ),
          );
        }
      }

      // Biggest wedges first, so a capped break keeps the panels the eye would
      // actually notice and drops the slivers along the seams.
      wedges.sort((a, b) => b.area.compareTo(a.area));
      final kept = wedges.take(Metrics.debrisMaxPieces);
      return _Shards(
        [for (final wedge in kept) wedge.piece],
        // Sprite space runs down the screen and the world runs up the lane, so
        // the offset is turned back the right way up on the way out.
        [for (final wedge in kept) Offset(wedge.centre.dx, -wedge.centre.dy)],
      );
    });
  }

  /// Twice the area of a triangle, which is all the ordering needs.
  static double _area(Offset a, Offset b, Offset c) {
    return ((b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx))
        .abs();
  }

  final double scale;
  final double lifespan;

  final Vector3 _origin;
  final _Shards _shards;
  final List<Vector3> _positions = [];
  final List<Vector3> _velocities = [];
  final List<double> _angles = [];
  final List<double> _spins = [];

  double _age = 0;

  /// How many pieces this wreck was broken into, which the cap bounds.
  int get pieceCount => _positions.length;

  @override
  Vector3 get worldPosition => _origin;

  @override
  void onMount() {
    super.onMount();
    game.scene.register(this);
  }

  @override
  void onRemove() {
    game.scene.unregister(this);
    super.onRemove();
  }

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= lifespan) {
      removeFromParent();
      return;
    }
    for (var i = 0; i < _positions.length; i++) {
      final velocity = _velocities[i];
      _positions[i]
        ..x += velocity.x * dt
        ..z += velocity.z * dt;
      // Drag, so the pieces slow as they spread instead of flying off flat.
      velocity.scale(1 - dt * Metrics.debrisDrag);
      _angles[i] += _spins[i] * dt;
    }
  }

  @override
  void paint(Canvas canvas, SpriteRenderer renderer, GameCamera camera) {
    // Pieces hold their colour for most of their life and then go quickly, so
    // the break is legible before it clears.
    final t = (_age / lifespan).clamp(0.0, 1.0);
    final opacity = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
    for (var i = 0; i < _positions.length; i++) {
      renderer.draw(
        canvas,
        _shards.pieces[i],
        position: _positions[i],
        yaw: _angles[i],
        scale: scale,
        opacity: opacity,
      );
    }
  }
}

class _Shards {
  const _Shards(this.pieces, this.offsets);

  final List<Sprite2D> pieces;

  /// Where each piece sat on the hull, in world units across and up the lane.
  final List<Offset> offsets;
}

/// One wedge while the cut is being worked out.
class _Wedge {
  const _Wedge(this.piece, this.centre, this.area);

  final Sprite2D piece;
  final Offset centre;
  final double area;
}
