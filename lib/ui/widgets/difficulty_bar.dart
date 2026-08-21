import 'package:flutter/material.dart';

import '../../levels/difficulty_curve.dart';
import '../../levels/level_spec.dart';
import '../../state/player_progress.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import 'nova_button.dart';

/// The three settings, as one row of pills above the level list.
///
/// It sits on the level map rather than in the settings screen on purpose. The
/// setting decides which campaign the levels below it belong to, so the place
/// to change it is the place the player is looking at those levels, and the row
/// underneath shows the change take effect straight away.
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
                      'normal to unlock hard',
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
    final edge = selected ? Palette.uiAccent : Palette.panelEdge;
    return Opacity(
      opacity: unlocked ? 1 : 0.35,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: novaShape(edge: edge, width: selected ? 1.6 : 1),
          color: selected ? Palette.panelFillLit : Palette.panelFill,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: unlocked ? onTap : null,
            customBorder: novaShape(),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
              // Scaled down rather than clipped. Three pills share the width of
              // whatever screen the game is on, and the longest of the three
              // labels does not fit on a narrow one.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!unlocked) ...[
                      const Icon(
                        Icons.lock_outline,
                        size: 13,
                        color: Palette.uiTextDim,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      DifficultyTuning.labelOf(difficulty),
                      style: AppType.button.copyWith(
                        color: selected ? Palette.uiAccent : Palette.uiText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
