import 'package:flame/components.dart' hide Vector3;
import 'package:flame/events.dart';

import '../../levels/difficulty_curve.dart';
import '../../theme/palette.dart';
import '../nova_game.dart';
import 'play_area.dart';

/// An invisible layer that catches drags anywhere on screen.
///
/// The finger may start its drag on any part of the glass, so the listener
/// covers the whole screen rather than sitting on the ship. Touches are cast
/// onto the plane the ship flies on, which is what turns a finger into a place
/// to fly to.
class TouchArea extends PositionComponent
    with DragCallbacks, HasGameReference<NovaGame> {
  TouchArea()
    : super(
        position: Vector2.zero(),
        size: Vector2(Metrics.worldWidth, Metrics.worldHeight),
        priority: -50,
      );

  @override
  bool containsLocalPoint(Vector2 point) => true;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _steer(event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    _steer(event.localEndPosition);
  }

  /// Where the last steer put the ship, so a drag can be told which way it
  /// went. Null until the finger has been down for one event.
  double? _lastLane;

  void _steer(Vector2 screen) {
    final world = game.gameCamera.screenToPlane(
      screen.toOffset(),
      PlayArea.playerDepth,
    );
    game.player.aimAt(world);

    // Tell whoever is listening which way the finger is taking the ship. Only
    // once it has travelled far enough to be a deliberate move rather than the
    // jitter of a thumb resting on the glass.
    final lane = world.z;
    final was = _lastLane;
    if (was != null && (lane - was).abs() >= Tuning.steerReportDistance) {
      _lastLane = lane;
      game.onSteer?.call(lane - was);
    } else if (was == null) {
      _lastLane = lane;
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _lastLane = null;
  }
}
