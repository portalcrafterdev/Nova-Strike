import 'package:flame/components.dart' hide Vector3;
import 'package:flame/events.dart';

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

  void _steer(Vector2 screen) {
    final world = game.gameCamera.screenToPlane(
      screen.toOffset(),
      PlayArea.playerDepth,
    );
    game.player.aimAt(world);
  }
}
