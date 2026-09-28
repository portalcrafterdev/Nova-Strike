import 'package:flutter/material.dart';

import '../../theme/palette.dart';
import '../../theme/typography.dart';

/// The shape every button and panel is cut to.
///
/// Fat rounded corners on all four sides, with a thick border rather than a
/// hairline. Both halves of that matter: the radius is what makes a control
/// look moulded instead of machined, and the weight of the outline is what
/// makes it look like an object rather than a region of the screen. It is
/// shared so a panel and a button never disagree about their own outline.
ShapeBorder novaShape({
  Color? edge,
  double width = 3,
  double bevel = Metrics.panelRound,
}) {
  return RoundedRectangleBorder(
    side: edge == null
        ? BorderSide.none
        : BorderSide(color: edge, width: width),
    borderRadius: BorderRadius.all(Radius.circular(bevel)),
  );
}

/// One button colour, as the four values a button needs to draw itself.
///
/// Held together in one object rather than passed as four arguments, because
/// the fill and the ink are only correct as a pair: every combination here has
/// been checked for contrast and a caller mixing its own would not be.
class NovaTone {
  const NovaTone({
    required this.fill,
    required this.fillLow,
    required this.ledge,
    required this.ink,
  });

  final Color fill;
  final Color fillLow;
  final Color ledge;
  final Color ink;

  /// The violet panel. Most of any screen.
  static const NovaTone quiet = NovaTone(
    fill: Palette.panelFill,
    fillLow: Palette.panelFillLow,
    ledge: Palette.panelLedge,
    ink: Palette.uiText,
  );

  /// Amber. The one action a screen wants taken.
  static const NovaTone primary = NovaTone(
    fill: Palette.panelFillLit,
    fillLow: Palette.panelFillLitLow,
    ledge: Palette.panelLedgeLit,
    ink: Palette.uiInkOnLit,
  );

  /// Pink. The other way to play.
  static const NovaTone fun = NovaTone(
    fill: Palette.panelFillFun,
    fillLow: Palette.panelFillFunLow,
    ledge: Palette.panelLedgeFun,
    ink: Palette.uiInkOnFun,
  );

  /// Teal. The setting you are already on.
  static const NovaTone go = NovaTone(
    fill: Palette.panelFillGo,
    fillLow: Palette.panelFillGoLow,
    ledge: Palette.panelLedgeGo,
    ink: Palette.uiInkOnGo,
  );
}

/// The solid band under a control.
///
/// A flat offset with no blur. Blur it and it becomes a drop shadow, which
/// says the button is floating above the screen; keep it hard and it reads as
/// the side of a key, which says the button can be pushed down onto it.
List<BoxShadow> novaLedge(Color color, {double depth = Metrics.ledgeDepth}) {
  return [
    BoxShadow(color: color, offset: Offset(0, depth)),
  ];
}

/// The one button style used across every screen.
///
/// A solid rounded panel sitting on a band of its own darker colour, and on
/// the one action a screen wants taken, a bright amber fill and a glow thrown
/// out past the edge. Solid rather than glass: stars crawling behind a label
/// make the label harder to read, not the screen prettier.
///
/// The lit button is deliberately loud. A child scanning a screen should not
/// have to work out which control moves the game forward.
class NovaButton extends StatelessWidget {
  const NovaButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.icon,
    this.enabled = true,
    this.tone,
    this.height,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Shorthand for the amber tone, kept because most callers only ever wanted
  /// to say whether this was the main action on the screen.
  final bool primary;
  final IconData? icon;
  final bool enabled;

  /// Overrides the colour [primary] would have picked.
  final NovaTone? tone;

  /// Forces a height, for the two buttons the menu sizes by hand.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onPressed != null;
    final colours =
        tone ?? (primary ? NovaTone.primary : NovaTone.quiet);
    // A coloured fill carries its own edge. Only the violet panel needs a
    // drawn outline to separate it from the sky behind it.
    final edge = colours == NovaTone.quiet ? Palette.panelEdge : null;
    final ledge = colours.ledge;
    final ink = colours.ink;
    final shape = novaShape(edge: edge);

    return Opacity(
      opacity: active ? 1 : 0.45,
      // The band sits under the button rather than behind it, so a column of
      // buttons keeps an even gap instead of the ledges closing the gaps up.
      child: Padding(
        padding: const EdgeInsets.only(bottom: Metrics.ledgeDepth),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: shape,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colours.fill, colours.fillLow],
            ),
            shadows: [
              BoxShadow(
                color: ledge,
                offset: const Offset(0, Metrics.ledgeDepth),
              ),
              if (colours == NovaTone.primary && active)
                const BoxShadow(
                  color: Palette.glow,
                  blurRadius: Metrics.panelGlowBlur,
                  spreadRadius: -4,
                ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: active ? onPressed : null,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: height ?? Metrics.tapTarget,
                  maxHeight: height ?? double.infinity,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 22, color: ink),
                        const SizedBox(width: 10),
                      ],
                      // Flexible, so a pair of buttons sharing a row on a
                      // narrow screen shrinks the label rather than
                      // overflowing it.
                      Flexible(
                        child: Text(
                          label,
                          style: primary
                              ? AppType.buttonLit
                              : AppType.button.copyWith(color: ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
    );
  }
}

/// A small icon button, used for pause and back.
class NovaIconButton extends StatelessWidget {
  const NovaIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final shape = novaShape(edge: Palette.panelEdge, bevel: 18);

    return Padding(
      padding: const EdgeInsets.only(bottom: Metrics.ledgeDepthSmall),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: shape,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Palette.panelFill, Palette.panelFillLow],
          ),
          shadows: const [
            BoxShadow(
              color: Palette.panelLedge,
              offset: Offset(0, Metrics.ledgeDepthSmall),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(icon, size: 24, color: Palette.uiText),
            ),
          ),
        ),
      ),
    );
  }
}
