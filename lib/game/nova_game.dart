import 'dart:math';

import 'package:flame/components.dart' hide Vector3;
import 'package:flame/game.dart' hide Vector3;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../audio/audio_controller.dart';
import '../audio/sfx.dart';
import '../levels/difficulty_curve.dart';
import '../levels/level_generator.dart';
import '../levels/level_spec.dart';
import '../state/player_progress.dart';
import '../theme/palette.dart';
import 'components/boss.dart';
import 'components/bullet.dart';
import 'components/coin.dart';
import 'components/enemy_ship.dart';
import 'components/freighter.dart';
import 'components/missile.dart';
import 'components/obstacle.dart';
import 'components/player_ship.dart';
import 'components/power_up.dart';
import 'components/warp_gate.dart';
import 'effects/camera_shake.dart';
import 'render3d/camera3d.dart';
import 'render3d/scene3d.dart';
import 'systems/collision_rules.dart';
import 'systems/level_runner.dart';
import 'world/parallax_bg.dart';
import 'world/touch_area.dart';

/// What the game is doing right now.
enum GameStatus { loading, playing, paused, complete, failed }

/// Wave progress for the heads up display.
class WaveProgress {
  const WaveProgress(this.current, this.total);

  final int current;
  final int total;
}

/// The world holds every gameplay component.
///
/// It carries the time scale so the killing blow on a boss can slow the action
/// down without slowing the heads up display or the menus.
class NovaWorld extends World with HasTimeScale {}

/// The root of the game.
///
/// It owns the level being played, the run state such as lives and score, and
/// the notifiers the Flutter overlays read. Gameplay lives in components below
/// it; every button and label is a Flutter widget outside it.
class NovaGame extends FlameGame<NovaWorld> with HasCollisionDetection {
  NovaGame({
    required this.audio,
    required this.progress,
    required this.levelNumber,
    this.onQuit,
    this.endless = false,
  }) : super(
         world: NovaWorld(),
         camera: CameraComponent.withFixedResolution(
           width: Metrics.worldWidth,
           height: Metrics.worldHeight,
         ),
       );

  static const String hudOverlay = 'hud';
  static const String pauseOverlay = 'pause';
  static const String gameOverOverlay = 'gameOver';
  static const String levelCompleteOverlay = 'levelComplete';

  final AudioController audio;
  final PlayerProgress progress;

  /// Called when the player leaves the level from a sheet or the pause menu.
  final VoidCallback? onQuit;

  /// True for an endless run: levels roll into each other, nothing is saved
  /// until the run ends, and it ends when the lives do.
  final bool endless;

  /// Score banked across the levels of an endless run so far.
  int endlessScore = 0;

  int levelNumber;
  late LevelSpec spec;
  late PlayerShip player;
  late LevelRunner runner;
  late CameraShake shake;

  /// The lens the world is seen through.
  late Camera3D camera3d;

  /// Paints everything in depth order.
  late Scene3D scene;

  /// Pool and cap for every bullet in the air.
  final BulletPool bullets = BulletPool();

  /// Live enemies, walked by the collision pass and by the level runner.
  final List<EnemyShip> enemies = [];

  /// Live weak points on the boss.
  final List<BossPod> bossPods = [];

  /// Rocks currently drifting down the lane.
  final List<Obstacle> obstacles = [];

  /// Missiles in the air, so the collision pass and the seeker can find them.
  final List<Missile> missiles = [];

  /// The boss, while one is in the fight.
  Boss? boss;

  /// The freighter, on an escort level.
  Freighter? freighter;

  /// The gate, on a gate level.
  WarpGate? gate;
  late Random rng;

  GameStatus status = GameStatus.loading;

  final ValueNotifier<int> livesNotifier = ValueNotifier(Tuning.playerLives);
  final ValueNotifier<int> scoreNotifier = ValueNotifier(0);
  final ValueNotifier<int> coinsNotifier = ValueNotifier(0);
  final ValueNotifier<int> levelNotifier = ValueNotifier(1);
  final ValueNotifier<WaveProgress> waveNotifier = ValueNotifier(
    const WaveProgress(0, 1),
  );

