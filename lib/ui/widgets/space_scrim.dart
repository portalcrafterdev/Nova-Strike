import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/palette.dart';
import 'nova_button.dart';

/// The veil a sheet lays over the level behind it.
///
/// The level does not disappear, it goes out of focus: blurred and darkened,
/// so the ship and the stars are still there behind the choice being made.
/// One blur per sheet, and a sheet is only ever up while the game is stopped.
class SpaceScrim extends StatelessWidget {
  const SpaceScrim({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: Metrics.sheetBlur,
        sigmaY: Metrics.sheetBlur,
      ),
      child: ColoredBox(
        color: Palette.uiBackground.withValues(alpha: Metrics.sheetTint),
        child: child,
      ),
    );
  }
}

/// A panel that the sky shows through, used for cards and rows in the menus.
class NovaPanel extends StatelessWidget {
  const NovaPanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.lit = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// A lit panel is the one the screen wants the player to look at.
  final bool lit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: lit ? Palette.panelFillLit : Palette.panelFill,
        shape: novaShape(edge: lit ? Palette.panelEdgeLit : Palette.panelEdge),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
