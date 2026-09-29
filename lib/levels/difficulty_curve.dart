import 'dart:math' as math;

import 'level_spec.dart';

/// Every tuning number in the game lives here.
///
/// Component and system files must never hold a magic number. If a value
/// changes how the game plays, it belongs in this file.
class Tuning {
  const Tuning._();

  // Structure.
  static const int totalLevels = 1500;
  static const int levelsPerChapter = 15;
  static const int totalChapters = totalLevels ~/ levelsPerChapter;
  static const int bossArchetypeCount = 10;
  static const int eliteLevelInChapter = 14;

  // Waves.
  static const int baseWaveCount = 2;
  /// How many waves of a newly unlocked family a chapter's opening level may
  /// use.
  ///
  /// One, so a new enemy is met alongside one the player already knows how to
  /// fight. Every other level in the chapter is free to use as many as it
  /// likes: by then the family is not new.
  static const int debutWaves = 1;

  static const int waveCountLevelStep = 60;
  static const int maxWaveCount = 6;
  static const double waveDelayMin = 1.1;
  static const double waveDelayMax = 2.4;

  /// A wave gives up waiting for stragglers after this long and sends the next
  /// one anyway, so a single evasive enemy can never stall a level.
  static const double waveTimeout = 22;

  // Enemy scaling.
  /// Enemy travel speed, as a multiplier on the catalog value.
  ///
  /// Flat, on purpose. Difficulty climbs through hit points, rate of fire,
  /// enemy count and the families that unlock later, never through raw pace.
  /// A game that speeds up with the level number eventually asks for reactions
  /// rather than for play, and level 900 stops being the same game as level 9.
  static const double enemySpeed = 1.0;

  /// Enemy bullet speed, as a multiplier on the base value. Flat for the same
  /// reason: a bullet that crosses the lane faster every chapter turns reading
  /// the screen into guessing.
  static const double bulletSpeed = 1.0;
  static const double hpPerLevel = 0.035;

  /// Where the hit point climb flattens off.
  static const int hpKnee = 300;

  /// How fast hit points grow past the knee, per level.
  static const double hpTailPerLevel = 0.0025;
  static const double fireRatePerLevel = 0.012;
  static const double fireRateCap = 3.0;

  /// Extra bite for the opening levels.
  ///
  /// The curve alone starts far too soft: at level 1 an enemy is worth a
  /// single shot, which reads as a walkover rather than a warm up. This adds a
  /// bump that fades out by [earlyBiteFade] and leaves the late game alone.
  static const double earlyBite = 0.75;
  static const int earlyBiteFade = 60;

  /// Difficulty must not climb forever. Every fifth normal level drops the
  /// multipliers so a long session has somewhere to breathe.
  static const int reliefInterval = 5;
  static const double reliefFactor = 0.8;

  // Level kind multipliers.
  static const double normalHpMultiplier = 1.0;
  static const double eliteHpMultiplier = 1.6;
  static const double eliteSpeedMultiplier = 1.15;
  static const double eliteCountMultiplier = 1.4;

  // Rewards.
  /// Coins for finishing a level, before the level number is added.
  ///
  /// High enough that the first boss is met with a ship that has been
  /// upgraded. At ten a player reached level 15 with 161 coins and the
  /// cheapest upgrade cost 120, so they fought it bare.
  static const int baseCoinReward = 22;
  static const int coinRewardLevelDivisor = 5;
  static const double eliteCoinBonus = 1.5;
  static const double bossCoinBonus = 2.5;
  static const double objectiveCoinBonus = 1.35;

  /// Chance that a normal enemy leaves a coin behind.
  static const double coinDropChance = 0.35;

  /// Chance that an elite enemy leaves a power-up gem.
  static const double powerUpDropChance = 0.45;

  // Boss scaling.
  /// Hit points of a boss before the level number is taken into account.
  ///
  /// A boss has to last long enough to have phases. At 320 the first one died
  /// in a little over three seconds against a ship that had bought a couple of
  /// upgrades, which is a big enemy rather than a boss fight.
  static const double bossBaseHp = 1870;

  /// How much a boss gains per level.
  ///
  /// Shallow, because the base already carries the weight. A steeper slope
  /// made the early bosses trivial and the late ones a grind, which is the
  /// wrong way round.
  static const double bossHpPerLevel = 0.0024;

