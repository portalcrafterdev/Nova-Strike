/// The three volume channels plus the quick mute flag.
///
/// This class is pure data with no plugin calls, so the persistence and
/// clamping rules can be unit tested.
class AudioSettings {
  AudioSettings({
    double master = defaultMaster,
    double music = defaultMusic,
    double sfx = defaultSfx,
    this.muted = false,
  }) : master = _clamp(master),
       music = _clamp(music),
       sfx = _clamp(sfx);

  static const double defaultMaster = 0.8;
  static const double defaultMusic = 0.6;
  static const double defaultSfx = 1.0;

  final double master;
  final double music;
  final double sfx;

  /// Set by the quick mute button. It never overwrites the slider values, so
  /// unmuting restores the levels the player chose.
  final bool muted;

  /// Volume a music player should run at.
  double get effectiveMusic => muted ? 0 : master * music;

  /// Volume a sound effect should play at.
  double get effectiveSfx => muted ? 0 : master * sfx;

  AudioSettings copyWith({
    double? master,
    double? music,
    double? sfx,
    bool? muted,
  }) {
    return AudioSettings(
      master: master ?? this.master,
      music: music ?? this.music,
      sfx: sfx ?? this.sfx,
      muted: muted ?? this.muted,
    );
  }

  Map<String, Object> toMap() {
    return {'master': master, 'music': music, 'sfx': sfx, 'muted': muted};
  }

  static AudioSettings fromMap(Map<String, Object?> map) {
    return AudioSettings(
      master: _readDouble(map['master'], defaultMaster),
      music: _readDouble(map['music'], defaultMusic),
      sfx: _readDouble(map['sfx'], defaultSfx),
      muted: map['muted'] == true,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AudioSettings &&
        other.master == master &&
        other.music == music &&
        other.sfx == sfx &&
        other.muted == muted;
  }

  @override
  int get hashCode => Object.hash(master, music, sfx, muted);

  @override
  String toString() {
    return 'AudioSettings(master: $master, music: $music, sfx: $sfx, '
        'muted: $muted)';
  }

  static double _clamp(double value) {
    if (value.isNaN) {
      return 0;
    }
    return value.clamp(0.0, 1.0);
  }

  static double _readDouble(Object? value, double fallback) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    return fallback;
  }
}
