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

/// The freighter the player is escorting.
///
/// It is slow, it does not shoot, and it cannot dodge. It crosses the lane on
/// rails and the level ends when it reaches the far side. It ending badly ends
/// the level too, which is what turns a shooting gallery into a defence.
class Freighter extends Component
    with Renderable3D, HitFlash, HasGameReference<NovaGame> {
  Freighter({required this.maxHp}) : hp = maxHp;

  static final Mesh _mesh = Meshes.capital(
    hull: Palette.freighterHull,
    hullDark: Palette.freighterHullDark,
    core: Palette.freighterCore,
    glow: Palette.freighterCore,
    width: Tuning.freighterWidth,
    height: Tuning.freighterHeight,
    depth: Tuning.freighterWidth * 0.6,
  );

  final Vector3 position = Vector3(0, 0, Tuning.freighterStartDepth);
  final double maxHp;
  double hp;

  double get radius => Tuning.freighterWidth * 0.42;

  /// How far along its crossing the freighter is, from 0 to 1.
  double get progress {
    final travelled = Tuning.freighterStartDepth - position.z;
    final total = Tuning.freighterStartDepth - Tuning.freighterEndDepth;
    return (travelled / total).clamp(0.0, 1.0);
  }

  bool get hasArrived => position.z <= Tuning.freighterEndDepth;

  @override
  Vector3 get worldPosition => position;

  @override
  void onMount() {
    super.onMount();
    game.scene.register(this);
    game.freighter = this;
    game.escortNotifier.value = 1;
  }

  @override
  void onRemove() {
    game.scene.unregister(this);
    if (game.freighter == this) {
      game.freighter = null;
    }
    super.onRemove();
  }

  @override
  void update(double dt) {
    if (game.isFrozen) {
      return;
    }
    updateFlash(dt);
    position.z -= Tuning.freighterSpeed * dt;
  }

  void takeDamage(double amount) {
    if (hp <= 0) {
      return;
    }
    hp -= amount;
    startFlash();
    game.escortNotifier.value = (hp / maxHp).clamp(0.0, 1.0);
    game.audio.play(Sfx.bossHit);
    if (hp <= 0) {
      destroy();
    }
  }

  void destroy() {
    if (isRemoving || !isMounted) {
      return;
    }
    game.world
      ..add(Explosion.large(position, Palette.freighterCore))
      ..add(
        Debris(
          source: _mesh,
          origin: position,
          inherited: Vector3(0, 0, -Tuning.freighterSpeed),
          seed: 71,
          lifespan: Metrics.debrisLifespan * 1.6,
        ),
      );
    game.audio.play(Sfx.bossExplode);
    game.shake.shake(Metrics.shakeAmplitudeLarge, Metrics.shakeDurationLarge);
    removeFromParent();
  }

  @override
  void render3d(Canvas canvas, MeshRenderer renderer, Camera3D camera) {
    renderer.draw(canvas, _mesh, position: position, flash: flashAmount);
  }
}
