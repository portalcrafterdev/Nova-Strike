import 'dart:ui';

import 'package:flame/components.dart' hide Vector3;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../audio/sfx.dart';
import '../../levels/difficulty_curve.dart';
import '../../theme/palette.dart';
import '../nova_game.dart';
import '../render/camera.dart';
import '../render/sprite.dart';
import '../render/sprite_renderer.dart';
import '../render/scene.dart';
import '../world/play_area.dart';

/// The six gems. Picking one up again refreshes it rather than stacking.
enum PowerUpType {
  doubleShot,
  spread,
  laser,
  shield,
  magnet,
  slow,

  /// Two wingmen that fly beside the ship and fire with it.
  drones,

  /// Each shot arcs on to nearby enemies after it lands.
  chain,

  /// Everything on the enemy side stops dead for a few seconds.
  freeze,
}

/// Colour and label for each gem, kept out of the component so the heads up
/// display can show the same values.
extension PowerUpLook on PowerUpType {
  Color get color {
    switch (this) {
      case PowerUpType.doubleShot:
        return Palette.gemDouble;
      case PowerUpType.spread:
        return Palette.gemSpread;
      case PowerUpType.laser:
        return Palette.gemLaser;
      case PowerUpType.shield:
        return Palette.gemShield;
      case PowerUpType.magnet:
        return Palette.gemMagnet;
      case PowerUpType.slow:
        return Palette.gemSlow;
      case PowerUpType.drones:
        return Palette.gemDrones;
      case PowerUpType.chain:
        return Palette.gemChain;
      case PowerUpType.freeze:
        return Palette.gemFreeze;
    }
  }

  String get label {
    switch (this) {
      case PowerUpType.doubleShot:
        return 'DOUBLE';
      case PowerUpType.spread:
        return 'SPREAD';
      case PowerUpType.laser:
        return 'LASER';
      case PowerUpType.shield:
        return 'SHIELD';
      case PowerUpType.magnet:
        return 'MAGNET';
      case PowerUpType.slow:
        return 'SLOW';
      case PowerUpType.drones:
        return 'DRONES';
      case PowerUpType.chain:
        return 'CHAIN';
      case PowerUpType.freeze:
        return 'FREEZE';
    }
  }
}

/// A gem turning as it drifts down the lane toward the player.
class PowerUp extends Component with Renderable, HasGameReference<NovaGame> {
  PowerUp({required this.type, required Vector3 spawn})
    : _sprite = Sprites.gem(
        body: type.color,
        trim: Palette.pickupTrim(type.color),
        size: Metrics.powerUpRadius,
      ) {
    position.setFrom(spawn);
  }

  final PowerUpType type;
  final Sprite2D _sprite;
  final Vector3 position = Vector3.zero();

  double _age = 0;

  @override
  Vector3 get worldPosition => position;

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
    position.z -= Tuning.powerUpFallSpeed * dt;

    final player = game.player;
    if (player.isMounted) {
      final reach = Tuning.coinPickupRadius + Metrics.powerUpRadius;
      if (position.distanceToSquared(player.position) < reach * reach) {
        player.applyPowerUp(type);
        game.audio.play(Sfx.powerUpPickup);
        game.vibrate(HapticsStrength.light);
        removeFromParent();
        return;
      }
    }

    if (PlayArea.isOutside(position)) {
      removeFromParent();
    }
  }

  @override
  void paint(Canvas canvas, SpriteRenderer renderer, GameCamera camera) {
    renderer.draw(
      canvas,
      _sprite,
      position: position,
      // Turning in the plane only. A gem that also pitched went edge on twice
      // a turn, which is the moment the player is trying to read its colour.
      yaw: _age * 2.2,
    );
  }
}
