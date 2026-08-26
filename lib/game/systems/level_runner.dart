import 'dart:math';

import 'package:flame/components.dart' hide Vector3;
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../audio/sfx.dart';
import '../../levels/difficulty_curve.dart';
import '../../levels/level_spec.dart';
import '../../theme/palette.dart';
import '../components/boss.dart';
import '../components/freighter.dart';
import '../components/obstacle.dart';
import '../components/warp_gate.dart';
import '../effects/wave_warning.dart';
import '../nova_game.dart';
import '../world/play_area.dart';
import 'spawner.dart';

/// The stages of the run home after a level is won.
enum Outro { none, bonus, warp, done }

/// Drives the waves of the current level.
///
/// It owns the pacing of a level: when the next wave arrives, when a wave is
/// considered clear, when the boss appears, and when the level is finished. It
/// never spawns anything itself, that is the spawner.
class LevelRunner extends Component with HasGameReference<NovaGame> {
  LevelRunner(this.spec);

  final LevelSpec spec;

  late final Spawner _spawner = Spawner(game, spec);

  final Random _rng = Random(4);

  int _waveIndex = 0;
  int _wavesSent = 0;
  double _levelElapsed = 0;
  double _obstacleTimer = 0;
  int _obstacleShape = 0;
  double _waitTimer = 0;
  double _waveElapsed = 0;
  bool _waveActive = false;
  bool _warned = false;
  bool _escortStarted = false;
  bool _gateOpened = false;
  double _objectiveClock = Tuning.survivalDuration;
  bool _bossSpawned = false;
  bool _bossDefeated = false;
  double _victoryTimer = -1;

  Outro _outro = Outro.none;
  double _outroTimer = 0;
  double _bonusTimer = 0;
  int _bonusIndex = 0;

  /// True once the level is won and the run home has started.
  bool get isOutro => _outro != Outro.none;

  /// Waves already sent, for the heads up display.
  int get waveNumber => _wavesSent;

  /// Seconds of play so far, with the run home excluded.
  double get levelElapsed => _levelElapsed;

  /// Whether the level has run long enough to be allowed to end.
  ///
  /// [RunnerTuning.minLevelDuration] is a floor rather than a target: reaching it
  /// only lifts the block on finishing, it never cuts a level short.
  bool get floorReached => _levelElapsed >= RunnerTuning.minLevelDuration;

  /// The wave to send when the scripted list has run out but the floor has
  /// not been reached.
  ///
  /// The level's own waves are reused as a rotation, so an extended level
  /// still draws only on the families, formations and patterns its chapter
  /// has unlocked. The gem guarantee is stripped: an elite level promises one
  /// power up, not one per lap.
  WaveSpec? get _encoreWave {
    if (spec.waves.isEmpty) {
      return null;
    }
    return spec.waves[_waveIndex % spec.waves.length].copyWith(
      dropsPowerUp: false,
    );
  }

  @override
  Future<void> onLoad() async {
    _waitTimer = spec.waves.isEmpty ? 0 : spec.waves.first.spawnDelay;
  }

  @override
  void update(double dt) {
    if (game.status != GameStatus.playing) {
      return;
    }

    if (_outro != Outro.none) {
      _updateOutro(dt);
      return;
    }

    // The level clock. It stops at the outro on purpose: the run home is a
    // victory lap, not part of the fight, and counting it would let a level
    // reach its floor by playing an animation.
    _levelElapsed += dt;

    _updateObstacles(dt);

    switch (spec.kind) {
      case LevelKind.survival:
        _updateSurvival(dt);
        return;
      case LevelKind.escort:
        _updateEscort(dt);
        return;
      case LevelKind.gate:
        _updateGate(dt);
      case LevelKind.normal:
      case LevelKind.elite:
      case LevelKind.boss:
        break;
    }

    if (_finishing(dt)) {
      return;
    }

    if (_waveActive) {
      _waveElapsed += dt;
      if (_isWaveClear()) {
        _waveActive = false;
        _waitTimer = _nextDelay();
      }
      return;
    }

    _waitTimer -= dt;

    // Warn a beat before the wave lands, so arriving in a formation is
    // something the player can answer rather than something that happens
    // to them.
    if (!_warned &&
        _waveIndex < spec.waves.length &&
        _waitTimer <= Metrics.warningLead) {
      _warned = true;
      game.world.add(WaveWarning(entry: spec.waves[_waveIndex].entry));
    }

    if (_waitTimer > 0) {
      return;
    }

    if (_waveIndex < spec.waves.length) {
      _startWave(spec.waves[_waveIndex]);
      return;
    }

    if (spec.boss != null && !_bossSpawned) {
      // The boss waits behind the escort until there is only its own share of
      // the clock left, so a boss level reaches the floor with build up rather
      // than by keeping the player in the fight longer than the fight wants
      // to last.
      if (_levelElapsed <
              RunnerTuning.minLevelDuration -
                  RunnerTuning.bossFightAllowance &&
          _sendEncore()) {
        return;
      }
      _spawnBoss();
      return;
    }

    if (spec.boss != null) {
      if (!_bossDefeated && _bossGone()) {
        _bossDefeated = true;
        _victoryTimer = RunnerTuning.bossVictoryDelay;
      }
      return;
    }

    // Every scripted wave is done. A level that is over in fifteen seconds
    // does not read as a level, so the lane keeps refilling until the floor is
    // reached. A player who took their time is already past it and sees none
    // of this.
    if (!floorReached && _sendEncore()) {
      return;
    }

    _victoryTimer = RunnerTuning.levelCompleteDelay;
  }

