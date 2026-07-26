import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart' hide Vector3;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../audio/sfx.dart';
import '../../levels/difficulty_curve.dart';
import '../../state/player_progress.dart';
import '../../state/ship_catalog.dart';
import '../../theme/palette.dart';
import '../effects/chain_arc.dart';
import '../effects/explosion.dart';
import '../effects/screen_flash.dart';
import '../effects/thruster.dart';
import '../nova_game.dart';
import '../render3d/camera3d.dart';
import '../render3d/mesh.dart';
import '../render3d/mesh_renderer.dart';
import '../render3d/scene3d.dart';
import '../systems/bullet_patterns.dart';
import '../world/play_area.dart';
import 'bullet.dart';
import 'drone.dart';
import 'flak_shell.dart';
import 'missile.dart';
import 'power_up.dart';
import 'shield.dart';

/// The player ship.
///
/// It mirrors the finger with a vertical offset so the ship is never hidden
/// under the thumb, eases toward that target so movement feels weighty, banks
/// into its turns, and fires on its own. The player never taps to shoot.
class PlayerShip extends Component
    with Renderable3D, HasGameReference<NovaGame> {
  /// Built from the hull the player chose and the ordnance they have bought.
  late final Mesh _mesh = _hullFor(
    game.progress.ship,
    game.progress.tierOf(UpgradeId.ordnance),
  );

  static final Map<String, Mesh> _hulls = {};

  /// The model for one hull at one ordnance tier.
  ///
  /// The rack is on the outside of the ship: nothing at tier zero, a pod on
  /// each wing once the first tier is bought, and canards up front on top of
  /// that further up. An upgrade the player paid for should be visible on the
  /// thing they fly, not only in the numbers.
  static Mesh _hullFor(ShipDef def, int tier) {
    return _hulls.putIfAbsent(
      '${def.id.name}-$tier',
      () => Meshes.ship(
        hull: def.hull,
        hullDark: def.hullDark,
        accent: def.accent,
        pods: tier >= Tuning.podRackTier,
        canards: tier >= Tuning.canardTier,
        podColor: Palette.playerPod,
        nose: def.nose,
        span: def.span,
        sweep: def.sweep,
        spine: def.spine,
        keel: def.keel,
        tailSpan: def.tailSpan,
      ),
    );
  }

  final Vector3 position = Vector3(0, 0, PlayArea.playerDepth);
  final Vector3 _target = Vector3(0, 0, PlayArea.playerDepth);
  final Vector3 _muzzle = Vector3.zero();
  final Map<PowerUpType, double> _powerTimers = {};
  final ThrusterTrail _trail = ThrusterTrail();
  final List<Drone> _drones = [];
  final List<Vector3> _arcTargets = [];

  double _fireTimer = 0;
  double _missileTimer = Tuning.missileInterval;
  double _railTimer = Tuning.railInterval;
  double _flakTimer = Tuning.flakInterval;
  double _podTimer = Tuning.podInterval;
  double _arcTimer = Tuning.arcInterval;
  int _rail = 0;
  double _invulnerable = 0;
  double _blink = 0;
  double _bank = 0;
  double _driftX = 0;
  ShieldRing? _shield;
  LaserBeam? _laser;

  bool get isInvulnerable => _invulnerable > 0;

  double get hitRadius => Metrics.playerHitRadius;

  bool hasPowerUp(PowerUpType type) => (_powerTimers[type] ?? 0) > 0;

  /// Seconds left on a gem, for the heads up display.
  double timeLeft(PowerUpType type) => _powerTimers[type] ?? 0;

  @override
  Vector3 get worldPosition => position;

  @override
  Future<void> onLoad() async {
    await game.world.add(_trail);
  }

  @override
  void onMount() {
    super.onMount();
    game.scene.register(this);
  }

  @override
  void onRemove() {
    game.scene.unregister(this);
    _trail.removeFromParent();
    super.onRemove();
  }

  /// Points the ship at a world position taken from a touch.
  ///
  /// The ship sits above the finger so the thumb never covers it.
  void aimAt(Vector3 touch) {
    _target.setValues(touch.x, 0, touch.z + Tuning.playerTouchOffsetZ);
  }

  @override
  void update(double dt) {
    if (game.warpFactor > 0) {
      _warpOut(dt);
      return;
    }

    _moveToward(dt);
    _trail.follow(position, dt);

    if (_invulnerable > 0) {
      _invulnerable -= dt;
      _blink += dt;
    }

    _tickPowerUps(dt);

    // The guns go quiet the moment the level is won. Firing into an empty
    // lane during the victory lap looks like the game did not notice.
    if (game.runner.isOutro) {
      return;
    }

    _fireTimer -= dt;
    if (_fireTimer <= 0) {
      _fire();
      _fireTimer = game.progress.fireInterval;
    }

    // Every weapon runs on its own clock. The player never taps to shoot, so
    // the ordnance has to look after itself the way the cannon does.
    if (game.levelNumber >= Tuning.missileFirstLevel) {
      _missileTimer -= dt;
      if (_missileTimer <= 0) {
        _launchMissiles();
        _missileTimer = game.progress.missileInterval;
      }
    }
    if (game.levelNumber >= Tuning.railFirstLevel) {
      _railTimer -= dt;
      if (_railTimer <= 0) {
        _fireRail();
        _railTimer = game.progress.railInterval;
      }
    }
    if (game.levelNumber >= Tuning.flakFirstLevel) {
      _flakTimer -= dt;
      if (_flakTimer <= 0) {
        _fireFlak();
        _flakTimer = game.progress.flakInterval;
      }
    }
    if (game.levelNumber >= Tuning.podFirstLevel) {
      _podTimer -= dt;
      if (_podTimer <= 0) {
        _firePods();
        _podTimer = game.progress.podInterval;
      }
    }
    if (game.levelNumber >= Tuning.arcFirstLevel) {
      _arcTimer -= dt;
      if (_arcTimer <= 0) {
        _fireArc();
        _arcTimer = game.progress.arcInterval;
      }
    }
  }

  /// The run home once the level is won.
  ///
  /// Control is taken away, the guns go quiet, the ship straightens up and
  /// pulls away down the lane. It is a short thing, but a level that simply
  /// stops feels like the game lost its place.
  void _warpOut(double dt) {
    position.x += (0 - position.x) * math.min(1, dt * 3);
    position.y += (0 - position.y) * math.min(1, dt * 3);
    position.z += Metrics.warpShipSpeed * game.warpFactor * dt;
    _bank += (0 - _bank) * math.min(1, dt * 6);
    _driftX = 0;
    _trail.follow(position, dt);
  }

  /// Smoothed follow. The design gives the lerp per frame at 60fps, so it is
  /// converted here to something that behaves the same at any frame rate.
  void _moveToward(double dt) {
    final factor =
        1 - math.pow(1 - game.progress.followLerp, dt * 60).toDouble();
    final previousX = position.x;
    position.x += (_target.x - position.x) * factor;
    position.z += (_target.z - position.z) * factor;
    position.x = PlayArea.clampX(position.x, 6);
    position.z = PlayArea.clampLane(position.z, 6);

    // Bank into the turn, which is most of what sells the third dimension.
    _driftX = dt > 0 ? (position.x - previousX) / dt : 0;
    final targetBank =
        (-_driftX / 220).clamp(-1.0, 1.0) * Metrics.playerBankAngle;
    _bank += (targetBank - _bank) * math.min(1, dt * 8);
  }

  void _tickPowerUps(double dt) {
    if (_powerTimers.isEmpty) {
      return;
    }
    var changed = false;
    for (final type in PowerUpType.values) {
      final left = _powerTimers[type];
      if (left == null) {
        continue;
      }
      final next = left - dt;
      if (next <= 0) {
        _powerTimers.remove(type);
        _onPowerUpExpired(type);
        changed = true;
      } else {
        _powerTimers[type] = next;
      }
    }
    if (changed) {
      _publishPowerUps();
    }
  }

  void _fire() {
    if (hasPowerUp(PowerUpType.laser)) {
      // The beam does its own damage, so no bullets are spawned while it runs.
      return;
    }
    final streams =
        game.progress.bulletStreams +
        (hasPowerUp(PowerUpType.doubleShot) ? 1 : 0);
    final shots = BulletPatterns.playerShots(
      streams: streams,
      spread: hasPowerUp(PowerUpType.spread),
      speed: Tuning.playerBulletSpeed,
      streamOffset: Tuning.doubleShotOffset,
    );
    for (final shot in shots) {
      _muzzle.setValues(
        position.x + shot.offsetX,
        position.y + shot.offsetY,
        position.z + shot.offsetZ,
      );
      game.bullets.spawn(
        game.world,
        spawn: _muzzle,
        velocityX: shot.velocityX,
        velocityY: shot.velocityY,
        velocityZ: shot.velocityZ,
        owner: BulletOwner.player,
        damage: game.progress.bulletDamage,
      );
    }
    game.audio.play(Sfx.laserFire);
  }

  /// Sends off a salvo of homing missiles.
  ///
  /// They alternate rails so a single missile does not always leave from the
  /// same side, and each one is given a slight outward lean so a salvo opens
  /// into a fan before the seekers pull it back together.
  void _launchMissiles() {
    final count = game.progress.missileSalvo;
    for (var i = 0; i < count; i++) {
      _rail++;
      final side = _rail.isEven ? 1.0 : -1.0;
      _muzzle.setValues(
        position.x + side * Tuning.missileRailOffset,
        position.y,
        position.z,
      );
      game.world.add(
        Missile(
          spawn: _muzzle,
          damage: game.progress.missileDamage,
          lean: side * 0.25,
        ),
      );
    }
    game.audio.play(Sfx.missileLaunch);
  }

  /// Fires the railgun: one lance straight up the lane that punches through
  /// everything standing in it rather than stopping at the first thing hit.
  void _fireRail() {
    _muzzle.setValues(position.x, position.y, position.z);
    game.bullets.spawn(
      game.world,
      spawn: _muzzle,
      velocityX: 0,
      velocityY: 0,
      velocityZ: Tuning.railSpeed,
      owner: BulletOwner.player,
      damage: Tuning.railDamage,
      piercing: true,
      heavy: true,
    );
    game.audio.play(Sfx.railFire);
  }

  /// Lobs a flak shell up the lane.
  ///
  /// No sound goes out with the launch on purpose. The burst is the event, and
  /// a launch cue as well would double up on a weapon that goes off a beat
  /// later anyway.
  void _fireFlak() {
    _muzzle.setValues(position.x, position.y, position.z);
    game.world.add(FlakShell(spawn: _muzzle, damage: game.progress.flakDamage));
  }

  /// Fires the wing pods, which point outward rather than up the lane.
  ///
  /// The main cannon only ever covers the column in front of the ship. These
  /// cover the ground to either side of it, so anything holding station at the
  /// edge of the lane can be answered without flying over to it.
  void _firePods() {
    final shots = BulletPatterns.podShots(
      angle: Tuning.podAngle,
      offset: Tuning.podOffset,
      speed: Tuning.podSpeed,
    );
    for (final shot in shots) {
      _muzzle.setValues(
        position.x + shot.offsetX,
        position.y + shot.offsetY,
        position.z + shot.offsetZ,
      );
      game.bullets.spawn(
        game.world,
        spawn: _muzzle,
        velocityX: shot.velocityX,
        velocityY: shot.velocityY,
        velocityZ: shot.velocityZ,
        owner: BulletOwner.player,
        damage: game.progress.podDamage,
      );
    }
    game.audio.play(Sfx.podFire);
  }

  /// Discharges the arc coil into whatever has come close.
  ///
  /// The coil needs no aim at all, so the whole price of it is having to be
  /// near the thing you want dead. It reaches for ships first and spends what
  /// is left of its budget on rocks, because a rock is never the threat.
  void _fireArc() {
    _arcTargets.clear();
    for (final enemy in game.enemies) {
      if (!enemy.isRemoving &&
          _within(enemy.position, Tuning.arcRange + enemy.stats.hitRadius)) {
        _arcTargets.add(enemy.position);
      }
    }
    final budget = game.progress.arcTargets;
    if (_arcTargets.length < budget) {
      for (final rock in game.obstacles) {
        if (!rock.isRemoving &&
            rock.hp > 0 &&
            _within(rock.position, Tuning.arcRange + rock.radius)) {
          _arcTargets.add(rock.position);
        }
      }
    }
    if (_arcTargets.isEmpty) {
      return;
    }

    // Nearest first, so a coil that can only reach two things spends itself on
    // the two that are about to run into the ship.
    _arcTargets.sort(
      (a, b) => _distanceSquared(a).compareTo(_distanceSquared(b)),
    );
    final damage = game.progress.arcDamage;
    final count = math.min(_arcTargets.length, budget);
    for (var i = 0; i < count; i++) {
      final at = _arcTargets[i];
      game.world.add(ChainArc(from: position, to: at));
      _arcDamage(at, damage);
    }
    _arcTargets.clear();
    game.audio.play(Sfx.arcZap);
  }

  /// Hands the coil's damage to whatever is standing at [at].
  ///
  /// The targets were gathered as positions rather than components so the list
  /// can hold ships and rocks at once, so this finds the owner again. Both
  /// lists are short, and the coil fires seconds apart.
  void _arcDamage(Vector3 at, double damage) {
    for (final enemy in List.of(game.enemies)) {
      if (identical(enemy.position, at)) {
        enemy.takeDamage(damage, fromFront: false);
        return;
      }
    }
    for (final rock in List.of(game.obstacles)) {
      if (identical(rock.position, at)) {
        rock.takeDamage(damage);
        return;
      }
    }
  }

  double _distanceSquared(Vector3 other) {
    final dx = other.x - position.x;
    final dy = other.y - position.y;
    final dz = other.z - position.z;
    return dx * dx + dy * dy + dz * dz;
  }

  bool _within(Vector3 other, double reach) =>
      _distanceSquared(other) <= reach * reach;

  /// Applies a gem. Picking up the same type again refreshes the timer rather
  /// than stacking a second copy.
  void applyPowerUp(PowerUpType type) {
    // The freeze runs on its own much shorter clock. Stopping the whole level
    // is the strongest thing any gem does, so it does not get to last as long
    // as the ones that only change how the ship shoots.
    _powerTimers[type] = type == PowerUpType.freeze
        ? Tuning.freezeDuration
        : game.progress.powerUpDuration;
    switch (type) {
      case PowerUpType.drones:
        if (_drones.isEmpty) {
          for (final side in const [-1.0, 1.0]) {
            final drone = Drone(ship: this, side: side);
            _drones.add(drone);
            game.world.add(drone);
          }
          game.audio.play(Sfx.shieldUp);
        }
      case PowerUpType.freeze:
        game.world.add(ScreenFlash(color: Palette.gemFreeze));
        game.audio.play(Sfx.shieldUp);
      case PowerUpType.shield:
        if (_shield == null) {
          final shield = ShieldRing(ship: this);
          _shield = shield;
          game.world.add(shield);
          game.audio.play(Sfx.shieldUp);
        }
      case PowerUpType.laser:
        if (_laser == null) {
          final laser = LaserBeam(ship: this);
          _laser = laser;
          game.world.add(laser);
          game.audio.play(Sfx.laserHeavy);
        }
      case PowerUpType.doubleShot:
      case PowerUpType.spread:
      case PowerUpType.magnet:
      case PowerUpType.slow:
      case PowerUpType.chain:
        break;
    }
    _publishPowerUps();
  }

  void _onPowerUpExpired(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield:
        _shield?.removeFromParent();
        _shield = null;
      case PowerUpType.laser:
        _laser?.removeFromParent();
        _laser = null;
      case PowerUpType.drones:
        for (final drone in _drones) {
          drone.removeFromParent();
        }
        _drones.clear();
      case PowerUpType.doubleShot:
      case PowerUpType.spread:
      case PowerUpType.magnet:
      case PowerUpType.slow:
      case PowerUpType.chain:
      case PowerUpType.freeze:
        break;
    }
  }

  void _publishPowerUps() {
    game.powerUpsNotifier.value = _powerTimers.keys.toList(growable: false);
  }

  /// Takes a hit unless the ship is blinking or the shield eats it.
  void takeHit() {
    if (_invulnerable > 0 || game.status != GameStatus.playing) {
      return;
    }
    if (_shield != null) {
      _shield!.removeFromParent();
      _shield = null;
      _powerTimers.remove(PowerUpType.shield);
      _publishPowerUps();
      game.audio.play(Sfx.shieldBreak);
      game.shake.shake(Metrics.shakeAmplitudeSmall, Metrics.shakeDurationSmall);
      _invulnerable = Tuning.playerInvulnerability / 2;
      return;
    }
    _invulnerable = Tuning.playerInvulnerability;
    _blink = 0;
    game.world.add(Explosion.small(position, Palette.playerHull));
    // Losing a life is the moment that has to land hardest, so it gets the
    // freeze as well as the burst.
    game.hitStop(Metrics.hitStopPlayer);
    game.onPlayerHit();
  }

  @override
  void render3d(Canvas canvas, MeshRenderer renderer, Camera3D camera) {
    // Blink while invulnerable so the player can see the state.
    if (_invulnerable > 0 &&
        (_blink * Metrics.invulnerabilityBlinkRate).floor().isEven) {
      return;
    }
    renderer.draw(
      canvas,
      _mesh,
      position: position,
      roll: _bank,
      pitch: Metrics.playerPitch + (_driftX.abs() / 900).clamp(0.0, 0.12),
      scale: Metrics.playerScale,
    );
  }
}

