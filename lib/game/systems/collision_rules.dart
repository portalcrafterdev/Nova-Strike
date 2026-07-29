import 'package:flame/components.dart' hide Vector3;

import '../../audio/sfx.dart';
import '../../levels/difficulty_curve.dart';
import '../../theme/palette.dart';
import '../components/bullet.dart';
import '../components/enemy_ship.dart';
import '../components/missile.dart';
import '../components/power_up.dart';
import '../effects/chain_arc.dart';
import '../effects/explosion.dart';
import '../nova_game.dart';

/// The rules that decide what a collision means, and the pass that finds them.
///
/// Everything in the world is a sphere for the purposes of hitting it, which
/// is both the cheapest test there is and the one that feels fairest: the
/// player hitbox is deliberately smaller than the ship that is drawn.
class CollisionSystem extends Component with HasGameReference<NovaGame> {
  CollisionSystem() : super(priority: 50);

  @override
  void update(double dt) {
    if (game.status != GameStatus.playing) {
      return;
    }
    _bulletsAgainstTargets();
    _missilesAgainstTargets();
    _shipAgainstEnemies();
    _escortAndGate();
  }

  /// The two objective levels that need something checked every frame.
  ///
  /// The freighter is hit by anything the player let through, and the gate is
  /// the one thing in the game the player wants to fly into.
  void _escortAndGate() {
    final freighter = game.freighter;
    if (freighter != null && freighter.isMounted && freighter.hp > 0) {
      for (final bullet in game.bullets.active) {
        if (bullet.owner != BulletOwner.enemy || bullet.isRemoving) {
          continue;
        }
        if (_swept(
          bullet.previous.x,
          bullet.previous.y,
          bullet.previous.z,
          bullet.position.x,
          bullet.position.y,
          bullet.position.z,
          bullet.radius,
          freighter.position.x,
          freighter.position.y,
          freighter.position.z,
          freighter.radius,
        )) {
          bullet.removeFromParent();
          freighter.takeDamage(Tuning.freighterBulletDamage);
        }
      }
      for (final enemy in List.of(game.enemies)) {
        if (!enemy.isMounted || enemy.isRemoving) {
          continue;
        }
        if (_touching(
          freighter.position.x,
          freighter.position.y,
          freighter.position.z,
          freighter.radius,
          enemy.position.x,
          enemy.position.y,
          enemy.position.z,
          enemy.stats.hitRadius,
        )) {
          enemy.destroy(byPlayer: false);
          freighter.takeDamage(Tuning.freighterRamDamage);
        }
      }
    }

    final gate = game.gate;
    if (gate != null &&
        gate.isMounted &&
        game.player.isMounted &&
        gate.accepts(game.player.position, game.player.hitRadius)) {
      game.runner.onGateReached();
    }
  }

  /// Sets off a missile when it reaches something.
  ///
  /// The missile itself decides what the blast does. This pass only says when
  /// it went off, and it sweeps the line the missile travelled so a fast one
  /// cannot slip past a small enemy between frames.
  void _missilesAgainstTargets() {
    if (game.missiles.isEmpty) {
      return;
    }
    for (final missile in List.of(game.missiles)) {
      if (missile.isRemoving || !missile.isMounted) {
        continue;
      }
      if (_sweptToEnemies(missile) ||
          _sweptToRocks(missile) ||
          _sweptToPods(missile)) {
        continue;
      }
      final boss = game.boss;
      if (boss != null && boss.isMounted && !boss.isEntering) {
        if (_swept(
          missile.previous.x,
          missile.previous.y,
          missile.previous.z,
          missile.position.x,
          missile.position.y,
          missile.position.z,
          missile.radius,
          boss.position.x,
          boss.position.y,
          boss.position.z,
          boss.radius,
        )) {
          missile.detonate();
        }
      }
    }
  }

