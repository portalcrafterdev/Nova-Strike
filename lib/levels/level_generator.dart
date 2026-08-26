import 'dart:math';

import 'boss_catalog.dart';
import 'difficulty_curve.dart';
import 'enemy_catalog.dart';
import 'handcrafted.dart';
import 'level_spec.dart';

/// Turns a level number into a [LevelSpec].
///
/// Nothing about a level is stored on disk. The same level number produces the
/// same level for every player on every device, which is what makes 1500
/// levels cost nothing to author or to save.
class LevelGenerator {
  const LevelGenerator._();

  /// Seed constants, chosen as primes so neighbouring levels do not correlate.
  static const int seedMultiplier = 7919;
  static const int seedOffset = 104729;

  /// Builds the spec for [levelNumber], honouring any handcrafted override.
  static LevelSpec generate(
    int levelNumber, {
    Difficulty difficulty = Difficulty.medium,
  }) {
    final level = levelNumber.clamp(1, Tuning.totalLevels);
    final override = Handcrafted.levels[level];
    if (override != null) {
      return _atDifficulty(override, difficulty);
    }
    return build(level, difficulty: difficulty);
  }

  /// Re-scales an already built spec for a setting.
  ///
  /// The handcrafted levels are written out by hand rather than generated, so
  /// they cannot fold the setting in as they go and have it applied here
  /// instead. Every field the generator would have scaled is scaled the same
  /// way, because a tutorial level that ignored the setting would be the one
  /// place the player could not tell it had taken.
  static LevelSpec _atDifficulty(LevelSpec spec, Difficulty difficulty) {
    if (difficulty == Difficulty.medium) {
      return spec;
    }
    return LevelSpec(
      number: spec.number,
      chapter: spec.chapter,
      kind: spec.kind,
      waves: spec.waves,
      boss: spec.boss,
      enemyHpMultiplier:
          spec.enemyHpMultiplier * DifficultyTuning.hpFactor(difficulty),
      enemySpeedMultiplier:
          spec.enemySpeedMultiplier * DifficultyTuning.speedFactor(difficulty),
      enemyFireRateMultiplier:
          spec.enemyFireRateMultiplier *
          DifficultyTuning.fireRateFactor(difficulty),
      bulletSpeedMultiplier:
          spec.bulletSpeedMultiplier *
          DifficultyTuning.bulletSpeedFactor(difficulty),
      coinReward: (spec.coinReward * DifficultyTuning.coinFactor(difficulty))
          .round(),
      musicTrack: spec.musicTrack,
      modifier: spec.modifier,
      obstacleRate: spec.obstacleRate,
      difficulty: difficulty,
    );
  }

  /// Generates a level without consulting the handcrafted overrides. Exposed
  /// so the overrides can build on top of generated content.
  static LevelSpec build(int level, {Difficulty difficulty = Difficulty.medium}) {
    final rng = Random(level * seedMultiplier + seedOffset);
    final chapter = Tuning.chapterOf(level);
    final kind = Tuning.kindOf(level);

    // Drawn before the waves so the twist is part of the same deterministic
    // sequence as everything else in the level.
    final modifier = _pickModifier(rng, level, kind);

    final waves = kind == LevelKind.boss
        ? _bossEscort(rng, level, chapter)
        : _waves(rng, level, chapter, kind, modifier);

    return LevelSpec(
      number: level,
      chapter: chapter,
      kind: kind,
      waves: waves,
      boss: kind == LevelKind.boss
          ? BossCatalog.build(level, difficulty: difficulty)
          : null,
      enemyHpMultiplier:
          Tuning.enemyHpMultiplier(level) *
          (kind == LevelKind.elite ? Tuning.eliteHpMultiplier : 1.0) *
          ModifierTuning.hpFactor(modifier) *
          DifficultyTuning.hpFactor(difficulty),
      enemySpeedMultiplier:
          Tuning.enemySpeed *
          (kind == LevelKind.elite ? Tuning.eliteSpeedMultiplier : 1.0) *
          ModifierTuning.speedFactor(modifier) *
          DifficultyTuning.speedFactor(difficulty),
      enemyFireRateMultiplier:
          Tuning.enemyFireRateMultiplier(level) *
          ModifierTuning.fireRateFactor(modifier) *
          DifficultyTuning.fireRateFactor(difficulty),
      bulletSpeedMultiplier:
          Tuning.bulletSpeed *
          ModifierTuning.bulletSpeedFactor(modifier) *
          DifficultyTuning.bulletSpeedFactor(difficulty),
      coinReward:
          (Tuning.coinReward(level, kind) *
                  DifficultyTuning.coinFactor(difficulty))
              .round(),
      musicTrack: musicFor(level),
      modifier: modifier,
      obstacleRate: _obstacleRate(rng, level),
      difficulty: difficulty,
    );
  }

