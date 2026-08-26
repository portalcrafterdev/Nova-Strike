import 'dart:ui';

import '../theme/palette.dart';
import 'level_spec.dart';

/// Base stats for one enemy family, before any level scaling is applied.
class EnemyStats {
  const EnemyStats({
    required this.type,
    required this.name,
    required this.baseHp,
    required this.baseSpeed,
    required this.size,
    required this.baseHitRadius,
    required this.fireInterval,
    required this.unlockChapter,
    required this.score,
    required this.contactDamage,
    required this.defaultMovement,
    required this.defaultBullets,
    required this.color,
    this.splitsInto = 0,
    this.frontalArmour = 1.0,
  });

  final EnemyType type;
  final String name;
  final double baseHp;

  /// Logical units per second before the level speed multiplier.
  final double baseSpeed;

  /// Drawn width and height of the hull.
  final double size;

  /// Collision radius before the drawing scale, deliberately smaller than
  /// the hull it sits inside.
  final double baseHitRadius;

  /// Collision radius as drawn. It tracks the drawing scale so a hit lands
  /// where the ship looks like it is.
  double get hitRadius => baseHitRadius * Metrics.enemyScale;

  /// Seconds between shots before the level fire rate multiplier.
  final double fireInterval;
  final int unlockChapter;
  final int score;
  final int contactDamage;
  final MovementPattern defaultMovement;
  final BulletPattern defaultBullets;
  final Color color;

  /// Splitters spawn this many scouts when they die.
  final int splitsInto;

  /// Damage taken from the front is divided by this. Shielders block head on.
  final double frontalArmour;
}

/// Every enemy family in the game, keyed by type.
class EnemyCatalog {
  const EnemyCatalog._();

  static const Map<EnemyType, EnemyStats> entries = {
    EnemyType.scout: EnemyStats(
      type: EnemyType.scout,
      name: 'Scout',
      baseHp: 10,
      baseSpeed: 88,
      size: 26,
      baseHitRadius: 11,
      fireInterval: 1.9,
      unlockChapter: 1,
      score: 100,
      contactDamage: 1,
      defaultMovement: MovementPattern.straight,
      defaultBullets: BulletPattern.aimedSingle,
      color: Palette.enemyScout,
    ),
    EnemyType.darter: EnemyStats(
      type: EnemyType.darter,
      name: 'Darter',
      baseHp: 8,
      baseSpeed: 148,
      size: 22,
      baseHitRadius: 9,
      fireInterval: 1.6,
      unlockChapter: 2,
      score: 130,
      contactDamage: 1,
      defaultMovement: MovementPattern.sine,
      defaultBullets: BulletPattern.spread3,
      color: Palette.enemyDarter,
    ),
    EnemyType.gunner: EnemyStats(
      type: EnemyType.gunner,
      name: 'Gunner',
      baseHp: 20,
      baseSpeed: 70,
      size: 30,
      baseHitRadius: 13,
      fireInterval: 1.0,
      unlockChapter: 3,
      score: 200,
      contactDamage: 1,
      defaultMovement: MovementPattern.hover,
      defaultBullets: BulletPattern.waveShot,
      color: Palette.enemyGunner,
    ),
    EnemyType.bomber: EnemyStats(
      type: EnemyType.bomber,
      name: 'Bomber',
      baseHp: 30,
      baseSpeed: 54,
      size: 36,
      baseHitRadius: 16,
      fireInterval: 2.2,
      unlockChapter: 4,
      score: 260,
      contactDamage: 1,
      defaultMovement: MovementPattern.zigzag,
      defaultBullets: BulletPattern.ringBurst,
      color: Palette.enemyBomber,
    ),
    EnemyType.shielder: EnemyStats(
      type: EnemyType.shielder,
      name: 'Shielder',
      baseHp: 40,
      baseSpeed: 60,
      size: 32,
      baseHitRadius: 14,
      fireInterval: 1.7,
      unlockChapter: 5,
      score: 300,
      contactDamage: 1,
      defaultMovement: MovementPattern.swoop,
      defaultBullets: BulletPattern.aimedBurst3,
      color: Palette.enemyShielder,
      frontalArmour: 3.0,
    ),
    EnemyType.splitter: EnemyStats(
      type: EnemyType.splitter,
      name: 'Splitter',
      baseHp: 22,
      baseSpeed: 80,
      size: 30,
      baseHitRadius: 13,
      fireInterval: 2.0,
      unlockChapter: 7,
      score: 280,
      contactDamage: 1,
      defaultMovement: MovementPattern.orbit,
      defaultBullets: BulletPattern.spiralShot,
      color: Palette.enemySplitter,
      splitsInto: 2,
    ),
    EnemyType.turret: EnemyStats(
      type: EnemyType.turret,
      name: 'Turret',
      baseHp: 48,
      baseSpeed: 0,
      size: 30,
      baseHitRadius: 14,
      fireInterval: 1.2,
      unlockChapter: 9,
      score: 340,
      contactDamage: 1,
      defaultMovement: MovementPattern.hold,
      defaultBullets: BulletPattern.aimedBurst3,
      color: Palette.enemyTurret,
    ),
    EnemyType.kamikaze: EnemyStats(
      type: EnemyType.kamikaze,
      name: 'Kamikaze',
      baseHp: 12,
      baseSpeed: 205,
      size: 24,
      baseHitRadius: 10,
      fireInterval: 0,
      unlockChapter: 11,
      score: 220,
      contactDamage: 1,
      defaultMovement: MovementPattern.dive,
      defaultBullets: BulletPattern.none,
      color: Palette.enemyKamikaze,
    ),
  };

  static EnemyStats of(EnemyType type) => entries[type]!;

  /// Enemy families available in a chapter, in unlock order.
  /// The families a chapter introduces, which is empty for most chapters.
  static List<EnemyType> newIn(int chapter) {
    final list = <EnemyType>[];
    for (final entry in entries.values) {
      if (entry.unlockChapter == chapter) {
        list.add(entry.type);
      }
    }
    return list;
  }

  static List<EnemyType> unlockedIn(int chapter) {
    final list = <EnemyType>[];
    for (final entry in entries.values) {
      if (entry.unlockChapter <= chapter) {
        list.add(entry.type);
      }
    }
    return list;
  }
}
