import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

import '../state/save_service.dart';
import 'audio_settings.dart';
import 'sfx.dart';

/// The single source of truth for sound.
///
/// Nothing else in the codebase talks to FlameAudio or audioplayers. This
/// class owns the three volume channels, the music player, the effect pools,
/// and the rules that stop a bullet hell turning the mix into noise.
class AudioController {
  AudioController(this._save);

  /// Minimum gap between two plays of the same effect.
  static const Duration minGapBetweenSameEffect = Duration(milliseconds: 60);

  /// Volume changes are written to disk at most this often while a slider is
  /// being dragged.
  static const Duration persistDebounce = Duration(milliseconds: 300);

  /// How long music stays quiet after a boss explosion.
  static const Duration duckDuration = Duration(milliseconds: 400);

  /// How far music drops while ducked.
  static const double duckFactor = 0.7;

  /// Fallback used when a preview sound is played from the settings screen.
  static const double previewPitch = 1.0;

  final SaveService _save;

  AudioSettings _settings = AudioSettings();
  final Map<Sfx, _SfxPool> _pools = {};
  final Map<Sfx, DateTime> _lastPlayed = {};
  AudioPlayer? _musicPlayer;
  String? _currentTrack;
  Timer? _persistTimer;
  Timer? _duckTimer;
  bool _ducked = false;
  bool _ready = false;
  bool _musicPausedByApp = false;

  AudioSettings get settings => _settings;
  double get master => _settings.master;
  double get music => _settings.music;
  double get sfx => _settings.sfx;
  bool get muted => _settings.muted;

  /// The track currently loaded, or null when music is stopped.
  String? get currentTrack => _currentTrack;

  /// True once [init] has finished. Calls made before that are ignored rather
  /// than queued, so a slow audio device never blocks the first frame.
  bool get isReady => _ready;

  /// Loads saved settings and preloads every effect.
  ///
  /// Preloading matters: a first play decode stutter during a boss fight is
  /// unacceptable, so the cost is paid on the loading screen instead.
  Future<void> init() async {
    _settings = _save.loadAudioSettings();
    await _applyAudioContext();
    for (final effect in Sfx.values) {
      final pool = _SfxPool(effect);
      _pools[effect] = pool;
      await pool.preload();
    }
    _ready = true;
  }

  /// Starts a music track, or does nothing when that track is already playing.
  Future<void> playMusic(String track) async {
    if (!_ready) {
      // Audio has not been initialised yet, so there is nothing to play on.
      return;
    }
    if (_currentTrack == track && _musicPlayer != null) {
      return;
    }
    _currentTrack = track;
    try {
      final player = _musicPlayer ??= _createMusicPlayer();
      await player.stop();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setSource(AssetSource(MusicTracks.path(track)));
      await player.setVolume(_musicVolume());
      await player.resume();
    } catch (error) {
      // A missing or unplayable track must never take the game down.
      _logAudioFailure('music $track', error);
      _currentTrack = null;
    }
  }

  Future<void> stopMusic() async {
    _currentTrack = null;
    try {
      await _musicPlayer?.stop();
    } catch (error) {
      _logAudioFailure('stop music', error);
    }
  }

  /// Pauses music when the app goes to the background.
  Future<void> pauseMusic() async {
    if (_currentTrack == null) {
      return;
    }
    _musicPausedByApp = true;
    try {
      await _musicPlayer?.pause();
    } catch (error) {
      _logAudioFailure('pause music', error);
    }
  }

  Future<void> resumeMusic() async {
    if (!_musicPausedByApp) {
      return;
    }
    _musicPausedByApp = false;
    try {
      await _musicPlayer?.resume();
    } catch (error) {
      _logAudioFailure('resume music', error);
    }
  }

  /// Plays a sound effect.
  ///
  /// Repeats are throttled two ways: a pool caps how many copies of one effect
  /// can sound at once, and a minimum gap stops the same effect retriggering
  /// on consecutive frames.
  void play(Sfx effect, {double pitch = 1.0}) {
    if (!_ready) {
      return;
    }
    final volume = _settings.effectiveSfx;
    if (volume <= 0) {
      return;
    }
    final now = DateTime.now();
    final last = _lastPlayed[effect];
    if (last != null && now.difference(last) < minGapBetweenSameEffect) {
      return;
    }
    _lastPlayed[effect] = now;
    _pools[effect]?.play(volume: volume, pitch: pitch);
  }