  /// Each time an archetype comes back around it gains hit points and one
  /// more attack pattern. It does not gain speed: a boss that moves faster
  /// every time it returns stops being the fight the player learned.
  static const double bossRepeatHpBonus = 0.06;
  static const double bossPhaseTwoThreshold = 0.66;
  static const double bossPhaseThreeThreshold = 0.33;

  /// How many phases a boss fight has.
  static const int bossPhases = 3;

  /// Which phase a boss at this much health belongs in.
  ///
  /// Derived from the health rather than read off the boss, so the readout
  /// and the behaviour cannot disagree: the boss decides its own phase from
  /// the same two thresholds, and a second source of truth here is a bug
  /// waiting for the frame where one updates before the other.
  static int bossPhaseAt(double fraction) {
    if (fraction <= bossPhaseThreeThreshold) {
      return 3;
    }
    if (fraction <= bossPhaseTwoThreshold) {
      return 2;
    }
    return 1;
  }
  static const double bossPhaseSpeedStep = 0.25;
  static const double bossPhaseFireStep = 0.15;
  static const double bossEntryDuration = 2.0;

  /// Hit points of one weak point, as a fraction of the boss total.
  static const int enemyCountLevelStep = 60;

  static const double bossPodHpFraction = 0.12;

  /// Hit points of the shield arc, as a fraction of the boss total.
  static const double bossShieldHpFraction = 0.25;

  // Player.
  static const int playerLives = 3;
  static const double playerFollowLerp = 0.25;

  /// How far up the lane from the finger the ship flies, so the thumb never
  /// covers it.
  static const double playerTouchOffsetZ = 26;
  static const double playerInvulnerability = 1.5;

  /// Lives handed back for watching a rewarded ad. One, and once per run.
  static const int reviveLives = 1;

  /// Grace after a revive, in seconds.
  ///
  /// Longer than an ordinary respawn. The player has been looking at an ad for
  /// half a minute rather than at the screen, and coming back into a lane full
  /// of fire with the usual second and a half would spend the life they just
  /// earned before they had their thumb down.
  static const double reviveGrace = 3.0;
  static const double playerFireInterval = 0.22;
  static const double playerBulletSpeed = 620;
  static const double playerBulletDamage = 10;
  /// What the beam does per second, as a share of what the guns it replaces
  /// would have done.
  ///
  /// It used to be a flat number, which meant the gem was an upgrade on a bare
  /// ship and a punishment on a bought one: by the top tier the guns put out
  /// thirteen times what the beam did, so picking the beam up cut the player's
  /// damage to seven per cent and stopped their bullets as well. A share keeps
  /// the trade honest at every tier. Slightly under one, because the beam hits
  /// everything standing in the column at once and burns incoming fire out of
  /// it, and that breadth is what the player is paying for.
  static const double laserDpsFraction = 0.85;
  static const double playerLaserTickInterval = 0.08;
  static const double playerMagnetRadius = 110;
  static const double playerMagnetPull = 420;
  static const double coinPickupRadius = 22;
  static const double powerUpFallSpeed = 90;
  static const double coinFallSpeed = 70;

  // Drone wingmen. Two of them, one on each wing.
  static const double droneOffsetX = 26;
  static const double droneOffsetY = -3;
  static const double droneOffsetZ = 12;

  /// How quickly a drone catches up with where it should be.
  ///
  /// Loose on purpose: a drone welded to the wing looks like part of the
  /// sprite, one that swings back into place looks like it is flying.
  static const double droneFollow = 7;
  static const double droneFireInterval = 0.34;

  /// Share of the ship's own damage each drone shot carries.
  static const double droneDamageShare = 0.5;
  static const double droneScale = 0.9;
  static const double droneRoll = 0.2;
  static const double droneBobRate = 3.0;

  // Chain lightning. A shot that lands arcs on to whatever is nearby.
  static const int chainJumps = 3;
  static const double chainRange = 90;

  /// Each jump carries less than the one before it, so a dense wave is not
  /// simply wiped by one bullet.
  static const double chainFalloff = 0.6;
  static const double chainArcLifespan = 0.18;

  /// Seconds the freeze gem stops the enemy side for.
  ///
  /// Shorter than the other gems because stopping the whole level is the
  /// strongest thing any of them do.
  static const double freezeDuration = 4;

  // Power-ups.
  static const double powerUpDuration = 12;
  static const double slowBulletFactor = 0.6;

  /// How far apart the three streams of the spread gem sit.
  ///
  /// Wider than the double shot, because widening the wall of fire is the
  /// whole of what the gem now does.
  static const double spreadOffset = 22;
  static const double doubleShotOffset = 9;

