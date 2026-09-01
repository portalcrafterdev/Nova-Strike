import 'package:flutter/material.dart';

import '../levels/difficulty_curve.dart';
import '../levels/level_spec.dart';
import 'player_progress.dart';
import 'save_service.dart';
import 'ship_catalog.dart';

/// One badge: what it is called, what earns it, and what it looks like.
///
/// [progress] returns how far the player has got rather than a yes or no, so a
/// bar can be drawn for the counting ones and the same number can be handed to
/// Play Games as a step count. A badge that is not incremental reports 0 or 1
/// against a target of 1.
class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.points,
    required this.progress,
    this.steps = 0,
    this.goal = 0,
    this.hidden = false,
  });

  /// Stable slug. It is the key in [PlayIds], the Name column in the Play
  /// Console import, and the icon filename. It never changes once shipped,
  /// because Play Games matches on it and a game gets 400 badges for its whole
  /// lifetime. A renamed badge burns one of those and loses everyone's
  /// progress on it.
  final String id;

  /// Shown to the player. Must not contain a comma: the Play Console import
  /// is a headerless CSV with no quoting.
  final String name;
  final String description;
  final IconData icon;

  /// Play Games points. A multiple of 5 between [AchievementCatalog.minPoints]
  /// and [AchievementCatalog.maxPoints], and the total across every badge may
  /// not exceed [AchievementCatalog.maxTotalPoints].
  final int points;

  /// Steps for a counting badge, or 0 for one that simply happens.
  ///
  /// This is what Play Games is told, so it obeys Play Games' cap of 10000.
  final int steps;

  /// A target too large for [steps] to carry.
  ///
  /// Play Games will not take more than 10000 steps, but a larger number can
  /// still be worth a bar in the game's own list. Setting this instead of
  /// [steps] gives the player the bar and gives the store a plain unlock,
  /// which is the only pair of behaviours both can actually support.
  final int goal;

  /// Hidden badges stay secret until earned. Used for the far end of the
  /// campaign so the list does not read as a wall of things not done yet.
  final bool hidden;

  /// How far along the player is, counted in the same units as [target].
  final int Function(PlayerProgress) progress;

  /// Whether Play Games should be sent step counts rather than an unlock.
  bool get isIncremental => steps > 0;

  /// What [progress] has to reach.
  int get target => steps > 0 ? steps : (goal > 0 ? goal : 1);

  /// Whether the game's own list should draw a bar for this one.
  bool get hasBar => target > 1;

  int progressIn(PlayerProgress p) => progress(p).clamp(0, target);

  bool earnedBy(PlayerProgress p) => progress(p) >= target;

  /// 0 to 1, for a progress bar.
  double fractionIn(PlayerProgress p) => progressIn(p) / target;
}

/// Every badge in the game.
///
/// One list, read by the achievements screen, by the store submission, and by
/// the generator that writes the Play Console import. Adding a badge here is
/// the only edit needed for all three.
///
/// Fifteen to start with, against a lifetime allowance of 400 and a points
/// budget of 2000. That is deliberate. Badge ids can never be reused and
/// points can never be taken back off a player, so the room to grow is worth
/// more than a long list on day one. The campaign is also going from 1500
/// levels to 10000, and the milestones below are picked to still mean
/// something at that length rather than all being cleared in the first week.
class AchievementCatalog {
  const AchievementCatalog._();

  /// Play Games refuses an import whose points do not fit in this.
  static const int maxTotalPoints = 2000;

  /// Badges a game may create over its whole life, reused ids included.
  static const int maxBadges = 400;

  /// The band every badge is worth.
  ///
  /// Play Games itself allows 5 to 200. This game holds to a narrower band on
  /// purpose: no badge is worth forty times another, so nothing in the list is
  /// beneath bothering with and nothing towers over the rest. Both ends are
  /// multiples of 5, which Play Games requires.
  static const int minPoints = 5;
  static const int maxPoints = 50;

  /// Levels cleared for the middle campaign badge.
  ///
  /// A thousand is past the end of the campaign as it stands and a tenth of
  /// the way through the one it is growing into, so it survives the change
  /// without becoming trivial.
  static const int voidRunnerLevels = 1000;

  /// Counts a boolean as a step, so a plain badge and a counting one can share
  /// one shape.
  static int _flag(bool value) => value ? 1 : 0;

