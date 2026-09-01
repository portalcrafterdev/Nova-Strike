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
  /// Keyed by the slug in [AchievementCatalog]. Empty means nothing has been
  /// imported yet, which is not an error: the game runs, the achievements
  /// screen works off the local save, and only the submission to Google is
  /// held back.
  static const Map<String, String> androidAchievements = <String, String>{};

  /// The ids this build ships with.
  static final PlayIds live = PlayIds(
    // Highest campaign level reached. The obvious board for a game whose whole
    // shape is a ladder of 1500 levels.
    highestLevel: const LeaderboardId(
      android: unset,
      ios: '$iosPrefix.leaderboard.highest_level',
    ),
    // Stars across every level, which rewards going back and flying an old
    // level properly rather than only ever pushing forward.
    totalStars: const LeaderboardId(
      android: unset,
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

  /// True once every id above has been replaced on the platform being run.
  ///
  /// The two platforms are judged separately, because a game can be set up on
  /// one store months before the other and the one that is ready should work.
  bool configuredFor({required bool android}) {
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
