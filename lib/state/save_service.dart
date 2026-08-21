import 'package:shared_preferences/shared_preferences.dart';

import '../audio/audio_settings.dart';
import '../levels/level_spec.dart';

/// The only place that touches shared_preferences.
///
/// Everything the game remembers between runs goes through this class: audio
/// settings, unlocked levels, coins, upgrades, stars and the haptics toggle.
class SaveService {
  /// Bumped whenever the shape of what is stored changes.
  ///
  /// A save written by a newer build than the one reading it cannot be trusted
  /// field by field, so the reader falls back to defaults rather than guessing.
  /// Nothing is ever deleted on the way, because a player who downgrades and
  /// upgrades again should get their progress back.
  static const int currentVersion = 2;

  static const String keyVersion = 'saveVersion';
  static const String keyHighestLevel = 'highestLevelUnlocked';
  static const String keyCoins = 'coins';
  static const String keyUpgrades = 'upgrades';
  static const String keyStars = 'starsPerLevel';
  static const String keyAudioMaster = 'audioMaster';
  static const String keyAudioMusic = 'audioMusic';
  static const String keyAudioSfx = 'audioSfx';
  static const String keyAudioMuted = 'audioMuted';
  static const String keyHaptics = 'hapticsEnabled';
  static const String keyReduceShake = 'reduceShake';
  static const String keyHighContrast = 'highContrast';
  static const String keyLargeBullets = 'largeBullets';
  static const String keyShip = 'shipId';
  static const String keyShipsOwned = 'shipsOwned';
  static const String keyEndlessBest = 'endlessBest';
  static const String keyDifficulty = 'difficulty';

  SharedPreferences? _prefs;

  /// True when the save on disk came from a build newer than this one.
  ///
  /// Everything still loads, but anything this build does not understand is
  /// left alone rather than being overwritten with a default.
  bool fromFuture = false;

