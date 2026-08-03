import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/audio/audio_settings.dart';
import 'package:novastrike/levels/difficulty_curve.dart';
import 'package:novastrike/state/player_progress.dart';
import 'package:novastrike/state/save_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('SaveService', () {
    test('audio settings survive a restart', () async {
      final first = SaveService();
      await first.init();
      await first.saveAudioSettings(
        AudioSettings(master: 0.31, music: 0.42, sfx: 0.53, muted: true),
      );

      final second = SaveService();
      await second.init();
      final loaded = second.loadAudioSettings();

      expect(loaded.master, closeTo(0.31, 0.0001));
      expect(loaded.music, closeTo(0.42, 0.0001));
      expect(loaded.sfx, closeTo(0.53, 0.0001));
      expect(loaded.muted, isTrue);
    });

    test('upgrades encode and decode without a parser', () {
      const upgrades = {'fireRate': 2, 'damage': 5};
      final encoded = SaveService.encodeUpgrades(upgrades);
      expect(SaveService.decodeUpgrades(encoded), upgrades);
      expect(SaveService.decodeUpgrades(null), isEmpty);
      expect(SaveService.decodeUpgrades('rubbish'), isEmpty);
    });

    test('works with no plugin behind it', () {
      final service = SaveService();
      expect(service.isReady, isFalse);
      expect(service.loadHighestLevel(), 1);
      expect(service.loadCoins(), 0);
      expect(service.loadAudioSettings(), AudioSettings());
    });
  });

  group('PlayerProgress', () {
    late SaveService save;
    late PlayerProgress progress;

    setUp(() async {
      save = SaveService();
      await save.init();
      progress = PlayerProgress(save)..load();
    });

    test('starts at level one with nothing earned', () {
      expect(progress.highestLevelUnlocked, 1);
      expect(progress.coins, 0);
      expect(progress.totalStars, 0);
      expect(progress.isUnlocked(1), isTrue);
      expect(progress.isUnlocked(2), isFalse);
    });

    test(
      'finishing a level unlocks the next one and banks the coins',
      () async {
        await progress.completeLevel(level: 1, stars: 2, coinsEarned: 30);

        expect(progress.highestLevelUnlocked, 2);
        expect(progress.coins, 30);
        expect(progress.starsFor(1), 2);
        expect(progress.starsFor(2), 0);
      },
    );

    test('stars only ever go up', () async {
      await progress.completeLevel(level: 1, stars: 3, coinsEarned: 0);
      await progress.completeLevel(level: 1, stars: 1, coinsEarned: 0);
      expect(progress.starsFor(1), 3);
    });

    test('progress survives a restart', () async {
      await progress.completeLevel(level: 1, stars: 3, coinsEarned: 500);
      progress.buyUpgrade(UpgradeId.fireRate);

      final reloaded = PlayerProgress(save)..load();
      expect(reloaded.highestLevelUnlocked, 2);
      expect(reloaded.starsFor(1), 3);
      expect(reloaded.tierOf(UpgradeId.fireRate), 1);
      expect(reloaded.coins, 500 - Tuning.upgradeCost(0));
    });

    test('upgrades change the ship and stop at the last tier', () {
      final baseInterval = progress.fireInterval;
      final baseDamage = progress.bulletDamage;
      final baseStreams = progress.bulletStreams;

      progress.addCoins(1000000);
      for (var i = 0; i < Tuning.upgradeMaxTier; i++) {
        expect(progress.buyUpgrade(UpgradeId.fireRate), isTrue);
        expect(progress.buyUpgrade(UpgradeId.damage), isTrue);
        expect(progress.buyUpgrade(UpgradeId.bulletCount), isTrue);
        expect(progress.buyUpgrade(UpgradeId.hitPoints), isTrue);
      }

      expect(progress.buyUpgrade(UpgradeId.fireRate), isFalse);
      expect(progress.costOf(UpgradeId.fireRate), isNull);
      expect(progress.fireInterval, lessThan(baseInterval));
      expect(progress.bulletDamage, greaterThan(baseDamage));
      expect(progress.bulletStreams, greaterThan(baseStreams));
      expect(progress.lives, greaterThan(Tuning.playerLives));
    });

    test('an upgrade cannot be bought without the coins', () {
      expect(progress.canAfford(UpgradeId.damage), isFalse);
      expect(progress.buyUpgrade(UpgradeId.damage), isFalse);
      expect(progress.tierOf(UpgradeId.damage), 0);
    });

    test('reset clears progress but keeps audio settings', () async {
      await save.saveAudioSettings(AudioSettings(master: 0.25));
      await progress.completeLevel(level: 1, stars: 3, coinsEarned: 100);

      await progress.resetProgress();

      expect(progress.highestLevelUnlocked, 1);
      expect(progress.coins, 0);
      expect(progress.totalStars, 0);
      expect(save.loadAudioSettings().master, closeTo(0.25, 0.0001));
    });
  });
  group('save versioning', () {
    test('a fresh install is stamped with the current version', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final save = SaveService();
      await save.init();

      expect(save.version, SaveService.currentVersion);
      expect(save.fromFuture, isFalse);
    });

    test('a save from before versioning is brought forward intact', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SaveService.keyHighestLevel: 42,
        SaveService.keyCoins: 800,
      });
      final save = SaveService();
      await save.init();

      expect(save.version, SaveService.currentVersion);
      expect(save.loadHighestLevel(), 42);
      expect(save.loadCoins(), 800);
    });

    test('a save from a newer build is read but not trusted', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SaveService.keyVersion: SaveService.currentVersion + 5,
        SaveService.keyCoins: 1234,
      });
      final save = SaveService();
      await save.init();

      expect(save.fromFuture, isTrue);
      expect(
        save.loadCoins(),
        1234,
        reason: 'progress should still load, just not be written over',
      );
    });

    test('settings this build does not know about fall back safely', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final save = SaveService();
      await save.init();

      expect(save.loadReduceShake(), isFalse);
      expect(save.loadHighContrast(), isFalse);
      expect(save.loadLargeBullets(), isFalse);
      expect(save.loadShip(), '');
      expect(save.loadShipsOwned(), isEmpty);
      expect(save.loadEndlessBest(), 0);
    });
  });
}