  static const List<AchievementDef> all = [
    // The campaign. Five rungs from the first minute to the last level, spaced
    // so the gap between them keeps growing.
    AchievementDef(
      id: 'first_flight',
      name: 'First Flight',
      description: 'Clear level 1 and get off the ground.',
      icon: Icons.flight_takeoff,
      points: 5,
      progress: _clearedFirst,
    ),
    AchievementDef(
      id: 'chapter_closed',
      name: 'Chapter Closed',
      description: 'Bring down the boss at the end of chapter one.',
      icon: Icons.shield_moon,
      points: 10,
      progress: _clearedFirstChapter,
    ),
    AchievementDef(
      id: 'centurion',
      name: 'Centurion',
      description: 'Clear one hundred levels.',
      icon: Icons.workspace_premium,
      points: 20,
      progress: _clearedHundred,
    ),
    AchievementDef(
      id: 'void_runner',
      name: 'Void Runner',
      description: 'Clear one thousand levels.',
      icon: Icons.dark_mode,
      points: 35,
      hidden: true,
      progress: _clearedThousand,
    ),
    AchievementDef(
      id: 'nova_legend',
      name: 'Nova Legend',
      description: 'Clear the final level and finish the campaign.',
      icon: Icons.auto_awesome,
      points: 50,
      hidden: true,
      progress: _clearedFinal,
    ),

    // Stars. What rewards going back and flying an old level properly rather
    // than only ever pushing forward.
    AchievementDef(
      id: 'three_star_pilot',
      name: 'Three Star Pilot',
      description: 'Earn all three stars on any level.',
      icon: Icons.star,
      points: 10,
      progress: _anyThreeStar,
    ),
    AchievementDef(
      id: 'star_collector',
      name: 'Star Collector',
      description: 'Collect two hundred and fifty stars.',
      icon: Icons.stars,
      points: 20,
      steps: 250,
      progress: _stars,
    ),

    // Combat. Counted across every run whether it was won or lost.
    AchievementDef(
      id: 'sweeper',
      name: 'Sweeper',
      description: 'Destroy one thousand enemy ships.',
      icon: Icons.whatshot,
      points: 15,
      steps: 1000,
      progress: _enemies,
    ),
    AchievementDef(
      id: 'exterminator',
      name: 'Exterminator',
      description: 'Destroy ten thousand enemy ships.',
      icon: Icons.local_fire_department,
      points: 30,
      steps: 10000,
      hidden: true,
      progress: _enemies,
    ),
    AchievementDef(
      id: 'boss_hunter',
      name: 'Boss Hunter',
      description: 'Defeat twenty five bosses.',
      icon: Icons.bolt,
      points: 25,
      steps: 25,
      progress: _bosses,
    ),

    // Skill. The ones worth having.
    AchievementDef(
      id: 'untouchable',
      name: 'Untouchable',
      description: 'Clear a level without losing a ship.',
      icon: Icons.verified,
      points: 10,
      progress: _anyPerfect,
    ),
    AchievementDef(
      id: 'flawless_ten',
      name: 'Flawless Ten',
      description: 'Clear ten levels without losing a ship.',
      icon: Icons.verified_user,
      points: 25,
      steps: 10,
      progress: _perfectLevels,
    ),
    AchievementDef(
      id: 'hard_line',
      name: 'Hard Line',
      description: 'Clear a level on hard.',
      icon: Icons.flash_on,
      points: 20,
      progress: _hardCleared,
    ),

    // The two things coins are spent on.
    AchievementDef(
      id: 'fully_loaded',
      name: 'Fully Loaded',
      description: 'Take one upgrade to its top tier.',
      icon: Icons.build,
      points: 15,
      progress: _anyMaxedUpgrade,
    ),
    AchievementDef(
      id: 'fleet_commander',
      name: 'Fleet Commander',
      description: 'Own every hull in the hangar.',
      icon: Icons.flight,
      points: 30,
      progress: _allShips,
    ),
  ];

  static AchievementDef byId(String id) =>
      all.firstWhere((badge) => badge.id == id);

  /// Points across every badge, which Play Games caps at [maxTotalPoints].
  static int get totalPoints =>
      all.fold(0, (sum, badge) => sum + badge.points);

  /// What is left in the points budget for badges added later.
  static int get pointsSpare => maxTotalPoints - totalPoints;

  static List<AchievementDef> earnedIn(PlayerProgress p) =>
      all.where((badge) => badge.earnedBy(p)).toList();

  // The conditions. Written as named top level functions rather than closures
  // so the list above can stay const, which is what lets a test walk it
  // without building anything.

  /// Levels are judged on the furthest reached at any setting, so a player who
  /// switched to hard and started again does not lose a badge they earned.
  static int _cleared(PlayerProgress p, int level) =>
      _flag(p.furthestLevel > level);

  static int _clearedFirst(PlayerProgress p) => _cleared(p, 1);
  static int _clearedFirstChapter(PlayerProgress p) =>
      _cleared(p, Tuning.levelsPerChapter);
  static int _clearedHundred(PlayerProgress p) => _cleared(p, 100);
  static int _clearedThousand(PlayerProgress p) =>
      _cleared(p, voidRunnerLevels);

  /// The last level is the one case where the level above it does not exist,
  /// so finishing it is judged on the star it leaves behind. Read from
  /// [Tuning.totalLevels] rather than written out, so growing the campaign
  /// moves the finish line instead of handing everyone the badge.
  static int _clearedFinal(PlayerProgress p) =>
      _flag(p.starsFor(Tuning.totalLevels) > 0);

  static int _stars(PlayerProgress p) => p.starsEverywhere;

  static int _anyThreeStar(PlayerProgress p) =>
      _flag(p.starsData.contains('${Tuning.starsPerLevel}'));

  static int _enemies(PlayerProgress p) =>
      p.lifetime(SaveService.keyLifetimeEnemies);
  static int _bosses(PlayerProgress p) =>
      p.lifetime(SaveService.keyLifetimeBosses);
  static int _perfectLevels(PlayerProgress p) =>
      p.lifetime(SaveService.keyPerfectLevels);
  static int _anyPerfect(PlayerProgress p) => _flag(_perfectLevels(p) > 0);

  static int _hardCleared(PlayerProgress p) =>
      _flag(p.highestLevelIn(Difficulty.hard) > 1);

  static int _anyMaxedUpgrade(PlayerProgress p) => _flag(p.maxedUpgrades > 0);

  static int _allShips(PlayerProgress p) =>
      _flag(p.shipsOwned >= ShipCatalog.ships.length);
}