  /// Battle tracks rotate by chapter so a long session does not loop one tune.
  static String musicFor(int level) {
    if (Tuning.kindOf(level) == LevelKind.boss) {
      return 'boss';
    }
    const tracks = ['battle_a', 'battle_b', 'battle_c'];
    return tracks[(Tuning.chapterOf(level) - 1) % tracks.length];
  }

  /// How often rocks drift down the lane, or zero for a clear one.
  ///
  /// Debris gives the lane something to read against between waves and
  /// something to shoot at while waiting, without adding another thing that
  /// shoots back.
  static double _obstacleRate(Random rng, int level) {
    if (level < Tuning.obstacleFirstLevel) {
      return 0;
    }
    if (rng.nextDouble() > Tuning.obstacleFieldChance) {
      return 0;
    }
    final spread = Tuning.obstacleRateMax - Tuning.obstacleRateMin;
    return Tuning.obstacleRateMax - rng.nextDouble() * spread;
  }

  /// A level drawn without a twist stays plain, which is what makes the ones
  /// that do carry a twist feel like a change of pace.
  ///
  /// Only ordinary levels draw one. A boss, an objective and an elite swarm
  /// all already change the rules the player is working under, and a second
  /// twist on top of that is not a harder level, it is two new rules at once.
  /// The elite levels were the worst of it: an elite is already half again the
  /// hit points and forty percent more of them, so an elite that also drew
  /// VANGUARD landed at nearly four times the level before it.
  static LevelModifier _pickModifier(Random rng, int level, LevelKind kind) {
    if (kind != LevelKind.normal) {
      return LevelModifier.none;
    }
    if (level < ModifierTuning.firstModifiedLevel) {
      return LevelModifier.none;
    }
    // A level that introduces a new enemy is already teaching something.
    // Putting a twist on top means the player cannot tell which of the two is
    // beating them, and level 16 got the swarm modifier on the same level it
    // first showed a darter.
    if (_debutTypes(level, Tuning.chapterOf(level)).isNotEmpty) {
      return LevelModifier.none;
    }
    if (rng.nextDouble() > ModifierTuning.chance) {
      return LevelModifier.none;
    }
    const options = [
      LevelModifier.swarm,
      LevelModifier.vanguard,
      LevelModifier.swift,
      LevelModifier.barrage,
      LevelModifier.armoured,
    ];
    return options[rng.nextInt(options.length)];
  }

