import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart' hide Vector3;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../audio/sfx.dart';
import '../../levels/difficulty_curve.dart';
import '../../theme/palette.dart';
import '../effects/debris.dart';
import '../effects/explosion.dart';
import '../effects/hit_flash.dart';
import '../nova_game.dart';
import '../render3d/camera3d.dart';
import '../render3d/mesh.dart';
import '../render3d/mesh_renderer.dart';
import '../render3d/scene3d.dart';
import '../world/play_area.dart';

/// A rock drifting down the lane.
///
/// Obstacles are not enemies: they never shoot and they are worth little, but
/// they are solid, they are in the way, and they can be shot apart. They give
/// the lane something to read against and a reason to keep firing between
/// waves.
class Obstacle extends Component
    with Renderable3D, HitFlash, HasGameReference<NovaGame> {
  Obstacle({required Vector3 spawn, required this.hp, required int shape})
    : _mesh = _meshes[shape % _meshes.length],
      maxHp = hp {
    position.setFrom(spawn);
    _tumbleRate = 0.4 + (shape % 3) * 0.2;
  }

  /// A handful of shapes, so a field of rocks does not look stamped out.
  static final List<Mesh> _meshes = [
    for (var seed = 0; seed < 4; seed++)
      Meshes.asteroid(
        body: Palette.obstacleRock,
        trim: Palette.obstacleRockDark,
        seed: seed,
      ),
  ];

  final Mesh _mesh;
  final Vector3 position = Vector3.zero();
  final Vector3 velocity = Vector3(0, 0, -Tuning.obstacleSpeed);

  double hp;
  final double maxHp;

  /// Radians per second the rock turns in the play plane. Varies by shape so a
  /// field of rocks does not turn in lockstep.
  late final double _tumbleRate;
  double _age = 0;

  /// Collision radius in world units.
  double get radius => Tuning.obstacleRadius;

  @override
  Vector3 get worldPosition => position;

  @override
  void onMount() {
    super.onMount();
    game.scene.register(this);
    game.obstacles.add(this);
  }

  @override
  void onRemove() {
    game.scene.unregister(this);
    game.obstacles.remove(this);
    super.onRemove();
  }

  @override
  void update(double dt) {
    if (game.isFrozen) {
      return;
    }
    _age += dt;
    updateFlash(dt);
    position.x += velocity.x * dt;
    position.y += velocity.y * dt;
    position.z += velocity.z * dt;
    if (PlayArea.isOutside(position)) {
      removeFromParent();
    }
  }

  void takeDamage(double amount) {
    if (hp <= 0) {
      return;
    }
    hp -= amount;
    startFlash();
    if (hp <= 0) {
      shatter(byPlayer: true);
    } else {
      game.audio.play(Sfx.enemyHit);
    }
  }

  /// Breaks the rock apart. Shooting one is worth a little score and often a
  /// coin, so clearing the lane is never a waste of time.
  void shatter({required bool byPlayer}) {
    if (isRemoving || !isMounted) {
      return;
    }
    game.world.add(Explosion.small(position, Palette.obstacleRock));
    game.world.add(
      Debris(
        source: _mesh,
        origin: position,
        inherited: Vector3(0, 0, -Tuning.obstacleSpeed),
        seed: _meshes.indexOf(_mesh) + 5,
      ),
    );
    game.audio.play(Sfx.enemyExplode);
    if (byPlayer) {
      game.addScore(Tuning.obstacleScore);
      game.dropCoin(position, chance: Tuning.obstacleCoinChance);
    }
    removeFromParent();
  }

  @override
  void render3d(Canvas canvas, MeshRenderer renderer, Camera3D camera) {
    renderer.draw(
      canvas,
      _mesh,
      position: position,
      // A rock turns in the play plane and nowhere else. The lens is straight
      // overhead, so a tumble on the other two axes folds a rock edge on and
      // it vanishes into a sliver twice a turn.
      yaw: _age * _tumbleRate,
      flash: flashAmount,
    );
  }

  /// Where a rock enters the lane, spread across it rather than dead centre.
  static Vector3 spawnPoint(math.Random rng) {
    return Vector3(
      (rng.nextDouble() * 2 - 1) * PlayArea.halfWidth,
      (rng.nextDouble() * 2 - 1) * PlayArea.halfHeight * 0.8,
      PlayArea.spawnDepth,
    );
  }
}
