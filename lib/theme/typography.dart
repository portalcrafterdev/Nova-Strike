import 'package:flutter/material.dart';

import 'palette.dart';

/// Text styles for every Flutter surface in the game.
///
/// Two faces, and the split between them is not a matter of taste. Baloo2 is
/// the one that is read: rounded, heavy set, and legible at the sizes a child
/// holds a phone at. BungeeSpice is the one that is looked at.
class AppType {
  const AppType._();

  /// The face everything readable is set in.
  ///
  /// Baloo2 is a variable font, and the only form Google publishes it in, so
  /// a weight here is a coordinate on the weight axis rather than a separate
  /// file. Every style below asks for it with a FontVariation and sets the
  /// matching [FontWeight] alongside, so anything measuring the style, and the
  /// fallback face if the asset ever fails to load, still agree about how
  /// heavy the text is meant to be.
  static const String _family = 'Baloo2';

  /// The wordmark face.
  ///
  /// BungeeSpice carries its own colour in a COLRv1 table, so setting a colour
  /// on [display] does nothing at all. That is the whole reason it is kept to
  /// the wordmark and the two result banners: everywhere else in the game the
  /// colour of a word is carrying meaning, and a face that ignores it cannot
  /// be used there.
  static const String displayFamily = 'BungeeSpice';

  /// The game name and the result banners. Size and spacing only.
  static const TextStyle display = TextStyle(
    fontFamily: displayFamily,
    fontSize: 40,
    height: 1.04,
    letterSpacing: 1,
  );

  static const TextStyle title = TextStyle(
    fontFamily: _family,
    fontVariations: <FontVariation>[FontVariation('wght', 800)],
    fontWeight: FontWeight.w800,
    fontSize: 30,
    height: 1.12,
    letterSpacing: 0.5,
    color: Palette.uiText,
  );

  /// Kept for anything still setting a lit title in the body face.
  static final TextStyle titleGlow = title.copyWith(
    shadows: const [
      Shadow(color: Palette.glow, blurRadius: 18),
      Shadow(color: Palette.glow, blurRadius: 54),
    ],
  );

  static const TextStyle heading = TextStyle(
    fontFamily: _family,
    fontVariations: <FontVariation>[FontVariation('wght', 800)],
    fontWeight: FontWeight.w800,
    fontSize: 22,
    height: 1.15,
    letterSpacing: 0.4,
    color: Palette.uiText,
  );

  static const TextStyle subheading = TextStyle(
    fontFamily: _family,
    fontVariations: <FontVariation>[FontVariation('wght', 700)],
    fontWeight: FontWeight.w700,
    fontSize: 17,
    height: 1.2,
    letterSpacing: 0.8,
    color: Palette.uiAccent,
  );

  static const TextStyle body = TextStyle(
    fontFamily: _family,
    fontVariations: <FontVariation>[FontVariation('wght', 600)],
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 1.3,
    color: Palette.uiText,
  );

  static const TextStyle bodyDim = TextStyle(
    fontFamily: _family,
    fontVariations: <FontVariation>[FontVariation('wght', 600)],
    fontWeight: FontWeight.w600,
    fontSize: 14,
    height: 1.35,
    color: Palette.uiTextDim,
  );

  /// The label on a quiet button. Its colour is set by the button, because a
  /// quiet button and a lit one sit on very different fills.
  static const TextStyle button = TextStyle(
    fontFamily: _family,
    fontVariations: <FontVariation>[FontVariation('wght', 800)],
    fontWeight: FontWeight.w800,
    fontSize: 19,
    height: 1.1,
    letterSpacing: 0.8,
    color: Palette.uiText,
  );

  /// The label on the one action a screen wants taken.
  ///
  /// Dark ink, because the lit fill is now a bright amber and white on amber
  /// is the one pairing on this screen that fails to read.
  static const TextStyle buttonLit = TextStyle(
    fontFamily: _family,
    fontVariations: <FontVariation>[FontVariation('wght', 800)],
    fontWeight: FontWeight.w800,
    fontSize: 21,
    height: 1.1,
    letterSpacing: 1,
    color: Palette.uiInkOnLit,
  );

  static const TextStyle hud = TextStyle(
    fontFamily: _family,
    fontVariations: <FontVariation>[FontVariation('wght', 800)],
    fontWeight: FontWeight.w800,
    fontSize: 16,
    height: 1.15,
    letterSpacing: 0.4,
    color: Palette.uiText,
  );

  static const TextStyle hudSmall = TextStyle(
    fontFamily: _family,
    fontVariations: <FontVariation>[FontVariation('wght', 700)],
    fontWeight: FontWeight.w700,
    fontSize: 12.5,
    height: 1.2,
    letterSpacing: 1.2,
    color: Palette.uiTextDim,
  );
}
