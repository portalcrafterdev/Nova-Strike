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
  int get waveNumber => _waveIndex;

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

    if (_victoryTimer >= 0) {
      _victoryTimer -= dt;
      if (_victoryTimer <= 0) {
        _victoryTimer = -1;
        _beginOutro();
      }
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

    _victoryTimer = RunnerTuning.levelCompleteDelay;
  }

  /// Survival: no wave list, just a clock and a lane that keeps refilling.
  ///
  /// The waves the generator produced are reused as a rotation rather than a
  /// running order, so a survival level still draws on the families and
  /// formations its chapter has unlocked.
  void _updateSurvival(double dt) {
    if (_victoryTimer >= 0) {
      _victoryTimer -= dt;
      if (_victoryTimer <= 0) {
        _victoryTimer = -1;
        _beginOutro();
      }
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
    if (_victoryTimer >= 0) {
      _victoryTimer -= dt;
      if (_victoryTimer <= 0) {
        _victoryTimer = -1;
        _beginOutro();
      }
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
    if (_waveIndex >= spec.waves.length && !_waveActive) {
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
    _waveActive = true;
    _waveElapsed = 0;
    _warned = false;
    game.waveNotifier.value = WaveProgress(_waveIndex, spec.waves.length);
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
    return spec.boss != null
        ? RunnerTuning.bossArrivalDelay
        : RunnerTuning.levelCompleteDelay;
  }

  void _spawnBoss() {
    _bossSpawned = true;
    game.world.add(Boss(spec.boss!));
    game.audio.play(Sfx.waveIncoming);
  }

  bool _bossGone() => game.boss == null;
}
