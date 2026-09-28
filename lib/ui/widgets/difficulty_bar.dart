import 'package:flutter/material.dart';

import '../../levels/difficulty_curve.dart';
import '../../levels/level_spec.dart';
import '../../state/player_progress.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import 'nova_button.dart';

/// The three settings, as one row of pills.
///
/// It sits on the menu above PLAY and again on the level map, rather than in
/// the settings screen. The setting decides which campaign the player is in, so
/// the place to change it is the place they are about to enter one from, and on
/// the map the levels underneath show the change take effect straight away.
class DifficultyBar extends StatelessWidget {
  const DifficultyBar({
    required this.progress,
    required this.onChanged,
    super.key,
  });

  final PlayerProgress progress;

  /// Called with the setting the player picked. A locked one never gets here.
  final ValueChanged<Difficulty> onChanged;

  @override
  Widget build(BuildContext context) {
    final chosen = progress.difficulty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (final difficulty in Difficulty.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _Pill(
                      difficulty: difficulty,
                      selected: difficulty == chosen,
                      unlocked: progress.isAvailable(difficulty),
                      onTap: () => onChanged(difficulty),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            progress.isAvailable(Difficulty.hard)
                ? DifficultyTuning.describe(chosen)
                : 'Reach level ${DifficultyTuning.hardUnlockLevel + 1} on '
                      'medium to unlock hard',
            textAlign: TextAlign.center,
            style: AppType.bodyDim,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.difficulty,
    required this.selected,
    required this.unlocked,
    required this.onTap,
  });

  final Difficulty difficulty;
  final bool selected;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The setting you are on is filled teal, not merely outlined. On a screen
    // where the main action is a solid amber slab, an outline does not read as
    // chosen; it reads as the one that has been switched off.
    final tone = selected ? NovaTone.go : NovaTone.quiet;
    final shape = novaShape(
      edge: selected ? null : Palette.panelEdge,
      bevel: 18,
    );
    final ink = unlocked ? tone.ink : Palette.uiTextLocked;

    return Padding(
      padding: const EdgeInsets.only(bottom: Metrics.ledgeDepthSmall),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: shape,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tone.fill, tone.fillLow],
          ),
          shadows: [
            BoxShadow(
              color: tone.ledge,
              offset: const Offset(0, Metrics.ledgeDepthSmall),
            ),
          ],
        ),
        child: Opacity(
          opacity: unlocked ? 1 : 0.55,
          child: Material(
            color: Colors.transparent,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: unlocked ? onTap : null,
              child: SizedBox(
                height: 54,
                // Scaled down rather than clipped. Three pills share the width
                // of whatever screen the game is on, and the longest of the
                // three labels does not fit on a narrow one.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!unlocked) ...[
                          Icon(Icons.lock_rounded, size: 15, color: ink),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          DifficultyTuning.labelOf(difficulty),
                          style: AppType.button.copyWith(
                            color: ink,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
