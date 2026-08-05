import 'package:flutter/material.dart';

import '../../theme/palette.dart';
import '../../theme/typography.dart';

/// The shape every button and panel is cut to.
///
/// All four corners chamfered by the same amount. It is the one detail that
/// stops the interface reading as a stack of stock rounded rectangles, and it
/// is shared so a panel and a button never disagree about their own outline.
ShapeBorder novaShape({
  Color? edge,
  double width = 1,
  double bevel = Metrics.panelBevel,
}) {
  return BeveledRectangleBorder(
    side: edge == null
        ? BorderSide.none
        : BorderSide(color: edge, width: width),
    borderRadius: BorderRadius.all(Radius.circular(bevel)),
  );
}

/// The one button style used across every screen.
///
/// A solid panel lit from above, chamfered on all four corners, with a lit bar
/// down the leading edge and, on the one action a screen wants taken, a glow
/// thrown out past the edge. Solid rather than glass: stars crawling behind a
/// label make the label harder to read, not the screen prettier.
class NovaButton extends StatelessWidget {
  const NovaButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.icon,
    this.enabled = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && onPressed != null;
    final edge = primary ? Palette.panelEdgeLit : Palette.panelEdge;
    final bar = primary ? Palette.uiAccent : Palette.panelEdgeLit;
    final shape = novaShape(edge: edge, width: primary ? 1.4 : 1);

    return Opacity(
      opacity: active ? 1 : 0.4,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: shape,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: primary
                ? const [Palette.panelFillLit, Palette.panelFillLitLow]
                : const [Palette.panelFill, Palette.panelFillLow],
          ),
          shadows: primary && active
              ? const [
                  BoxShadow(
                    color: Palette.glow,
                    blurRadius: Metrics.panelGlowBlur,
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: active ? onPressed : null,
            // A stack rather than a row, so the lit edge stretches to whatever
            // height the label ends up needing without asking the row for an
            // intrinsic pass.
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 18, 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          size: 18,
                          color: primary ? Palette.uiAccent : Palette.uiTextDim,
                        ),
                        const SizedBox(width: 12),
                      ],
                      // Flexible, so a pair of buttons sharing a row on a
                      // narrow screen shrinks the label rather than
                      // overflowing it.
                      Flexible(
                        child: Text(
                          label,
                          style: primary
                              ? AppType.buttonLit
                              : AppType.button.copyWith(color: Palette.uiText),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // The lit edge. It is what tells the eye where a column of
                // buttons starts without drawing a box around each one.
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: Metrics.panelBar,
                  child: ColoredBox(color: bar),
                ),
              ],
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
    final shape = novaShape(edge: Palette.panelEdge);

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.panelFill, Palette.panelFillLow],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 20, color: Palette.uiText),
          ),
        ),
      ),
    );
  }
}
