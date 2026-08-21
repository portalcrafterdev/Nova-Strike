import 'dart:ui';

import 'package:flame/components.dart' hide Vector3;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../levels/difficulty_curve.dart';
import '../../theme/palette.dart';
import '../nova_game.dart';
import '../render/camera.dart';
import '../render/sprite_renderer.dart';
import '../render/scene.dart';

/// The line drawn between two things a chain shot jumped across.
///
/// It carries no damage of its own. The damage is already done by the time
/// this exists; it only shows the player why the enemy they did not shoot at
/// died anyway.
class ChainArc extends Component with Renderable, HasGameReference<NovaGame> {
  ChainArc({required Vector3 from, required Vector3 to})
    : _from = from.clone(),
      _to = to.clone();

  static final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  final Vector3 _from;
  final Vector3 _to;
  double _age = 0;

  @override
  bool get drawsOnTop => true;

  @override
  Vector3 get worldPosition => _from;

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
    if (_age >= Tuning.chainArcLifespan) {
      removeFromParent();
    }
  }

  @override
  void paint(Canvas canvas, SpriteRenderer renderer, GameCamera camera) {
    final a = camera.project(_from);
    final b = camera.project(_to);
    if (a == null || b == null) {
      return;
    }
    final life = 1 - (_age / Tuning.chainArcLifespan).clamp(0.0, 1.0);
    _paint
      ..color = Palette.chainArc.withValues(alpha: life)
      ..strokeWidth = Metrics.chainArcWidth * life;
    canvas.drawLine(a.screen, b.screen, _paint);
  }
}