  static List<WaveSpec> _waves(
    Random rng,
    int level,
    int chapter,
    LevelKind kind,
    LevelModifier modifier,
  ) {
    final count = Tuning.waveCount(level);
    final types = EnemyCatalog.unlockedIn(chapter);
    final formations = unlockedFormations(chapter);
    final movements = unlockedMovements(chapter);
    final patterns = unlockedBulletPatterns(chapter);

    // The level a chapter opens on is where the player meets whatever that
    // chapter unlocked. Left alone, the generator could hand them a level made
    // entirely of a family and a bullet pattern they had never seen: level 16
    // came out as two waves of darters, both firing three way spreads, with a
    // swarm modifier on top, and measured two and a half times the enemy fire
    // of the elite level before it.
    //
    // So a debut is arranged rather than rolled. The newcomer takes the last
    // wave, which is the one the level builds toward, and every wave before it
    // is a family the player already knows how to fight. Leaving it to the
    // weighting would have meant a chapter that sometimes never showed its own
    // new enemy on its opening level.
    final debutTypes = _debutTypes(level, chapter);
    final newcomer = debutTypes.isEmpty
        ? null
        : debutTypes[rng.nextInt(debutTypes.length)];

    final waves = <WaveSpec>[];
    for (var i = 0; i < count; i++) {
      final EnemyType type;
      if (newcomer == null) {
        type = _pickType(rng, types, chapter);
      } else if (i == count - 1) {
        type = newcomer;
      } else {
        type = _familiarType(rng, types, chapter) ??
            _pickType(rng, types, chapter);
      }
      final stats = EnemyCatalog.of(type);
      final delaySpread = Tuning.waveDelayMax - Tuning.waveDelayMin;
      waves.add(
        WaveSpec(
          type: type,
          count: _enemyCount(rng, level, kind, type, modifier),
          formation: _pickFormation(rng, formations, type),
          entry: _pickEntry(rng, chapter),
          movement: _pickMovement(rng, movements, stats),
          bullets: _pickBullets(rng, patterns, stats),
          spawnDelay: i == 0
              ? 0.6
              : Tuning.waveDelayMin + rng.nextDouble() * delaySpread,
          dropsPowerUp: kind == LevelKind.elite && i == count - 1,
        ),
      );
    }
    return waves;
  }

  /// Boss levels open with one small escort wave so the arrival has a beat of
  /// build up before the health bar appears.
  static List<WaveSpec> _bossEscort(Random rng, int level, int chapter) {
    final types = EnemyCatalog.unlockedIn(chapter);
    final type = types[rng.nextInt(types.length)];
    final stats = EnemyCatalog.of(type);
    return [
      WaveSpec(
        type: type,
        count: 3 + rng.nextInt(3),
        formation: Formation.line,
        entry: EntrySide.top,
        movement: stats.defaultMovement,
        bullets: stats.defaultBullets,
        spawnDelay: 0.5,
      ),
    ];
  }

  /// The families this level is responsible for introducing.
  ///
  /// Empty unless the level opens a chapter and that chapter unlocks a family,
  /// which is most of them: the schedule adds an enemy at chapters 1, 2, 4, 6,
  /// 9, 13, 18 and 24 and nothing in between.
  static List<EnemyType> _debutTypes(int level, int chapter) {
    if (Tuning.levelInChapter(level) != 1) {
      return const [];
    }
    final fresh = EnemyCatalog.newIn(chapter);
    // Chapter one is every family's debut only because it is the first. There
    // is nothing familiar to sit it next to, so it is left alone.
    if (chapter <= 1) {
      return const [];
    }
    return fresh;
  }

  /// A family the player has already met, or null in the first chapter where
  /// there is no such thing.
  static EnemyType? _familiarType(
    Random rng,
    List<EnemyType> types,
    int chapter,
  ) {
    final older = types
        .where((type) => EnemyCatalog.of(type).unlockChapter < chapter)
        .toList();
    if (older.isEmpty) {
      return null;
    }
    return older[rng.nextInt(older.length)];
  }

  static EnemyType _pickType(Random rng, List<EnemyType> types, int chapter) {
    // Weight the newest unlocks higher so a chapter feels like it introduces
    // something, without ever dropping the older families entirely.
    final weights = <double>[];
    var total = 0.0;
    for (final type in types) {
      final unlock = EnemyCatalog.of(type).unlockChapter;
      final age = (chapter - unlock).clamp(0, 40);
      final weight = 1.0 + 2.0 / (1.0 + age * 0.35);
      weights.add(weight);
      total += weight;
    }
    var roll = rng.nextDouble() * total;
    for (var i = 0; i < types.length; i++) {
      roll -= weights[i];
      if (roll <= 0) {
        return types[i];
      }
    }
    return types.last;
  }

  static int _enemyCount(
    Random rng,
    int level,
    LevelKind kind,
    EnemyType type,
    LevelModifier modifier,
  ) {
    final base = 4 + (level ~/ Tuning.enemyCountLevelStep);
    var count = base + rng.nextInt(3);
    if (kind == LevelKind.elite) {
      count = (count * Tuning.eliteCountMultiplier).round();
    }
    count = (count * ModifierTuning.countFactor(modifier)).round();
    if (type == EnemyType.turret) {
      count = (count / 2).ceil();
    }
    if (type == EnemyType.bomber) {
      count = (count * 0.7).ceil();
    }
    return count.clamp(2, 12);
  }