  bool _sweptToEnemies(Missile missile) {
    for (final enemy in game.enemies) {
      if (!enemy.isMounted || enemy.isRemoving) {
        continue;
      }
      if (_swept(
        missile.previous.x,
        missile.previous.y,
        missile.previous.z,
        missile.position.x,
        missile.position.y,
        missile.position.z,
        missile.radius,
        enemy.position.x,
        enemy.position.y,
        enemy.position.z,
        enemy.stats.hitRadius,
      )) {
        missile.detonate();
        return true;
      }
    }
    return false;
  }

  bool _sweptToRocks(Missile missile) {
    for (final rock in game.obstacles) {
      if (rock.isRemoving || rock.hp <= 0) {
        continue;
      }
      if (_swept(
        missile.previous.x,
        missile.previous.y,
        missile.previous.z,
        missile.position.x,
        missile.position.y,
        missile.position.z,
        missile.radius,
        rock.position.x,
        rock.position.y,
        rock.position.z,
        rock.radius,
      )) {
        missile.detonate();
        return true;
      }
    }
    return false;
  }

  bool _sweptToPods(Missile missile) {
    for (final pod in game.bossPods) {
      if (!pod.isMounted || pod.hp <= 0) {
        continue;
      }
      if (_swept(
        missile.previous.x,
        missile.previous.y,
        missile.previous.z,
        missile.position.x,
        missile.position.y,
        missile.position.z,
        missile.radius,
        pod.position.x,
        pod.position.y,
        pod.position.z,
        pod.radius,
      )) {
        missile.detonate();
        return true;
      }
    }
    return false;
  }

  /// Enemy shots currently in the air, gathered once a frame so the intercept
  /// pass does not walk the whole bullet list for every shot the player fires.
  final List<Bullet> _incoming = [];

  void _bulletsAgainstTargets() {
    final player = game.player;
    final boss = game.boss;

    _incoming.clear();
    for (final bullet in game.bullets.active) {
      if (bullet.owner == BulletOwner.enemy &&
          !bullet.isRemoving &&
          !bullet.isRemoved) {
        _incoming.add(bullet);
      }
    }

    for (final bullet in game.bullets.active) {
      if (bullet.isRemoving || bullet.isRemoved) {
        continue;
      }

      if (bullet.owner == BulletOwner.enemy) {
        if (_swept(
          bullet.previous.x,
          bullet.previous.y,
          bullet.previous.z,
          bullet.position.x,
          bullet.position.y,
          bullet.position.z,
          bullet.radius,
          player.position.x,
          player.position.y,
          player.position.z,
          player.hitRadius,
        )) {
          bullet.removeFromParent();
          player.takeHit();
        }
        continue;
      }

      var consumed = false;
      for (final enemy in game.enemies) {
        if (!enemy.isMounted || enemy.isRemoving) {
          continue;
        }
        if (_swept(
          bullet.previous.x,
          bullet.previous.y,
          bullet.previous.z,
          bullet.position.x,
          bullet.position.y,
          bullet.position.z,
          bullet.radius,
          enemy.position.x,
          enemy.position.y,
          enemy.position.z,
          enemy.stats.hitRadius,
        )) {
          // A shot travelling up the lane hits the armoured face head on.
          enemy.takeDamage(bullet.damage, fromFront: bullet.velocity.z > 0);
          _chain(enemy, bullet.damage);
          consumed = !bullet.piercing;
          break;
        }
      }
      if (consumed) {
        bullet.removeFromParent();
        continue;
      }

      if (_intercept(bullet)) {
        continue;
      }

      for (final rock in game.obstacles) {
        if (rock.isRemoving || rock.hp <= 0) {
          continue;
        }
        if (_swept(
          bullet.previous.x,
          bullet.previous.y,
          bullet.previous.z,
          bullet.position.x,
          bullet.position.y,
          bullet.position.z,
          bullet.radius,
          rock.position.x,
          rock.position.y,
          rock.position.z,
          rock.radius,
        )) {
          rock.takeDamage(bullet.damage);
          consumed = !bullet.piercing;
          break;
        }
      }
      if (consumed) {
        bullet.removeFromParent();
        continue;
      }

      for (final pod in game.bossPods) {
        if (!pod.isMounted || pod.hp <= 0) {
          continue;
        }
        if (_swept(
          bullet.previous.x,
          bullet.previous.y,
          bullet.previous.z,
          bullet.position.x,
          bullet.position.y,
          bullet.position.z,
          bullet.radius,
          pod.position.x,
          pod.position.y,
          pod.position.z,
          pod.radius,
        )) {
          pod.takeDamage(bullet.damage);
          consumed = !bullet.piercing;
          break;
        }
      }
      if (consumed) {
        bullet.removeFromParent();
        continue;
      }

      if (boss != null && boss.isMounted && !boss.isEntering) {
        if (_swept(
          bullet.previous.x,
          bullet.previous.y,
          bullet.previous.z,
          bullet.position.x,
          bullet.position.y,
          bullet.position.z,
          bullet.radius,
          boss.position.x,
          boss.position.y,
          boss.position.z,
          boss.radius,
        )) {
          boss.takeDamage(bullet.damage, at: bullet.position);
          if (!bullet.piercing) {
            bullet.removeFromParent();
          }
        }
      }
    }
  }