  /// Counts down the beat between winning and the run home.
  ///
  /// Returns true while the level is finishing, so every caller stops there.
  /// This is where the floor is finally enforced: whatever route a level took
  /// to being won, it cannot start its run home until it has been a level for
  /// [RunnerTuning.minLevelDuration]. The wave loops above mean the lane is
  /// normally still busy when that happens, so this backstop only really bites
  /// after a boss dies early, where an explosion and the slow motion are
  /// playing out anyway.
  bool _finishing(double dt) {
    if (_victoryTimer < 0) {
      return false;
    }
    // Held at zero rather than allowed to run negative. A negative timer reads
    // as "not finishing" to the check above, which would drop a level that is
    // waiting out its floor back into the wave logic it has already left.
    _victoryTimer = max(0, _victoryTimer - dt);
    if (_victoryTimer <= 0 && floorReached) {
      _victoryTimer = -1;
      _beginOutro();
    }
    return true;
  }

  /// Sends one more wave from the rotation. False when there is nothing to
  /// send, which keeps a spec with no waves from hanging the level.
  bool _sendEncore() {
    final wave = _encoreWave;
    if (wave == null) {
      return false;
    }
    _startWave(wave);
    return true;
  }

  /// Survival: no wave list, just a clock and a lane that keeps refilling.
  ///
  /// The waves the generator produced are reused as a rotation rather than a
  /// running order, so a survival level still draws on the families and
  /// formations its chapter has unlocked.
  void _updateSurvival(double dt) {
    if (_finishing(dt)) {
      return;
    }

    _objectiveClock -= dt;
    game.survivalNotifier.value = _objectiveClock.clamp(0, double.infinity);
    if (_objectiveClock <= 0) {
      // Anything still in the lane when the clock runs out is left alive. The
      // player held out, which was the whole ask.
      for (final enemy in List.of(game.enemies)) {
        enemy.removeFromParent();
      }
      _victoryTimer = RunnerTuning.levelCompleteDelay;
      return;
    }

    _waitTimer -= dt;
    if (_waitTimer > 0) {
      return;
    }
    _waitTimer = Tuning.survivalWaveInterval;
    if (spec.waves.isNotEmpty) {
      _startWave(spec.waves[_waveIndex % spec.waves.length]);
    }
  }

  /// Escort: the freighter crosses the lane and everything else is in the way.
  void _updateEscort(double dt) {
    if (_finishing(dt)) {
      return;
    }

    final freighter = game.freighter;
    if (freighter == null) {
      // It never arrived, or it did not survive. Either way the escort is
      // over and the run is lost.
      if (_escortStarted) {
        game.failLevel();
        return;
      }
      _escortStarted = true;
      game.world.add(Freighter(maxHp: Tuning.freighterHp(spec.number)));
      return;
    }

    if (freighter.hasArrived) {
      freighter.removeFromParent();
      _victoryTimer = RunnerTuning.levelCompleteDelay;
      return;
    }

    // Reinforcements keep coming for as long as the crossing takes.
    _waitTimer -= dt;
    if (_waitTimer > 0) {
      return;
    }
    _waitTimer = Tuning.survivalWaveInterval;
    if (spec.waves.isNotEmpty) {
      _startWave(spec.waves[_waveIndex % spec.waves.length]);
    }
  }

  /// Gate: clear the waves, then leave through the ring.
  void _updateGate(double dt) {
    if (_gateOpened) {
      return;
    }
    // The ring does not appear until the floor is reached. The wave loop below
    // keeps the lane busy until then, so the ship is not left flying at an
    // empty sky waiting for its way out.
    if (_waveIndex >= spec.waves.length && !_waveActive && floorReached) {
      _gateOpened = true;
      game.world.add(WarpGate());
    }
  }