  static Formation _pickFormation(
    Random rng,
    List<Formation> formations,
    EnemyType type,
  ) {
    if (type == EnemyType.turret) {
      return Formation.line;
    }
    return formations[rng.nextInt(formations.length)];
  }

  static EntrySide _pickEntry(Random rng, int chapter) {
    if (chapter < 2) {
      return EntrySide.top;
    }
    final roll = rng.nextDouble();
    if (roll < 0.6) {
      return EntrySide.top;
    }
    return roll < 0.8 ? EntrySide.left : EntrySide.right;
  }

  static MovementPattern _pickMovement(
    Random rng,
    List<MovementPattern> movements,
    EnemyStats stats,
  ) {
    if (stats.type == EnemyType.turret) {
      return MovementPattern.hold;
    }
    if (stats.type == EnemyType.kamikaze) {
      return MovementPattern.dive;
    }
    // Half the time an enemy uses the movement its family is known for.
    final canUseDefault = movements.contains(stats.defaultMovement);
    if (canUseDefault && rng.nextBool()) {
      return stats.defaultMovement;
    }
    return movements[rng.nextInt(movements.length)];
  }

  static BulletPattern _pickBullets(
    Random rng,
    List<BulletPattern> patterns,
    EnemyStats stats,
  ) {
    if (stats.type == EnemyType.kamikaze) {
      return BulletPattern.none;
    }
    if (patterns.contains(stats.defaultBullets) && rng.nextBool()) {
      return stats.defaultBullets;
    }
    return patterns[rng.nextInt(patterns.length)];
  }

  /// Formations available in a chapter, following the unlock schedule.
  static List<Formation> unlockedFormations(int chapter) {
    final list = <Formation>[Formation.line, Formation.vee];
    if (chapter >= 2) {
      list.add(Formation.arc);
    }
    if (chapter >= 3) {
      list.add(Formation.column);
    }
    if (chapter >= 4) {
      list.add(Formation.pincer);
    }
    if (chapter >= 5) {
      list.add(Formation.sweep);
    }
    if (chapter >= 7) {
      list.add(Formation.spiral);
    }
    return list;
  }

  /// Bullet patterns available in a chapter.
  static List<BulletPattern> unlockedBulletPatterns(int chapter) {
    final list = <BulletPattern>[BulletPattern.aimedSingle];
    if (chapter >= 2) {
      list.add(BulletPattern.spread3);
    }
    if (chapter >= 3) {
      list.add(BulletPattern.waveShot);
    }
    if (chapter >= 4) {
      list.add(BulletPattern.ringBurst);
    }
    if (chapter >= 5) {
      list.add(BulletPattern.aimedBurst3);
    }
    if (chapter >= 7) {
      list.add(BulletPattern.spiralShot);
    }
    return list;
  }

  /// Movement patterns available in a chapter.
  static List<MovementPattern> unlockedMovements(int chapter) {
    final list = <MovementPattern>[MovementPattern.straight];
    if (chapter >= 2) {
      list.add(MovementPattern.sine);
    }
    if (chapter >= 3) {
      list.add(MovementPattern.hover);
    }
    if (chapter >= 4) {
      list.add(MovementPattern.zigzag);
    }
    if (chapter >= 5) {
      list.add(MovementPattern.swoop);
    }
    if (chapter >= 7) {
      list.add(MovementPattern.orbit);
    }
    // The behaviours that ask the player to do something other than shoot
    // forward. They arrive late on purpose: a sniper at the edge is only
    // interesting once holding the middle has become a habit.
    if (chapter >= 8) {
      list.add(MovementPattern.snipe);
    }
    if (chapter >= 10) {
      list.add(MovementPattern.screen);
    }
    if (chapter >= 12) {
      list.add(MovementPattern.flank);
    }
    return list;
  }
}
