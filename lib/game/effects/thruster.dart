import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart' hide Vector3;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../theme/palette.dart';
import '../nova_game.dart';
import '../render3d/camera3d.dart';
import '../render3d/mesh_renderer.dart';
import '../render3d/scene3d.dart';

/// The engine trail behind the player ship.
///
/// The trail is a ring buffer of world points written in place, so it emits
/// continuously without allocating anything per frame.
class ThrusterTrail extends Component
    with Renderable3D, HasGameReference<NovaGame> {
  ThrusterTrail({this.length = 16});

  final int length;

  late final List<Vector3> _points = List<Vector3>.generate(
    length,
    (_) => Vector3.zero(),
    growable: false,
  );
  static final Paint _paint = Paint()..color = Palette.thruster;
  static final Paint _hotPaint = Paint()..color = Palette.thrusterHot;

  final Vector3 _head3 = Vector3.zero();

  int _head = 0;
  double _timer = 0;
  bool _seeded = false;

  @override
  Vector3 get worldPosition => _head3;

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

  /// Records where the ship is now. Called by the ship every frame.
  void follow(Vector3 shipPosition, double dt) {
    _head3.setFrom(shipPosition);
    if (!_seeded) {
      for (final point in _points) {
        point.setFrom(shipPosition);
      }
      _seeded = true;
    }
    _timer += dt;
    if (_timer < Metrics.thrusterInterval) {
      return;
    }
    _timer = 0;
    _head = (_head + 1) % length;
    _points[_head].setValues(
      shipPosition.x,
      shipPosition.y,
      shipPosition.z - 14,
    );
  }

  @override
  void render3d(Canvas canvas, MeshRenderer renderer, Camera3D camera) {
    if (!_seeded) {
      return;
    }
    for (var i = 0; i < length; i++) {
      final index = (_head - i + length) % length;
      final projected = camera.project(_points[index]);
      if (projected == null) {
        continue;
      }
      final fade = 1 - i / length;
      // The cap tapers with the trail, so the flame narrows behind the ship
      // instead of becoming a row of discs all the same size.
      final radius = math.min(
        Metrics.thrusterRadius * fade * projected.scale,
        Metrics.thrusterMaxRadius * fade,
      );
      if (radius <= 0.3) {
        continue;
      }
      canvas.drawCircle(projected.screen, radius, i < 2 ? _hotPaint : _paint);
    }
  }
}
