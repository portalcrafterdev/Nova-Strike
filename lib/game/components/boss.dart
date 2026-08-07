import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart' hide Vector3;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../audio/sfx.dart';
import '../../levels/difficulty_curve.dart';
import '../../levels/level_spec.dart';
import '../../theme/palette.dart';
import '../effects/debris.dart';
import '../effects/explosion.dart';
import '../effects/screen_flash.dart';
import '../effects/shockwave.dart';
import '../effects/hit_flash.dart';
import '../nova_game.dart';
import '../render3d/camera3d.dart';
import '../render3d/mesh.dart';
import '../render3d/mesh_renderer.dart';
import '../render3d/scene3d.dart';
import '../systems/bullet_patterns.dart';
import '../world/play_area.dart';
import 'bullet.dart';

/// A boss fight.
///
/// The boss owns its phases, its weak points and its shield arc. Phase one
/// runs from full health to 66 percent, phase two to 33 percent, and phase
/// three to the end, with each phase adding a bullet pattern and speeding the
/// movement up.
class Boss extends Component
    with Renderable3D, HitFlash, HasGameReference<NovaGame> {
  Boss(this.spec)
    : _mesh = Meshes.capital(
        hull: Palette.bossHull,
        hullDark: Palette.bossHullDark,
        core: Palette.bossCore,
        glow: Palette.bossThruster,
        width: spec.width,
        height: spec.height,
        depth: spec.width * 0.7,
      );

  /// How far ahead of the player the boss settles.
  static const double restDepth = 300;

  /// How far out the boss swings while it moves.
  static const double sweepWidth = 46;

  final BossSpec spec;
  final Mesh _mesh;

  static final Paint _shieldPaint = Paint()..style = PaintingStyle.stroke;

  final Vector3 position = Vector3(0, 0, PlayArea.spawnDepth * 1.4);
  final Vector3 _origin = Vector3.zero();
  final Vector3 _muzzle = Vector3.zero();
  final List<BossPod> pods = [];

  late double hp = spec.maxHp;
  int phase = 1;
  double shieldHp = 0;
  double maxShieldHp = 0;

  double _age = 0;
  double _entryTime = 0;
  double _fireTimer = 0;
  int _patternCursor = 0;
  bool _dying = false;

  bool get isEntering => _entryTime < Tuning.bossEntryDuration;
  bool get hasShield => spec.hasShieldArc && shieldHp > 0;
  bool get podsAlive => pods.any((pod) => pod.isMounted && pod.hp > 0);

  /// Collision radius in world units.
  double get radius => spec.width * 0.42;

  /// Health as a fraction, which is what the bar at the top of the screen
  /// reads.
  double get healthFraction => (hp / spec.maxHp).clamp(0.0, 1.0);

  @override
  Vector3 get worldPosition => position;

  @override
  Future<void> onLoad() async {
    if (spec.hasShieldArc) {
      maxShieldHp = spec.maxHp * Tuning.bossShieldHpFraction;
      shieldHp = maxShieldHp;
    }

    for (var i = 0; i < spec.weakPoints; i++) {
      final side = i.isEven ? -1 : 1;
      final row = i ~/ 2;
      final pod = BossPod(
        boss: this,
        hp: spec.maxHp * Tuning.bossPodHpFraction,
        offset: Vector3(
          side * spec.width * 0.42,
          row == 0 ? spec.height * 0.18 : -spec.height * 0.22,
          -spec.width * 0.1,
        ),
      );
      pods.add(pod);
      await game.world.add(pod);
    }

    game.bossNameNotifier.value = spec.name;
    game.bossHealthNotifier.value = 1;
  }

  @override
  void onMount() {
    super.onMount();
    game.scene.register(this);
    game.boss = this;
  }

  @override
  void onRemove() {
    game.scene.unregister(this);
    if (game.boss == this) {
      game.boss = null;
    }
    for (final pod in pods) {
      pod.removeFromParent();
    }
    super.onRemove();
  }

  @override
  void update(double dt) {
    if (game.isFrozen) {
      return;
    }
    _age += dt;
    updateFlash(dt);

    if (isEntering) {
      _entryTime += dt;
      final t = (_entryTime / Tuning.bossEntryDuration).clamp(0.0, 1.0);
      // Ease out so the arrival settles rather than stopping dead.
      final eased = 1 - math.pow(1 - t, 3).toDouble();
      position.z =
          PlayArea.spawnDepth * 1.4 +
          (restDepth - PlayArea.spawnDepth * 1.4) * eased;
      return;
    }

    _move(dt);
    _updateFiring(dt);
  }

  void _move(double dt) {
    final rate = spec.moveSpeed * (1 + Tuning.bossPhaseSpeedStep * (phase - 1));
    position.x = math.sin(_age * rate / 90) * sweepWidth;
    position.z = restDepth + math.sin(_age * 0.45) * 40;
  }

  void _updateFiring(double dt) {
    _fireTimer -= dt;
    if (_fireTimer > 0) {
      return;
    }
    final patterns = _activePatterns();
    if (patterns.isEmpty) {
      return;
    }
    final pattern = patterns[_patternCursor % patterns.length];
    _patternCursor++;
    _fireTimer =
        spec.fireInterval / (1 + Tuning.bossPhaseFireStep * (phase - 1));
    _shoot(pattern);
  }

  /// Later phases stack patterns on top of earlier ones rather than replacing
  /// them, so the fight gets busier as it goes.
  List<BulletPattern> _activePatterns() {
    final patterns = <BulletPattern>[];
    for (var i = 0; i < phase && i < spec.phasePatterns.length; i++) {
      patterns.addAll(spec.phasePatterns[i]);
    }
    return patterns;
  }

  void _shoot(BulletPattern pattern) {
    final player = game.player;
    _origin.setValues(position.x, position.y, position.z - spec.width * 0.3);
    final shots = BulletPatterns.shotsFor(
      pattern,
      aimX: player.position.x - _origin.x,
      aimY: player.position.y - _origin.y,
      aimZ: player.position.z - _origin.z,
      speed: Tuning.baseEnemyBulletSpeed * game.spec.bulletSpeedMultiplier,
      phase: _age,
    );
    for (final shot in shots) {
      _muzzle.setValues(
        _origin.x + shot.offsetX,
        _origin.y + shot.offsetY,
        _origin.z + shot.offsetZ,
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

  /// Damage arriving at the core.
  ///
  /// The shield arc eats damage until it breaks, and while any weak point is
  /// alive the core takes nothing at all.
  void takeDamage(double amount, {required Vector3 at}) {
    if (_dying || isEntering) {
      return;
    }
    if (hasShield) {
      shieldHp -= amount;
      startFlash();
      game.audio.play(Sfx.bossHit);
      if (shieldHp <= 0) {
        shieldHp = 0;
        game.audio.play(Sfx.shieldBreak);
        game.shake.shake(
          Metrics.shakeAmplitudeSmall,
          Metrics.shakeDurationSmall,
        );
      }
      return;
    }
    if (podsAlive) {
      startFlash();
      game.world.add(Explosion.spark(at, Palette.bossShield));
      return;
    }

    hp -= amount;
    startFlash();
    game.audio.play(Sfx.bossHit);
    game.bossHealthNotifier.value = healthFraction;

    final fraction = healthFraction;
    if (phase == 1 && fraction <= Tuning.bossPhaseTwoThreshold) {
      _enterPhase(2);
    } else if (phase == 2 && fraction <= Tuning.bossPhaseThreeThreshold) {
      _enterPhase(3);
    }

    if (hp <= 0) {
      _die();
    }
  }

  void _enterPhase(int next) {
    phase = next;
    game.audio.play(Sfx.waveIncoming);
    game.shake.shake(Metrics.shakeAmplitudeSmall, Metrics.shakeDurationSmall);
    // The longest freeze in the game, because a phase change is the fight
    // telling the player it has more to give.
    game.hitStop(Metrics.hitStopPhase);
    game.world.add(ScreenFlash(color: Palette.bossShield));
    game.world.add(Shockwave(origin: position, color: Palette.bossShield));
    // A broken shield comes back for the last phase on the archetypes that
    // carry one, so the fight does not end as a damage race.
    if (spec.hasShieldArc && next == 3) {
      shieldHp = maxShieldHp * 0.5;
    }
  }

  /// Called by a weak point when it is destroyed.
  void onPodDestroyed() {
    game.shake.shake(Metrics.shakeAmplitudeSmall, Metrics.shakeDurationSmall);
    if (!podsAlive) {
      game.audio.play(Sfx.shieldBreak);
    }
  }

  void _die() {
    if (_dying) {
      return;
    }
    _dying = true;
    hp = 0;
    game.bossHealthNotifier.value = 0;
    game.audio.play(Sfx.bossExplode);
    game.audio.duckMusic();
    game.slowMotion();
    game.shake.shake(Metrics.shakeAmplitudeLarge, Metrics.shakeDurationLarge);
    game.vibrate(HapticsStrength.heavy);
    game.addScore(spec.maxHp.round());
    for (var i = 0; i < 4; i++) {
      game.world.add(
        Explosion.large(
          Vector3(
            position.x + (i.isEven ? -1 : 1) * spec.width * 0.2,
            0,
            position.z,
          ),
          Palette.bossCore,
        ),
      );
    }
    game.world.add(
      Debris(
        source: _mesh,
        origin: position,
        inherited: Vector3(0, 0, -60),
        seed: spec.archetype + 11,
        lifespan: Metrics.debrisLifespan * 2,
      ),
    );
    game.world.add(
      Shockwave(
        origin: position,
        color: Palette.bossCore,
        reach: Metrics.shockwaveBossReach,
        lifespan: Metrics.shockwaveBossLifespan,
      ),
    );
    game.dropLoot(position, guaranteedPowerUp: true);
    removeFromParent();
  }

  @override
  void render3d(Canvas canvas, MeshRenderer renderer, Camera3D camera) {
    renderer.draw(
      canvas,
      _mesh,
      position: position,
      pitch: Metrics.enemyPitch,
      roll: math.sin(_age * 0.6) * 0.06,
      flash: flashAmount,
    );

    if (!hasShield) {
      return;
    }
    final projected = camera.project(position);
    if (projected == null) {
      return;
    }
    final radius = spec.width * 0.62 * projected.scale;
    _shieldPaint
      ..color = Palette.bossShield.withValues(
        alpha: 0.25 + 0.35 * (shieldHp / maxShieldHp),
      )
      ..strokeWidth = math.max(2, radius * 0.06);
    canvas.drawArc(
      Rect.fromCircle(center: projected.screen, radius: radius),
      math.pi * 0.15,
      math.pi * 0.7,
      false,
      _shieldPaint,
    );
  }
}

/// A destructible pod on the side of a boss.
///
/// While any pod is alive the core is armoured, so the pods are the opening
/// move of the fight.
class BossPod extends Component
    with Renderable3D, HitFlash, HasGameReference<NovaGame> {
  BossPod({required this.boss, required this.hp, required Vector3 offset})
    : maxHp = hp,
      _mesh = _podMesh {
    _offset.setFrom(offset);
  }

  static final Mesh _podMesh = Meshes.weakPoint(
    hull: Palette.bossHull,
    hullDark: Palette.bossHullDark,
    core: Palette.bossCore,
    radius: podRadius,
  );

  /// Radius in world units.
  static const double podRadius = 13;

  final Boss boss;
  final Vector3 _offset = Vector3.zero();

  final Mesh _mesh;
  final Vector3 position = Vector3.zero();

  double hp;
  final double maxHp;

  double get radius => podRadius;

  @override
  Vector3 get worldPosition => position;

  @override
  void onMount() {
    super.onMount();
    game.scene.register(this);
    game.bossPods.add(this);
  }

  @override
  void onRemove() {
    game.scene.unregister(this);
    game.bossPods.remove(this);
    super.onRemove();
  }

  @override
  void update(double dt) {
    updateFlash(dt);
    position
      ..setFrom(boss.position)
      ..add(_offset);
    if (!boss.isMounted) {
      removeFromParent();
    }
  }

  void takeDamage(double amount) {
    if (hp <= 0) {
      return;
    }
    hp -= amount;
    startFlash();
    game.audio.play(Sfx.enemyHit);
    if (hp <= 0) {
      game.world.add(Explosion.small(position, Palette.bossCore));
      game.audio.play(Sfx.enemyExplode);
      boss.onPodDestroyed();
      removeFromParent();
    }
  }

  @override
  void render3d(Canvas canvas, MeshRenderer renderer, Camera3D camera) {
    renderer.draw(
      canvas,
      _mesh,
      position: position,
      pitch: Metrics.enemyPitch,
      // Square on to the player, the same as the hull it is bolted to. It used
      // to sit at an angle taken from the boss phase, which turned a pod edge
      // on and made it hard to see what you were shooting at.
      yaw: 0,
      flash: flashAmount,
    );
  }
}
