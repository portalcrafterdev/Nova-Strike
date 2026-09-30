import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../ads/ads_controller.dart';
import '../../app.dart';
import '../../audio/sfx.dart';
import '../../game/nova_game.dart';
import '../../theme/palette.dart';
import '../../tutorial/flight_tutorial.dart';
import '../../tutorial/tutorial_controller.dart';
import '../overlays/hud.dart';
import '../overlays/pause_overlay.dart';
import 'game_over_sheet.dart';
import 'level_complete_sheet.dart';

/// Hosts the Flame game and its Flutter overlays.
///
/// The game itself draws only gameplay. Every sheet, button and label on top
/// of it is a widget declared here.
class GameScreen extends StatefulWidget {
  const GameScreen({
    required this.levelNumber,
    this.endless = false,
    super.key,
  });

  final int levelNumber;

  /// True for an endless run, which rolls from level to level without a sheet.
  final bool endless;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  NovaGame? _game;

  final FlightTutorialTargets _targets = FlightTutorialTargets.wholeScreen();
  late final TutorialController _tutorial = TutorialController(
    steps: flightTutorialSteps(_targets, enemy: _enemySpot),
    flag: flightTutorialFlag,
    // Every time level 1 is opened, not once ever. Which level it runs on is
    // what decides who sees it now, so the flag has nothing left to say.
    everyTime: true,
  );

  /// Whether this run is the one that teaches flying.
  bool get _teachesFlight =>
      teachesFlightOn(level: widget.levelNumber, endless: widget.endless);

  /// True once there is a frame to hold. A game paused before it has rendered
  /// anything shows black, because there is nothing to hold.
  bool _teachable = false;

