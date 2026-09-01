import '../state/achievement_catalog.dart';

/// The ids Google Play Games and Apple Game Center know this game's boards and
/// badges by.
///
/// Neither service invents these. Each one is created by hand, once, in a
/// console, and pasted in below:
///
///   Android: import the ZIP written by `PGS=1 flutter test test/pgs_test.dart`
///   into Play Console, then Play Games Services, then Achievements. Every id
///   it hands back looks like CgkIxxxxxxxxxxEAIQAQ, and they go into
///   [androidAchievements] keyed by the slug in [AchievementCatalog]. The
///   project id at the top of that page is a separate thing and belongs in
///   android/app/src/main/res/values/game_services.xml.
///
///   iOS: App Store Connect, then Game Center. There the ids are chosen rather
///   than handed out, so [iosIdFor] builds them from the same slugs and no
///   table is needed.
///
/// Until the real ids are in, [configuredFor] is false, and the game says so
/// plainly rather than firing calls at a service that has never heard of it.
class PlayIds {
  const PlayIds({
    required this.highestLevel,
    required this.totalStars,
    required this.achievementIds,
  });

  /// What an id looks like before anyone has been to a console.
  static const String unset = 'PASTE_ID_HERE';

  /// Reverse domain root for the Game Center ids, which are ours to name.
  static const String iosPrefix = 'com.portalcrafter.novastrike';

  static String iosIdFor(String slug) => '$iosPrefix.achievement.$slug';

  /// Ids Play Console hands back after the achievements ZIP is imported.
  ///
  /// Keyed by the slug in [AchievementCatalog]. Copied out of the games-ids
  /// file the console generates, which also carries the project id; that one
  /// number goes to android/app/src/main/res/values/game_services.xml because
  /// the SDK reads it from the manifest before any Dart runs.
  ///
  /// A missing entry is not an error. The game runs, the achievements screen
  /// works off the local save, and only the submission to Google is held back
  /// for the badges that have no id.
  static const Map<String, String> androidAchievements = <String, String>{
    'first_flight': 'CgkI3qX-6fEdEAIQLw',
    'chapter_closed': 'CgkI3qX-6fEdEAIQKQ',
    'centurion': 'CgkI3qX-6fEdEAIQJQ',
    'void_runner': 'CgkI3qX-6fEdEAIQLQ',
    'nova_legend': 'CgkI3qX-6fEdEAIQMQ',
    'three_star_pilot': 'CgkI3qX-6fEdEAIQKg',
    'star_collector': 'CgkI3qX-6fEdEAIQKw',
    'sweeper': 'CgkI3qX-6fEdEAIQLA',
    'exterminator': 'CgkI3qX-6fEdEAIQJg',
    'boss_hunter': 'CgkI3qX-6fEdEAIQJw',
    'untouchable': 'CgkI3qX-6fEdEAIQLg',
    'flawless_ten': 'CgkI3qX-6fEdEAIQMg',
    'hard_line': 'CgkI3qX-6fEdEAIQKA',
    'fully_loaded': 'CgkI3qX-6fEdEAIQMA',
    'fleet_commander': 'CgkI3qX-6fEdEAIQJA',
  };

  /// The ids this build ships with.
  static final PlayIds live = PlayIds(
    // Highest campaign level reached. The obvious board for a game whose whole
    // shape is a ladder of 1500 levels.
    highestLevel: const LeaderboardId(
      name: 'Levels Cleared',
      android: 'CgkI3qX-6fEdEAIQMw',
      ios: '$iosPrefix.leaderboard.highest_level',
    ),
    // Stars across every level, which rewards going back and flying an old
    // level properly rather than only ever pushing forward.
    totalStars: const LeaderboardId(
      name: 'Stars Collected',
      android: 'CgkI3qX-6fEdEAIQNA',
      ios: '$iosPrefix.leaderboard.total_stars',
    ),
    // Built from the catalogue rather than written out again, so a badge added
    // there can never be forgotten here.
    achievementIds: {
      for (final badge in AchievementCatalog.all)
        badge.id: AchievementId(
          android: androidAchievements[badge.id] ?? unset,
          ios: iosIdFor(badge.id),
        ),
    },
  );

  final LeaderboardId highestLevel;
  final LeaderboardId totalStars;

  /// One entry per badge in [AchievementCatalog], keyed by its slug.
  final Map<String, AchievementId> achievementIds;

  List<LeaderboardId> get leaderboards => [highestLevel, totalStars];

  List<AchievementId> get achievements => achievementIds.values.toList();

  /// The id for one badge on the platform being run, or [unset].
  String achievementIdFor(String slug, {required bool android}) {
    final entry = achievementIds[slug];
    if (entry == null) {
      return unset;
    }
    return android ? entry.android : entry.ios;
  }

  static bool ready(String id) => id.isNotEmpty && id != unset;

  /// Whether every badge has a real id on the platform being run.
  bool achievementsConfiguredFor({required bool android}) => achievements.every(
    (badge) => ready(android ? badge.android : badge.ios),
  );

  /// Whether every board has a real id on the platform being run.
  bool leaderboardsConfiguredFor({required bool android}) => leaderboards.every(
    (board) => ready(android ? board.android : board.ios),
  );

  /// Names of the boards still waiting on an id.
  ///
  /// Boards are created one at a time on a form, so having some and not others
  /// is the normal middle of the job. A screen that said "leaderboards are not
  /// set up" while one of them was live would be telling the player something
  /// untrue.
  List<String> unreadyBoards({required bool android}) => [
    for (final board in leaderboards)
      if (!ready(android ? board.android : board.ios)) board.name,
  ];

  /// How many badges are still waiting on an id.
  int unreadyBadgeCount({required bool android}) => achievements
      .where((badge) => !ready(android ? badge.android : badge.ios))
      .length;

  /// True once every id above has been replaced on the platform being run.
  ///
  /// The two platforms are judged separately, because a game can be set up on
  /// one store months before the other and the one that is ready should work.
  ///
  /// Badges and boards are judged separately too, and that matters more than
  /// it looks. They are created in the console as two independent jobs, so the
  /// normal state of a game being set up is one done and the other not. Judged
  /// together, importing fifteen achievements would still submit nothing until
  /// somebody also got round to the leaderboards.
  bool configuredFor({required bool android}) =>
      achievementsConfiguredFor(android: android) &&
      leaderboardsConfiguredFor(android: android);
}

/// One leaderboard, named once per store.
class LeaderboardId {
  const LeaderboardId({
    required this.name,
    required this.android,
    required this.ios,
  });

  /// What it is called in the console, so a screen can say which board is
  /// still missing rather than just that something is.
  final String name;

  final String android;
  final String ios;
}

/// One achievement, named once per store.
class AchievementId {
  const AchievementId({required this.android, required this.ios});

  final String android;
  final String ios;
}
