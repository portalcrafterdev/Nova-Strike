import 'dart:ui';

import 'package:flame/components.dart' hide Vector3;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../levels/difficulty_curve.dart';
import '../../theme/palette.dart';
import '../nova_game.dart';
import '../render/camera.dart';
import '../render/sprite.dart';
import '../render/sprite_renderer.dart';
import '../render/scene.dart';
import 'bullet.dart';
import 'player_ship.dart';

/// A wingman that flies beside the player and fires with them.
///
/// Drones are the only power-up that adds something to the screen rather than
/// changing what the ship already does, which is most of why picking one up
/// feels different from picking up a fire rate gem.
class Drone extends Component with Renderable, HasGameReference<NovaGame> {
  Drone({required this.ship, required this.side});

  /// A miniature of the ship it flies beside, not a missile wearing a gem
  /// colour. A wingman has to read as a wingman at a glance.
  static final Sprite2D _sprite = Sprites.ship(
    hull: Palette.droneHull,
    hullDark: Palette.droneHullDark,
    accent: Palette.playerAccent,
    nose: 12,
    span: 9,
    sweep: -6,
    tailSpan: 3,
  );

  final PlayerShip ship;

  /// Minus one for the left wing, plus one for the right.
  final double side;

  final Vector3 position = Vector3.zero();
  final Vector3 _muzzle = Vector3.zero();

  double _fireTimer = 0;

  @override
  Vector3 get worldPosition => position;

  @override
  void onMount() {
    super.onMount();
    game.scene.register(this);
    position.setFrom(ship.position);
  }

  @override
  void onRemove() {
    game.scene.unregister(this);
    super.onRemove();
  }

  @override
  void update(double dt) {

    // Trails the ship rather than being welded to it, so a hard turn throws
    // the pair out and they swing back into place.
    final targetX = ship.position.x + side * Tuning.droneOffsetX;
    final targetY = ship.position.y;
    final targetZ = ship.position.z - Tuning.droneOffsetZ;
    final follow = (dt * Tuning.droneFollow).clamp(0.0, 1.0);
    position
      ..x += (targetX - position.x) * follow
      ..y += (targetY - position.y) * follow
      ..z += (targetZ - position.z) * follow;

    if (game.runner.isOutro) {
      return;
    }
    _fireTimer -= dt;
    if (_fireTimer <= 0) {
      _fireTimer = Tuning.droneFireInterval;
      _shoot();
    }
  }

  void _shoot() {
    _muzzle.setValues(position.x, position.y, position.z);
    game.bullets.spawn(
      game.world,
      spawn: _muzzle,
      velocityX: 0,
      velocityY: 0,
      velocityZ: Tuning.playerBulletSpeed,
      owner: BulletOwner.player,
      damage: game.progress.bulletDamage * Tuning.droneDamageShare,
    );
  }

  @override
  void paint(Canvas canvas, SpriteRenderer renderer, GameCamera camera) {
    renderer.draw(
      canvas,
      _sprite,
      position: position,
      scale: Tuning.droneScale,
      // A slow bob, so a parked drone still reads as flying.
    );
  }
}