  /// Runs while the game is let off the brake between lessons.
  Timer? _breathe;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_game != null) {
      return;
    }
    final scope = AppScope.of(context);
    _game = NovaGame(
      audio: scope.audio,
      progress: scope.progress,
      levelNumber: widget.levelNumber,
      endless: widget.endless,
      onQuit: _leave,
    )..onSteer = _onSteer;
    // The brake follows the lesson. Dismissing the last step ends the
    // sequence, and without this the game would still be sitting frozen
    // behind a scrim that is no longer there.
    _tutorial.addListener(_syncBrake);
    _armTutorial();
    // Fetch the extra life ad while the player still has a life to lose. A
    // rewarded ad takes seconds to arrive, and asking for it at the moment the
    // ship blows up means the offer is not there when the sheet opens.
    _ads = scope.ads;
    _game!.livesNotifier.addListener(_onLivesChanged);
  }

  AdsController? _ads;

  void _onLivesChanged() {
    if (_game?.livesNotifier.value == 1) {
      _ads?.prepareReward();
    }
  }

  /// Waits for the game to have something on screen before the lesson may
  /// freeze it, then lets the launcher know.
  Future<void> _armTutorial() async {
    final game = _game;
    if (game == null || !_teachesFlight) {
      // Any other level leaves the launcher disabled, so nothing is ever
      // started and the game is never held still waiting for a drag.
      return;
    }
    await game.loaded;
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() => _teachable = true);
      _syncBrake();
    });
  }

  /// Where the nearest enemy is on the glass, or null when there is none.
  ///
  /// The game draws its own world through its own camera, so there is no
  /// widget here to measure and no render box to find. This projects the
  /// enemy through that camera and offsets the result by where the game
  /// surface sits on the screen, which puts it in the same global coordinates
  /// a widget key would have produced.
  Rect? _enemySpot() {
    final game = _game;
    if (game == null || game.enemies.isEmpty) {
      return null;
    }
    final surface =
        _targets.up.currentContext?.findRenderObject() as RenderBox?;
    if (surface == null || !surface.hasSize) {
      return null;
    }
    // Where a marked enemy has to be. Clear of the display at the top, which
    // would cover the hole, and of the bottom of the screen, where the caption
    // and the player's own ship are. An enemy is mounted while it is still
    // above the top edge flying in, and a mark put there cuts its hole off the
    // screen and puts the caption above that, so the player is shown a dimmed
    // screen with nothing on it and no way to tell what for.
    final glass = surface.localToGlobal(Offset.zero) & surface.size;
    final band = Rect.fromLTRB(
      glass.left + Metrics.enemyMarkInset,
      glass.top +
          math.max(
            Metrics.hudBandHeight + Metrics.enemyMarkInset,
            glass.height * Metrics.enemyMarkTopFraction,
          ),
      glass.right - Metrics.enemyMarkInset,
      glass.bottom - Metrics.enemyMarkClearance,
    );

    Offset? centre;
    double radius = 0;
    for (final enemy in game.enemies) {
      final shot = game.scene.camera.project(enemy.worldPosition);
      if (shot == null) {
        continue;
      }

      // Two conversions, not one. The game's own camera projects the world
      // onto a fixed 540 by 960 surface, and Flame then letterboxes that onto
      // whatever the phone actually is, so a point straight out of project()
      // is in neither the world's coordinates nor the screen's. Skipping the
      // second step puts the mark near the top left corner on every device.
      //
      // Flame's own conversion is used rather than the letterbox arithmetic,
      // because it already knows the viewport and will keep being right if
      // the viewport is ever set up differently.
      final onGlass = game.camera.localToGlobal(
        Vector2(shot.screen.dx, shot.screen.dy),
      );
      final at = surface.localToGlobal(Offset(onGlass.x, onGlass.y));
      if (!band.contains(at)) {
        continue;
      }
      // The lowest one that is properly on screen, so the mark lands on the
      // enemy the player is about to meet rather than on one still entering
      // behind it. Picked from the ones inside the band rather than from all
      // of them, or a wave whose leader has already swept past the bottom
      // marks nothing while the rest of it is in plain sight.
      //
      // A whole wave arrives in a line at the same height, so height alone
      // picks an arbitrary one and it turns out to be the one at the end of
      // the row, half under the edge of the screen with the hand on top of
      // it. Level with another, the more central one wins.
      if (centre != null) {
        final mid = band.center.dx;
        final better = at.dy > centre.dy + 1
            ? true
            : at.dy < centre.dy - 1
            ? false
            : (at.dx - mid).abs() < (centre.dx - mid).abs();
        if (!better) {
          continue;
        }
      }

      // The radius goes through the same two steps, measured rather than
      // scaled by hand: a length in the fixed surface is not a length on the
      // glass.
      final edge = game.camera.localToGlobal(
        Vector2(
          shot.screen.dx + enemy.stats.size * 0.5 * shot.scale,
          shot.screen.dy,
        ),
      );
      centre = at;
      radius = (edge - onGlass).length;
    }
    if (centre == null) {
      return null;
    }

    return Rect.fromCircle(center: centre, radius: radius);
  }

  /// Whether the lesson should be holding the game still right now.
  ///
  /// The first two steps always hold: they are waiting on a drag, and the
  /// player is meant to be looking at the caption rather than at a fight. The
  /// third cannot, until there is something to point at. Held from the moment
  /// it became current, no enemy would ever arrive and the lesson would wait
  /// forever for a wave it had itself prevented.
  bool get _shouldHold {
    if (!_tutorial.isRunning) {
      return false;
    }
    final step = _tutorial.current;
    if (step == null) {
      return false;
    }
    return step.id == FlightLesson.shoot ? _enemySpot() != null : true;
  }

  /// Puts the brake where [_shouldHold] says it belongs.
  void _syncBrake() {
    final game = _game;
    if (game == null) {
      return;
    }
    // Holding wins over the breath. The window after a drag exists so the
    // player sees what their own finger did, but an enemy reaching the place
    // it is about to be marked in is exactly the moment to stop, and a step
    // that let the window run instead watched the wave fly out from under its
    // own ring.
    if (_shouldHold) {
      _breathe?.cancel();
      _breathe = null;
      game.paused = true;
      return;
    }
    if (_breathe?.isActive ?? false) {
      return;
    }
    game.paused = false;
  }

  /// The real steering, reported afterwards.
  ///
  /// Unconditional: an id that is not the current step is ignored and nothing
  /// happens when no sequence is running, so this never asks whether a lesson
  /// is up.
  void _onSteer(double lane) {
    final before = _tutorial.current?.id;
    _tutorial.report(lane > 0 ? FlightLesson.up : FlightLesson.down);
    if (_tutorial.current?.id != before) {
      _letItPlay();
    }
  }

  /// Off the brake for a moment, so the player sees what their own finger did.
  ///
  /// Done with the engine's own paused flag and a timer rather than by
  /// branching the simulation's advance step: a conditional in the solver's
  /// hot path is a cost paid forever for something that happens once per
  /// install.
  void _letItPlay() {
    final game = _game;
    if (game == null) {
      return;
    }
    _breathe?.cancel();
    game.paused = false;
    if (!_tutorial.isRunning) {
      return;
    }
    _breathe = Timer(const Duration(milliseconds: 700), () {
      _breathe = null;
      if (mounted) {
        _syncBrake();
      }
    });
  }

  @override
  void dispose() {
    _breathe?.cancel();
    _game?.livesNotifier.removeListener(_onLivesChanged);
    _game?.onSteer = null;
    _tutorial.removeListener(_syncBrake);
    // Put the brake back, or a game handed on somewhere else stays frozen.
    _game?.paused = false;
    _tutorial.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    final navigator = Navigator.of(context);
    await AppScope.of(context).audio.playMusic(MusicTracks.menu);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = _game!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        // The system back gesture pauses rather than dropping the run.
        if (game.status == GameStatus.playing) {
          game.pauseGame();
        } else {
          _leave();
        }
      },
      child: TutorialLauncher(
        controller: _tutorial,
        // Held off until there is a frame to freeze. didUpdateWidget picks it
        // up the moment there is.
        enabled: _teachable,
        child: Scaffold(
          backgroundColor: Palette.spaceDeep,
          // The lesson cuts its hole around the whole play surface, because the
          // finger may start its drag anywhere on the glass.
          body: KeyedSubtree(
            key: _targets.up,
            child: GameWidget<NovaGame>(
              game: game,
              overlayBuilderMap: {
                NovaGame.hudOverlay: (context, game) => Hud(game: game),
                NovaGame.pauseOverlay: (context, game) =>
                    PauseOverlay(game: game),
                NovaGame.gameOverOverlay: (context, game) =>
                    GameOverSheet(game: game, ads: AppScope.of(context).ads),
                NovaGame.levelCompleteOverlay: (context, game) =>
                    LevelCompleteSheet(
                      game: game,
                      ads: AppScope.of(context).ads,
                    ),
              },
            ),
          ),
        ),
      ),
    );
  }
}