  /// Called by the collision pass when the ship reaches the gate.
  void onGateReached() {
    if (_outro != Outro.none) {
      return;
    }
    for (final enemy in List.of(game.enemies)) {
      enemy.removeFromParent();
    }
    game.gate?.removeFromParent();
    _beginOutro();
  }

  /// Starts the run home.
  ///
  /// The lane is swept clear first. Nothing is allowed to kill the player
  /// after they have already won the level, and a stray rock arriving during
  /// the victory lap would do exactly that.
  void _beginOutro() {
    _outro = Outro.bonus;
    _outroTimer = RunnerTuning.bonusRunDuration;
    _bonusTimer = 0;
    _bonusIndex = 0;
    game.bullets.clear();
    for (final rock in List.of(game.obstacles)) {
      rock.removeFromParent();
    }
  }

  void _updateOutro(double dt) {
    _outroTimer -= dt;

    switch (_outro) {
      case Outro.none:
        return;

      case Outro.bonus:
        // A stream of coins with nothing shooting back. It pays for the level
        // just played and gives the magnet upgrade a moment to look good.
        _bonusTimer -= dt;
        if (_bonusTimer <= 0) {
          _bonusTimer = RunnerTuning.bonusCoinInterval;
          game.dropBonusCoin(_bonusCoinAt());
          _bonusIndex++;
        }
        if (_outroTimer <= 0) {
          _outro = Outro.warp;
          _outroTimer = RunnerTuning.warpDuration;
          game.audio.play(Sfx.laserHeavy);
        }

      case Outro.warp:
        // Eased in, so the ship leans into the run rather than snapping into
        // it, and the star field stretches with it.
        final t = 1 - (_outroTimer / RunnerTuning.warpDuration).clamp(0.0, 1.0);
        game.warpFactor = t * t;
        if (_outroTimer <= 0) {
          _outro = Outro.done;
          game.warpFactor = 0;
          game.completeLevel();
        }

      case Outro.done:
        return;
    }
  }

  /// Coins weave across the lane so the player has to fly the victory lap
  /// rather than sit still through it.
  Vector3 _bonusCoinAt() {
    return Vector3(
      sin(_bonusIndex * 0.7) * RunnerTuning.bonusCoinSweep,
      cos(_bonusIndex * 0.5) * RunnerTuning.bonusCoinSweep * 0.35,
      PlayArea.spawnDepth * 0.5,
    );
  }

  /// Rocks arrive on their own clock, independent of the waves, so the lane
  /// never goes completely quiet.
  void _updateObstacles(double dt) {
    if (!spec.hasObstacles) {
      return;
    }
    _obstacleTimer -= dt;
    if (_obstacleTimer > 0) {
      return;
    }
    _obstacleTimer = spec.obstacleRate * (0.7 + _rng.nextDouble() * 0.6);
    _obstacleShape++;
    game.world.add(
      Obstacle(
        spawn: Obstacle.spawnPoint(_rng),
        hp: Tuning.obstacleHp(spec.number),
        shape: _obstacleShape,
      ),
    );
  }

  void _startWave(WaveSpec wave) {
    _spawner.spawnWave(wave);
    _waveIndex++;
    _wavesSent++;
    _waveActive = true;
    _waveElapsed = 0;
    _warned = false;
    // The total stays what the level was scripted for. Once a level runs past
    // that, the count exceeds the total and the display drops the total rather
    // than growing it, because a denominator that keeps moving reads as making
    // no progress at all.
    game.waveNotifier.value = WaveProgress(_wavesSent, spec.waves.length);
    game.audio.play(Sfx.waveIncoming);
  }

  /// A wave is clear when nothing is left, or when it has outstayed the
  /// timeout, so one evasive enemy can never stall a level.
  bool _isWaveClear() {
    if (_waveElapsed < RunnerTuning.waveMinDuration) {
      return false;
    }
    if (_waveElapsed > Tuning.waveTimeout) {
      return true;
    }
    return game.enemies.isEmpty;
  }

  double _nextDelay() {
    if (_waveIndex < spec.waves.length) {
      return spec.waves[_waveIndex].spawnDelay;
    }
    if (spec.boss != null) {
      return RunnerTuning.bossArrivalDelay;
    }
    // Still short of the floor, so another wave is coming and it is paced like
    // any other rather than arriving the instant the last one died.
    if (!floorReached && spec.waves.isNotEmpty) {
      return spec.waves[_waveIndex % spec.waves.length].spawnDelay;
    }
    return RunnerTuning.levelCompleteDelay;
  }

  void _spawnBoss() {
    _bossSpawned = true;
    game.world.add(Boss(spec.boss!));
    game.audio.play(Sfx.waveIncoming);
  }

  bool _bossGone() => game.boss == null;
}
