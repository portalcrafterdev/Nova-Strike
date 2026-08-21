import 'dart:ui';

import 'package:flame/components.dart' hide Vector3;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../theme/palette.dart';
import '../nova_game.dart';
import '../render/camera.dart';
import '../render/sprite_renderer.dart';
import '../render/scene.dart';

/// An expanding ring of light thrown out by something large.
///
/// It carries no damage. Its whole job is to say that what just happened was
/// bigger than the last thing, which is what a boss phase break and a boss
/// death both need and neither had.
class Shockwave extends Component
    with Renderable, HasGameReference<NovaGame> {
  Shockwave({
    required Vector3 origin,
    required this.color,
    this.reach = Metrics.shockwaveReach,
    this.lifespan = Metrics.shockwaveLifespan,
  }) : _origin = origin.clone();

  static final Paint _paint = Paint()..style = PaintingStyle.stroke;

  final Color color;

  /// How wide the ring grows, in world units.
  final double reach;
  final double lifespan;

  final Vector3 _origin;
  double _age = 0;

  /// Drawn over the ships it came from rather than behind them.
  @override
  bool get drawsOnTop => true;

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
    }
  }

  @override
  void paint(Canvas canvas, SpriteRenderer renderer, GameCamera camera) {
    final projected = camera.project(_origin);
    if (projected == null) {
      return;
    }
    // Fast out of the gate and slowing as it goes, which is how a real blast
    // front behaves and reads as far more energetic than a linear expansion.
    final t = (_age / lifespan).clamp(0.0, 1.0);
    final eased = 1 - (1 - t) * (1 - t);
    final radius = reach * eased * projected.scale;
    if (radius < 1) {
      return;
    }
    _paint
      ..color = color.withValues(alpha: (1 - t) * (1 - t))
      ..strokeWidth = Metrics.shockwaveWidth * (1 - t) * projected.scale;
    canvas.drawCircle(projected.screen, radius, _paint);
  }
}
