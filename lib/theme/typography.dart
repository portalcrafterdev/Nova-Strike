import 'package:flutter/material.dart';

import 'palette.dart';

/// Text styles for every Flutter surface in the game.
class AppType {
  const AppType._();

  static const String _family = 'monospace';

  static const TextStyle title = TextStyle(
    fontFamily: _family,
    fontSize: 40,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: 6,
    color: Palette.uiText,
  );

  /// The game name, lit from behind.
  ///
  /// Two shadows rather than one: a tight halo that reads as the letters
  /// glowing, and a wide one that spills onto the sky behind them.
  static final TextStyle titleGlow = title.copyWith(
    shadows: const [
      Shadow(color: Palette.glow, blurRadius: 18),
      Shadow(color: Palette.glow, blurRadius: 54),
    ],
  );

  static const TextStyle heading = TextStyle(
    fontFamily: _family,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
    color: Palette.uiText,
  );

  static const TextStyle subheading = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    color: Palette.uiAccent,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    color: Palette.uiText,
  );

  static const TextStyle bodyDim = TextStyle(
    fontFamily: _family,
    fontSize: 13,
    color: Palette.uiTextDim,
  );

  static const TextStyle button = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
    color: Palette.uiBackground,
  );

  /// The label on the one action a screen wants taken. Wider spacing and a
  /// halo, so it reads as lit rather than merely coloured.
  static final TextStyle buttonLit = button.copyWith(
    color: Palette.uiText,
    letterSpacing: 3,
    shadows: const [Shadow(color: Palette.glow, blurRadius: 14)],
  );

  static const TextStyle hud = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 1,
    color: Palette.uiText,
  );

  static const TextStyle hudSmall = TextStyle(
    fontFamily: _family,
    fontSize: 11,
    letterSpacing: 1,
    color: Palette.uiTextDim,
  );
}