  // Objective levels. Three shapes that end on something other than killing
  // every wave, so a run through a chapter is not the same level six times.

  /// Seconds to hold out on a survival level.
  static const double survivalDuration = 45;

  /// Seconds between the reinforcements a survival level keeps sending.
  static const double survivalWaveInterval = 4.5;

  /// The escorted freighter. Slow, defenceless, and the whole point.
  static const double freighterWidth = 78;
  static const double freighterHeight = 26;
  static const double freighterSpeed = 26;

  /// Where the freighter starts its crossing.
  ///
  /// An escort level is exactly as long as this journey, so this is the one
  /// place its length is set. At 500 the crossing came in under the floor in
  /// [RunnerTuning.minLevelDuration]; the extra distance buys the seconds
  /// without slowing the freighter down, which would have made it a drag to
  /// nurse rather than a thing to protect.
  static const double freighterStartDepth = 640;
  static const double freighterEndDepth = -60;
  static const double freighterBaseHp = 260;
  static const double freighterHpPerLevel = 0.02;

  /// Hit points of the freighter on a given level.
  static double freighterHp(int level) =>
      freighterBaseHp * (1 + freighterHpPerLevel * level);

  /// Damage the freighter takes from one enemy shot and from one collision.
  static const double freighterBulletDamage = 6;
  static const double freighterRamDamage = 22;

  // The warp gate at the end of a gate level.
  static const double gateStartDepth = 560;
  static const double gateRestDepth = 120;
  static const double gateOpenDepth = 380;
  static const double gateApproachSpeed = 150;
  static const double gateRadius = 44;
  static const double gateDepthTolerance = 26;
  static const double gatePulseRate = 3.4;

  /// Chance a level in an eligible chapter is one of the objective kinds.
  static const double objectiveChance = 0.22;

  /// Objective levels start here, once the basics are taught.
  static const int objectiveFirstLevel = 20;

  // Obstacles: rocks that drift down the lane and can be shot apart.
  static const double obstacleBaseHp = 18;
  static const double obstacleHpPerLevel = 0.02;
  static const double obstacleSpeed = 150;
  static const double obstacleRadius = 13;
  static const int obstacleScore = 60;
  static const double obstacleCoinChance = 0.5;
  static const double obstacleRateMin = 2.2;
  static const double obstacleRateMax = 5.0;

  /// Chance that a level has a debris field at all.
  static const double obstacleFieldChance = 0.45;

  /// Debris starts appearing here, so the tutorial stays clean.
  static const int obstacleFirstLevel = 6;

  // Bullets.
  static const int maxActiveBullets = 400;
  static const double baseEnemyBulletSpeed = 195;
  static const double enemyBulletDamage = 1;

  // Secondary weapons. The ship carries these alongside the main cannon and
  // fires all of them on their own clocks. The player never taps to shoot.

  /// Seconds between missile salvos at ordnance tier zero.
  static const double missileInterval = 2.6;

  /// Seconds taken off the missile gap per tier of the ordnance upgrade.
  static const double missileIntervalStep = 0.22;

  /// Missiles in a salvo. A second one arrives at the tier below.
  static const int missileSalvoBase = 1;
  static const int missileSalvoSecondTier = 3;

  /// Sideways offset of the two missile rails from the middle of the ship.
  static const double missileRailOffset = 9;

  /// Speed a missile leaves the rail at, and the speed it settles to.
  static const double missileLaunchSpeed = 150;
  static const double missileCruiseSpeed = 460;

  /// How hard a missile can pull toward its target, in radians per second.
  ///
  /// Turn too tight and a missile never misses, which takes the aiming out of
  /// the player's hands. This is deliberately loose enough to be dodged by a
  /// fast crosser.
  static const double missileTurnRate = 2.6;

  /// A missile flies straight for this long before the seeker wakes up, so it
  /// clears the ship instead of curling back over it.
  static const double missileSeekerDelay = 0.12;

  /// Seconds a missile lives before it burns out.
  static const double missileLifespan = 3.2;

  /// Impact damage, and the damage handed to everything inside the blast.
  static const double missileDamage = 6;
  static const double missileSplashDamage = 3.5;
  static const double missileSplashRadius = 34;

  /// Extra damage per tier of the ordnance upgrade, as a fraction.
  static const double missileDamageStep = 0.25;

  /// Collision radius of the missile body.
  static const double missileRadius = 5;

