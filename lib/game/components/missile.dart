import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart' hide Vector3;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../audio/sfx.dart';
import '../../levels/difficulty_curve.dart';
import '../../theme/palette.dart';
import '../effects/explosion.dart';
import '../nova_game.dart';
import '../render/camera.dart';
import '../render/sprite.dart';
import '../render/sprite_renderer.dart';
import '../render/scene.dart';
import '../world/play_area.dart';

/// A homing missile fired by the player ship.
///
/// It owns its own flight: it leaves the rail slowly, picks the nearest thing
/// worth killing once the seeker wakes up, then leans toward it at a limited
/// turn rate so a fast crosser can still shake it off. On impact it hurts what
/// it touched and everything standing near it.
///
/// Missiles are not pooled the way bullets are. A salvo arrives every couple of
/// seconds rather than several times a second, so the allocation is noise next
/// to the bullet stream that pooling exists for.
class Missile extends Component with Renderable, HasGameReference<NovaGame> {
  Missile({required Vector3 spawn, required this.damage}) {
    position.setFrom(spawn);
    previous.setFrom(spawn);
    // Straight up the lane. The seeker turns it from here.
    _heading.setValues(0, 0, 1);
    _heading.normalize();
    _speed = Tuning.missileLaunchSpeed;
  }

  static final Sprite2D _sprite = Sprites.missile(
    body: Palette.missileHull,
    trim: Palette.missileHullDark,
    accent: Palette.missileFlame,
  );

  final Vector3 position = Vector3.zero();

  /// Where the missile was last frame, so the collision pass can sweep the
  /// line between the two instead of testing a single point.
  final Vector3 previous = Vector3.zero();

  final Vector3 _heading = Vector3(0, 0, 1);
  final Vector3 _toTarget = Vector3.zero();
  final double damage;

  double _speed = Tuning.missileLaunchSpeed;
  double _age = 0;
  bool _spent = false;

  double get radius => Tuning.missileRadius;

  @override
  Vector3 get worldPosition => position;

  @override
  void onMount() {
    super.onMount();
    game.scene.register(this);
    game.missiles.add(this);
  }

  @override
  void onRemove() {
    game.scene.unregister(this);
    game.missiles.remove(this);
    super.onRemove();
  }

  @override
  void update(double dt) {
    _age += dt;
    if (_age > Tuning.missileLifespan) {
      detonate();
      return;
    }

    if (_age > Tuning.missileSeekerDelay) {
      _steer(dt);
    }

    // The motor keeps building until the missile is at cruise.
    _speed = math.min(
      Tuning.missileCruiseSpeed,
      _speed + (Tuning.missileCruiseSpeed - Tuning.missileLaunchSpeed) * dt * 3,
    );

    previous.setFrom(position);
    position.x += _heading.x * _speed * dt;
    position.y += _heading.y * _speed * dt;
    position.z += _heading.z * _speed * dt;

    if (PlayArea.isOutside(position)) {
      removeFromParent();
    }
  }

  /// Leans the nose toward the nearest target, never faster than the airframe
  /// allows.
  void _steer(double dt) {
    final target = _pickTarget();
    if (target == null) {
      return;
    }
    _toTarget
      ..setFrom(target)
      ..sub(position);
    final distance = _toTarget.length;
    if (distance < 0.001) {
      return;
    }
    _toTarget.scale(1 / distance);

    // Rotate the heading toward the target by at most one frame of turn.
    final dot = _heading.dot(_toTarget).clamp(-1.0, 1.0);
    final angle = math.acos(dot);
    final most = Tuning.missileTurnRate * dt;
    final blend = angle <= most ? 1.0 : most / angle;
    _heading
      ..x += (_toTarget.x - _heading.x) * blend
      ..y += (_toTarget.y - _heading.y) * blend
      ..z += (_toTarget.z - _heading.z) * blend
      ..normalize();
  }

  /// The nearest thing ahead of the missile that is worth spending it on.
  Vector3? _pickTarget() {
    Vector3? best;
    var bestDistance = double.infinity;

    void consider(Vector3 candidate) {
      if (candidate.z < position.z) {
        return;
      }
      final dx = candidate.x - position.x;
      final dy = candidate.y - position.y;
      final dz = candidate.z - position.z;
      final distance = dx * dx + dy * dy + dz * dz;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = candidate;
      }
    }

    for (final enemy in game.enemies) {
      if (enemy.isMounted && !enemy.isRemoving) {
        consider(enemy.position);
      }
    }
    for (final pod in game.bossPods) {
      if (pod.isMounted && pod.hp > 0) {
        consider(pod.position);
      }
    }
    final boss = game.boss;
    if (best == null && boss != null && boss.isMounted && !boss.isEntering) {
      consider(boss.position);
    }
    if (best == null) {
      for (final rock in game.obstacles) {
        if (!rock.isRemoving && rock.hp > 0) {
          consider(rock.position);
        }
      }
    }
    return best;
  }

  /// Blows the missile up where it stands and hurts everything close by.
  ///
  /// Safe to call twice: a missile caught by two things in one frame only ever
  /// goes off once.
  void detonate() {
    if (_spent) {
      return;
    }
    _spent = true;

    final splash = damage * Tuning.missileSplashDamage / Tuning.missileDamage;
    final reach = Tuning.missileSplashRadius;

    for (final enemy in List.of(game.enemies)) {
      if (!enemy.isMounted || enemy.isRemoving) {
        continue;
      }
      if (_within(enemy.position, reach + enemy.stats.hitRadius)) {
        enemy.takeDamage(splash, fromFront: false);
      }
    }
    for (final rock in List.of(game.obstacles)) {
      if (rock.isRemoving || rock.hp <= 0) {
        continue;
      }
      if (_within(rock.position, reach + rock.radius)) {
        rock.takeDamage(splash);
      }
    }
    for (final pod in List.of(game.bossPods)) {
      if (!pod.isMounted || pod.hp <= 0) {
        continue;
      }
      if (_within(pod.position, reach + pod.radius)) {
        pod.takeDamage(splash);
      }
    }
    final boss = game.boss;
    if (boss != null &&
        boss.isMounted &&
        !boss.isEntering &&
        _within(boss.position, reach + boss.radius)) {
      boss.takeDamage(splash, at: position);
    }

    game.world.add(Explosion.small(position, Palette.missileFlame));
    game.audio.play(Sfx.missileHit);
    removeFromParent();
  }

  bool _within(Vector3 other, double reach) {
    final dx = other.x - position.x;
    final dy = other.y - position.y;
    final dz = other.z - position.z;
    return dx * dx + dy * dy + dz * dz <= reach * reach;
  }

  @override
  void paint(Canvas canvas, SpriteRenderer renderer, GameCamera camera) {
    renderer.draw(
      canvas,
      _sprite,
      position: position,
      yaw: math.atan2(_heading.x, _heading.z),
    );
  }
}