  /// Boss health as a fraction, or a negative value when there is no boss.
  final ValueNotifier<double> bossHealthNotifier = ValueNotifier(-1);
  final ValueNotifier<String> bossNameNotifier = ValueNotifier('');

  /// Freighter health on an escort level, or a negative value when there is
  /// no freighter.
  final ValueNotifier<double> escortNotifier = ValueNotifier(-1);

  /// Seconds left on a survival level, or a negative value otherwise.
  final ValueNotifier<double> survivalNotifier = ValueNotifier(-1);

  /// What this level asks of the player, shown where the wave count goes.
  final ValueNotifier<String> objectiveNotifier = ValueNotifier('');

  /// The weapon fitted on this level, shown once and then faded out.
  final ValueNotifier<String> armamentNotifier = ValueNotifier('');

  /// The twist on the current level, shown under the level number.
  final ValueNotifier<String> modifierNotifier = ValueNotifier('');
  final ValueNotifier<List<PowerUpType>> powerUpsNotifier = ValueNotifier(
    const [],
  );

  int lives = Tuning.playerLives;
  int score = 0;
  int coinsCollected = 0;
  int coinsSpawned = 0;
  bool lostALife = false;

  double _slowMotionTimer = 0;
  double _hitStopTimer = 0;

  /// How far into the run home the level is, from 0 to 1.
  ///
  /// The star field and the ship both read this, which is what turns the end
  /// of a level into a warp out rather than a stop.
  double warpFactor = 0;

  /// True while the slow gem is running, which halves enemy bullet speed.
  bool get isSlowActive =>
      player.isMounted && player.hasPowerUp(PowerUpType.slow);

  /// True while the freeze gem is running.
  ///
  /// Everything on the enemy side stops where it stands: no movement, no
  /// firing, and shots already in the air hang there.
  bool get isFrozen =>
      player.isMounted && player.hasPowerUp(PowerUpType.freeze);

  @override
  Color backgroundColor() => Palette.spaceDeep;

  @override
  Future<void> onLoad() async {
    camera.viewfinder
      ..anchor = Anchor.topLeft
      ..position = Vector2.zero();
    shake = CameraShake(camera);
    shake.reduced = progress.reduceShake;
    camera3d = Camera3D(
      viewportWidth: Metrics.worldWidth,
      viewportHeight: Metrics.worldHeight,
    );
    await add(shake);
    await startLevel(levelNumber);
  }

  /// Builds and starts a level. Retrying calls this again, which is why retry
  /// is instant: nothing is torn down except the world children.
  Future<void> startLevel(int number, {bool carryOver = false}) async {
    levelNumber = number.clamp(1, Tuning.totalLevels);
    spec = LevelGenerator.generate(levelNumber);
    rng = Random(levelNumber * LevelGenerator.seedMultiplier);

    bullets.clear();
    enemies.clear();
    obstacles.clear();
    missiles.clear();
    freighter = null;
    gate = null;
    bossPods.clear();
    boss = null;
    world.removeAll(world.children.toList());
    world.timeScale = 1;
    _slowMotionTimer = 0;
    _hitStopTimer = 0;
    warpFactor = 0;
    shake.reduced = progress.reduceShake;

    // An endless run keeps the lives it has left. Handing back a full three
    // at every level would make the run trivial and the score meaningless.
    lives = carryOver ? lives : progress.lives;
    score = 0;
    coinsCollected = 0;
    coinsSpawned = 0;
    lostALife = false;
    status = GameStatus.playing;

    livesNotifier.value = lives;
    scoreNotifier.value = 0;
    coinsNotifier.value = 0;
    levelNotifier.value = levelNumber;
    modifierNotifier.value = spec.modifier.label;
    bossHealthNotifier.value = -1;
    bossNameNotifier.value = '';
    escortNotifier.value = -1;
    survivalNotifier.value = spec.kind == LevelKind.survival
        ? Tuning.survivalDuration
        : -1;
    objectiveNotifier.value = spec.objective;
    armamentNotifier.value = Tuning.armamentAt(levelNumber);
    powerUpsNotifier.value = const [];
    waveNotifier.value = WaveProgress(0, spec.waves.length);

    player = PlayerShip();
    runner = LevelRunner(spec);
    scene = Scene3D(camera: camera3d);

    await world.addAll([
      scene,
      ParallaxBackground(),
      TouchArea(),
      player,
      runner,
      CollisionSystem(),
    ]);

    overlays.remove(pauseOverlay);
    overlays.remove(gameOverOverlay);
    overlays.remove(levelCompleteOverlay);
    overlays.add(hudOverlay);

    await audio.playMusic(spec.musicTrack);
    resumeEngine();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // A freeze always wins over the slow motion under it, and the slow motion
    // picks up again from wherever it had got to once the freeze lets go.
    if (_hitStopTimer > 0) {
      _hitStopTimer -= dt;
      world.timeScale = Metrics.hitStopScale;
      if (_hitStopTimer > 0) {
        return;
      }
      world.timeScale = 1;
    }

    if (_slowMotionTimer > 0) {
      _slowMotionTimer -= dt;
      if (_slowMotionTimer <= 0) {
        world.timeScale = 1;
      } else {
        // Ease back out of the slow motion rather than snapping.
        final t = 1 - (_slowMotionTimer / Metrics.slowMotionDuration);
        world.timeScale =
            Metrics.slowMotionScale + (1 - Metrics.slowMotionScale) * t * t;
      }
    }
  }

