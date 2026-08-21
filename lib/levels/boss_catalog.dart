import 'difficulty_curve.dart';
import 'level_spec.dart';

/// The fixed part of a boss archetype. The changing parts, hit points and the
/// extra pattern earned on every repeat, are applied by [BossCatalog.build].
class BossArchetype {
  const BossArchetype({
    required this.name,
    required this.width,
    required this.height,
    required this.moveSpeed,
    required this.fireInterval,
    required this.weakPoints,
    required this.hasShieldArc,
    required this.phasePatterns,
    required this.extraPatterns,
  });

  final String name;
  final double width;
  final double height;
  final double moveSpeed;
  final double fireInterval;
  final int weakPoints;
  final bool hasShieldArc;

  /// Three lists, one per phase. Later phases stack on top of earlier ones.
  final List<List<BulletPattern>> phasePatterns;

  /// Drawn from in order every time this archetype comes back around.
  final List<BulletPattern> extraPatterns;
}

/// The ten boss archetypes. Chapter 1 meets archetype 0, chapter 11 meets it
/// again with more hit points and one more attack pattern, and so on.
class BossCatalog {
  const BossCatalog._();

  static const List<BossArchetype> archetypes = [
    BossArchetype(
      name: 'Hammerhead',
      width: 190,
      height: 120,
      moveSpeed: 60,
      fireInterval: 1.5,
      weakPoints: 0,
      hasShieldArc: false,
      phasePatterns: [
        [BulletPattern.aimedSingle],
        [BulletPattern.spread3],
        [BulletPattern.ringBurst],
      ],
      extraPatterns: [BulletPattern.waveShot, BulletPattern.spiralShot],
    ),
    BossArchetype(
      name: 'Vulcan Array',
      width: 210,
      height: 110,
      moveSpeed: 52,
      fireInterval: 1.2,
      weakPoints: 2,
      hasShieldArc: false,
      phasePatterns: [
        [BulletPattern.waveShot],
        [BulletPattern.aimedBurst3],
        [BulletPattern.spread3],
      ],
      extraPatterns: [BulletPattern.ringBurst, BulletPattern.spiralShot],
    ),
    BossArchetype(
      name: 'Nova Crawler',
      width: 170,
      height: 150,
      moveSpeed: 74,
      fireInterval: 1.35,
      weakPoints: 0,
      hasShieldArc: false,
      phasePatterns: [
        [BulletPattern.spiralShot],
        [BulletPattern.aimedSingle],
        [BulletPattern.ringBurst],
      ],
      extraPatterns: [BulletPattern.spread3, BulletPattern.waveShot],
    ),
    BossArchetype(
      name: 'Aegis Warden',
      width: 200,
      height: 130,
      moveSpeed: 46,
      fireInterval: 1.6,
      weakPoints: 2,
      hasShieldArc: true,
      phasePatterns: [
        [BulletPattern.spread3],
        [BulletPattern.waveShot],
        [BulletPattern.aimedBurst3],
      ],
      extraPatterns: [BulletPattern.ringBurst, BulletPattern.spiralShot],
    ),
    BossArchetype(
      name: 'Siege Colossus',
      width: 230,
      height: 140,
      moveSpeed: 38,
      fireInterval: 1.8,
      weakPoints: 4,
      hasShieldArc: false,
      phasePatterns: [
        [BulletPattern.ringBurst],
        [BulletPattern.aimedBurst3],
        [BulletPattern.waveShot],
      ],
      extraPatterns: [BulletPattern.spiralShot, BulletPattern.spread3],
    ),
    BossArchetype(
      name: 'Wraith Lance',
      width: 160,
      height: 160,
      moveSpeed: 88,
      fireInterval: 1.1,
      weakPoints: 0,
      hasShieldArc: false,
      phasePatterns: [
        [BulletPattern.aimedBurst3],
        [BulletPattern.spiralShot],
        [BulletPattern.spread3],
      ],
      extraPatterns: [BulletPattern.waveShot, BulletPattern.ringBurst],
    ),
    BossArchetype(
      name: 'Bastion Prime',
      width: 220,
      height: 120,
      moveSpeed: 44,
      fireInterval: 1.45,
      weakPoints: 2,
      hasShieldArc: true,
      phasePatterns: [
        [BulletPattern.waveShot],
        [BulletPattern.ringBurst],
        [BulletPattern.spiralShot],
      ],
      extraPatterns: [BulletPattern.aimedBurst3, BulletPattern.spread3],
    ),
    BossArchetype(
      name: 'Hydra Swarmer',
      width: 180,
      height: 140,
      moveSpeed: 70,
      fireInterval: 1.25,
      weakPoints: 4,
      hasShieldArc: false,
      phasePatterns: [
        [BulletPattern.spread3],
        [BulletPattern.spiralShot],
        [BulletPattern.ringBurst],
      ],
      extraPatterns: [BulletPattern.waveShot, BulletPattern.aimedBurst3],
    ),
    BossArchetype(
      name: 'Eclipse Reaper',
      width: 200,
      height: 150,
      moveSpeed: 64,
      fireInterval: 1.15,
      weakPoints: 0,
      hasShieldArc: false,
      phasePatterns: [
        [BulletPattern.ringBurst],
        [BulletPattern.spiralShot],
        [BulletPattern.aimedBurst3],
      ],
      extraPatterns: [BulletPattern.spread3, BulletPattern.waveShot],
    ),
    BossArchetype(
      name: 'Sovereign Core',
      width: 240,
      height: 160,
      moveSpeed: 56,
      fireInterval: 1.05,
      weakPoints: 4,
      hasShieldArc: true,
      phasePatterns: [
        [BulletPattern.spiralShot],
        [BulletPattern.ringBurst],
        [BulletPattern.waveShot],
      ],
      extraPatterns: [BulletPattern.aimedBurst3, BulletPattern.spread3],
    ),
  ];

  /// Builds the boss for a level. Archetype comes from the chapter, and every
  /// repeat of an archetype adds hit points, speed and one attack pattern.
  static BossSpec build(
    int level, {
    Difficulty difficulty = Difficulty.medium,
  }) {
    final chapter = Tuning.chapterOf(level);
    final index = (chapter - 1) % Tuning.bossArchetypeCount;
    final repeat = (chapter - 1) ~/ Tuning.bossArchetypeCount;
    final archetype = archetypes[index];

    final patterns = <List<BulletPattern>>[
      for (final phase in archetype.phasePatterns)
        List<BulletPattern>.of(phase),
    ];
    for (var i = 0; i < repeat; i++) {
      final extra = archetype.extraPatterns[i % archetype.extraPatterns.length];
      final phase = patterns[i % patterns.length];
      if (!phase.contains(extra)) {
        phase.add(extra);
      }
    }

    return BossSpec(
      archetype: index,
      name: archetype.name,
      maxHp:
          Tuning.bossHp(level, repeat) *
          DifficultyTuning.hpFactor(difficulty),
      width: archetype.width,
      height: archetype.height,
      phasePatterns: patterns,
      moveSpeed: archetype.moveSpeed,
      fireInterval:
          archetype.fireInterval /
          Tuning.enemyFireRateMultiplier(level) /
          DifficultyTuning.fireRateFactor(difficulty),
      weakPoints: archetype.weakPoints,
      hasShieldArc: archetype.hasShieldArc,
      contactDamage: 1,
    );
  }
}