/// The continuous beam from the laser gem.
///
/// It pierces everything in the lane ahead of the ship, dealing damage on a
/// fixed tick rather than per frame so the damage never depends on frame rate.
class LaserBeam extends Component
    with Renderable3D, HasGameReference<NovaGame> {
  LaserBeam({required this.ship});

  static final Paint _core = Paint()..color = Palette.laserBeam;
  static final Paint _glow = Paint()
    ..color = Palette.laserBeam.withValues(alpha: 0.25);

  final PlayerShip ship;
  final Vector3 _far = Vector3.zero();

  double _tick = 0;

  @override
  Vector3 get worldPosition => ship.position;

  @override
  bool get drawsOnTop => true;

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
    _tick += dt;
    if (_tick < Tuning.playerLaserTickInterval) {
      return;
    }
    final damage = Tuning.playerLaserDamagePerSecond * _tick;
    _tick = 0;

    for (final enemy in game.enemies) {
      if (enemy.position.z < ship.position.z) {
        continue;
      }
      final dx = enemy.position.x - ship.position.x;
      final dy = enemy.position.y - ship.position.y;
      final reach = Metrics.laserWidth + enemy.stats.hitRadius;
      if (dx * dx + dy * dy > reach * reach) {
        continue;
      }
      enemy.takeDamage(damage, fromFront: false);
    }

    // The beam burns incoming fire out of the column as well, which is most of
    // why it is worth standing still under one.
    for (final shot in game.bullets.active) {
      if (shot.owner != BulletOwner.enemy ||
          shot.isRemoving ||
          shot.position.z < ship.position.z) {
        continue;
      }
      final dx = shot.position.x - ship.position.x;
      final dy = shot.position.y - ship.position.y;
      final reach = Metrics.laserWidth + shot.radius;
      if (dx * dx + dy * dy > reach * reach) {
        continue;
      }
      game.world.add(Explosion.spark(shot.position, Palette.enemyBullet));
      game.addScore(Tuning.interceptScore);
      shot.removeFromParent();
    }

    final boss = game.boss;
    if (boss != null && boss.isMounted) {
      final dx = boss.position.x - ship.position.x;
      final reach = Metrics.laserWidth + boss.spec.width / 2;
      if (dx.abs() <= reach) {
        boss.takeDamage(damage, at: boss.position);
      }
    }
  }

  @override
  void render3d(Canvas canvas, MeshRenderer renderer, Camera3D camera) {
    final near = camera.project(ship.position);
    _far.setValues(ship.position.x, ship.position.y, PlayArea.spawnDepth);
    final far = camera.project(_far);
    if (near == null || far == null) {
      return;
    }
    final nearWidth = Metrics.laserWidth * near.scale;
    final farWidth = Metrics.laserWidth * far.scale;
    final path = Path()
      ..moveTo(near.screen.dx - nearWidth, near.screen.dy)
      ..lineTo(far.screen.dx - farWidth, far.screen.dy)
      ..lineTo(far.screen.dx + farWidth, far.screen.dy)
      ..lineTo(near.screen.dx + nearWidth, near.screen.dy)
      ..close();
    canvas.drawPath(path, _glow);
    canvas.drawPath(
      Path()
        ..moveTo(near.screen.dx - nearWidth * 0.45, near.screen.dy)
        ..lineTo(far.screen.dx - farWidth * 0.45, far.screen.dy)
        ..lineTo(far.screen.dx + farWidth * 0.45, far.screen.dy)
        ..lineTo(near.screen.dx + nearWidth * 0.45, near.screen.dy)
        ..close(),
      _core,
    );
  }
}
