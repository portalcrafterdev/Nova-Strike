import 'package:flutter/foundation.dart';

import '../levels/difficulty_curve.dart';
import '../levels/level_spec.dart';
import 'save_service.dart';
import 'ship_catalog.dart';

/// The seven things coins can be spent on.
enum UpgradeId {
  fireRate,
  damage,
  bulletCount,
  hitPoints,
  magnetRadius,
  powerUpDuration,
  ordnance,
}

/// Display information for an upgrade. The numbers behind it live in the
/// difficulty curve.
class UpgradeDef {
  const UpgradeDef({
    required this.id,
    required this.name,
    required this.description,
  });

  final UpgradeId id;
  final String name;
  final String description;

  String get key => id.name;
}

/// Everything the player has earned, and the only writer of save data.
///
/// The game reads derived stats such as [fireInterval] from here rather than
/// working out upgrade maths on its own.
class PlayerProgress extends ChangeNotifier {
  PlayerProgress(this._save);

  static const List<UpgradeDef> upgrades = [
    UpgradeDef(
      id: UpgradeId.fireRate,
      name: 'Fire Rate',
      description: 'Shorter gap between shots',
    ),
    UpgradeDef(
      id: UpgradeId.damage,
      name: 'Damage',
      description: 'Every bullet hits harder',
    ),
    UpgradeDef(
      id: UpgradeId.bulletCount,
      name: 'Bullet Count',
      description: 'More streams of fire',
    ),
    UpgradeDef(
      id: UpgradeId.hitPoints,
      name: 'Hull',
      description: 'Extra life in every level',
    ),
    UpgradeDef(
      id: UpgradeId.magnetRadius,
      name: 'Magnet',
      description: 'Coins are pulled in from further away',
    ),
    UpgradeDef(
      id: UpgradeId.powerUpDuration,
      name: 'Gem Charge',
      description: 'Power-ups last longer',
    ),
    UpgradeDef(
      id: UpgradeId.ordnance,
      name: 'Ordnance',
      description: 'Every secondary weapon fires more often and hits harder',
    ),
  ];

  final SaveService _save;

  Difficulty _difficulty = DifficultyTuning.starting;
  final Map<Difficulty, int> _highest = {
    for (final d in Difficulty.values) d: 1,
  };
  final Map<Difficulty, String> _starsAt = {
    for (final d in Difficulty.values) d: '',
  };
  int _coins = 0;
  bool _haptics = true;
  bool _reduceShake = false;
  bool _highContrast = false;
  bool _largeBullets = false;
  Map<String, int> _upgradeTiers = <String, int>{};

  /// The setting the player is on. Everything below that reads progress reads
  /// it for this one.
  Difficulty get difficulty => _difficulty;

  int get highestLevelUnlocked => _highest[_difficulty]!;
  int get coins => _coins;
  bool get hapticsEnabled => _haptics;
  String get starsData => _starsAt[_difficulty]!;

  /// How far the player has got at a given setting.
  int highestLevelIn(Difficulty difficulty) => _highest[difficulty]!;

  /// Whether a setting can be chosen yet.
  ///
  /// Easy and normal are always open. Hard waits until the player has taken
  /// normal past its first boss, because a setting that beats a new player
  /// eight times running is not a choice, it is a trap.
  bool isAvailable(Difficulty difficulty) =>
      difficulty != Difficulty.hard ||
      _highest[Difficulty.normal]! > DifficultyTuning.hardUnlockLevel;

  /// Switches setting. Each one keeps its own place in the campaign, so this
  /// never moves the player forward or back through levels they have earned.
  Future<void> setDifficulty(Difficulty difficulty) async {
    if (difficulty == _difficulty || !isAvailable(difficulty)) {
      return;
    }
    _difficulty = difficulty;
    await _save.saveDifficulty(difficulty);
    notifyListeners();
  }

  /// Camera shake is cut to nothing when this is on.
  bool get reduceShake => _reduceShake;

  /// Enemy fire is repainted in a colour that does not sit next to the
  /// player's own, which is the pairing most likely to give trouble.
  bool get highContrast => _highContrast;

  /// Every bullet is drawn bigger, without changing what it can hit.
  bool get largeBullets => _largeBullets;

  Future<void> setReduceShake(bool value) async {
    _reduceShake = value;
    await _save.saveReduceShake(value);
    notifyListeners();
  }

  Future<void> setHighContrast(bool value) async {
    _highContrast = value;
    await _save.saveHighContrast(value);
    notifyListeners();
  }

  Future<void> setLargeBullets(bool value) async {
    _largeBullets = value;
    await _save.saveLargeBullets(value);
    notifyListeners();
  }

