import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart' hide Vector3;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../audio/sfx.dart';
import '../../levels/difficulty_curve.dart';
import '../../theme/palette.dart';
import '../effects/explosion.dart';
import '../effects/shockwave.dart';
import '../nova_game.dart';
import '../render3d/camera3d.dart';
import '../render3d/mesh.dart';
import '../render3d/mesh_renderer.dart';
import '../render3d/scene3d.dart';
import '../world/play_area.dart';
import 'bullet.dart';

/// A flak shell fired by the player ship.
///
/// It flies straight, does not chase anything, and bursts on a proximity fuse
/// or at a set distance up the lane. The burst hurts everything standing in it
/// and, more to the point, burns incoming fire out of the air. Nothing else the
/// ship carries clears a pocket of the lane before the player has to fly into
/// it.
///
/// A shell answers for its own flight and its own fuse rather than being swept
/// by the collision pass. It is not aimed at any one thing, so there is nothing
/// for that pass to test it against.
class FlakShell extends Component
    with Renderable3D, HasGameReference<NovaGame> {
  FlakShell({required Vector3 spawn, required this.damage}) {
    position.setFrom(spawn);
    _origin = spawn.z;
  }

  static final Mesh _mesh = Meshes.shell(
    body: Palette.flakShell,
    trim: Palette.flakShellDark,
    accent: Palette.flakBurst,
  );

  final Vector3 position = Vector3.zero();
  final double damage;

  late final double _origin;
  double _age = 0;
  double _spin = 0;
  bool _spent = false;

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
    _spin += dt * 6;
    position.z += Tuning.flakSpeed * dt;

    if (_age >= Tuning.flakLifespan ||
        position.z - _origin >= Tuning.flakArmDistance ||
        _fuseTripped()) {
      burst();
      return;
    }

    if (PlayArea.isOutside(position)) {
      removeFromParent();
    }
  }

  /// True once something worth burning is close enough to set the fuse off.
  bool _fuseTripped() {
    for (final enemy in game.enemies) {
      if (!enemy.isRemoving &&
          _within(
            enemy.position,
            Tuning.flakFuseRadius + enemy.stats.hitRadius,
          )) {
        return true;
      }
    }
    for (final rock in game.obstacles) {
      if (!rock.isRemoving &&
          rock.hp > 0 &&
          _within(rock.position, Tuning.flakFuseRadius + rock.radius)) {
        return true;
      }
    }
    for (final pod in game.bossPods) {
      if (pod.hp > 0 &&
          _within(pod.position, Tuning.flakFuseRadius + pod.radius)) {
        return true;
      }
    }
    final boss = game.boss;
    return boss != null &&
        boss.isMounted &&
        !boss.isEntering &&
        _within(boss.position, Tuning.flakFuseRadius + boss.radius);
  }

  /// Sets the shell off. Safe to call twice.
  void burst() {
    if (_spent) {
      return;
    }
    _spent = true;
    final reach = Tuning.flakBurstRadius;

    for (final enemy in List.of(game.enemies)) {
      if (enemy.isRemoving) {
        continue;
      }
      if (_within(enemy.position, reach + enemy.stats.hitRadius)) {
        enemy.takeDamage(damage, fromFront: false);
      }
    }
    for (final rock in List.of(game.obstacles)) {
      if (!rock.isRemoving &&
          rock.hp > 0 &&
          _within(rock.position, reach + rock.radius)) {
        rock.takeDamage(damage);
      }
    }
    for (final pod in List.of(game.bossPods)) {
      if (pod.hp > 0 && _within(pod.position, reach + pod.radius)) {
        pod.takeDamage(damage);
      }
    }
    final boss = game.boss;
    if (boss != null &&
        boss.isMounted &&
        !boss.isEntering &&
        _within(boss.position, reach + boss.radius)) {
      boss.takeDamage(damage, at: position);
    }

    // The shrapnel takes the lane clean of incoming fire, which is the reason
    // to carry the thing at all.
    for (final shot in List.of(game.bullets.active)) {
      if (shot.owner != BulletOwner.enemy || shot.isRemoving) {
        continue;
      }
      if (_within(shot.position, reach + shot.radius)) {
        game.world.add(Explosion.spark(shot.position, Palette.enemyBullet));
        game.addScore(Tuning.interceptScore);
        shot.removeFromParent();
      }
    }

    game.world.add(
      Shockwave(origin: position, color: Palette.flakBurst, reach: reach),
    );
    game.world.add(Explosion.small(position, Palette.flakBurst));
    game.audio.play(Sfx.flakBurst);
    removeFromParent();
  }

  bool _within(Vector3 other, double reach) {
    final dx = other.x - position.x;
    final dy = other.y - position.y;
    final dz = other.z - position.z;
    return dx * dx + dy * dy + dz * dz <= reach * reach;
  }

  @override
  void render3d(Canvas canvas, MeshRenderer renderer, Camera3D camera) {
    // A shell tumbles rather than flying nose first, so it never reads as a
    // small missile.
    renderer.draw(
      canvas,
      _mesh,
      position: position,
      roll: _spin,
      pitch: math.sin(_spin) * 0.3,
    );
  }
}