  /// Drops the time scale for the killing blow on a boss.
  void slowMotion() {
    _slowMotionTimer = Metrics.slowMotionDuration;
    world.timeScale = Metrics.slowMotionScale;
  }

  /// Freezes the world for a fraction of a second on an impact.
  ///
  /// This is what makes a hit feel like it landed. A longer freeze already
  /// running is never cut short by a shorter one.
  void hitStop(double seconds) {
    if (seconds > _hitStopTimer) {
      _hitStopTimer = seconds;
    }
  }

  void addScore(int points) {
    score += points;
    scoreNotifier.value = score;
  }

  /// Called by a coin when it reaches the ship.
  void collectCoin() {
    coinsCollected++;
    coinsNotifier.value = coinsCollected;
    audio.play(Sfx.coinCollect);
  }

  /// Drops a coin where something broke apart, some of the time.
  void dropCoin(Vector3 position, {required double chance}) {
    if (rng.nextDouble() >= chance) {
      return;
    }
    registerCoinSpawn();
    world.add(CoinPickup(spawn: position.clone()));
  }

  /// Drops a coin during the victory lap.
  ///
  /// These are a reward, not part of the level, so they are deliberately not
  /// counted toward the collect every coin star. Missing one during the run
  /// home must never cost the player a star they had already earned.
  void dropBonusCoin(Vector3 position) {
    world.add(CoinPickup(spawn: position.clone()));
  }

  /// Called by the spawner every time a coin is dropped, so the third star can
  /// be judged against how many were available.
  void registerCoinSpawn() {
    coinsSpawned++;
  }

  /// Drops a coin, and sometimes a gem, where something died.
  void dropLoot(Vector3 position, {required bool guaranteedPowerUp}) {
    if (guaranteedPowerUp || rng.nextDouble() < Tuning.powerUpDropChance / 4) {
      final type = PowerUpType.values[rng.nextInt(PowerUpType.values.length)];
      world.add(PowerUp(type: type, spawn: position.clone()));
    }
    if (rng.nextDouble() < Tuning.coinDropChance) {
      registerCoinSpawn();
      world.add(CoinPickup(spawn: position.clone()));
    }
  }

  /// Called when the ship is hit and has no shield left.
  void onPlayerHit() {
    if (status != GameStatus.playing) {
      return;
    }
    lives--;
    lostALife = true;
    livesNotifier.value = lives;
    audio.play(lives > 0 ? Sfx.playerHit : Sfx.playerExplode);
    shake.shake(Metrics.shakeAmplitudeLarge, Metrics.shakeDurationLarge);
    vibrate(HapticsStrength.heavy);
    if (lives <= 0) {
      failLevel();
    }
  }

