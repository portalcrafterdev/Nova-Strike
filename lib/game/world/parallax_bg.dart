import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart' hide Vector3;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../theme/palette.dart';
import '../nova_game.dart';
import '../render/camera.dart';
import '../render/sprite_renderer.dart';
import '../render/scene.dart';
import 'play_area.dart';

/// The star field the game flies through.
///
/// Stars are real points in the world rather than a scrolling image, so they
/// stream past with the same perspective as everything else and give the lane
/// its sense of speed. Positions are recycled in place, so the field never
/// allocates after it is built.
///
/// Every star is a round point, at every speed. The near layer used to be
/// drawn as a streak, which did not read as a fast star: it read as white
/// scratches on the screen. Speed comes from the three layers moving at three
/// rates, and during the warp home from the whole field moving many times
/// faster, not from stretching a star into a line.
class ParallaxBackground extends Component
    with Renderable, HasGameReference<NovaGame> {
  /// How far up the lane the field is built, past the top of the screen.
  static const double fieldDepth = 700;

  /// How far the field spreads either side of the middle, past the walls.
  static const double fieldRadius = 150;

  /// How fast the nearest layer streams down the screen.
  static const double flowSpeed = 320;

  /// What each layer of the field is: its share of the flow speed, the size
  /// of a star in it, and the paint it is drawn with.
  ///
  /// Three layers at three speeds is what gives a flat field its depth. It is
  /// the only parallax a game with no perspective gets, so it does the work.
  static const List<double> layerSpeed = [0.32, 0.62, 1.0];
  static const List<double> layerSize = [0.9, 1.4, 2.1];

  final Random _rng = Random(20260818);

  final List<Vector3> _stars = [];
  final List<int> _layers = [];
  final List<double> _sizes = [];
  final List<Offset> _nebulaCentres = [];
  final List<double> _nebulaRadius = [];
  final List<Paint> _nebulaPaints = [];

  static final Paint _farPaint = Paint()..color = Palette.starFar;
  static final Paint _midPaint = Paint()..color = Palette.starMid;
  static final Paint _nearPaint = Paint()..color = Palette.starNear;

  /// Sits far up the lane, so the depth sort always draws it first.
  @override
  Vector3 get worldPosition => Vector3(0, 0, fieldDepth * 2);

  @override
  Future<void> onLoad() async {
    const counts = [Metrics.starsFar, Metrics.starsMid, Metrics.starsNear];
    for (var layer = 0; layer < counts.length; layer++) {
      for (var i = 0; i < counts[layer]; i++) {
        _stars.add(_randomStar());
        _layers.add(layer);
        _sizes.add(layerSize[layer] * (0.7 + _rng.nextDouble() * 0.6));
      }
    }

    for (var i = 0; i < Metrics.nebulaBlobs; i++) {
      final centre = Offset(
        _rng.nextDouble() * Metrics.worldWidth,
        _rng.nextDouble() * Metrics.worldHeight,
      );
      final radius = 150 + _rng.nextDouble() * 220;
      _nebulaCentres.add(centre);
      _nebulaRadius.add(radius);
      _nebulaPaints.add(
        Paint()
          ..shader = Gradient.radial(centre, radius, [
            i.isEven ? Palette.nebulaA : Palette.nebulaB,
            const Color(0x00000000),
          ]),
      );
    }
  }

  Vector3 _randomStar() {
    return Vector3(
      (_rng.nextDouble() * 2 - 1) * fieldRadius,
      0,
      _rng.nextDouble() * fieldDepth,
    );
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
    // The run home at the end of a level drives the field far faster, which is
    // most of what sells the warp.
    final step = flowSpeed * (1 + game.warpFactor * Metrics.warpStarBoost) * dt;
    for (var i = 0; i < _stars.length; i++) {
      final star = _stars[i];
      star.z -= step * layerSpeed[_layers[i]];
      if (star.z < PlayArea.despawnDepth) {
        star
          ..z += fieldDepth
          ..x = (_rng.nextDouble() * 2 - 1) * fieldRadius;
      }
    }
  }

  @override
  void paint(Canvas canvas, SpriteRenderer renderer, GameCamera camera) {
    for (var i = 0; i < _nebulaCentres.length; i++) {
      canvas.drawCircle(_nebulaCentres[i], _nebulaRadius[i], _nebulaPaints[i]);
    }

    for (var i = 0; i < _stars.length; i++) {
      final star = _stars[i];
      final projected = camera.project(star);
      if (projected == null) {
        continue;
      }
      final radius = _sizes[i];
      switch (_layers[i]) {
        case 0:
          canvas.drawCircle(projected.screen, radius, _farPaint);
        case 1:
          canvas.drawCircle(projected.screen, radius, _midPaint);
        default:
          canvas.drawCircle(projected.screen, radius, _nearPaint);
      }
    }
  }
}