  /// Seconds between railgun lances at ordnance tier zero.
  ///
  /// The lance pierces everything in its column, so it is rare on purpose.
  static const double railInterval = 6.4;
  static const double railIntervalStep = 0.5;

  /// Damage a lance does to each thing it passes through.
  static const double railDamage = 9;

  /// Speed of a lance. Fast enough to read as a beam rather than a shot.
  static const double railSpeed = 1150;

  /// Seconds between flak shells at ordnance tier zero.
  ///
  /// The shell bursts short of whatever it is aimed at and clears a pocket of
  /// the lane, so it arrives rarely enough that the pocket matters.
  static const double flakInterval = 4.2;
  static const double flakIntervalStep = 0.32;

  /// Speed of a shell on its way out. Slower than a lance on purpose, so the
  /// player can see where the burst is going to happen.
  static const double flakSpeed = 520;

  /// How far ahead of the ship the shell bursts if nothing sets it off first.
  static const double flakArmDistance = 235;

  /// How close something has to be for the proximity fuse to fire early.
  static const double flakFuseRadius = 24;

  /// Damage handed to everything caught in the burst.
  static const double flakDamage = 4;

  /// How wide the burst reaches, in world units.
  static const double flakBurstRadius = 46;

  /// Collision radius of the shell body.
  static const double flakRadius = 5;

  /// Seconds a shell lives before it burns out and goes off anyway.
  static const double flakLifespan = 2.4;

  /// Seconds between wing pod bursts at ordnance tier zero.
  ///
  /// The pods fire outward rather than up the lane, so they are the answer to
  /// anything that sits at the edge where the main cannon never points.
  static const double podInterval = 1.15;
  static const double podIntervalStep = 0.09;

  /// Speed of a pod bolt.
  static const double podSpeed = 620;

  /// Damage of one pod bolt. Low, because two of them land every burst and
  /// they cover ground nothing else does.
  static const double podDamage = 2;

  /// How far out from straight ahead the pods point, in radians.
  /// Wing pods fire straight up the lane, parallel to the cannon.
  ///
  /// They used to splay outward, which put two permanent diagonal streams
  /// either side of the ship. Coverage comes from how far apart the pods sit,
  /// not from pointing them away from where the player is aiming.
  static const double podAngle = 0;

  /// Sideways mounting offset of the pods from the middle of the ship.
  static const double podOffset = 13;

  /// Seconds between arc coil discharges at ordnance tier zero.
  ///
  /// The coil needs no aim at all, so its whole cost is having to be close.
  static const double arcInterval = 2.4;
  static const double arcIntervalStep = 0.16;

  /// Damage the coil hands to each thing it reaches.
  static const double arcDamage = 4;

  /// How far the coil reaches from the ship, in world units.
  static const double arcRange = 95;

  /// How many things one discharge can reach, and the ordnance tier at which
  /// the coil starts reaching further.
  static const int arcTargetsBase = 2;
  static const int arcTargetsWide = 4;
  static const int arcTargetsSecondTier = 3;

  /// Extra damage per tier of the ordnance upgrade for the flak, pods and
  /// coil, as a fraction. Missiles have their own steeper step because a
  /// salvo lands far less often.
  static const double ordnanceDamageStep = 0.20;

  /// Level from which each secondary weapon is fitted.
  ///
  /// The first levels teach the drag and the main cannon. Ordnance arrives
  /// once the player has that, rather than on top of it.
  static const int missileFirstLevel = 3;
  static const int railFirstLevel = 9;
  static const int flakFirstLevel = 13;
  static const int podFirstLevel = 21;
  static const int arcFirstLevel = 28;

  /// Ordnance tiers at which the rack becomes visible on the hull.
  ///
  /// The pods arrive with the first tier the player buys, the canards later,
  /// so the ship they fly changes shape twice on the way to a full rack.
  static const int podRackTier = 1;
  static const int canardTier = 3;

  /// The weapon fitted at this exact level, if any.
  ///
  /// A weapon that simply starts firing one level teaches the player nothing,
  /// so the display says what arrived. Returns an empty string on every other
  /// level.
  static String armamentAt(int level) {
    switch (level) {
      case missileFirstLevel:
        return 'MISSILE RACK ONLINE';
      case railFirstLevel:
        return 'RAILGUN ONLINE';
      case flakFirstLevel:
        return 'FLAK CANNON ONLINE';
      case podFirstLevel:
        return 'WING PODS ONLINE';
      case arcFirstLevel:
        return 'ARC COIL ONLINE';
      default:
        return '';
    }
  }

