import 'package:flutter/material.dart';

import '../../theme/palette.dart';
import '../../theme/typography.dart';
import 'nova_button.dart';

/// The small pieces the menu is built from.
///
/// They live together because they share one set of proportions: a 46 high
/// pill, a 72 high tile, a 3 pixel outline and the same corner on all of it.
/// Split across the screens that use them, those numbers drift within a week.
class MenuMetrics {
  const MenuMetrics._();

  static const double pillHeight = 46;
  static const double tileHeight = 72;
  static const double stripHeight = 62;
  static const double pillRound = 23;
  static const double tileRound = 26;
}

/// A readout pill: an icon, then a number.
class StatPill extends StatelessWidget {
  const StatPill({
    required this.icon,
    required this.tint,
    required this.value,
    super.key,
  });

  final IconData icon;
  final Color tint;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MenuMetrics.pillHeight,
      padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
      decoration: ShapeDecoration(
        shape: novaShape(edge: Palette.panelEdge, bevel: MenuMetrics.pillRound),
        color: Palette.panelFill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: tint, size: 22),
          const SizedBox(width: 7),
          Text(value, style: AppType.hud.copyWith(fontSize: 19)),
        ],
      ),
    );
  }
}

/// A round icon button, for the one control that sits on its own.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.diameter = MenuMetrics.pillHeight,
    super.key,
  });

  final IconData icon;

  /// Read out by a screen reader. An icon on its own says nothing to one.
  final String label;
  final VoidCallback onPressed;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final shape = novaShape(bevel: diameter / 2);
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: shape,
            gradient: novaGloss(NovaTone.quiet),
          ),
          child: Material(
            color: Colors.transparent,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Icon(icon, size: 24, color: Palette.uiTextDim),
            ),
          ),
        ),
      ),
    );
  }
}

/// How far through the campaign the player is, as one line.
///
/// A bar rather than a sentence, because at level 40 of 1500 the sentence is
/// discouraging and the bar is honest about the same thing without saying it
/// out loud.
class ProgressPill extends StatelessWidget {
  const ProgressPill({required this.level, required this.total, super.key});

  final int level;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total <= 0 ? 0.0 : (level / total).clamp(0.0, 1.0);
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: ShapeDecoration(
        shape: novaShape(edge: Palette.panelEdge, bevel: 21),
        color: Palette.panelFillLow,
      ),
      child: Row(
        children: [
          Text(
            'LEVEL $level',
            style: AppType.hudSmall.copyWith(color: Palette.uiTextSoft),
          ),
          const SizedBox(width: 10),
          Expanded(
            // Measured rather than laid out as a fraction. A fraction of the
            // width is the obvious way to draw this and it is wrong here: one
            // level in fifteen hundred is less than a pixel, so the bar reads
            // as empty for the first dozen hours of play. The fill is given a
            // floor of its own height, which makes it a dot.
            child: LayoutBuilder(
              builder: (context, constraints) {
                const track = 10.0;
                final width = constraints.maxWidth;
                final filled = (width * fraction).clamp(track, width);
                return SizedBox(
                  height: track,
                  child: Stack(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: Palette.uiBackground,
                          borderRadius: BorderRadius.all(Radius.circular(5)),
                        ),
                      ),
                      Container(
                        width: filled,
                        decoration: const BoxDecoration(
                          color: Palette.panelFillLit,
                          borderRadius: BorderRadius.all(Radius.circular(5)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Text('$total', style: AppType.hudSmall),
        ],
      ),
    );
  }
}

/// A square way through to another screen: icon above a short label.
class MenuTile extends StatelessWidget {
  const MenuTile({
    required this.icon,
    required this.label,
    required this.tint,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // No outline and no band under it. The light across the top is what lifts
    // a tile off the sky now, and a drawn edge on top of that reads as a
    // second edge competing with it.
    final shape = novaShape(bevel: MenuMetrics.tileRound);
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        // Lit the same way as every button beside it. A tile left flat next
        // to a lit button does not read as quieter, it reads as unfinished.
        gradient: novaGloss(NovaTone.quiet),
        shadows: novaLift(depth: Metrics.liftDepthSmall),
      ),
      child: Material(
        color: Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: MenuMetrics.tileHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: tint),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: AppType.hudSmall.copyWith(
                      color: Palette.uiTextSoft,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
