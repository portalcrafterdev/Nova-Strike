import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../ads/ads_controller.dart';
import '../../app.dart';
import '../../audio/sfx.dart';
import '../../game/nova_game.dart';
import '../../theme/palette.dart';
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
    );
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

  @override
  void dispose() {
    _game?.livesNotifier.removeListener(_onLivesChanged);
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
      child: Scaffold(
        backgroundColor: Palette.spaceDeep,
        body: GameWidget<NovaGame>(
          game: game,
          overlayBuilderMap: {
            NovaGame.hudOverlay: (context, game) => Hud(game: game),
            NovaGame.pauseOverlay: (context, game) => PauseOverlay(game: game),
            NovaGame.gameOverOverlay: (context, game) =>
                GameOverSheet(game: game, ads: AppScope.of(context).ads),
            NovaGame.levelCompleteOverlay: (context, game) =>
                LevelCompleteSheet(game: game, ads: AppScope.of(context).ads),
          },
        ),
      ),
    );
  }
}
