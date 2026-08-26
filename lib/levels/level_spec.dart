// Pure data describing a level. No Flame types are allowed in this file so
// the whole level layer can be unit tested without a game loop.

/// How hard the campaign is being played at.
///
/// The same 1500 levels at any of the three. What changes is how much every
/// wave brings and how much the level pays for clearing it, so a player who
/// finds normal too steep has somewhere to go that is not quitting, and one
/// who finds it too soft has a reason to come back to a level they have
/// already beaten.
enum Difficulty { easy, medium, hard }

/// What sort of level this is. Every 15th level in a chapter is a boss, the
/// 14th is an elite swarm, the rest are normal.
enum LevelKind {
  normal,
  elite,
  boss,

  /// No wave list. Hold out for a fixed time against a lane that keeps
  /// feeding itself.
  survival,

  /// A freighter crosses the lane and has to reach the far side alive.
  escort,

  /// The waves are only the way in. The level ends when the player flies
  /// through the gate at the end of it.
  gate,
}

/// The eight enemy families. Behaviour is composed from a movement pattern and
/// a bullet pattern rather than subclassed per type.
enum EnemyType {
  scout,
  darter,
  gunner,
  bomber,
  shielder,
  splitter,
  turret,
  kamikaze,
}

/// How a wave is arranged when it enters the play area.
enum Formation { line, vee, arc, column, pincer, sweep, spiral }

/// Which edge a wave enters from.
enum EntrySide { top, left, right }

/// How an enemy travels once it has entered.
enum MovementPattern {
  straight,
  sine,
  hover,
  zigzag,
  swoop,
  orbit,
  dive,
  hold,

  /// Runs past the player, turns around and comes back at them from behind.
  flank,

  /// Holds station out at the edge of the lane and shoots from there.
  snipe,

  /// Sits in front of whatever it is protecting and refuses to close.
  screen,
}

/// What an enemy fires.
enum BulletPattern {
  none,
  aimedSingle,
  spread3,
  waveShot,
  ringBurst,
  aimedBurst3,
  spiralShot,
}

/// A twist applied to one level, so two levels in the same chapter never play
/// the same way even when they draw the same enemies.
enum LevelModifier { none, swarm, vanguard, swift, barrage, armoured }

/// Short name shown on the heads up display.
extension LevelModifierLabel on LevelModifier {
  String get label {
    switch (this) {
      case LevelModifier.none:
        return '';
      case LevelModifier.swarm:
        return 'SWARM';
      case LevelModifier.vanguard:
        return 'VANGUARD';
      case LevelModifier.swift:
        return 'SWIFT';
      case LevelModifier.barrage:
        return 'BARRAGE';
      case LevelModifier.armoured:
        return 'ARMOURED';
    }
  }

  /// One line of plain English for the level map.
  String get description {
    switch (this) {
      case LevelModifier.none:
        return '';
      case LevelModifier.swarm:
        return 'More enemies, each of them weaker';
      case LevelModifier.vanguard:
        return 'Fewer enemies, each of them tougher';
      case LevelModifier.swift:
        return 'Everything flies faster';
      case LevelModifier.barrage:
        return 'They fire far more often';
      case LevelModifier.armoured:
        return 'Heavy hulls, slower approach';
    }
  }
}

/// One group of enemies that arrives together.
class WaveSpec {
  const WaveSpec({
    required this.type,
    required this.count,
    required this.formation,
    required this.entry,
    required this.movement,
    required this.bullets,
    required this.spawnDelay,
    this.dropsPowerUp = false,
  });

  final EnemyType type;
  final int count;
  final Formation formation;
  final EntrySide entry;
  final MovementPattern movement;
  final BulletPattern bullets;

  /// Seconds after the previous wave clears or times out.
  final double spawnDelay;

  /// Elite waves guarantee a gem drop from the last enemy killed.
  final bool dropsPowerUp;

