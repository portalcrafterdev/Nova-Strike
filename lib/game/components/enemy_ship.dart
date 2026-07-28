import 'dart:ui';

import 'package:flame/components.dart' hide Vector3;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../audio/sfx.dart';
import '../../levels/difficulty_curve.dart';
import '../../levels/enemy_catalog.dart';
import '../../levels/level_spec.dart';
import '../../theme/palette.dart';
import '../effects/debris.dart';
import '../effects/explosion.dart';
import '../effects/hit_flash.dart';
import '../nova_game.dart';
import '../render3d/camera3d.dart';
import '../render3d/mesh.dart';
import '../render3d/mesh_renderer.dart';
import '../render3d/scene3d.dart';
import '../systems/bullet_patterns.dart';
import '../systems/movement_patterns.dart';
import '../world/play_area.dart';
import 'bullet.dart';

/// One enemy.
///
/// An enemy is a component plus a movement pattern plus a bullet pattern.
/// There is no subclass per family: the catalog supplies the numbers, the pure
/// pattern functions supply the behaviour, and the mesh library supplies the
/// shape.
class EnemyShip extends Component
    with Renderable3D, HitFlash, HasGameReference<NovaGame> {
  static final Map<EnemyType, Mesh> _meshes = {
    for (final entry in EnemyCatalog.entries.values)
      entry.type: _meshFor(entry),
  };

  /// The model a family flies, so a look at the art never has to rebuild one.
  static Mesh meshOf(EnemyType type) => _meshes[type]!;

  /// Every family gets its own silhouette, because the shape is how a player
  /// reads what is coming at them before the colour registers.
  static Mesh _meshFor(EnemyStats stats) {
    final body = stats.color;
    final trim = Color.lerp(stats.color, const Color(0xFF060A16), 0.3)!;
    final s = stats.size / 26;
    switch (stats.type) {
      case EnemyType.scout:
        return Meshes.scout(body: body, trim: trim, s: s);
      case EnemyType.darter:
        return Meshes.darter(body: body, trim: trim, s: s);
      case EnemyType.gunner:
        return Meshes.gunner(body: body, trim: trim, s: s);
      case EnemyType.bomber:
        return Meshes.bomber(body: body, trim: trim, s: s);
      case EnemyType.shielder:
        return Meshes.shielder(body: body, trim: trim, s: s);
      case EnemyType.splitter:
        return Meshes.splitter(body: body, trim: trim, s: s);
      case EnemyType.turret:
        return Meshes.turret(body: body, trim: trim, s: s);
      case EnemyType.kamikaze:
        return Meshes.kamikaze(body: body, trim: trim, s: s);
    }
  }

  final Vector3 position = Vector3.zero();
  final Vector3 _muzzle = Vector3.zero();
  final Vector3 _velocity = Vector3.zero();

  late EnemyStats stats;
  late MovementPattern movement;
  late BulletPattern bulletPattern;

  double hp = 1;
  double maxHp = 1;
  double speed = 60;
  double fireInterval = 2;
  double bulletSpeed = Tuning.baseEnemyBulletSpeed;
  double phase = 0;
  double holdDepth = PlayArea.holdDepth;
  bool dropsPowerUp = false;

  double _approachX = 0;
  double _approachY = 0;
  double _approachZ = -1;
  double _age = 0;
  double _fireTimer = 0;
  double _burstTimer = 0;
  double _spin = 0;
  int _burstLeft = 0;

  @override
  Vector3 get worldPosition => position;

  /// Sets every value an enemy needs for one life.
  void configure({
    required EnemyStats stats,
    required MovementPattern movement,
    required BulletPattern bullets,
    required double hp,
    required double speed,
    required double fireInterval,
    required double bulletSpeed,
    required Vector3 spawn,
    required double approachX,
    required double approachY,
    required double approachZ,
    required double phase,
    required double holdDepth,
    bool dropsPowerUp = false,
  }) {
    this.stats = stats;
    this.movement = movement;
    bulletPattern = bullets;
    this.hp = hp;
    maxHp = hp;
    this.speed = speed;
    this.fireInterval = fireInterval;
    this.bulletSpeed = bulletSpeed;
    _approachX = approachX;
    _approachY = approachY;
    _approachZ = approachZ;
    this.phase = phase;
    this.holdDepth = holdDepth;
    this.dropsPowerUp = dropsPowerUp;
    position.setFrom(spawn);
    _age = 0;
    _spin = phase;
    _fireTimer = fireInterval * (0.4 + phase.abs() % 0.6);
    _burstLeft = 0;
    _burstTimer = 0;
  }

  @override
  void onMount() {
    super.onMount();
    game.scene.register(this);
    game.enemies.add(this);
  }

  @override
  void onRemove() {
    game.scene.unregister(this);
    game.enemies.remove(this);
    super.onRemove();
  }

  @override
  void update(double dt) {
    // The freeze gem stops the enemy side where it stands.
    if (game.isFrozen) {
      return;
    }
    _age += dt;
    _spin += dt * Metrics.enemySpin;
    updateFlash(dt);

    final player = game.player;
    final velocity = MovementPatterns.velocity(
      movement,
      t: _age,
      speed: speed,
      phase: phase,
      x: position.x,
      y: position.y,
      z: position.z,
      approachX: _approachX,
      approachY: _approachY,
      approachZ: _approachZ,
      holdDepth: holdDepth,
      targetX: player.position.x,
      targetY: player.position.y,
      targetZ: player.position.z,
    );
    _velocity.setValues(velocity.x, velocity.y, velocity.z);
    position.x += velocity.x * dt;
    position.y += velocity.y * dt;
    position.z += velocity.z * dt;

    // Hovering and holding families stay inside the lane.
    if (movement == MovementPattern.hover || movement == MovementPattern.hold) {
      position.x = PlayArea.clampX(position.x, stats.hitRadius);
    }

    if (PlayArea.isOutside(position)) {
      removeFromParent();
      return;
    }

    _updateFiring(dt);
  }

  void _updateFiring(double dt) {
    if (bulletPattern == BulletPattern.none) {
      return;
    }
    if (position.z > PlayArea.spawnDepth * 0.92) {
      // Still arriving out of the distance.
      return;
    }
    if (_burstLeft > 0) {
      _burstTimer -= dt;
      if (_burstTimer <= 0) {
        _shoot(BulletPatterns.burstCount(bulletPattern) - _burstLeft);
        _burstLeft--;
        _burstTimer = BulletPatterns.burstInterval(bulletPattern);
      }
      return;
    }
    _fireTimer -= dt;
    if (_fireTimer <= 0) {
      _fireTimer = fireInterval;
      _burstLeft = BulletPatterns.burstCount(bulletPattern);
      _burstTimer = 0;
    }
  }

  void _shoot(int burstIndex) {
    final player = game.player;
    final shots = BulletPatterns.shotsFor(
      bulletPattern,
      aimX: player.position.x - position.x,
      aimY: player.position.y - position.y,
      aimZ: player.position.z - position.z,
      speed: bulletSpeed,
      phase: _age,
      burstIndex: burstIndex,
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
        owner: BulletOwner.enemy,
        damage: Tuning.enemyBulletDamage,
        waveAmplitude: shot.waveAmplitude,
        waveFrequency: shot.waveFrequency,
      );
    }
  }

  /// Applies damage. Shielders take much less from the front, which is what
  /// makes them worth flanking or hitting with the beam.
  void takeDamage(double amount, {required bool fromFront}) {
    final divisor = fromFront ? stats.frontalArmour : 1.0;
    hp -= amount / divisor;
    startFlash();
    if (hp <= 0) {
      destroy(byPlayer: true);
    } else {
      game.audio.play(Sfx.enemyHit);
    }
  }

  /// Removes the enemy, with the reward and the noise when the player earned
  /// it and quietly when it simply flew past or crashed into the ship.
  void destroy({required bool byPlayer}) {
    if (isRemoving || !isMounted) {
      return;
    }
    game.world.add(Explosion.small(position, stats.color));
    game.world.add(
      Debris(
        source: _meshes[stats.type]!,
        origin: position,
        scale: Metrics.enemyScale,
        inherited: _velocity,
        seed: stats.type.index + 1,
      ),
    );
    game.audio.play(Sfx.enemyExplode);
    if (byPlayer) {
      // Anything with real hit points gets a beat of hit stop, so a kill that
      // took work lands harder than a scout popping.
      if (stats.baseHp >= Tuning.hitStopHpThreshold) {
        game.hitStop(Metrics.hitStopHeavy);
      }
      game.addScore(stats.score);
      game.dropLoot(position, guaranteedPowerUp: dropsPowerUp);
      if (stats.splitsInto > 0) {
        _split();
      }
    }
    removeFromParent();
  }

  /// Splitters leave two smaller scouts behind.
  void _split() {
    final child = EnemyCatalog.of(EnemyType.scout);
    for (var i = 0; i < stats.splitsInto; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final enemy = EnemyShip()
        ..configure(
          stats: child,
          movement: MovementPattern.sine,
          bullets: BulletPattern.none,
          hp: maxHp * 0.25,
          speed: speed * 1.15,
          fireInterval: fireInterval,
          bulletSpeed: bulletSpeed,
          spawn: Vector3(
            position.x + side * stats.size * 0.5,
            position.y,
            position.z,
          ),
          approachX: side * 0.3,
          approachY: 0,
          approachZ: -0.95,
          phase: phase + i,
          holdDepth: holdDepth,
        );
      game.world.add(enemy);
    }
  }

  @override
  void render3d(Canvas canvas, MeshRenderer renderer, Camera3D camera) {
    // The models are built nose first down the negative z axis, the way they
    // fly, so nothing has to be turned around here.
    renderer.draw(
      canvas,
      _meshes[stats.type]!,
      position: position,
      // Square down the lane, whatever the ship is doing. A turret is a drum
      // on a mount, so it is the one family that turns.
      //
      // Nothing banks and nothing aims its nose at the player. The lens looks
      // straight down, so every degree of turn or lean shows the hull at an
      // angle, and eight families all leaning different ways is what made a
      // wave hard to read.
      yaw: stats.type == EnemyType.turret ? _spin : 0,
      pitch: stats.type == EnemyType.turret ? 0 : Metrics.enemyPitch,
      scale: Metrics.enemyScale,
      flash: flashAmount,
    );
  }
}