  /// Base hit points from which a kill earns a beat of hit stop.
  ///
  /// A scout popping every fifth of a second must never freeze the game, so
  /// only the families that take real work to kill qualify.
  static const double hitStopHpThreshold = 20;

  /// Points for shooting an incoming shot out of the air.
  static const int interceptScore = 5;

  /// Extra reach given to an intercept, in world units.
  ///
  /// Two bullets are small and closing fast, so without a little help the
  /// player would almost never land one, and the move would not feel real.
  static const double interceptAssist = 2.5;
  static const double ringBurstCount = 10;
  static const double spiralStep = 0.42;
  static const double waveShotAmplitude = 60;
  static const double waveShotFrequency = 3.2;

  // Upgrades. Five tiers each, cost rising geometrically.
  static const int upgradeMaxTier = 5;
  static const int upgradeBaseCost = 90;
  static const double upgradeCostGrowth = 1.85;
  static const double fireRateUpgradeStep = 0.10;
  static const double damageUpgradeStep = 0.22;
  static const double hitPointsUpgradeStep = 0.5;
  static const double magnetUpgradeStep = 0.25;
  static const double powerUpDurationStep = 0.2;

  // Stars.
  static const int starsPerLevel = 3;

  /// Enemy hit points for a level. [kindMultiplier] comes from the enemy
  /// catalog entry and the level kind.
  static double enemyHp(double baseHp, int level, double kindMultiplier) {
    return baseHp * (1 + hpPerLevel * level) * kindMultiplier * _relief(level);
  }

  /// Enemy rate of fire multiplier for a level.
  static double enemyFireRateMultiplier(int level) {
    final raw = 1 + fireRatePerLevel * level;
    // Half of the opening bump goes on rate of fire, so early enemies shoot
    // back rather than just soaking up bullets.
    final early = 1 + (earlyFactor(level) - 1) * 0.5;
    return math.min(raw, fireRateCap) * _relief(level) * early;
  }

  /// Enemy hit point multiplier for a level, before the catalog base value.
  static double enemyHpMultiplier(int level) {
    // Steep to the knee, then almost flat.
    //
    // A straight line here was the single worst thing in the game. Hit points
    // grew fifty three times over by level 1500 while everything the player
    // can buy only multiplies their damage about thirteen times, so the last
    // levels took minutes of holding the trigger on the same wave. Past the
    // knee a level gets harder through more waves, more families and more
    // fire, not through enemies that soak longer.
    final ramp = hpPerLevel * math.min(level, hpKnee);
    final tail = hpTailPerLevel * math.max(0, level - hpKnee);
    return (1 + ramp + tail) * _relief(level) * earlyFactor(level);
  }

  /// The opening bump, which is at its strongest on level 1 and gone by the
  /// time the player has upgrades worth the name.
  static double earlyFactor(int level) {
    if (level >= earlyBiteFade) {
      return 1;
    }
    return 1 + earlyBite * (1 - level / earlyBiteFade);
  }

  /// Coins awarded for finishing a level.
  static int coinReward(int level, LevelKind kind) {
    final base = baseCoinReward + level ~/ coinRewardLevelDivisor;
    switch (kind) {
      case LevelKind.normal:
        return base;
      case LevelKind.elite:
        return (base * eliteCoinBonus).round();
      case LevelKind.boss:
        return (base * bossCoinBonus).round();
      case LevelKind.survival:
      case LevelKind.escort:
      case LevelKind.gate:
        // The set piece kinds pay a little over a normal level, because they
        // ask for something the player has not practised.
        return (base * objectiveCoinBonus).round();
    }
  }

  /// Number of waves in a level, capped so a level never overstays.
  static int waveCount(int level) {
    return math.min(baseWaveCount + level ~/ waveCountLevelStep, maxWaveCount);
  }

  /// Chapter number, 1 based, for a level number.
  static int chapterOf(int level) => ((level - 1) ~/ levelsPerChapter) + 1;

  /// Position inside the chapter, 1 to 15.
  static int levelInChapter(int level) {
    final index = ((level - 1) % levelsPerChapter) + 1;
    return index;
  }

  /// What sort of level this is.
  static LevelKind kindOf(int level) {
    final index = levelInChapter(level);
    if (index == levelsPerChapter) {
      return LevelKind.boss;
    }
    if (index == eliteLevelInChapter) {
      return LevelKind.elite;
    }

    // A slice of ordinary levels becomes an objective level instead. It is
    // decided from the level number alone, so the level map can colour a level
    // without generating it, and every player gets the same one.
    if (level >= objectiveFirstLevel) {
      final roll = math.Random(level * 5701 + 2029).nextDouble();
      if (roll < objectiveChance) {
        const kinds = [LevelKind.survival, LevelKind.escort, LevelKind.gate];
        return kinds[level % kinds.length];
      }
    }
    return LevelKind.normal;
  }

