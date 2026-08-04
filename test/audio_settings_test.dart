import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/audio/audio_settings.dart';
import 'package:novastrike/audio/sfx.dart';

void main() {
  group('AudioSettings', () {
    test('starts at the designed defaults', () {
      final settings = AudioSettings();
      expect(settings.master, AudioSettings.defaultMaster);
      expect(settings.music, AudioSettings.defaultMusic);
      expect(settings.sfx, AudioSettings.defaultSfx);
      expect(settings.muted, isFalse);
    });

    test('clamps every channel to the slider range', () {
      final settings = AudioSettings(master: 4, music: -2, sfx: double.nan);
      expect(settings.master, 1.0);
      expect(settings.music, 0.0);
      expect(settings.sfx, 0.0);
    });

    test('effective volume is master times the channel', () {
      final settings = AudioSettings(master: 0.5, music: 0.4, sfx: 0.8);
      expect(settings.effectiveMusic, closeTo(0.2, 0.0001));
      expect(settings.effectiveSfx, closeTo(0.4, 0.0001));
    });

    test('muting silences sound without losing the slider values', () {
      final settings = AudioSettings(master: 0.7, music: 0.5, sfx: 0.9);
      final muted = settings.copyWith(muted: true);

      expect(muted.effectiveMusic, 0);
      expect(muted.effectiveSfx, 0);
      expect(muted.master, 0.7);
      expect(muted.music, 0.5);
      expect(muted.sfx, 0.9);

      final unmuted = muted.copyWith(muted: false);
      expect(unmuted.effectiveMusic, closeTo(0.35, 0.0001));
      expect(unmuted, equals(settings));
    });

    test('survives a round trip through a map', () {
      final settings = AudioSettings(
        master: 0.31,
        music: 0.62,
        sfx: 0.93,
        muted: true,
      );
      expect(AudioSettings.fromMap(settings.toMap()), equals(settings));
    });

    test('falls back to defaults when stored values are missing', () {
      final settings = AudioSettings.fromMap(const {});
      expect(settings, equals(AudioSettings()));
    });
  });

  group('Sfx', () {
    test('file paths follow the enum names', () {
      expect(Sfx.laserFire.path, 'sfx/laser_fire.wav');
      expect(Sfx.powerUpPickup.path, 'sfx/power_up_pickup.wav');
      expect(Sfx.buttonTap.path, 'sfx/button_tap.wav');
    });

    test('repeat heavy effects get more players than one shots', () {
      expect(
        Sfx.laserFire.maxPlayers,
        greaterThan(Sfx.levelComplete.maxPlayers),
      );
    });

    test('music paths point at the music folder', () {
      expect(MusicTracks.path('boss'), 'music/boss.wav');
    });
  });
}
