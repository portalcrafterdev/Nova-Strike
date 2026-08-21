import 'dart:ui';

import 'package:flame/components.dart' hide Vector3;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../theme/palette.dart';
import '../nova_game.dart';
import '../render/camera.dart';
import '../render/sprite_renderer.dart';
import '../render/scene.dart';

/// A single frame of light across the whole screen, fading out fast.
///
/// Used to punctuate the moments a shake and a noise are not enough on their
/// own: a boss changing phase, and the hit that ends a fight.
class ScreenFlash extends Component
    with Renderable, HasGameReference<NovaGame> {
  ScreenFlash({
    this.color = Palette.hitFlash,
    this.strength = Metrics.screenFlashStrength,
    this.lifespan = Metrics.screenFlashLifespan,
  });

  static final Paint _paint = Paint();
  static const Rect _screen = Rect.fromLTWH(
    0,
    0,
    Metrics.worldWidth,
    Metrics.worldHeight,
  );

  final Color color;

  /// Peak opacity. Kept well under half, because a flash that whites the
  /// screen out costs the player the frame they needed to dodge.
  final double strength;
  final double lifespan;

  double _age = 0;

  /// Painted last, over everything in the scene.
  @override
  bool get drawsOnTop => true;

  /// Sits at the lens, so the depth sort puts it in front of the world.
  @override
  Vector3 get worldPosition => Vector3.zero();

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
    final t = (_age / lifespan).clamp(0.0, 1.0);
    _paint.color = color.withValues(alpha: strength * (1 - t) * (1 - t));
    canvas.drawRect(_screen, _paint);
  }
}