  /// True when a level is a relief level, meaning the curve steps back.
  ///
  /// Boss levels are never relief levels. Without that exclusion every boss
  /// would land on a relief step, since 15 divides by 5.
  static bool isReliefLevel(int level) {
    if (kindOf(level) == LevelKind.boss) {
      return false;
    }
    return level % reliefInterval == 0;
  }

  static double _relief(int level) {
    return isReliefLevel(level) ? reliefFactor : 1.0;
  }

  /// Hit points of one rock at a level.
  static double obstacleHp(int level) {
    return obstacleBaseHp * (1 + obstacleHpPerLevel * level);
  }

  /// Boss hit points for a chapter, growing with the level and again every
  /// time the archetype repeats.
  static double bossHp(int level, int repeatIndex) {
    return bossBaseHp *
        (1 + bossHpPerLevel * level) *
        (1 + bossRepeatHpBonus * repeatIndex);
  }

  /// Cost of the next tier of an upgrade. Tier is the count already owned.
  static int upgradeCost(int tier) {
    return (upgradeBaseCost * math.pow(upgradeCostGrowth, tier)).round();
  }
}

/// Shape constants for the movement patterns.
///
/// These describe how a path looks rather than how hard it is, but they are
/// still tuning numbers, so they live beside the curve.
class MoveTuning {
  // The flanker: runs past, turns, comes back up the lane behind the player.
  /// How far past the player it goes before turning.
  /// How wide a cone in front of its own nose an enemy will shoot into, in
  /// radians.
  ///
  /// Every hull points down the lane, so a shot outside this reads as leaving
  /// the wing or the tail rather than the nose. Just under 55 degrees, which
  /// is wide enough that a wave arriving from the top never holds fire and
  /// narrow enough that one crossing the lane does.
  static const double fireCone = 0.95;

  /// How far in front of the player an enemy must still be to keep firing.
  ///
  /// Slightly ahead of the ship rather than level with it, so a shot is never
  /// released from a hull that is already alongside and pointing away.
  static const double fireCutoff = 12;

  static const double flankOvershoot = 140;
  static const double flankRunSpeed = 1.5;

  /// How long the wide swing at the far end takes.
  static const double flankTurnTime = 3.2;
  static const double flankSwing = 1.2;
  static const double flankReturnSpeed = 0.9;
  static const double flankReturnAim = 0.35;

  // The sniper: holds station out at the edge and shoots from there.
  static const double snipeDepth = 300;
  static const double snipeOffset = 96;
  static const double snipeDrift = 0.8;
  static const double snipeBobRate = 1.1;
  static const double snipeBob = 0.2;

  // The screen: holds a line further out than anything else, so it has to be
  // shot through rather than gone around.
  static const double screenDepth = 350;
  static const double screenSweepRate = 0.8;
  static const double screenSweep = 0.6;

  const MoveTuning._();

  static const double sineFrequency = 2.4;
  static const double sineAmplitude = 0.85;
  static const double zigzagFrequency = 1.5;
  static const double zigzagAmplitude = 0.95;
  static const double hoverStrafeFrequency = 0.9;
  static const double hoverStrafeSpeed = 0.8;
  static const double hoverHoldFraction = 0.28;

  /// How fast a hovering enemy keeps closing once it has arrived, as a
  /// fraction of its own speed.
  ///
  /// It used to be zero, which parked the wave across the top of the screen
  /// sliding left and right and never coming down the lane. A wave that never
  /// arrives is a wave the player waits out rather than fights.
  static const double hoverCloseSpeed = 0.34;
  static const double swoopFrequency = 0.75;
  static const double swoopLateral = 1.3;
  static const double orbitAngularSpeed = 1.5;
  static const double orbitDrift = 0.25;
  static const double diveAcceleration = 0.35;
  static const double diveMaxFactor = 2.0;
  static const double holdHoldFraction = 0.22;
  static const double entryOvershoot = 0.15;
}

/// Shape constants for the bullet patterns.
class BulletTuning {
  const BulletTuning._();

  static const double spreadAngle = 0.26;
  static const int ringCount = 10;
  static const double spiralAngularStep = 0.42;
  static const int spiralArms = 2;

