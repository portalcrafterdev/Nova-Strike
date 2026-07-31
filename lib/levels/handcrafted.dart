import 'boss_catalog.dart';
import 'difficulty_curve.dart';
import 'enemy_catalog.dart';
import 'level_spec.dart';

/// Levels that override the generated spec.
///
/// The generator is consulted only when a level number is absent from
/// [levels]. Three things live here: the hand tuned opening levels, a set
/// piece on every hundredth level, and any level that playtesting flags as
/// unfair.
class Handcrafted {
  const Handcrafted._();

  /// Levels 1 to 8 teach the game. Level 1 has one slow wave and no enemy fire
  /// at all, and difficulty is added one idea at a time after that.
  static final Map<int, LevelSpec> levels = _build();

  static Map<int, LevelSpec> _build() {
    final map = <int, LevelSpec>{};

    map[1] = _tutorial(
      1,
      hp: 1.3,
      speed: 0.7,
      waves: const [
        WaveSpec(
          type: EnemyType.scout,
          count: 6,
          formation: Formation.line,
          entry: EntrySide.top,
          movement: MovementPattern.straight,
          bullets: BulletPattern.none,
          spawnDelay: 1.2,
        ),
      ],
    );

    map[2] = _tutorial(
      2,
      hp: 1.5,
      speed: 0.8,
      fireRate: 0.7,
      waves: const [
        WaveSpec(
          type: EnemyType.scout,
          count: 4,
          formation: Formation.line,
          entry: EntrySide.top,
          movement: MovementPattern.straight,
          bullets: BulletPattern.none,
          spawnDelay: 1.0,
        ),
        WaveSpec(
          type: EnemyType.scout,
          count: 6,
          formation: Formation.vee,
          entry: EntrySide.top,
          movement: MovementPattern.straight,
          bullets: BulletPattern.aimedSingle,
          spawnDelay: 1.8,
        ),
      ],
    );

    map[3] = _tutorial(
      3,
      hp: 1.6,
      speed: 0.85,
      fireRate: 0.8,
      waves: const [
        WaveSpec(
          type: EnemyType.scout,
          count: 5,
          formation: Formation.vee,
          entry: EntrySide.top,
          movement: MovementPattern.straight,
          bullets: BulletPattern.aimedSingle,
          spawnDelay: 1.0,
        ),
        WaveSpec(
          type: EnemyType.scout,
          count: 5,
          formation: Formation.line,
          entry: EntrySide.top,
          movement: MovementPattern.straight,
          bullets: BulletPattern.aimedSingle,
          spawnDelay: 1.8,
        ),
      ],
    );

    map[4] = _tutorial(
      4,
      hp: 1.7,
      speed: 0.9,
      fireRate: 0.85,
      waves: const [
        WaveSpec(
          type: EnemyType.scout,
          count: 5,
          formation: Formation.line,
          entry: EntrySide.top,
          movement: MovementPattern.sine,
          bullets: BulletPattern.aimedSingle,
          spawnDelay: 0.9,
        ),
        WaveSpec(
          type: EnemyType.scout,
          count: 6,
          formation: Formation.vee,
          entry: EntrySide.top,
          movement: MovementPattern.straight,
          bullets: BulletPattern.aimedSingle,
          spawnDelay: 1.6,
        ),
      ],
    );

    map[5] = _tutorial(
      5,
      hp: 1.6,
      speed: 0.85,
      fireRate: 0.75,
      waves: const [
        WaveSpec(
          type: EnemyType.scout,
          count: 6,
          formation: Formation.vee,
          entry: EntrySide.top,
          movement: MovementPattern.straight,
          bullets: BulletPattern.aimedSingle,
          spawnDelay: 0.9,
        ),
        WaveSpec(
          type: EnemyType.scout,
          count: 6,
          formation: Formation.line,
          entry: EntrySide.top,
          movement: MovementPattern.sine,
          bullets: BulletPattern.none,
          spawnDelay: 1.6,
        ),
      ],
    );

    map[6] = _tutorial(
      6,
      hp: 1.8,
      speed: 0.95,
      fireRate: 0.9,
      waves: const [
        WaveSpec(
          type: EnemyType.scout,
          count: 6,
          formation: Formation.vee,
          entry: EntrySide.top,
          movement: MovementPattern.sine,
          bullets: BulletPattern.aimedSingle,
          spawnDelay: 0.9,
        ),
        WaveSpec(
          type: EnemyType.scout,
          count: 6,
          formation: Formation.line,
          entry: EntrySide.top,
          movement: MovementPattern.straight,
          bullets: BulletPattern.aimedSingle,
          spawnDelay: 1.6,
        ),
        WaveSpec(
          type: EnemyType.scout,
          count: 5,
          formation: Formation.vee,
          entry: EntrySide.top,
          movement: MovementPattern.straight,
          bullets: BulletPattern.none,
          spawnDelay: 1.8,
        ),
      ],
    );

    map[7] = _tutorial(
      7,
      hp: 1.9,
      speed: 1.0,
      fireRate: 0.95,
      waves: const [
        WaveSpec(
          type: EnemyType.scout,
          count: 7,
          formation: Formation.line,
          entry: EntrySide.top,
          movement: MovementPattern.straight,
          bullets: BulletPattern.aimedSingle,
          spawnDelay: 0.8,
        ),
        WaveSpec(
          type: EnemyType.scout,
          count: 7,
          formation: Formation.vee,
          entry: EntrySide.top,
          movement: MovementPattern.sine,
          bullets: BulletPattern.aimedSingle,
          spawnDelay: 1.5,
        ),
        WaveSpec(
          type: EnemyType.scout,
          count: 6,
          formation: Formation.line,
          entry: EntrySide.top,
          movement: MovementPattern.sine,
          bullets: BulletPattern.aimedSingle,
          spawnDelay: 1.7,
        ),
      ],
    );

    map[8] = _tutorial(
      8,
      hp: 2.0,
      speed: 1.05,
      fireRate: 1.0,
      waves: const [
        WaveSpec(
          type: EnemyType.scout,
          count: 7,
          formation: Formation.vee,
          entry: EntrySide.top,
          movement: MovementPattern.sine,
          bullets: BulletPattern.aimedSingle,
          spawnDelay: 0.8,
        ),
        WaveSpec(
          type: EnemyType.scout,
          count: 8,
          formation: Formation.line,
          entry: EntrySide.top,
          movement: MovementPattern.straight,
          bullets: BulletPattern.aimedSingle,
          spawnDelay: 1.4,
        ),
        WaveSpec(
          type: EnemyType.scout,
          count: 8,
          formation: Formation.vee,
          entry: EntrySide.top,
          movement: MovementPattern.sine,
          bullets: BulletPattern.aimedSingle,
          spawnDelay: 1.6,
          dropsPowerUp: true,
        ),
      ],
    );

    // A set piece on every hundredth level, with a scripted wave order rather
    // than a random one.
    for (var level = 100; level <= Tuning.totalLevels; level += 100) {
      map[level] = _setPiece(level);
    }

    return map;
  }

