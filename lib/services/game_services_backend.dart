import 'package:games_services/games_services.dart';

/// The thin seam between this game and the two stores' game services.
///
/// Everything that reaches a platform channel goes through here, so the
/// controller above it can be driven by a fake in a test. Without this seam
/// nothing about sign in, score submission or badge unlocking could be tested
/// off a device, because a plugin channel has no answer in a unit test.
abstract class GameServicesBackend {
  /// Whether the player is already signed in from a previous run.
  Future<bool> isSignedIn();

  /// Opens the store's own sign in flow. Returns true if it ends signed in.
  Future<bool> signIn();

  /// The name the store shows for the signed in player, if it has one.
  Future<String?> playerName();

  Future<void> submitScore({required String leaderboardId, required int value});

  Future<void> unlock({required String achievementId});

  /// Opens the store's own leaderboard sheet, on the given board when named.
  Future<void> showLeaderboards({String? leaderboardId});

  /// Opens the store's own achievement sheet.
  Future<void> showAchievements();
}

/// The real one: Google Play Games on Android, Game Center on iOS.
///
/// The plugin picks the store from the platform it is running on, so the ids
/// for both are handed over together and only the right one is used.
class StoreGameServices implements GameServicesBackend {
  const StoreGameServices();

  @override
  Future<bool> isSignedIn() => GameAuth.isSignedIn;

  @override
  Future<bool> signIn() async {
    await GameAuth.signIn();
    return GameAuth.isSignedIn;
  }

  @override
  Future<String?> playerName() => Player.getPlayerName();

  @override
  Future<void> submitScore({
    required String leaderboardId,
    required int value,
  }) async {
    await Leaderboards.submitScore(
      score: Score(
        androidLeaderboardID: leaderboardId,
        iOSLeaderboardID: leaderboardId,
        value: value,
      ),
    );
  }

  @override
  Future<void> unlock({required String achievementId}) async {
    await Achievements.unlock(
      achievement: Achievement(
        androidID: achievementId,
        iOSID: achievementId,
      ),
    );
  }

  @override
  Future<void> showLeaderboards({String? leaderboardId}) async {
    // The plugin reads an empty string, not a null, as "every board".
    await Leaderboards.showLeaderboards(
      androidLeaderboardID: leaderboardId ?? '',
      iOSLeaderboardID: leaderboardId ?? '',
    );
  }

  @override
  Future<void> showAchievements() async {
    await Achievements.showAchievements();
  }
}