  /// Loads everything from disk. Safe to call before the first frame.
  void load() {
    _difficulty = _save.loadDifficulty();
    for (final setting in Difficulty.values) {
      _highest[setting] = _save
          .loadHighestLevel(setting)
          .clamp(1, Tuning.totalLevels);
      _starsAt[setting] = _save.loadStars(setting);
    }
    // A save written before hard existed can leave the player pointed at a
    // setting they have not earned yet.
    if (!isAvailable(_difficulty)) {
      _difficulty = DifficultyTuning.starting;
    }
    _coins = _save.loadCoins();
    _haptics = _save.loadHaptics();
    _reduceShake = _save.loadReduceShake();
    _highContrast = _save.loadHighContrast();
    _largeBullets = _save.loadLargeBullets();
    _upgradeTiers = _save.loadUpgrades();
    _loadShips();
    _endlessBest = _save.loadEndlessBest();
    notifyListeners();
  }

  bool isUnlocked(int level) => level <= highestLevelUnlocked;

  int tierOf(UpgradeId id) => _upgradeTiers[id.name] ?? 0;

  /// Cost of the next tier, or null when the upgrade is maxed.
  int? costOf(UpgradeId id) {
    final tier = tierOf(id);
    if (tier >= Tuning.upgradeMaxTier) {
      return null;
    }
    return Tuning.upgradeCost(tier);
  }

  bool canAfford(UpgradeId id) {
    final cost = costOf(id);
    return cost != null && _coins >= cost;
  }

  /// Buys one tier of an upgrade. Returns false when it is maxed or the player
  /// cannot afford it.
  bool buyUpgrade(UpgradeId id) {
    final cost = costOf(id);
    if (cost == null || _coins < cost) {
      return false;
    }
    _coins -= cost;
    _upgradeTiers[id.name] = tierOf(id) + 1;
    _save.saveCoins(_coins);
    _save.saveUpgrades(_upgradeTiers);
    notifyListeners();
    return true;
  }

  /// Stars earned on a level at the current setting, 0 to 3.
  int starsFor(int level) {
    final stars = starsData;
    final index = level - 1;
    if (index < 0 || index >= stars.length) {
      return 0;
    }
    final digit = int.tryParse(stars[index]) ?? 0;
    return digit.clamp(0, Tuning.starsPerLevel);
  }

  int get totalStars {
    final stars = starsData;
    var total = 0;
    for (var i = 0; i < stars.length; i++) {
      total += int.tryParse(stars[i]) ?? 0;
    }
    return total;
  }

  /// Records a finished level. Stars only ever go up, and the next level
  /// unlocks straight away.
  Future<void> completeLevel({
    required int level,
    required int stars,
    required int coinsEarned,
  }) async {
    final clamped = stars.clamp(0, Tuning.starsPerLevel);
    if (clamped > starsFor(level)) {
      _starsAt[_difficulty] = _writeStar(level, clamped);
      await _save.saveStars(_difficulty, starsData);
    }
    if (level + 1 > highestLevelUnlocked && level < Tuning.totalLevels) {
      _highest[_difficulty] = level + 1;
      await _save.saveHighestLevel(_difficulty, level + 1);
    }
    if (coinsEarned > 0) {
      _coins += coinsEarned;
      await _save.saveCoins(_coins);
    }
    notifyListeners();
  }

  Future<void> addCoins(int amount) async {
    if (amount <= 0) {
      return;
    }
    _coins += amount;
    await _save.saveCoins(_coins);
    notifyListeners();
  }

  Future<void> setHaptics(bool enabled) async {
    _haptics = enabled;
    await _save.saveHaptics(enabled);
    notifyListeners();
  }

  /// Wipes progress. Audio settings survive, since they are not progress.
  Future<void> resetProgress() async {
    for (final difficulty in Difficulty.values) {
      _highest[difficulty] = 1;
      _starsAt[difficulty] = '';
    }
    _difficulty = DifficultyTuning.starting;
    _coins = 0;
    _upgradeTiers = <String, int>{};
    _ship = ShipCatalog.starter;
    _owned = {ShipCatalog.starter};
    _endlessBest = 0;
    await _save.clearProgress();
    notifyListeners();
  }

  // The hangar. Hulls are bought once and then chosen freely.

  ShipId _ship = ShipCatalog.starter;
  Set<ShipId> _owned = {ShipCatalog.starter};
  int _endlessBest = 0;

  ShipId get shipId => _ship;
  ShipDef get ship => ShipCatalog.of(_ship);
  int get endlessBest => _endlessBest;

  bool owns(ShipId id) => _owned.contains(id);

  void _loadShips() {
    _owned = {ShipCatalog.starter};
    for (final key in _save.loadShipsOwned()) {
      final id = ShipCatalog.byKey(key);
      if (id != null) {
        _owned.add(id);
      }
    }
    final chosen = ShipCatalog.byKey(_save.loadShip());
    // A hull the player no longer owns, or one this build does not know about,
    // falls back to the starter rather than leaving them with nothing to fly.
    _ship = chosen != null && _owned.contains(chosen)
        ? chosen
        : ShipCatalog.starter;
  }

  Future<bool> buyShip(ShipId id) async {
    final def = ShipCatalog.of(id);
    if (_owned.contains(id) || _coins < def.cost) {
      return false;
    }
    _coins -= def.cost;
    _owned.add(id);
    await _save.saveCoins(_coins);
    await _save.saveShipsOwned(_owned.map((s) => s.name).toList());
    notifyListeners();
    return true;
  }

