import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/game/render/camera.dart';
import 'package:novastrike/theme/palette.dart';
import 'package:vector_math/vector_math_64.dart';

GameCamera buildCamera() {
  return GameCamera(
    viewportWidth: Metrics.worldWidth,
    viewportHeight: Metrics.worldHeight,
  );
}

void main() {
  group('the top down camera', () {
    test('puts the start of the lane in the lower part of the screen', () {
      final camera = buildCamera();
      final origin = camera.project(Vector3.zero());

      expect(origin, isNotNull);
      expect(origin!.screen.dx, closeTo(Metrics.worldWidth / 2, 0.001));
      expect(origin.screen.dy, greaterThan(Metrics.worldHeight * 0.5));
      expect(origin.screen.dy, lessThan(Metrics.worldHeight * 0.95));
    });

    test('further up the lane is further up the screen', () {
      final camera = buildCamera();
      final near = camera.project(Vector3(0, 0, 0))!;
      final far = camera.project(Vector3(0, 0, laneTop))!;

      expect(far.screen.dy, lessThan(near.screen.dy));
    });

    test('nothing is drawn smaller for being further away', () {
      final camera = buildCamera();
      final near = camera.project(Vector3(0, 0, 0))!;
      final far = camera.project(Vector3(0, 0, 400))!;

      // This is the whole difference between a flat game and a deep one.
      expect(far.scale, closeTo(near.scale, 0.000001));
      expect(camera.scaleAt(0), closeTo(camera.scaleAt(900), 0.000001));
    });

    test('left is left and up the lane is up', () {
      final camera = buildCamera();
      final centre = camera.project(Vector3.zero())!;
      final left = camera.project(Vector3(-50, 0, 0))!;
      final ahead = camera.project(Vector3(0, 0, 50))!;

      expect(left.screen.dx, lessThan(centre.screen.dx));
      expect(ahead.screen.dy, lessThan(centre.screen.dy));
    });

    test('a touch maps back to the point it came from', () {
      final camera = buildCamera();
      final world = Vector3(-40, 0, 120);
      final screen = camera.project(world)!.screen;
      final back = camera.screenToPlane(screen, 0);

      expect(back.x, closeTo(world.x, 0.001));
      expect(back.z, closeTo(world.z, 0.001));
      expect(back.y, 0);
    });

    test('the height of a thing never moves it across the screen', () {
      final camera = buildCamera();
      final flat = camera.project(Vector3(20, 0, 100))!;
      final raised = camera.project(Vector3(20, 30, 100))!;

      // y is not a direction the player can see. It only ever decides which of
      // two things sitting on the same spot paints on top.
      expect(raised.screen, flat.screen);
    });

    test('resizing keeps the middle of the screen the middle of the lane', () {
      final camera = buildCamera()..resize(300, 600);
      final origin = camera.project(Vector3.zero())!;

      expect(origin.screen.dx, closeTo(150, 0.001));
      expect(origin.screen.dy, closeTo(600 - Metrics.laneOrigin, 0.001));
    });

    test('the lane is taller than it is wide', () {
      expect(Metrics.worldHeight, greaterThan(Metrics.worldWidth));
    });

    test('the full width of the lane fits on the screen', () {
      final camera = buildCamera();
      final wall = camera.project(Vector3(Metrics.playHalfWidth, 0, 0))!;

      expect(wall.screen.dx, lessThan(Metrics.worldWidth));
      expect(wall.screen.dx, greaterThan(Metrics.worldWidth * 0.9));
    });
  });
}

/// The far end of the visible lane, for the readability of the tests above.
const double laneTop = 380;