  /// A tutorial level. Multipliers are passed in rather than taken from the
  /// curve so the opening levels stay gentle whatever the curve does later.
  static LevelSpec _tutorial(
    int number, {
    required List<WaveSpec> waves,
    double hp = 1.0,
    double speed = 1.0,
    double fireRate = 1.0,
    double bulletSpeed = 0.8,
  }) {
    return LevelSpec(
      number: number,
      chapter: 1,
      kind: LevelKind.normal,
      waves: waves,
      boss: null,
      enemyHpMultiplier: hp,
      enemySpeedMultiplier: speed,
      enemyFireRateMultiplier: fireRate,
      bulletSpeedMultiplier: bulletSpeed,
      coinReward: Tuning.coinReward(number, LevelKind.normal),
      musicTrack: 'battle_a',
    );
  }

  /// A hundredth level. The wave order is fixed: a warm up, a flanking wave,
  /// then the heaviest family unlocked so far carrying a gem.
  static LevelSpec _setPiece(int level) {
    final chapter = Tuning.chapterOf(level);
    final kind = Tuning.kindOf(level);
    final unlocked = EnemyCatalog.unlockedIn(chapter);
    final newest = unlocked.last;
    final middle = unlocked[unlocked.length ~/ 2];
    final oldest = unlocked.first;

    final waves = <WaveSpec>[
      WaveSpec(
        type: oldest,
        count: 6,
        formation: Formation.line,
        entry: EntrySide.top,
        movement: EnemyCatalog.of(oldest).defaultMovement,
        bullets: EnemyCatalog.of(oldest).defaultBullets,
        spawnDelay: 0.6,
      ),
      WaveSpec(
        type: middle,
        count: 6,
        formation: _formation(chapter, Formation.pincer, Formation.vee),
        entry: EntrySide.left,
        movement: EnemyCatalog.of(middle).defaultMovement,
        bullets: EnemyCatalog.of(middle).defaultBullets,
        spawnDelay: 1.4,
      ),
      WaveSpec(
        type: newest,
        count: 5,
        formation: _formation(chapter, Formation.arc, Formation.line),
        entry: EntrySide.top,
        movement: EnemyCatalog.of(newest).defaultMovement,
        bullets: EnemyCatalog.of(newest).defaultBullets,
        spawnDelay: 1.6,
        dropsPowerUp: true,
      ),
    ];

    if (kind != LevelKind.boss) {
      waves.add(
        WaveSpec(
          type: middle,
          count: 7,
          formation: _formation(chapter, Formation.sweep, Formation.column),
          entry: EntrySide.right,
          movement: EnemyCatalog.of(middle).defaultMovement,
          bullets: EnemyCatalog.of(newest).defaultBullets,
          spawnDelay: 1.8,
        ),
      );
    }

    return LevelSpec(
      number: level,
      chapter: chapter,
      kind: kind,
      waves: waves,
      boss: kind == LevelKind.boss ? BossCatalog.build(level) : null,
      enemyHpMultiplier: Tuning.enemyHpMultiplier(level),
      enemySpeedMultiplier: Tuning.enemySpeed,
      enemyFireRateMultiplier: Tuning.enemyFireRateMultiplier(level),
      bulletSpeedMultiplier: Tuning.bulletSpeed,
      coinReward: Tuning.coinReward(level, kind),
      musicTrack: kind == LevelKind.boss ? 'boss' : 'battle_c',
    );
  }

  static Formation _formation(
    int chapter,
    Formation preferred,
    Formation fallback,
  ) {
    const unlockChapter = <Formation, int>{
      Formation.line: 1,
      Formation.vee: 1,
      Formation.arc: 2,
      Formation.column: 4,
      Formation.pincer: 6,
      Formation.sweep: 9,
      Formation.spiral: 13,
    };
    return chapter >= unlockChapter[preferred]! ? preferred : fallback;
  }
}
