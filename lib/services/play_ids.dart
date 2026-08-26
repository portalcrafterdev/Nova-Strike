/// The ids Google Play Games and Apple Game Center know this game's boards and
/// badges by.
///
/// Neither service invents these. Each one is created by hand, once, in a
/// console, and pasted into [live]:
///
///   Android: Play Console, then Play Games Services, then Leaderboards and
///   Achievements. Every id it hands back looks like CgkIxxxxxxxxxxEAIQAQ. The
///   project id at the top of that same page is a separate thing, and it goes
///   into android/app/src/main/res/values/game_services.xml.
///
///   iOS: App Store Connect, then Game Center. There the ids are whatever you
///   name them, and reverse domain style keeps them from colliding with
///   another game on the same account.
///
/// Until the real ids are in, [configuredFor] is false, and the game says so
/// plainly rather than firing calls at a service that has never heard of it.
///
/// This is a value rather than a bag of statics so a test can hand the
/// controller a filled in table. Without that, every path past "not set up
/// yet" would be unreachable off a device.
class PlayIds {
  const PlayIds({
    required this.highestLevel,
    required this.totalStars,
    required this.firstFlight,
    required this.bossSlayer,
    required this.perfectRun,
    required this.centurion,
    required this.starCollector,
  });

  /// What an id looks like before anyone has been to a console.
  ///
  /// Checked for rather than assumed, so a half filled table counts as not
  /// configured instead of failing one call at a time on a player's phone.
  static const String unset = 'PASTE_ID_HERE';

  /// The ids this build ships with.
  static const PlayIds live = PlayIds(
    // Highest campaign level reached. The obvious board for a game whose whole
    // shape is a ladder of 1500 levels.
    highestLevel: LeaderboardId(
      android: unset,
      ios: 'com.portalcrafter.novastrike.leaderboard.highest_level',
    ),
    // Stars across every level, which rewards going back and flying an old
    // level properly rather than only ever pushing forward.
    totalStars: LeaderboardId(
      android: unset,
      ios: 'com.portalcrafter.novastrike.leaderboard.total_stars',
    ),
    // Five badges, not fifty. Each one is a moment worth remembering rather
    // than a tax on grinding.
    firstFlight: AchievementId(
      android: unset,
      ios: 'com.portalcrafter.novastrike.achievement.first_flight',
    ),
    bossSlayer: AchievementId(
      android: unset,
      ios: 'com.portalcrafter.novastrike.achievement.boss_slayer',
    ),
    perfectRun: AchievementId(
      android: unset,
      ios: 'com.portalcrafter.novastrike.achievement.perfect_run',
    ),
    centurion: AchievementId(
      android: unset,
      ios: 'com.portalcrafter.novastrike.achievement.centurion',
    ),
    starCollector: AchievementId(
      android: unset,
      ios: 'com.portalcrafter.novastrike.achievement.star_collector',
    ),
  );

  final LeaderboardId highestLevel;
  final LeaderboardId totalStars;
  final AchievementId firstFlight;
  final AchievementId bossSlayer;
  final AchievementId perfectRun;
  final AchievementId centurion;
  final AchievementId starCollector;

  List<LeaderboardId> get leaderboards => [highestLevel, totalStars];

  List<AchievementId> get achievements => [
    firstFlight,
    bossSlayer,
    perfectRun,
    centurion,
    starCollector,
  ];

  /// True once every id above has been replaced on the platform being run.
  ///
  /// The two platforms are judged separately, because a game can be set up on
  /// one store months before the other and the one that is ready should work.
  bool configuredFor({required bool android}) {
    bool ready(String id) => id.isNotEmpty && id != unset;
    for (final board in leaderboards) {
      if (!ready(android ? board.android : board.ios)) {
        return false;
      }
    }
    for (final badge in achievements) {
      if (!ready(android ? badge.android : badge.ios)) {
        return false;
      }
    }
    return true;
  }
}

/// One leaderboard, named once per store.
class LeaderboardId {
  const LeaderboardId({required this.android, required this.ios});

  final String android;
  final String ios;
}

/// One achievement, named once per store.
class AchievementId {
  const AchievementId({required this.android, required this.ios});

  final String android;
  final String ios;
}
