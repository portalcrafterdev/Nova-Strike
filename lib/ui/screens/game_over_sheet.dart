import 'package:flutter/material.dart';

import '../../ads/ads_controller.dart';
import '../../audio/sfx.dart';
import '../../game/nova_game.dart';
import '../../theme/typography.dart';
import '../widgets/nova_button.dart';
import '../widgets/space_scrim.dart';

/// Shown when the ship runs out of lives.
///
/// Retry restarts the same level immediately. There is no ad gate and no wait,
/// because friction here is what makes players quit. One column, result above
/// the choices, so a button is never too narrow to say what it does.
///
/// The one ad on this screen is the extra life, and it is an offer rather than
/// a toll. Watching it hands back a life and drops the player back into the
/// fight they just lost, keeping their score and their place in the level.
/// Ignoring it costs nothing, because RETRY sits right underneath it and is
/// still instant and still free.
class GameOverSheet extends StatefulWidget {
  const GameOverSheet({required this.game, this.ads, super.key});

  final NovaGame game;
  final AdsController? ads;

  @override
  State<GameOverSheet> createState() => _GameOverSheetState();
}

class _GameOverSheetState extends State<GameOverSheet> {
  bool _busy = false;

  NovaGame get game => widget.game;

  @override
  void initState() {
    super.initState();
    // A last chance to fetch one. The game asks for a rewarded ad as soon as
    // the player is down to their last life, so by here it is normally already
    // waiting, and this only matters when that load failed or never ran.
    widget.ads?.prepareReward();
  }

  Future<void> _watchForLife() async {
    final ads = widget.ads;
    if (ads == null || _busy || !game.canRevive) {
      return;
    }
    game.audio.play(Sfx.buttonTap);
    setState(() => _busy = true);
    final earned = await ads.showRewarded();
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (earned) {
      // Only on a watched ad. Skipping out early pays nothing, which is what
      // the store means by a reward.
      game.revive();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ads = widget.ads;
    if (ads == null) {
      return _build(canWatch: false);
    }
    // Rebuilt when the controller changes, so an ad that finishes loading a
    // moment after this sheet opened still puts the button on screen. Reading
    // the flag once and never listening was why the offer could be missing
    // even with an ad sitting ready.
    return ListenableBuilder(
      listenable: ads,
      builder: (context, _) => _build(
        // Offered only when there is an ad loaded and the run has not already
        // spent its revive. A button promising a life that then does nothing
        // is worse than no button at all.
        canWatch: ads.canOfferReward && game.canRevive,
      ),
    );
  }

  Widget _build({required bool canWatch}) {
    return SpaceScrim(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Not SHIP LOST. Losing is the most common thing that
                  // happens in this game and the moment a child is most
                  // likely to put it down, so the banner is a shrug rather
                  // than a verdict. Retry stays one tap away and ungated.
                  const Text(
                    'OOPS',
                    textAlign: TextAlign.center,
                    style: AppType.display,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'LEVEL ${game.levelNumber}',
                    textAlign: TextAlign.center,
                    style: AppType.hudSmall,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'SCORE ${game.runScore}',
                    textAlign: TextAlign.center,
                    style: AppType.body,
                  ),
                  if (game.endless)
                    Text(
                      'BEST ${game.progress.endlessBest}',
                      textAlign: TextAlign.center,
                      style: AppType.bodyDim,
                    ),
                  const SizedBox(height: 28),
                  if (canWatch) ...[
                    NovaButton(
                      label: _busy ? 'LOADING' : 'EXTRA LIFE',
                      primary: true,
                      icon: Icons.favorite,
                      enabled: !_busy,
                      onPressed: _watchForLife,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'WATCH AN AD TO CARRY ON WHERE YOU FELL',
                      textAlign: TextAlign.center,
                      style: AppType.bodyDim,
                    ),
                    const SizedBox(height: 14),
                  ],
                  NovaButton(
                    label: 'RETRY',
                    // The primary action, unless the extra life is on offer.
                    // Two glowing buttons on one sheet is no emphasis at all.
                    primary: !canWatch,
                    icon: Icons.refresh,
                    onPressed: () {
                      game.audio.play(Sfx.buttonTap);
                      game.retry();
                    },
                  ),
                  const SizedBox(height: 12),
                  NovaButton(
                    label: 'MENU',
                    icon: Icons.home,
                    onPressed: () {
                      game.audio.play(Sfx.buttonTap);
                      game.onQuit?.call();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