  Future<void> selectShip(ShipId id) async {
    if (!_owned.contains(id)) {
      return;
    }
    _ship = id;
    await _save.saveShip(id.name);
    notifyListeners();
  }

  /// Records an endless run. Only a better one is written.
  Future<void> recordEndless(int score) async {
    if (score <= _endlessBest) {
      return;
    }
    _endlessBest = score;
    await _save.saveEndlessBest(score);
    notifyListeners();
  }

  // Derived combat stats. The hull the player chose multiplies each of them,
  // which is what makes choosing one a decision rather than a skin.

  double get fireInterval {
    final tier = tierOf(UpgradeId.fireRate);
    return Tuning.playerFireInterval /
        (1 + Tuning.fireRateUpgradeStep * tier) /
        ship.fireRate;
  }

  double get bulletDamage {
    final tier = tierOf(UpgradeId.damage);
    return Tuning.playerBulletDamage *
        (1 + Tuning.damageUpgradeStep * tier) *
        ship.damage;
  }

  /// How quickly the hull answers the finger.
  double get followLerp =>
      (Tuning.playerFollowLerp * ship.speed).clamp(0.05, 0.6);

  /// Streams of fire before any power-up is applied.
  int get bulletStreams {
    final tier = tierOf(UpgradeId.bulletCount);
    return 1 + (tier + 1) ~/ 2;
  }

  int get lives {
    final tier = tierOf(UpgradeId.hitPoints);
    final base =
        Tuning.playerLives + (tier * Tuning.hitPointsUpgradeStep).floor();
    // A hull may give a life or take one, and the setting may do the same, but
    // between them they can never take the last one.
    return (base + ship.livesBonus + DifficultyTuning.livesBonus(_difficulty))
        .clamp(1, 99);
  }

  double get magnetRadius {
    final tier = tierOf(UpgradeId.magnetRadius);
    return Tuning.playerMagnetRadius * (1 + Tuning.magnetUpgradeStep * tier);
  }

  double get powerUpDuration {
    final tier = tierOf(UpgradeId.powerUpDuration);
    return Tuning.powerUpDuration * (1 + Tuning.powerUpDurationStep * tier);
  }

  // Secondary weapons. One upgrade drives all of them, so the ordnance rack
  // improves as a whole rather than asking the player to level three things.

  double get missileInterval {
    final tier = tierOf(UpgradeId.ordnance);
    return Tuning.missileInterval - Tuning.missileIntervalStep * tier;
  }

  double get missileDamage {
    final tier = tierOf(UpgradeId.ordnance);
    return Tuning.missileDamage * (1 + Tuning.missileDamageStep * tier);
  }

  /// Missiles in one salvo. A second rail comes online partway up the tiers.
  int get missileSalvo {
    final tier = tierOf(UpgradeId.ordnance);
    return tier >= Tuning.missileSalvoSecondTier
        ? Tuning.missileSalvoBase + 1
        : Tuning.missileSalvoBase;
  }

  double get railInterval {
    final tier = tierOf(UpgradeId.ordnance);
    return Tuning.railInterval - Tuning.railIntervalStep * tier;
  }

  double get flakInterval {
    final tier = tierOf(UpgradeId.ordnance);
    return Tuning.flakInterval - Tuning.flakIntervalStep * tier;
  }

  double get flakDamage {
    final tier = tierOf(UpgradeId.ordnance);
    return Tuning.flakDamage * (1 + Tuning.ordnanceDamageStep * tier);
  }

  double get podInterval {
    final tier = tierOf(UpgradeId.ordnance);
    return Tuning.podInterval - Tuning.podIntervalStep * tier;
  }

  double get podDamage {
    final tier = tierOf(UpgradeId.ordnance);
    return Tuning.podDamage * (1 + Tuning.ordnanceDamageStep * tier);
  }

  double get arcInterval {
    final tier = tierOf(UpgradeId.ordnance);
    return Tuning.arcInterval - Tuning.arcIntervalStep * tier;
  }

  double get arcDamage {
    final tier = tierOf(UpgradeId.ordnance);
    return Tuning.arcDamage * (1 + Tuning.ordnanceDamageStep * tier);
  }

  /// How many things one coil discharge reaches. The coil widens partway up
  /// the tiers rather than simply hitting harder.
  int get arcTargets {
    final tier = tierOf(UpgradeId.ordnance);
    return tier >= Tuning.arcTargetsSecondTier
        ? Tuning.arcTargetsWide
        : Tuning.arcTargetsBase;
  }

  String _writeStar(int level, int stars) {
    final current = starsData;
    final buffer = StringBuffer();
    final index = level - 1;
    final length = index + 1 > current.length ? index + 1 : current.length;
    for (var i = 0; i < length; i++) {
      if (i == index) {
        buffer.write(stars);
      } else if (i < current.length) {
        buffer.write(current[i]);
      } else {
        buffer.write('0');
      }
    }
    return buffer.toString();
  }
}