  /// How wide a ring or spiral opens as it travels.
  static const double ringSpread = 0.45;

  /// How much of the shot speed a ring keeps pointed at the player.
  static const double ringForward = 0.85;

  static const double waveAmplitude = 60;
  static const double waveFrequency = 3.2;
  static const int burstCount = 3;
  static const double burstInterval = 0.11;
  static const double muzzleOffset = 14;
}

/// Spacing constants for the entry formations.
class FormationTuning {
  const FormationTuning._();

  static const double spacing = 52;
  static const double depth = 38;
  static const double arcRadius = 150;
  static const double arcSweep = 1.4;
  static const double pincerGap = 300;
  static const double sweepSlope = 0.55;
  static const double spiralRadius = 26;
  static const double spiralTurn = 0.9;

  /// Where a formation aims to sit once it has entered, as a fraction of the
  /// play area height.
  static const double anchorHeightFraction = 0.28;
}

/// Pacing constants for the level runner.
class RunnerTuning {
  const RunnerTuning._();

  /// A wave is never considered clear before this, which covers the frame or
  /// two it takes newly added components to mount.
  static const double waveMinDuration = 1.0;

  /// The shortest a level is allowed to be, in seconds of play.
  ///
  /// Measured before this existed, a normal level was over in nine to fourteen
  /// seconds for a player who cleared each wave the moment it arrived, which
  /// is barely long enough to register as a level at all. The lane keeps
  /// refilling until this much time has passed, so the floor holds no matter
  /// how heavily upgraded the ship is.
  ///
  /// It is a floor and not a target. A level that runs longer because the
  /// player is taking their time is left alone.
  static const double minLevelDuration = 30.0;

  /// How much of [minLevelDuration] is reserved for the boss itself.
  ///
  /// Boss levels reach the floor by holding the boss back behind escort waves,
  /// so without this the boss would not arrive until the floor had already
  /// passed and the fight would be an epilogue. This much of the clock is left
  /// for the fight.
  static const double bossFightAllowance = 12.0;

  /// Beat between the last enemy dying and the level complete sheet.
  static const double levelCompleteDelay = 0.8;

  /// Longer beat after a boss, so the slow motion can play out.
  static const double bossVictoryDelay = 1.6;

  /// Gap between the escort wave clearing and the boss arriving.
  static const double bossArrivalDelay = 1.2;

  // The run home. A level that simply stops has no payoff, so a won level ends
  // with a breath and then a warp out.

  /// Seconds of quiet coin collecting after the last enemy is gone.
  static const double bonusRunDuration = 4.0;

  /// Gap between bonus coins.
  static const double bonusCoinInterval = 0.22;

  /// How far across the lane the bonus coins weave.
  static const double bonusCoinSweep = 70;

  /// Seconds the warp out takes before the level complete sheet appears.
  static const double warpDuration = 1.3;
}

/// How much each level modifier bends the level it is applied to.
///
/// Modifiers are what stop two levels in the same chapter feeling like the
/// same level twice. They are deterministic, so a level always has the same
/// twist for every player.
class ModifierTuning {
  const ModifierTuning._();

  /// Levels below this stay plain, so the tutorial teaches one thing at a time.
  static const int firstModifiedLevel = 9;

  /// Roughly how often a level carries a twist.
  static const double chance = 0.55;

  static const double swarmCount = 1.6;
  static const double swarmHp = 0.7;

  static const double vanguardCount = 0.6;
  static const double vanguardHp = 1.7;

  static const double swiftSpeed = 1.3;
  static const double swiftFireRate = 0.9;

  static const double barrageFireRate = 1.45;
  static const double barrageBulletSpeed = 1.1;

  static const double armouredHp = 1.45;
  static const double armouredSpeed = 0.8;

  /// Count multiplier for a modifier.
  static double countFactor(LevelModifier modifier) {
    switch (modifier) {
      case LevelModifier.swarm:
        return swarmCount;
      case LevelModifier.vanguard:
        return vanguardCount;
      case LevelModifier.none:
      case LevelModifier.swift:
      case LevelModifier.barrage:
      case LevelModifier.armoured:
        return 1;
    }
  }

  /// Hit point multiplier for a modifier.
  static double hpFactor(LevelModifier modifier) {
    switch (modifier) {
      case LevelModifier.swarm:
        return swarmHp;
      case LevelModifier.vanguard:
        return vanguardHp;
      case LevelModifier.armoured:
        return armouredHp;
      case LevelModifier.none:
      case LevelModifier.swift:
      case LevelModifier.barrage:
        return 1;
    }
  }

