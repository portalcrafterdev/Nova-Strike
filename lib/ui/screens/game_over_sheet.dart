import 'package:flutter/material.dart';

import '../../audio/sfx.dart';
import '../../game/nova_game.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../widgets/nova_button.dart';
import '../widgets/space_scrim.dart';

/// Shown when the ship runs out of lives.
///
/// Retry restarts the same level immediately. There is no ad gate and no wait,
/// because friction here is what makes players quit. One column, result above
/// the choices, so a button is never too narrow to say what it does.
class GameOverSheet extends StatelessWidget {
  const GameOverSheet({required this.game, super.key});

  final NovaGame game;

  @override
  Widget build(BuildContext context) {
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
                    'SHIP LOST',
                    textAlign: TextAlign.center,
                    style: AppType.heading.copyWith(
                      color: Palette.bossHealthBar,
                    ),
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
                  NovaButton(
                    label: 'RETRY',
                    primary: true,
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