  /// Drops music for a moment so a big explosion has room to land.
  void duckMusic() {
    if (_musicPlayer == null || _currentTrack == null) {
      return;
    }
    _ducked = true;
    _applyMusicVolume();
    _duckTimer?.cancel();
    _duckTimer = Timer(duckDuration, () {
      _ducked = false;
      _applyMusicVolume();
    });
  }

  Future<void> setMaster(double value) =>
      _update(_settings.copyWith(master: value));

  Future<void> setMusic(double value) =>
      _update(_settings.copyWith(music: value));

  Future<void> setSfx(double value) => _update(_settings.copyWith(sfx: value));

  Future<void> setMuted(bool value) =>
      _update(_settings.copyWith(muted: value));

  /// Applies a change immediately, then persists it after the debounce.
  Future<void> _update(AudioSettings next) async {
    final musicChanged = next.effectiveMusic != _settings.effectiveMusic;
    _settings = next;
    if (musicChanged) {
      // Set the volume on the running player rather than restarting, so the
      // track never gaps while a slider moves.
      _applyMusicVolume();
    }
    _schedulePersist();
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(persistDebounce, () {
      _save.saveAudioSettings(_settings);
    });
  }

  /// Writes any pending change straight away. Called when the app is closing
  /// or a settings screen is popped.
  Future<void> flush() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    await _save.saveAudioSettings(_settings);
  }

  double _musicVolume() {
    final base = _settings.effectiveMusic;
    return _ducked ? base * duckFactor : base;
  }

  void _applyMusicVolume() {
    final player = _musicPlayer;
    if (player == null) {
      return;
    }
    player.setVolume(_musicVolume()).catchError((Object error) {
      _logAudioFailure('set music volume', error);
    });
  }

  /// Every player mixes rather than grabbing audio focus.
  ///
  /// Without this each effect would take focus for itself, which ducks the
  /// music a few times a second and interrupts whatever else the phone is
  /// playing.
  Future<void> _applyAudioContext() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(
          focus: AudioContextConfigFocus.mixWithOthers,
        ).build(),
      );
    } catch (error) {
      _logAudioFailure('audio context', error);
    }
  }

  AudioPlayer _createMusicPlayer() {
    final player = AudioPlayer();
    player.audioCache = FlameAudio.audioCache;
    return player;
  }

  void dispose() {
    _persistTimer?.cancel();
    _duckTimer?.cancel();
    _musicPlayer?.dispose();
    for (final pool in _pools.values) {
      pool.dispose();
    }
    _pools.clear();
  }

  static void _logAudioFailure(String what, Object error) {
    if (kDebugMode) {
      debugPrint('Nova Strike audio: $what failed with $error');
    }
  }
}

/// A small ring of players for one effect.
///
/// Capping the ring is what keeps the mix clean: the laser fires several times
/// a second, and without a cap the overlapping copies turn to noise and frame
/// time spikes. Players are handed out round robin, so the copy that gets
/// interrupted is always the oldest one.
class _SfxPool {
  _SfxPool(this.effect);

  final Sfx effect;
  final List<AudioPlayer> _players = [];
  bool _available = true;
  int _next = 0;

  /// Creates the players and decodes the file once, before gameplay starts.
  Future<void> preload() async {
    try {
      for (var i = 0; i < effect.maxPlayers; i++) {
        final player = AudioPlayer();
        player.audioCache = FlameAudio.audioCache;
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setSource(AssetSource(effect.path));
        _players.add(player);
      }
    } catch (error) {
      // The effect file is missing or cannot be decoded. Drop this effect
      // rather than throwing every time something shoots.
      _available = false;
      AudioController._logAudioFailure('preload ${effect.path}', error);
    }
  }

  void play({required double volume, required double pitch}) {
    if (!_available || _players.isEmpty) {
      return;
    }
    final player = _players[_next];
    _next = (_next + 1) % _players.length;
    unawaited(_start(player, volume, pitch));
  }

  Future<void> _start(AudioPlayer player, double volume, double pitch) async {
    try {
      // Stop rather than seek. Low latency playback on Android never sends the
      // seek complete event, so seeking hangs until it times out and the sound
      // is lost. Stopping rewinds the player just as well.
      await player.stop();
      await player.setVolume(volume);
      if (pitch != 1.0) {
        await player.setPlaybackRate(pitch);
      }
      await player.resume();
    } catch (error) {
      AudioController._logAudioFailure('play ${effect.path}', error);
    }
  }

  void dispose() {
    for (final player in _players) {
      player.dispose();
    }
    _players.clear();
  }
}
