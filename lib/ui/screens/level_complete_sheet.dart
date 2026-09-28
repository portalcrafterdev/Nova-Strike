import 'package:flutter/material.dart';

import '../../ads/ads_controller.dart';
import '../../audio/sfx.dart';
import '../../game/nova_game.dart';
import '../../levels/difficulty_curve.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../widgets/nova_button.dart';
import '../widgets/space_scrim.dart';

/// Shown when a level is cleared: stars, coins, and the way on.
///
/// One column, result above the choices. Half of a portrait screen is not wide
/// enough for a button to say NEXT LEVEL without eliding it.
///
/// The interstitial goes on the way to the next level rather than on arrival
/// here. The player has just earned something and the first thing they should
/// see is what they earned. [ads] is optional so the sheet can be built
/// without an ad controller.
class LevelCompleteSheet extends StatefulWidget {
  const LevelCompleteSheet({required this.game, this.ads, super.key});

  final NovaGame game;
  final AdsController? ads;

  @override
  State<LevelCompleteSheet> createState() => _LevelCompleteSheetState();
}

class _LevelCompleteSheetState extends State<LevelCompleteSheet> {
  NovaGame get game => widget.game;

  Future<void> _next() async {
    game.audio.play(Sfx.buttonTap);
    // Awaited. The ad has to be finished with before the next level starts
    // underneath it, and this is the one moment in the game where waiting is
    // the point rather than a cost.
    await widget.ads?.onLevelCleared(game.levelNumber);
    if (mounted) {
      game.nextLevel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stars = game.earnedStars;
    final isLast = game.levelNumber >= Tuning.totalLevels;

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
                  // The banner is the one moment on this sheet worth
                  // celebrating, so it gets the colour face. The level number
                  // moves out of it and onto its own line: the wordmark face
                  // is wide, and CLEAR on its own reads from further away.
                  const Text(
                    'CLEAR',
                    textAlign: TextAlign.center,
                    style: AppType.display,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'LEVEL ${game.levelNumber}',
                    textAlign: TextAlign.center,
                    style: AppType.hudSmall,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(Tuning.starsPerLevel, (i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.star,
                          size: 38,
                          color: i < stars ? Palette.star : Palette.starEmpty,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'SCORE ${game.score}',
                    textAlign: TextAlign.center,
                    style: AppType.body,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.monetization_on,
                        size: 16,
                        color: Palette.coin,
                      ),
                      const SizedBox(width: 6),
                      Text('+${game.coinReward}', style: AppType.body),
                    ],
                  ),
                  const SizedBox(height: 28),
                  if (!isLast) ...[
                    NovaButton(
                      label: 'NEXT LEVEL',
                      primary: true,
                      icon: Icons.arrow_forward,
                      onPressed: _next,
                    ),
                    const SizedBox(height: 10),
                  ],
                  NovaButton(
                    label: 'REPLAY',
                    icon: Icons.refresh,
                    onPressed: () {
                      game.audio.play(Sfx.buttonTap);
                      game.retry();
                    },
                  ),
                  const SizedBox(height: 10),
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
