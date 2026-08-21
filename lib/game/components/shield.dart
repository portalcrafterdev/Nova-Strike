import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart' hide Vector3;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../theme/palette.dart';
import '../nova_game.dart';
import '../render/camera.dart';
import '../render/sprite_renderer.dart';
import '../render/scene.dart';
import 'player_ship.dart';

/// The bubble around the ship while the shield gem is active.
///
/// It absorbs exactly one hit. Drawing it as a ring that follows the ship in
/// depth keeps it readable without hiding what is behind it.
class ShieldRing extends Component
    with Renderable, HasGameReference<NovaGame> {
  ShieldRing({required this.ship});

  static final Paint _ring = Paint()
    ..color = Palette.shieldRing
    ..style = PaintingStyle.stroke;

  static final Paint _inner = Paint()
    ..color = Palette.shieldRing.withValues(alpha: 0.12);

  final PlayerShip ship;

  double _age = 0;

  @override
  Vector3 get worldPosition => ship.position;

  @override
  bool get drawsOnTop => true;

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
  }

  @override
  void paint(Canvas canvas, SpriteRenderer renderer, GameCamera camera) {
    final projected = camera.project(ship.position);
    if (projected == null) {
      return;
    }
    final pulse = 1 + math.sin(_age * 4) * 0.05;
    final radius = Metrics.shieldRadius * pulse * projected.scale;
    _ring.strokeWidth = math.max(1.5, radius * 0.05);
    canvas.drawCircle(projected.screen, radius, _inner);
    canvas.drawCircle(projected.screen, radius, _ring);
  }
}
