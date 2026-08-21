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
import '../world/play_area.dart';
import 'power_up.dart';

/// A coin dropped by an enemy.
///
/// Coins drift down the lane, and the magnet gem pulls them toward the ship.
/// Collecting every coin in a level is worth the third star.
class CoinPickup extends Component
    with Renderable, HasGameReference<NovaGame> {
  CoinPickup({required Vector3 spawn}) {
    position.setFrom(spawn);
  }

  static final Sprite2D _sprite = Sprites.gem(
    body: Palette.coin,
    trim: Palette.uiAccentWarm,
    size: Metrics.coinRadius,
  );

  final Vector3 position = Vector3.zero();
  final Vector3 _pull = Vector3.zero();

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
    final player = game.player;
    if (!player.isMounted) {
      position.z -= Tuning.coinFallSpeed * dt;
      return;
    }

    final distance = position.distanceTo(player.position);
    if (player.hasPowerUp(PowerUpType.magnet) &&
        distance < game.progress.magnetRadius) {
      _pull
        ..setFrom(player.position)
        ..sub(position);
      if (distance > 0.001) {
        _pull.scale(Tuning.playerMagnetPull * dt / distance);
        position.add(_pull);
      }
    } else {
      position.z -= Tuning.coinFallSpeed * dt;
    }

    if (distance < Tuning.coinPickupRadius) {
      game.collectCoin();
      removeFromParent();
      return;
    }

    if (PlayArea.isOutside(position)) {
      removeFromParent();
    }
  }

  @override
  void paint(Canvas canvas, SpriteRenderer renderer, GameCamera camera) {
    renderer.draw(canvas, _sprite, position: position, yaw: _age * 3.4);
  }
}
