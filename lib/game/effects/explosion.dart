import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart' hide Vector3;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../theme/palette.dart';
import '../nova_game.dart';
import '../render3d/camera3d.dart';
import '../render3d/mesh_renderer.dart';
import '../render3d/scene3d.dart';

/// A burst of debris.
///
/// Particle count and spread scale with the size of whatever died, so a scout
/// pops and a boss tears itself apart. Everything is stored in flat lists and
/// mutated in place, so a burst allocates once and never again.
class Explosion extends Component
    with Renderable3D, HasGameReference<NovaGame> {
  Explosion({
    required Vector3 origin,
    required this.color,
    required this.count,
    required this.lifespan,
    required this.speed,
    required this.particleSize,
  }) : _origin = origin.clone() {
    for (var i = 0; i < count; i++) {
      final theta = _rng.nextDouble() * pi * 2;
      final phi = (_rng.nextDouble() - 0.5) * pi;
      final rate = speed * (0.35 + _rng.nextDouble());
      _positions.add(origin.clone());
      _velocities.add(
        Vector3(
          cos(theta) * cos(phi) * rate,
          sin(phi) * rate,
          sin(theta) * cos(phi) * rate,
        ),
      );
      _sizes.add(particleSize * (0.5 + _rng.nextDouble()));
    }
  }

  /// A burst sized for an enemy or the player ship.
  factory Explosion.small(Vector3 origin, Color color) => Explosion(
    origin: origin,
    color: color,
    count: Metrics.explosionParticlesSmall,
    lifespan: Metrics.explosionLifespanSmall,
    speed: 70,
    particleSize: 1.6,
  );

  /// A burst sized for a boss or a heavy enemy.
  factory Explosion.large(Vector3 origin, Color color) => Explosion(
    origin: origin,
    color: color,
    count: Metrics.explosionParticlesLarge,
    lifespan: Metrics.explosionLifespanLarge,
    speed: 150,
    particleSize: 3.2,
  );

  /// A small spark for a shot that connected without killing anything.
  factory Explosion.spark(Vector3 origin, Color color) => Explosion(
    origin: origin,
    color: color,
    count: 5,
    lifespan: 0.22,
    speed: 45,
    particleSize: 1.1,
  );

  static final Random _rng = Random();
  static final Paint _paint = Paint();
  static final Paint _hotPaint = Paint();

  final Color color;
  final int count;
  final double lifespan;
  final double speed;
  final double particleSize;

  final Vector3 _origin;
  final List<Vector3> _positions = [];
  final List<Vector3> _velocities = [];
  final List<double> _sizes = [];

  double _age = 0;

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
      final position = _positions[i];
      position.x += velocity.x * dt;
      position.y += velocity.y * dt;
      position.z += velocity.z * dt;
      // A touch of drag, so debris slows as it spreads.
      velocity.scale(1 - dt * 1.2);
    }
  }

  @override
  void render3d(Canvas canvas, MeshRenderer renderer, Camera3D camera) {
    final life = 1 - (_age / lifespan).clamp(0.0, 1.0);
    _paint.color = color.withValues(alpha: life);
    _hotPaint.color = Palette.thrusterHot.withValues(alpha: life);
    for (var i = 0; i < _positions.length; i++) {
      final projected = camera.project(_positions[i]);
      if (projected == null) {
        continue;
      }
      final radius = min(
        _sizes[i] * life * projected.scale,
        Metrics.explosionMaxRadius * life,
      );
      if (radius < 0.3) {
        continue;
      }
      canvas.drawCircle(
        projected.screen,
        radius,
        i.isEven ? _paint : _hotPaint,
      );
    }
  }
}
