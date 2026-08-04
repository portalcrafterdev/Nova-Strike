/// Every sound effect in the game.
///
/// The file name is derived from the enum name, so adding a sound means adding
/// a case here and dropping the matching file into assets/audio/sfx.
enum Sfx {
  laserFire,
  laserHeavy,
  missileLaunch,
  missileHit,
  railFire,
  flakBurst,
  podFire,
  arcZap,
  enemyHit,
  enemyExplode,
  bossHit,
  bossExplode,
  playerHit,
  playerExplode,
  shieldUp,
  shieldBreak,
  powerUpPickup,
  waveIncoming,
  levelComplete,
  levelFailed,
  buttonTap,
  coinCollect,
  upgradeBuy,
}

/// File naming and mixing rules for each effect.
extension SfxFile on Sfx {
  /// Path relative to the audio cache prefix, which is assets/audio.
  String get path => 'sfx/${_snake()}.wav';

  /// How many copies of this effect may sound at once.
  ///
  /// Every copy is a preloaded player held for the whole session, so the count
  /// is kept to what an effect can actually overlap. One shots that can never
  /// double up get a single player.
  int get maxPlayers {
    switch (this) {
      case Sfx.laserFire:
      case Sfx.enemyHit:
      case Sfx.coinCollect:
      case Sfx.podFire:
        return 4;
      case Sfx.enemyExplode:
      case Sfx.bossHit:
      case Sfx.missileHit:
        return 3;
      case Sfx.playerHit:
      case Sfx.bossExplode:
      case Sfx.powerUpPickup:
      case Sfx.shieldUp:
      case Sfx.shieldBreak:
      case Sfx.waveIncoming:
      case Sfx.buttonTap:
      case Sfx.missileLaunch:
      case Sfx.railFire:
      case Sfx.flakBurst:
      case Sfx.arcZap:
        return 2;
      case Sfx.laserHeavy:
      case Sfx.playerExplode:
      case Sfx.levelComplete:
      case Sfx.levelFailed:
      case Sfx.upgradeBuy:
        return 1;
    }
  }

  String _snake() {
    final buffer = StringBuffer();
    for (final unit in name.codeUnits) {
      final char = String.fromCharCode(unit);
      final lower = char.toLowerCase();
      if (char != lower) {
        buffer.write('_');
      }
      buffer.write(lower);
    }
    return buffer.toString();
  }
}

/// The music tracks. Battle tracks rotate by chapter.
class MusicTracks {
  const MusicTracks._();

  static const String menu = 'menu';
  static const String boss = 'boss';
  static const List<String> all = [
    menu,
    'battle_a',
    'battle_b',
    'battle_c',
    boss,
  ];

  /// Path relative to the audio cache prefix.
  static String path(String track) => 'music/$track.wav';
}