  /// Arcs a shot that landed on to whatever is standing near it.
  ///
  /// Each jump carries less than the one before, so a dense wave is thinned
  /// rather than wiped by a single bullet, and nothing is ever hit twice by
  /// the same arc.
  void _chain(EnemyShip from, double damage) {
    if (!game.player.isMounted || !game.player.hasPowerUp(PowerUpType.chain)) {
      return;
    }
    _chained
      ..clear()
      ..add(from);
    var source = from;
    var carried = damage * Tuning.chainFalloff;

    for (var jump = 0; jump < Tuning.chainJumps; jump++) {
      EnemyShip? next;
      var nearest = Tuning.chainRange * Tuning.chainRange;
      for (final candidate in game.enemies) {
        if (!candidate.isMounted ||
            candidate.isRemoving ||
            _chained.contains(candidate)) {
          continue;
        }
        final dx = candidate.position.x - source.position.x;
        final dy = candidate.position.y - source.position.y;
        final dz = candidate.position.z - source.position.z;
        final distance = dx * dx + dy * dy + dz * dz;
        if (distance < nearest) {
          nearest = distance;
          next = candidate;
        }
      }
      if (next == null) {
        return;
      }
      game.world.add(ChainArc(from: source.position, to: next.position));
      next.takeDamage(carried, fromFront: false);
      _chained.add(next);
      source = next;
      carried *= Tuning.chainFalloff;
    }
  }

  /// Enemies already touched by the arc being drawn.
  final Set<EnemyShip> _chained = {};

  /// Shoots incoming fire out of the air.
  ///
  /// A shot from the player cancels one enemy shot and is spent doing it, so
  /// clearing a wall of fire costs the damage those bullets would have done.
  /// The piercing beam is the exception: it sweeps everything in its path.
  ///
  /// Both bullets are moving fast in opposite directions, so the test is done
  /// in the frame of the enemy shot. That turns two sweeps into one and means
  /// a pair closing at the full speed of both can never pass through each
  /// other between frames.
  bool _intercept(Bullet bullet) {
    var consumed = false;
    for (final shot in _incoming) {
      if (shot.isRemoving || shot.isRemoved) {
        continue;
      }
      final reach = bullet.radius + shot.radius + Tuning.interceptAssist;

      // Cheap gate first: if the pair is far apart along the lane at both ends
      // of the frame and never crosses, nothing else needs computing.
      final wasAhead = bullet.previous.z - shot.previous.z;
      final isAhead = bullet.position.z - shot.position.z;
      if ((wasAhead > reach && isAhead > reach) ||
          (wasAhead < -reach && isAhead < -reach)) {
        continue;
      }

      if (_swept(
        bullet.previous.x - shot.previous.x,
        bullet.previous.y - shot.previous.y,
        wasAhead,
        bullet.position.x - shot.position.x,
        bullet.position.y - shot.position.y,
        isAhead,
        reach,
        0,
        0,
        0,
        0,
      )) {
        game.world.add(Explosion.spark(shot.position, Palette.enemyBullet));
        game.audio.play(Sfx.enemyHit);
        game.addScore(Tuning.interceptScore);
        shot.removeFromParent();
        consumed = !bullet.piercing;
        if (consumed) {
          break;
        }
      }
    }
    if (consumed) {
      bullet.removeFromParent();
    }
    return consumed;
  }

