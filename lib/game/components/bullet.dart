import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart' hide Vector3;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../levels/difficulty_curve.dart';
import '../../theme/palette.dart';
import '../nova_game.dart';
import '../render/camera.dart';
import '../render/sprite_renderer.dart';
import '../render/scene.dart';
import '../world/play_area.dart';

/// Who fired a bullet. Bullets pass straight through whoever fired them.
enum BulletOwner { player, enemy }

/// A single bullet.
///
/// Bullets are pooled and reset rather than allocated, they mutate their own
/// vectors in place, and they draw as a projected glow rather than a model, so
/// a screen full of them costs almost nothing.
class Bullet extends Component with Renderable, HasGameReference<NovaGame> {
  static final Paint _paint = Paint();
  static final Paint _glowPaint = Paint();

  final Vector3 position = Vector3.zero();
  final Vector3 velocity = Vector3.zero();

  /// Where the bullet was at the end of the last frame.
  ///
  /// Collision is tested along the line between the two, because a fast bullet
  /// covers more ground in one frame than a small enemy is wide and would
  /// otherwise skip straight over it.
  final Vector3 previous = Vector3.zero();

  BulletOwner owner = BulletOwner.player;
  double damage = Tuning.playerBulletDamage;
  double waveAmplitude = 0;
  double waveFrequency = 0;
  double age = 0;
  bool piercing = false;

  /// True for a railgun lance, which is drawn fatter and in its own colour so
  /// the player can tell it apart from the stream of ordinary fire.
  bool heavy = false;

  /// Collision radius in world units.
  double get radius {
    if (owner != BulletOwner.player) {
      return Metrics.enemyBulletRadius;
    }
    return heavy ? Metrics.railBoltRadius : Metrics.bulletRadius;
  }

  @override
  Vector3 get worldPosition => position;

  /// Prepares a pooled bullet for another life.
  void reset({
    required Vector3 spawn,
    required double velocityX,
    required double velocityY,
    required double velocityZ,
    required BulletOwner owner,
    required double damage,
    double waveAmplitude = 0,
    double waveFrequency = 0,
    bool piercing = false,
    bool heavy = false,
  }) {
    position.setFrom(spawn);
    previous.setFrom(spawn);
    velocity.setValues(velocityX, velocityY, velocityZ);
    this.owner = owner;
    this.damage = damage;
    this.waveAmplitude = waveAmplitude;
    this.waveFrequency = waveFrequency;
    this.piercing = piercing;
    this.heavy = heavy;
    age = 0;
  }

  @override
  void onMount() {
    super.onMount();
    game.scene.register(this);
  }

  @override
  void onRemove() {
    game.scene.unregister(this);
    game.bullets.onBulletRemoved(this);
    super.onRemove();
  }

  @override
  void update(double dt) {
    // Enemy fire slows down while the slow gem is running.
    if (owner == BulletOwner.enemy && game.isFrozen) {
      // Frozen fire hangs in the air rather than vanishing, so the player can
      // see exactly what they have been given a moment to fly out of.
      return;
    }
    final step = owner == BulletOwner.enemy && game.isSlowActive
        ? dt * Tuning.slowBulletFactor
        : dt;
    age += step;

    previous.setFrom(position);
    position.x += velocity.x * step;
    position.y += velocity.y * step;
    position.z += velocity.z * step;

    if (waveAmplitude != 0) {
      // Sideways travel is the derivative of the sine the pattern asked for,
      // so the bullet weaves without having to remember a base line.
      final lateral =
          waveAmplitude * waveFrequency * math.cos(age * waveFrequency);
      position.x += lateral * step;
    }

    if (PlayArea.isOutside(position)) {
      removeFromParent();
    }
  }

  @override
  void paint(Canvas canvas, SpriteRenderer renderer, GameCamera camera) {
    final projected = camera.project(position);
    if (projected == null) {
      return;
    }
    // Drawn size and collision size are deliberately separate. The large
    // bullets setting makes fire easier to see without making it easier or
    // harder to hit anything with.
    final drawn = game.progress.largeBullets
        ? radius * Metrics.largeBulletScale
        : radius;
    final cap = game.progress.largeBullets
        ? Metrics.bulletMaxRadius * Metrics.largeBulletScale
        : Metrics.bulletMaxRadius;
    final size = math.min(drawn * projected.scale, cap);
    if (size < 0.4) {
      return;
    }
    final isPlayerShot = owner == BulletOwner.player;
    if (heavy) {
      _glowPaint.color = Palette.railBoltGlow;
      _paint.color = Palette.railBolt;
    } else if (isPlayerShot) {
      _glowPaint.color = Palette.playerBulletGlow;
      _paint.color = Palette.playerBullet;
    } else if (game.progress.highContrast) {
      _glowPaint.color = Palette.enemyBulletContrastGlow;
      _paint.color = Palette.enemyBulletContrast;
    } else {
      _glowPaint.color = Palette.enemyBulletGlow;
      _paint.color = Palette.enemyBullet;
    }
    canvas.drawCircle(
      projected.screen,
      size * Metrics.bulletGlowScale,
      _glowPaint,
    );
    canvas.drawCircle(projected.screen, size, _paint);
  }
}

/// Pool and cap for bullets.
///
/// Bullet hell dies on frame drops, so bullets are recycled and the number in
/// the air is capped. When the cap is hit the oldest bullet makes way.
class BulletPool {
  final ComponentPool<Bullet> _pool = ComponentPool<Bullet>(
    factory: Bullet.new,
    maxSize: Tuning.maxActiveBullets,
    initialSize: 80,
  );

  final List<Bullet> _active = [];

  /// Live bullets, which the collision system walks every frame.
  List<Bullet> get active => _active;

  int get activeCount => _active.length;

  /// Takes a bullet from the pool, resets it and adds it to the world.
  Bullet spawn(
    Component world, {
    required Vector3 spawn,
    required double velocityX,
    required double velocityY,
    required double velocityZ,
    required BulletOwner owner,
    required double damage,
    double waveAmplitude = 0,
    double waveFrequency = 0,
    bool piercing = false,
    bool heavy = false,
  }) {
    if (_active.length >= Tuning.maxActiveBullets) {
      _compact();
    }
    if (_active.length >= Tuning.maxActiveBullets) {
      _active.removeAt(0).removeFromParent();
    }
    final bullet = _pool.acquire()
      ..reset(
        spawn: spawn,
        velocityX: velocityX,
        velocityY: velocityY,
        velocityZ: velocityZ,
        owner: owner,
        damage: damage,
        waveAmplitude: waveAmplitude,
        waveFrequency: waveFrequency,
        piercing: piercing,
        heavy: heavy,
      );
    _active.add(bullet);
    world.add(bullet);
    return bullet;
  }

  /// Called by a bullet as it leaves the world.
  ///
  /// Bullets take themselves off the list rather than the list being swept for
  /// dead entries, because a bullet added this frame has not mounted yet and a
  /// sweep would drop it before it ever had a chance to hit anything.
  void onBulletRemoved(Bullet bullet) {
    _active.remove(bullet);
  }

  /// Drops anything left behind, used only when the cap is reached.
  void _compact() {
    _active.removeWhere((bullet) => bullet.isRemoving || bullet.isRemoved);
  }

  /// Called when a level restarts.
  void clear() {
    for (final bullet in _active) {
      bullet.removeFromParent();
    }
    _active.clear();
  }
}
