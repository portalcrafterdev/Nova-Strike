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
  static LevelSpec generate(int levelNumber) {
    final level = levelNumber.clamp(1, Tuning.totalLevels);
    final override = Handcrafted.levels[level];
    if (override != null) {
      return override;
    }
    return build(level);
  }

  /// Generates a level without consulting the handcrafted overrides. Exposed
  /// so the overrides can build on top of generated content.
  static LevelSpec build(int level) {
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
      boss: kind == LevelKind.boss ? BossCatalog.build(level) : null,
      enemyHpMultiplier:
          Tuning.enemyHpMultiplier(level) *
          (kind == LevelKind.elite ? Tuning.eliteHpMultiplier : 1.0) *
          ModifierTuning.hpFactor(modifier),
      enemySpeedMultiplier:
          Tuning.enemySpeed *
          (kind == LevelKind.elite ? Tuning.eliteSpeedMultiplier : 1.0) *
          ModifierTuning.speedFactor(modifier),
      enemyFireRateMultiplier:
          Tuning.enemyFireRateMultiplier(level) *
          ModifierTuning.fireRateFactor(modifier),
      bulletSpeedMultiplier:
          Tuning.bulletSpeed * ModifierTuning.bulletSpeedFactor(modifier),
      coinReward: Tuning.coinReward(level, kind),
      musicTrack: musicFor(level),
      modifier: modifier,
      obstacleRate: _obstacleRate(rng, level),
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
  /// Boss levels and the objective kinds never draw one. A survival, escort or
  /// gate level already changes the rules the player is working under, and a
  /// second twist on top of that is not a harder level, it is two new rules at
  /// once. Level 39 drew survival and BARRAGE together, which is the worst
  /// pair on the table, and it landed on a player with three upgrades bought.
  static LevelModifier _pickModifier(Random rng, int level, LevelKind kind) {
    if (kind != LevelKind.normal && kind != LevelKind.elite) {
      return LevelModifier.none;
    }
    if (level < ModifierTuning.firstModifiedLevel) {
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

    final waves = <WaveSpec>[];
    for (var i = 0; i < count; i++) {
      final type = _pickType(rng, types, chapter);
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
