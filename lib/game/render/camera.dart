import 'dart:ui';

import 'package:vector_math/vector_math_64.dart';

import '../../theme/palette.dart';

/// The top down camera the whole game is seen through.
///
/// The world is right handed: x runs right, z runs up the lane away from the
/// player, and y is only ever used to decide which of two things overlapping
/// sits on top. The lens looks straight down on the play plane with no
/// perspective at all, so x maps to the screen across and z maps to the screen
/// up, and a ship is always drawn the same size wherever it is.
class GameCamera {
  GameCamera({
    required this.viewportWidth,
    required this.viewportHeight,
    this.zoom = Metrics.cameraZoom,
    this.laneOrigin = Metrics.laneOrigin,
  }) {
    _rebuild();
  }

  /// Screen size in logical pixels.
  double viewportWidth;
  double viewportHeight;

  /// Screen pixels per world unit. Constant, because nothing is in perspective.
  double zoom;

  /// How far up from the bottom of the screen the line at z zero sits.
  double laneOrigin;

  final Vector3 _scratch = Vector3.zero();

  double _centreX = 0;
  double _baseY = 0;

  /// Pixels per world unit. The same everywhere, whatever the depth. Kept as a
  /// call so drawing code does not have to know that.
  double scaleAt(double depth) => zoom;

  void resize(double width, double height) {
    viewportWidth = width;
    viewportHeight = height;
    _rebuild();
  }

  /// Moves the lens. Used by the shake effect.
  void moveTo({double? cameraZoom, double? origin}) {
    zoom = cameraZoom ?? zoom;
    laneOrigin = origin ?? laneOrigin;
    _rebuild();
  }

  void _rebuild() {
    _centreX = viewportWidth / 2;
    _baseY = viewportHeight - laneOrigin;
  }

  /// Projects a world point to the screen.
  ///
  /// Never returns null. In a flat game every point is in front of the lens,
  /// but the signature is kept so callers can stay as they are.
  Projected? project(Vector3 world) {
    return Projected(
      Offset(_centreX + world.x * zoom, _baseY - world.z * zoom),
      zoom,
    );
  }

  /// Screen point to a world point on the play plane.
  ///
  /// This is what turns a finger on the glass into a place for the ship to
  /// fly to. The ship moves across the lane and up and down it, so both of
  /// the screen axes map to the plane rather than only one.
  Vector3 screenToPlane(Offset screen, double planeZ) {
    _scratch.setValues(
      (screen.dx - _centreX) / zoom,
      0,
      (_baseY - screen.dy) / zoom,
    );
    return Vector3.copy(_scratch);
  }
}

/// A world point after projection.
class Projected {
  const Projected(this.screen, this.scale);

  /// Where it lands on the screen.
  final Offset screen;

  /// Pixels per world unit. Constant in a flat game, but kept so the drawing
  /// code does not have to know that.
  final double scale;
}
