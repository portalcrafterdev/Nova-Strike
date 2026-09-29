import 'dart:async';

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
    steps: flightTutorialSteps(_targets),
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
      if (_tutorial.isRunning) {
        game.paused = true;
      }
    });
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
      if (mounted && _tutorial.isRunning) {
        game.paused = true;
      }
    });
  }

  @override
  void dispose() {
    _breathe?.cancel();
    _game?.livesNotifier.removeListener(_onLivesChanged);
    _game?.onSteer = null;
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
