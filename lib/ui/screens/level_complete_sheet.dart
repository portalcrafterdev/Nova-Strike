import 'package:flutter/material.dart';

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
class LevelCompleteSheet extends StatelessWidget {
  const LevelCompleteSheet({required this.game, super.key});

  final NovaGame game;

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
                  Text(
                    'LEVEL ${game.levelNumber} CLEAR',
                    textAlign: TextAlign.center,
                    style: AppType.heading.copyWith(color: Palette.uiAccent),
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
                      onPressed: () {
                        game.audio.play(Sfx.buttonTap);
                        game.nextLevel();
                      },
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