  /// True once [init] has run. Every getter falls back to a default before
  /// that, so a failed load never crashes the game.
  bool get isReady => _prefs != null;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      _prefs = null;
      return;
    }
    _migrate();
  }

  /// Brings an older save up to the current shape.
  ///
  /// Version 1 is any save written before versioning existed. It needs nothing
  /// done to it: every field added since has a default, so it simply gets
  /// stamped. The stamp matters more than the migration, because it is what
  /// lets a later change know what it is looking at.
  void _migrate() {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    final found =
        prefs.getInt(keyVersion) ??
        (prefs.containsKey(keyHighestLevel) ? 1 : currentVersion);
    if (found > currentVersion) {
      fromFuture = true;
      return;
    }
    if (found != currentVersion) {
      prefs.setInt(keyVersion, currentVersion);
    }
  }

  int get version => _prefs?.getInt(keyVersion) ?? currentVersion;

  bool loadReduceShake() => _prefs?.getBool(keyReduceShake) ?? false;

  Future<void> saveReduceShake(bool value) async {
    await _prefs?.setBool(keyReduceShake, value);
  }

  bool loadHighContrast() => _prefs?.getBool(keyHighContrast) ?? false;

  Future<void> saveHighContrast(bool value) async {
    await _prefs?.setBool(keyHighContrast, value);
  }

  bool loadLargeBullets() => _prefs?.getBool(keyLargeBullets) ?? false;

  Future<void> saveLargeBullets(bool value) async {
    await _prefs?.setBool(keyLargeBullets, value);
  }

  String loadShip() => _prefs?.getString(keyShip) ?? '';

  Future<void> saveShip(String id) async {
    await _prefs?.setString(keyShip, id);
  }

  /// Owned ships are a comma separated list of ids, the same cheap encoding
  /// the upgrades use.
  List<String> loadShipsOwned() {
    final raw = _prefs?.getString(keyShipsOwned) ?? '';
    if (raw.isEmpty) {
      return const [];
    }
    return raw.split(',').where((id) => id.isNotEmpty).toList();
  }

  Future<void> saveShipsOwned(List<String> ids) async {
    await _prefs?.setString(keyShipsOwned, ids.join(','));
  }

  int loadEndlessBest() => _prefs?.getInt(keyEndlessBest) ?? 0;

  Future<void> saveEndlessBest(int score) async {
    await _prefs?.setInt(keyEndlessBest, score);
  }

  AudioSettings loadAudioSettings() {
    final prefs = _prefs;
    if (prefs == null) {
      return AudioSettings();
    }
    return AudioSettings(
      master: prefs.getDouble(keyAudioMaster) ?? AudioSettings.defaultMaster,
      music: prefs.getDouble(keyAudioMusic) ?? AudioSettings.defaultMusic,
      sfx: prefs.getDouble(keyAudioSfx) ?? AudioSettings.defaultSfx,
      muted: prefs.getBool(keyAudioMuted) ?? false,
    );
  }

  Future<void> saveAudioSettings(AudioSettings settings) async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    await prefs.setDouble(keyAudioMaster, settings.master);
    await prefs.setDouble(keyAudioMusic, settings.music);
    await prefs.setDouble(keyAudioSfx, settings.sfx);
    await prefs.setBool(keyAudioMuted, settings.muted);
  }

  /// Progress is kept per setting, so clearing level 40 on easy does not hand
  /// the player level 40 on hard.
  ///
  /// Normal keeps the original key. It is the setting every existing save was
  /// written at, and moving it would throw that progress away.
  static String levelKeyFor(Difficulty difficulty) =>
      difficulty == Difficulty.normal
      ? keyHighestLevel
      : '${keyHighestLevel}_${difficulty.name}';

  static String starsKeyFor(Difficulty difficulty) =>
      difficulty == Difficulty.normal
      ? keyStars
      : '${keyStars}_${difficulty.name}';

  int loadHighestLevel(Difficulty difficulty) =>
      _prefs?.getInt(levelKeyFor(difficulty)) ?? 1;

  Future<void> saveHighestLevel(Difficulty difficulty, int level) async {
    await _prefs?.setInt(levelKeyFor(difficulty), level);
  }

  Difficulty loadDifficulty() {
    final name = _prefs?.getString(keyDifficulty);
    for (final difficulty in Difficulty.values) {
      if (difficulty.name == name) {
        return difficulty;
      }
    }
    return Difficulty.normal;
  }

  Future<void> saveDifficulty(Difficulty difficulty) async {
    await _prefs?.setString(keyDifficulty, difficulty.name);
  }

  int loadCoins() => _prefs?.getInt(keyCoins) ?? 0;

  Future<void> saveCoins(int coins) async {
    await _prefs?.setInt(keyCoins, coins);
  }

  bool loadHaptics() => _prefs?.getBool(keyHaptics) ?? true;

  Future<void> saveHaptics(bool enabled) async {
    await _prefs?.setBool(keyHaptics, enabled);
  }

  /// Upgrades are stored as id:tier pairs joined by commas, which is far
  /// smaller than JSON and needs no parser.
  Map<String, int> loadUpgrades() {
    final raw = _prefs?.getString(keyUpgrades);
    return decodeUpgrades(raw);
  }

  Future<void> saveUpgrades(Map<String, int> upgrades) async {
    await _prefs?.setString(keyUpgrades, encodeUpgrades(upgrades));
  }

  /// Stars are one digit per level, indexed by level number minus one.
  String loadStars(Difficulty difficulty) =>
      _prefs?.getString(starsKeyFor(difficulty)) ?? '';

  Future<void> saveStars(Difficulty difficulty, String stars) async {
    await _prefs?.setString(starsKeyFor(difficulty), stars);
  }

  /// Wipes progress but keeps audio settings, since a reset is about the game
  /// and not about how loud the player likes it.
  Future<void> clearProgress() async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    for (final difficulty in Difficulty.values) {
      await prefs.remove(levelKeyFor(difficulty));
      await prefs.remove(starsKeyFor(difficulty));
    }
    await prefs.remove(keyCoins);
    await prefs.remove(keyUpgrades);
    await prefs.remove(keyShip);
    await prefs.remove(keyShipsOwned);
    await prefs.remove(keyEndlessBest);
  }

  static Map<String, int> decodeUpgrades(String? raw) {
    final result = <String, int>{};
    if (raw == null || raw.isEmpty) {
      return result;
    }
    for (final pair in raw.split(',')) {
      final parts = pair.split(':');
      if (parts.length != 2) {
        continue;
      }
      final tier = int.tryParse(parts[1]);
      if (tier != null) {
        result[parts[0]] = tier;
      }
    }
    return result;
  }

  static String encodeUpgrades(Map<String, int> upgrades) {
    final parts = <String>[];
    upgrades.forEach((id, tier) {
      parts.add('$id:$tier');
    });
    return parts.join(',');
  }
}
