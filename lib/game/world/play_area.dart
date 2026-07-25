import 'package:vector_math/vector_math_64.dart';

import '../../levels/level_spec.dart';
import '../../theme/palette.dart';

/// The box the game is played in.
///
/// The world is right handed: x runs right, y runs up out of the play plane,
/// and z runs up the lane. The game is flat, so everything of consequence
/// happens on the plane at y zero: the ship flies across the lane and up and
/// down the bottom of it, and everything else comes down the lane toward it.
class PlayArea {
  const PlayArea._();

  /// Where the ship starts, and the line the lane is measured from.
  static const double playerDepth = 0;

  static const double halfWidth = Metrics.playHalfWidth;

  /// The band of the lane the ship may fly in.
  static const double playerBandBack = Metrics.playerBandBack;
  static const double playerBandForward = Metrics.playerBandForward;

  /// A guard on the axis the game does not use.
  static const double halfHeight = Metrics.playHalfHeight;

  /// Where waves are created, just past the top of the screen.
  static const double spawnDepth = Metrics.spawnDepth;

  /// Below the ship. Anything that gets here has flown by and is culled.
  static const double despawnDepth = Metrics.despawnDepth;

  /// Where hovering and holding families settle and start strafing.
  static const double holdDepth = 260;

  /// True when something has left the play box for good.
  static bool isOutside(Vector3 position) {
    const margin = Metrics.despawnMargin;
    return position.z < despawnDepth ||
        position.z > spawnDepth + margin ||
        position.x.abs() > halfWidth + margin ||
        position.y.abs() > halfHeight + margin;
  }

  /// Keeps a value inside the left and right walls.
  static double clampX(double x, [double margin = 0]) {
    final limit = halfWidth - margin;
    if (limit <= 0) {
      return 0;
    }
    return x.clamp(-limit, limit);
  }

  /// Keeps the ship inside the band of lane it is allowed to fly in.
  static double clampLane(double z, [double margin = 0]) {
    final back = playerBandBack + margin;
    final forward = playerBandForward - margin;
    if (forward <= back) {
      return playerDepth;
    }
    return z.clamp(back, forward);
  }

  /// Where the anchor of a formation sits when the wave is created.
  ///
  /// Waves from the sides start beyond the wall so they sweep in across the
  /// lane rather than appearing in front of the player.
  static Vector3 entryAnchor(EntrySide side) {
    switch (side) {
      case EntrySide.top:
        return Vector3(0, 0, spawnDepth);
      case EntrySide.left:
        return Vector3(-halfWidth * 1.9, 0, spawnDepth * 0.75);
      case EntrySide.right:
        return Vector3(halfWidth * 1.9, 0, spawnDepth * 0.75);
    }
  }
}