  /// Shows the level complete sheet and writes progress.
  ///
  /// In endless mode there is no sheet and no progress written. The run rolls
  /// straight into the next level with the score and the lives carried over,
  /// and only ends when the lives do.
  Future<void> completeLevel() async {
    if (status != GameStatus.playing) {
      return;
    }
    if (endless) {
      audio.play(Sfx.levelComplete);
      endlessScore += spec.coinReward + coinsCollected + score;
      await startLevel(levelNumber + 1, carryOver: true);
      return;
    }
    status = GameStatus.complete;
    audio.play(Sfx.levelComplete);
    final earned = spec.coinReward + coinsCollected;
    await progress.completeLevel(
      level: levelNumber,
      stars: earnedStars,
      coinsEarned: earned,
    );
    overlays.add(levelCompleteOverlay);
    pauseEngine();
  }

  /// Shows the game over sheet. Retry from there restarts immediately.
  void failLevel() {
    if (status == GameStatus.failed) {
      return;
    }
    status = GameStatus.failed;
    audio.play(Sfx.levelFailed);
    if (endless) {
      // The whole run is over. Bank the score and the coins it earned, since
      // an endless run that pays nothing is one nobody plays twice.
      final total = endlessScore + score;
      progress.recordEndless(total);
      progress.addCoins(coinsCollected);
    }
    overlays.add(gameOverOverlay);
    pauseEngine();
  }

  /// The score to show when a run ends: the level in a campaign run, the whole
  /// run in an endless one.
  int get runScore => endless ? endlessScore + score : score;

  /// Stars for this run: one for finishing, one for losing no life, one for
  /// collecting every coin the level dropped.
  int get earnedStars {
    var stars = 1;
    if (!lostALife) {
      stars++;
    }
    if (coinsSpawned == 0 || coinsCollected >= coinsSpawned) {
      stars++;
    }
    return stars;
  }

  /// Coins banked by finishing, shown on the level complete sheet.
  int get coinReward => spec.coinReward + coinsCollected;

  void pauseGame() {
    if (status != GameStatus.playing) {
      return;
    }
    status = GameStatus.paused;
    overlays.add(pauseOverlay);
    pauseEngine();
  }

  void resumeGame() {
    if (status != GameStatus.paused) {
      return;
    }
    status = GameStatus.playing;
    overlays.remove(pauseOverlay);
    resumeEngine();
  }

  /// Restarts the current level with no wait and no gate, because friction
  /// here is what makes players quit.
  Future<void> retry() async {
    await startLevel(levelNumber);
  }

  /// Moves on to the next level, or back out when the last one is done.
  Future<void> nextLevel() async {
    if (levelNumber >= Tuning.totalLevels) {
      onQuit?.call();
      return;
    }
    await startLevel(levelNumber + 1);
  }

  /// Fires a haptic pulse when the player has haptics switched on.
  void vibrate(HapticsStrength strength) {
    if (!progress.hapticsEnabled) {
      return;
    }
    switch (strength) {
      case HapticsStrength.light:
        HapticFeedback.lightImpact();
      case HapticsStrength.medium:
        HapticFeedback.mediumImpact();
      case HapticsStrength.heavy:
        HapticFeedback.heavyImpact();
    }
  }

  /// True when the ship is on its last life, which lights the screen edge.
  bool get onLastLife => lives == 1 && status == GameStatus.playing;

  @override
  void onRemove() {
    livesNotifier.dispose();
    scoreNotifier.dispose();
    coinsNotifier.dispose();
    levelNotifier.dispose();
    waveNotifier.dispose();
    bossHealthNotifier.dispose();
    bossNameNotifier.dispose();
    modifierNotifier.dispose();
    powerUpsNotifier.dispose();
    armamentNotifier.dispose();
    super.onRemove();
  }
}

/// Haptic pulse strengths, so components never talk to the platform directly.
enum HapticsStrength { light, medium, heavy }