  WaveSpec copyWith({double? spawnDelay, bool? dropsPowerUp}) {
    return WaveSpec(
      type: type,
      count: count,
      formation: formation,
      entry: entry,
      movement: movement,
      bullets: bullets,
      spawnDelay: spawnDelay ?? this.spawnDelay,
      dropsPowerUp: dropsPowerUp ?? this.dropsPowerUp,
    );
  }
}

/// One boss encounter. Phase thresholds are fixed at 66 and 33 percent, so a
/// boss only needs to declare which patterns each phase adds.
class BossSpec {
  const BossSpec({
    required this.archetype,
    required this.name,
    required this.maxHp,
    required this.width,
    required this.height,
    required this.phasePatterns,
    required this.moveSpeed,
    required this.fireInterval,
    required this.weakPoints,
    required this.hasShieldArc,
    required this.contactDamage,
  });

  /// Index 0 to 9 into the boss catalog.
  final int archetype;
  final String name;
  final double maxHp;
  final double width;
  final double height;

  /// One list per phase. Phase 1 uses index 0, phase 2 uses 0 and 1, and so on,
  /// so later phases stack patterns rather than replace them.
  final List<List<BulletPattern>> phasePatterns;
  final double moveSpeed;
  final double fireInterval;

  /// Side pods that must be destroyed before the core takes damage.
  final int weakPoints;

  /// Archetypes 4, 7 and 10 carry a shield arc.
  final bool hasShieldArc;
  final int contactDamage;
}

/// Everything the game needs to run one level.
class LevelSpec {
  const LevelSpec({
    required this.number,
    required this.chapter,
    required this.kind,
    required this.waves,
    required this.boss,
    required this.enemyHpMultiplier,
    required this.enemySpeedMultiplier,
    required this.enemyFireRateMultiplier,
    required this.bulletSpeedMultiplier,
    required this.coinReward,
    required this.musicTrack,
    this.modifier = LevelModifier.none,
    this.obstacleRate = 0,
    this.difficulty = Difficulty.medium,
  });

  final int number;
  final int chapter;
  final LevelKind kind;
  final List<WaveSpec> waves;
  final BossSpec? boss;
  final double enemyHpMultiplier;
  final double enemySpeedMultiplier;
  final double enemyFireRateMultiplier;
  final double bulletSpeedMultiplier;
  final int coinReward;
  final String musicTrack;

  /// The twist that makes this level its own thing.
  final LevelModifier modifier;

  /// Seconds between rocks drifting down the lane. Zero means a clear lane.
  final double obstacleRate;

  /// The setting this spec was built for. The multipliers above already have
  /// it folded in, so nothing downstream has to apply it a second time.
  final Difficulty difficulty;

  /// True when this level has debris in it.
  bool get hasObstacles => obstacleRate > 0;

  bool get isBoss => kind == LevelKind.boss;

  /// A label for the heads up display where the wave count would go.
  String get objective {
    switch (kind) {
      case LevelKind.survival:
        return 'SURVIVE';
      case LevelKind.escort:
        return 'ESCORT';
      case LevelKind.gate:
        return 'REACH THE GATE';
      case LevelKind.normal:
      case LevelKind.elite:
      case LevelKind.boss:
        return '';
    }
  }

  /// Total enemies across every wave, used for the wave progress readout.
  int get enemyCount {
    var total = 0;
    for (final wave in waves) {
      total += wave.count;
    }
    return total;
  }

  LevelSpec copyWith({
    List<WaveSpec>? waves,
    BossSpec? boss,
    int? coinReward,
    String? musicTrack,
  }) {
    return LevelSpec(
      number: number,
      chapter: chapter,
      kind: kind,
      waves: waves ?? this.waves,
      boss: boss ?? this.boss,
      enemyHpMultiplier: enemyHpMultiplier,
      enemySpeedMultiplier: enemySpeedMultiplier,
      enemyFireRateMultiplier: enemyFireRateMultiplier,
      bulletSpeedMultiplier: bulletSpeedMultiplier,
      coinReward: coinReward ?? this.coinReward,
      musicTrack: musicTrack ?? this.musicTrack,
      modifier: modifier,
      obstacleRate: obstacleRate,
      difficulty: difficulty,
    );
  }
}