  void _shipAgainstEnemies() {
    final player = game.player;
    if (!player.isMounted) {
      return;
    }
    for (final enemy in game.enemies) {
      if (!enemy.isMounted || enemy.isRemoving) {
        continue;
      }
      if (_touching(
        player.position.x,
        player.position.y,
        player.position.z,
        player.hitRadius,
        enemy.position.x,
        enemy.position.y,
        enemy.position.z,
        enemy.stats.hitRadius,
      )) {
        enemy.destroy(byPlayer: false);
        player.takeHit();
        return;
      }
    }

    for (final rock in game.obstacles) {
      if (rock.isRemoving || !rock.isMounted) {
        continue;
      }
      if (_touching(
        player.position.x,
        player.position.y,
        player.position.z,
        player.hitRadius,
        rock.position.x,
        rock.position.y,
        rock.position.z,
        rock.radius,
      )) {
        rock.shatter(byPlayer: false);
        player.takeHit();
        return;
      }
    }

    final boss = game.boss;
    if (boss != null && boss.isMounted && !boss.isEntering) {
      if (_touching(
        player.position.x,
        player.position.y,
        player.position.z,
        player.hitRadius,
        boss.position.x,
        boss.position.y,
        boss.position.z,
        boss.radius,
      )) {
        player.takeHit();
      }
    }
  }

  /// Whether the path a bullet swept this frame passed through a sphere.
  ///
  /// This is the fix for shots that seem to go straight through an enemy: a
  /// bullet covers more ground between two frames than a small enemy is wide,
  /// so testing only where it ended up misses the hit. Testing the whole line
  /// it travelled never does.
  static bool _swept(
    double fromX,
    double fromY,
    double fromZ,
    double toX,
    double toY,
    double toZ,
    double bulletRadius,
    double targetX,
    double targetY,
    double targetZ,
    double targetRadius,
  ) {
    final abX = toX - fromX;
    final abY = toY - fromY;
    final abZ = toZ - fromZ;
    final lengthSquared = abX * abX + abY * abY + abZ * abZ;

    var closestX = fromX;
    var closestY = fromY;
    var closestZ = fromZ;
    if (lengthSquared > 0.000001) {
      final t =
          (((targetX - fromX) * abX +
                      (targetY - fromY) * abY +
                      (targetZ - fromZ) * abZ) /
                  lengthSquared)
              .clamp(0.0, 1.0);
      closestX = fromX + abX * t;
      closestY = fromY + abY * t;
      closestZ = fromZ + abZ * t;
    }

    final dx = targetX - closestX;
    final dy = targetY - closestY;
    final dz = targetZ - closestZ;
    final reach = bulletRadius + targetRadius;
    return dx * dx + dy * dy + dz * dz <= reach * reach;
  }

  /// Two spheres overlap when the distance between them is less than the sum
  /// of their radii. Squared throughout, so nothing takes a square root.
  static bool _touching(
    double ax,
    double ay,
    double az,
    double ar,
    double bx,
    double by,
    double bz,
    double br,
  ) {
    final dx = ax - bx;
    final dy = ay - by;
    final dz = az - bz;
    final reach = ar + br;
    return dx * dx + dy * dy + dz * dz <= reach * reach;
  }
}
