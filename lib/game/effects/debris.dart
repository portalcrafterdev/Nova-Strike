import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart' hide Vector3;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../theme/palette.dart';
import '../nova_game.dart';
import '../render3d/camera3d.dart';
import '../render3d/mesh.dart';
import '../render3d/mesh_renderer.dart';
import '../render3d/scene3d.dart';

/// What is left of a ship after it dies: its own hull, in pieces.
///
/// The model that was on screen a frame ago is taken apart into the triangles
/// it was built from, and each one is thrown outward, tumbling, in the colour
/// it already had. Nothing new is authored for this. A puff of particles says
/// something happened; a hull coming apart says what happened to it.
class Debris extends Component with Renderable3D, HasGameReference<NovaGame> {
  Debris({
    required Mesh source,
    required Vector3 origin,
    this.scale = 1,
    this.lifespan = Metrics.debrisLifespan,
    double spread = Metrics.debrisSpread,
    Vector3? inherited,
    int seed = 0,
  }) : _origin = origin.clone(),
       _shards = _shardsOf(source) {
    final rng = Random(seed == 0 ? source.faces.length * 31 : seed);
    for (var i = 0; i < _shards.pieces.length; i++) {
      final offset = _shards.offsets[i];

      // Each piece starts where it sat on the hull and leaves along the line
      // out from the middle, which is what makes the break read as a break
      // rather than a scatter.
      _positions.add(
        Vector3(
          origin.x + offset.x * scale,
          origin.y + offset.y * scale,
          origin.z + offset.z * scale,
        ),
      );

      final push = spread * (0.55 + rng.nextDouble() * 0.9);
      final length = offset.length;
      final outX = length > 0.001 ? offset.x / length : rng.nextDouble() - 0.5;
      final outY = length > 0.001 ? offset.y / length : rng.nextDouble() - 0.5;
      final outZ = length > 0.001 ? offset.z / length : rng.nextDouble() - 0.5;
      _velocities.add(
        Vector3(
          outX * push + (inherited?.x ?? 0) * Metrics.debrisInherit,
          outY * push + (inherited?.y ?? 0) * Metrics.debrisInherit,
          outZ * push + (inherited?.z ?? 0) * Metrics.debrisInherit,
        ),
      );

      _angles.add(Vector3.zero());
      _spins.add(
        Vector3(
          (rng.nextDouble() * 2 - 1) * Metrics.debrisSpin,
          (rng.nextDouble() * 2 - 1) * Metrics.debrisSpin,
          (rng.nextDouble() * 2 - 1) * Metrics.debrisSpin,
        ),
      );
    }
  }

  /// One triangle of a model taken on its own, plus where it sat on the hull.
  ///
  /// The pieces are cut once per model and shared by every wreck of that
  /// model, so a screen full of dying scouts costs one set of triangles.
  static final Map<Mesh, _Shards> _cache = {};

  static _Shards _shardsOf(Mesh source) {
    return _cache.putIfAbsent(source, () {
      // Biggest triangles first, so a capped break keeps the panels the eye
      // would actually notice and drops the slivers along the seams.
      final order = List<int>.generate(source.faces.length, (i) => i)
        ..sort((a, b) => _area(source, b).compareTo(_area(source, a)));
      final kept = order.take(Metrics.debrisMaxPieces);

      final pieces = <Mesh>[];
      final offsets = <Vector3>[];
      for (final index in kept) {
        final face = source.faces[index];
        final a = source.vertices[face.a];
        final b = source.vertices[face.b];
        final c = source.vertices[face.c];
        final centre = ((a + b + c)..scale(1 / 3));
        pieces.add(
          Mesh(
            [a - centre, b - centre, c - centre],
            [Face(0, 1, 2, face.color)],
          ),
        );
        offsets.add(centre);
      }
      return _Shards(pieces, offsets);
    });
  }

  /// Twice the area of a face, which is all the ordering needs.
  static double _area(Mesh source, int index) {
    final face = source.faces[index];
    final a = source.vertices[face.a];
    final edge1 = source.vertices[face.b] - a;
    final edge2 = source.vertices[face.c] - a;
    return edge1.cross(edge2).length;
  }

  final double scale;
  final double lifespan;

  final Vector3 _origin;
  final _Shards _shards;
  final List<Vector3> _positions = [];
  final List<Vector3> _velocities = [];
  final List<Vector3> _angles = [];
  final List<Vector3> _spins = [];

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
        ..y += velocity.y * dt
        ..z += velocity.z * dt;
      // Drag, so the pieces slow as they spread instead of flying off flat.
      velocity.scale(1 - dt * Metrics.debrisDrag);

      final spin = _spins[i];
      _angles[i]
        ..x += spin.x * dt
        ..y += spin.y * dt
        ..z += spin.z * dt;
    }
  }

  @override
  void render3d(Canvas canvas, MeshRenderer renderer, Camera3D camera) {
    // Pieces hold their colour for most of their life and then go quickly, so
    // the break is legible before it clears.
    final t = (_age / lifespan).clamp(0.0, 1.0);
    final opacity = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
    for (var i = 0; i < _positions.length; i++) {
      final angle = _angles[i];
      renderer.draw(
        canvas,
        _shards.pieces[i],
        position: _positions[i],
        yaw: angle.y,
        pitch: angle.x,
        roll: angle.z,
        scale: scale,
        opacity: opacity,
        cull: false,
      );
    }
  }
}

class _Shards {
  const _Shards(this.pieces, this.offsets);

  final List<Mesh> pieces;
  final List<Vector3> offsets;
}
