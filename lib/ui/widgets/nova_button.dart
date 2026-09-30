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

/// The shade a control casts on the sky below it.
///
/// There was a solid band here too, drawn as the side of a key. It has gone:
/// a coloured slab under every button was a second edge competing with the
/// light on top, and on the amber one it read as a dirty stripe rather than as
/// depth. What is left is one soft shadow, which is what settles a control
/// onto the sky instead of leaving it pasted against it.
///
/// The depth still shrinks while a button is held, so the shadow tightening is
/// now what says the thing went down.
List<BoxShadow> novaLift({double depth = Metrics.liftDepth}) {
  return [
    BoxShadow(
      color: Palette.shadowAmbient,
      offset: Offset(0, depth),
      blurRadius: depth * 2.4,
    ),
  ];
}

/// Where the light falls across a control, as fractions of its height, and
/// how much of it lands at each.
///
/// One band lying over the top, fading out by the middle. The fade is the
/// whole point: a highlight that stops somewhere reads as a shape drawn on the
/// button rather than as light on it, which is what made the first attempt at
/// this look cheap.
const List<double> _glossStops = <double>[0, 0.38, 0.60, 0.92, 1];
const List<double> _glossLight = <double>[0.62, 0.16, 0, 0, 0];

/// How far the bottom edge is pulled toward the ledge colour.
///
/// Stands in for an inner shadow, which Flutter has no way to draw. Turning
/// under at the bottom is what gives the face its thickness.
const double _glossTurn = 0.28;

/// A tone's fill with that light laid over it.
///
/// Worked out from the tone rather than written down as a list of colours,
/// because every one of these has to be the tone's own fill lightened by the
/// same amount. Hand mixed, they drift, and four buttons on one screen end up
/// lit from four slightly different angles.
LinearGradient novaGloss(NovaTone tone) {
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: _glossStops,
    colors: <Color>[
      for (var i = 0; i < _glossStops.length; i++)
        _litAt(tone, _glossStops[i], _glossLight[i]),
    ],
  );
}

Color _litAt(NovaTone tone, double at, double light) {
  var body = Color.lerp(tone.fill, tone.fillLow, at)!;
  if (at >= 1) {
    body = Color.lerp(body, tone.ledge, _glossTurn)!;
  }
  if (light <= 0) {
    return body;
  }
  return Color.alphaBlend(Colors.white.withValues(alpha: light), body);
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
class NovaButton extends StatefulWidget {
  const NovaButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.icon,
    this.enabled = true,
    this.tone,
    this.height,
    this.compact = false,
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

  /// Smaller label, icon and padding, for a button sharing a row.
  ///
  /// Two buttons side by side on a portrait phone get about 150 logical
  /// pixels each, and at the full size the label is ellipsised: a button that
  /// cannot say what it does is not a button.
  final bool compact;

  @override
  State<NovaButton> createState() => _NovaButtonState();
}

class _NovaButtonState extends State<NovaButton> {
  /// True while a finger is on it.
  bool _down = false;

  void _setDown(bool down) {
    if (_down != down) {
      setState(() => _down = down);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final icon = widget.icon;
    final primary = widget.primary;
    final compact = widget.compact;
    final height = widget.height;
    final onPressed = widget.onPressed;

    final active = widget.enabled && onPressed != null;
    final colours =
        widget.tone ?? (primary ? NovaTone.primary : NovaTone.quiet);
    // No outline on any of them. The violet ones carried one because a flat
    // fill that close to the sky needed help separating from it; the light
    // across the top does that now, and the two together read as a doubled
    // edge.
    final ink = colours.ink;
    final shape = novaShape(bevel: Metrics.buttonRound);

    // Held, the face drops and its shadow tightens under it. With the band
    // gone the shadow is the only thing left saying how high the button is,
    // so it has to do the work the band used to.
    final held = _down && active;
    final sink = held ? Metrics.pressSink : 0.0;
    final depth = held ? Metrics.liftPressed : Metrics.liftDepth;

    return Opacity(
      opacity: active ? 1 : 0.45,
      // Exactly as much room is kept below as the face can travel, and it is
      // handed back at the top on the way down. Without that the button is
      // shorter while held and everything under it jumps up the screen at the
      // moment somebody is aiming at it.
      child: AnimatedPadding(
        duration: Metrics.pressFor,
        curve: Curves.easeOut,
        padding: EdgeInsets.only(top: sink, bottom: Metrics.pressSink - sink),
        child: AnimatedContainer(
          duration: Metrics.pressFor,
          curve: Curves.easeOut,
          decoration: ShapeDecoration(
            shape: shape,
            // The light comes off the tone rather than being mixed here, so
            // every button on a screen is lit from the same angle.
            gradient: novaGloss(colours),
            shadows: [
              ...novaLift(depth: depth),
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
              onTapDown: active ? (_) => _setDown(true) : null,
              onTapUp: active ? (_) => _setDown(false) : null,
              onTapCancel: active ? () => _setDown(false) : null,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: height ?? Metrics.tapTarget,
                  maxHeight: height ?? double.infinity,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 8 : 20,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: compact ? 18 : 22, color: ink),
                        SizedBox(width: compact ? 6 : 10),
                      ],
                      // Flexible, so a pair of buttons sharing a row on a
                      // narrow screen shrinks the label rather than
                      // overflowing it.
                      Flexible(
                        child: Text(
                          label,
                          style:
                              (primary
                                      ? AppType.buttonLit
                                      : AppType.button.copyWith(color: ink))
                                  .copyWith(
                                    fontSize: compact ? 16 : null,
                                    letterSpacing: compact ? 0.4 : null,
                                  ),
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
    final shape = novaShape(bevel: 18);

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
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
            width: 48,
            height: 48,
            child: Icon(icon, size: 24, color: Palette.uiText),
          ),
        ),
      ),
    );
  }
}
