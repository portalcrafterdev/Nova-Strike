import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart' hide Vector3;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../levels/difficulty_curve.dart';
import '../../theme/palette.dart';
import '../nova_game.dart';
import '../render/camera.dart';
import '../render/sprite_renderer.dart';
import '../render/scene.dart';

/// The ring the player has to fly through to finish a gate level.
///
/// Everything else in the game ends on a timer once the shooting stops. This
/// one hands the ending back: the gate drifts in, and the level is over when
/// the player decides to leave through it, which means the coins still on the
/// screen are a real decision rather than a formality.
class WarpGate extends Component with Renderable, HasGameReference<NovaGame> {
  static final Paint _ring = Paint()..style = PaintingStyle.stroke;
  static final Paint _inner = Paint()..style = PaintingStyle.stroke;

  final Vector3 position = Vector3(0, 0, Tuning.gateStartDepth);
  double _age = 0;

  /// True once the gate has drifted close enough to be flown through.
  bool get isOpen => position.z <= Tuning.gateOpenDepth;

  double get radius => Tuning.gateRadius;

  @override
  Vector3 get worldPosition => position;

  @override
  void onMount() {
    super.onMount();
    game.scene.register(this);
    game.gate = this;
  }

  @override
  void onRemove() {
    game.scene.unregister(this);
    if (game.gate == this) {
      game.gate = null;
    }
    super.onRemove();
  }

  @override
  void update(double dt) {
    _age += dt;
    if (position.z > Tuning.gateRestDepth) {
      position.z -= Tuning.gateApproachSpeed * dt;
    }
  }

  /// True when the ship has passed through the hoop rather than around it.
  bool accepts(Vector3 ship, double shipRadius) {
    if (!isOpen) {
      return false;
    }
    if ((ship.z - position.z).abs() > Tuning.gateDepthTolerance) {
      return false;
    }
    final dx = ship.x - position.x;
    final dy = ship.y - position.y;
    final reach = Tuning.gateRadius - shipRadius;
    return dx * dx + dy * dy <= reach * reach;
  }

  @override
  void paint(Canvas canvas, SpriteRenderer renderer, GameCamera camera) {
    final projected = camera.project(position);
    if (projected == null) {
      return;
    }
    final pulse = 0.6 + 0.4 * math.sin(_age * Tuning.gatePulseRate);
    final outer = Tuning.gateRadius * projected.scale;

    _ring
      ..color = Palette.gateRing.withValues(alpha: isOpen ? 1 : 0.45)
      ..strokeWidth = Metrics.gateRingWidth * projected.scale;
    _inner
      ..color = Palette.gateGlow.withValues(alpha: pulse * (isOpen ? 1 : 0.4))
      ..strokeWidth = Metrics.gateGlowWidth * projected.scale;

    canvas
      ..drawCircle(projected.screen, outer, _ring)
      ..drawCircle(projected.screen, outer * (0.72 + 0.06 * pulse), _inner);
  }
}
