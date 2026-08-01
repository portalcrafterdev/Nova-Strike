import 'dart:ui';

import 'package:flame/components.dart' hide Vector3;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../levels/level_spec.dart';
import '../../theme/palette.dart';
import '../nova_game.dart';
import '../render3d/camera3d.dart';
import '../render3d/mesh_renderer.dart';
import '../render3d/scene3d.dart';
import '../world/play_area.dart';

/// A marker showing where the next wave is about to arrive from.
///
/// Enemies resolve out of the dark at speed, and by the time a formation is
/// readable the player is already inside it. This puts a pulsing bracket at the
/// edge they are coming from, a beat before they get there, so the player can
/// be somewhere else.
class WaveWarning extends Component
    with Renderable3D, HasGameReference<NovaGame> {
  WaveWarning({required this.entry, this.lifespan = Metrics.warningLifespan});

  static final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = Metrics.warningWidth
    ..strokeCap = StrokeCap.round;

  final EntrySide entry;
  final double lifespan;

  final Vector3 _at = Vector3.zero();
  double _age = 0;

  @override
  bool get drawsOnTop => true;

  @override
  Vector3 get worldPosition => _at;

  @override
  Future<void> onLoad() async {
    // Placed at the depth the wave will resolve at rather than at the very
    // back, so the bracket sits where the player will actually meet them.
    switch (entry) {
      case EntrySide.top:
        _at.setValues(0, Metrics.playHalfHeight, PlayArea.holdDepth);
      case EntrySide.left:
        _at.setValues(-Metrics.playHalfWidth, 0, PlayArea.holdDepth);
      case EntrySide.right:
        _at.setValues(Metrics.playHalfWidth, 0, PlayArea.holdDepth);
    }
  }

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
  void render3d(Canvas canvas, MeshRenderer renderer, Camera3D camera) {
    final projected = camera.project(_at);
    if (projected == null) {
      return;
    }
    // Three pulses over its life, so it reads as a warning rather than as
    // something sitting in the lane.
    final t = (_age / lifespan).clamp(0.0, 1.0);
    final pulse = 0.5 + 0.5 * (1 - t) * _wave(t * 3);
    _paint.color = Palette.warning.withValues(alpha: pulse);

    final reach = Metrics.warningReach * projected.scale;
    final centre = projected.screen;
    final arm = reach * 0.55;

    // A bracket opening toward the lane, which points at where they will come
    // from without drawing a box around empty space.
    final sign = entry == EntrySide.right ? -1.0 : 1.0;
    if (entry == EntrySide.top) {
      canvas
        ..drawLine(
          Offset(centre.dx - reach, centre.dy),
          Offset(centre.dx - reach, centre.dy + arm),
          _paint,
        )
        ..drawLine(
          Offset(centre.dx - reach, centre.dy),
          Offset(centre.dx + reach, centre.dy),
          _paint,
        )
        ..drawLine(
          Offset(centre.dx + reach, centre.dy),
          Offset(centre.dx + reach, centre.dy + arm),
          _paint,
        );
      return;
    }
    canvas
      ..drawLine(
        Offset(centre.dx, centre.dy - reach),
        Offset(centre.dx + sign * arm, centre.dy - reach),
        _paint,
      )
      ..drawLine(
        Offset(centre.dx, centre.dy - reach),
        Offset(centre.dx, centre.dy + reach),
        _paint,
      )
      ..drawLine(
        Offset(centre.dx, centre.dy + reach),
        Offset(centre.dx + sign * arm, centre.dy + reach),
        _paint,
      );
  }

  /// A triangle wave from 0 to 1 and back, which needs no trigonometry.
  double _wave(double t) {
    final phase = t % 1.0;
    return phase < 0.5 ? phase * 2 : (1 - phase) * 2;
  }
}