  /// Speed multiplier for a modifier.
  static double speedFactor(LevelModifier modifier) {
    switch (modifier) {
      case LevelModifier.swift:
        return swiftSpeed;
      case LevelModifier.armoured:
        return armouredSpeed;
      case LevelModifier.none:
      case LevelModifier.swarm:
      case LevelModifier.vanguard:
      case LevelModifier.barrage:
        return 1;
    }
  }

  /// Rate of fire multiplier for a modifier.
  static double fireRateFactor(LevelModifier modifier) {
    switch (modifier) {
      case LevelModifier.barrage:
        return barrageFireRate;
      case LevelModifier.swift:
        return swiftFireRate;
      case LevelModifier.none:
      case LevelModifier.swarm:
      case LevelModifier.vanguard:
      case LevelModifier.armoured:
        return 1;
    }
  }

  /// Bullet speed multiplier for a modifier.
  static double bulletSpeedFactor(LevelModifier modifier) {
    return modifier == LevelModifier.barrage ? barrageBulletSpeed : 1;
  }
}

/// What each of the three settings does to a level.
///
/// The campaign is not three campaigns. It is the same 1500 generated levels
/// with these multipliers folded into the spec, which is why a level number
/// still produces the same waves in the same formations at any setting: the
/// player who moves down to easy is playing the level they were stuck on, not
/// a different one.
///
/// Easy takes hit points and rate of fire off rather than taking enemies away,
/// because a wave with pieces missing stops reading as the formation it was
/// drawn as. Hard adds hit points and fire, and pays for it.
class DifficultyTuning {
  const DifficultyTuning._();

  /// The setting a new player starts on.
  static const Difficulty starting = Difficulty.medium;

  /// Hard stays shut until the player has taken medium past its first boss.
  ///
  /// Offering it from the menu of a game nobody has played yet is how a player
  /// picks it once, loses eight times and stops.
  static const int hardUnlockLevel = 15;

  static const double easyHp = 0.68;
  static const double easySpeed = 0.88;
  static const double easyFireRate = 0.66;
  static const double easyBulletSpeed = 0.85;
  static const double easyCoin = 0.7;

  static const double hardHp = 1.5;
  static const double hardSpeed = 1.1;
  static const double hardFireRate = 1.35;
  static const double hardBulletSpeed = 1.12;
  static const double hardCoin = 1.75;

  /// Lives added on easy and taken away on hard.
  static const int easyLives = 2;
  static const int hardLives = -1;

  static double hpFactor(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return easyHp;
      case Difficulty.medium:
        return 1;
      case Difficulty.hard:
        return hardHp;
    }
  }

  static double speedFactor(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return easySpeed;
      case Difficulty.medium:
        return 1;
      case Difficulty.hard:
        return hardSpeed;
    }
  }

  static double fireRateFactor(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return easyFireRate;
      case Difficulty.medium:
        return 1;
      case Difficulty.hard:
        return hardFireRate;
    }
  }

  static double bulletSpeedFactor(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return easyBulletSpeed;
      case Difficulty.medium:
        return 1;
      case Difficulty.hard:
        return hardBulletSpeed;
    }
  }

  /// What the level pays. Hard pays well over normal on purpose: it is the
  /// only reason to replay a level the player has already cleared.
  static double coinFactor(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return easyCoin;
      case Difficulty.medium:
        return 1;
      case Difficulty.hard:
        return hardCoin;
    }
  }

  /// Lives added to, or taken off, a run at this setting.
  static int livesBonus(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return easyLives;
      case Difficulty.medium:
        return 0;
      case Difficulty.hard:
        return hardLives;
    }
  }

  /// The name shown on a button.
  static String labelOf(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.easy:
        return 'EASY';
      case Difficulty.medium:
        return 'MEDIUM';
      case Difficulty.hard:
        return 'HARD';
    }
  }

  /// One line of plain English about what the setting costs and pays.
  static String describe(Difficulty difficulty) {
    switch (difficulty) {
      // Kept to two lines on a phone. A third pushed the last button on the
      // menu below the fold.
      case Difficulty.easy:
        return 'Lighter hulls, less fire, 2 more lives. Pays 30% less.';
      case Difficulty.medium:
        return 'The game as it was tuned.';
      case Difficulty.hard:
        return 'Heavier hulls, far more fire, 1 life fewer. Pays 75% more.';
    }
  }
}
