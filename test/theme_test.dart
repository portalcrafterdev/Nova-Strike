import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/theme/palette.dart';
import 'package:novastrike/theme/typography.dart';

/// The WCAG contrast ratio between two opaque colours.
///
/// [Color.computeLuminance] is already the relative luminance the standard
/// asks for, so this is only the ratio around it.
double _contrast(Color a, Color b) {
  final one = a.computeLuminance();
  final other = b.computeLuminance();
  final light = one > other ? one : other;
  final dark = one > other ? other : one;
  return (light + 0.05) / (dark + 0.05);
}

void main() {
  group('the look holds together', () {
    // Every pairing here is one where the text and the fill are set in
    // different files, so nothing at the call site would show the two had
    // drifted apart. The lit button is the one that actually went wrong: the
    // fill moved from a mid teal to a bright amber, and the label was still
    // white, which is the single worst pairing in this palette.
    final pairs = <String, List<Color>>{
      'ink on the lit button': [Palette.uiInkOnLit, Palette.panelFillLit],
      'ink on the lit button at its darker stop': [
        Palette.uiInkOnLit,
        Palette.panelFillLitLow,
      ],
      'text on a panel': [Palette.uiText, Palette.panelFill],
      'dim text on a panel': [Palette.uiTextDim, Palette.panelFill],
      'text on the background': [Palette.uiText, Palette.uiBackground],
      'dim text on the background': [Palette.uiTextDim, Palette.uiBackground],
      'the accent on a panel': [Palette.uiAccent, Palette.panelFill],
    };

    for (final entry in pairs.entries) {
      test('${entry.key} is readable', () {
        final ratio = _contrast(entry.value.first, entry.value.last);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              '${entry.key} is ${ratio.toStringAsFixed(2)}:1, under the 4.5:1 '
              'a body size needs',
        );
      });
    }

    test('a full heart is told from an empty one by more than hue', () {
      // Red against a dark violet is a difference in hue, and a player who
      // cannot separate those two hues is left with no way to count their
      // lives. The two have to differ in lightness as well.
      final full = Palette.heartFull.computeLuminance();
      final empty = Palette.heartEmptyEdge.computeLuminance();
      expect(
        _contrast(Palette.heartFull, Palette.heartEmptyEdge),
        greaterThanOrEqualTo(2.0),
        reason: 'a spent life looks the same as a held one',
      );
      expect(full, greaterThan(empty));
    });
  });

  group('the faces are wired', () {
    // A missing font does not throw. Flutter quietly falls back, so the game
    // runs and only looks wrong, which is exactly the kind of fault that
    // reaches a store.
    test('both font files are in the bundle', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final path in const [
        'assets/fonts/Baloo2-var.ttf',
        'assets/fonts/BungeeSpice-Regular.ttf',
      ]) {
        expect(
          File(path).existsSync(),
          isTrue,
          reason: '$path is named in the theme but not on disk',
        );
        expect(
          pubspec.contains(path),
          isTrue,
          reason: '$path is on disk but not declared in pubspec.yaml',
        );
      }
    });

    test('every style is set in one of the two bundled faces', () {
      final styles = <String, TextStyle>{
        'display': AppType.display,
        'title': AppType.title,
        'titleGlow': AppType.titleGlow,
        'heading': AppType.heading,
        'subheading': AppType.subheading,
        'body': AppType.body,
        'bodyDim': AppType.bodyDim,
        'button': AppType.button,
        'buttonLit': AppType.buttonLit,
        'hud': AppType.hud,
        'hudSmall': AppType.hudSmall,
      };
      for (final entry in styles.entries) {
        expect(
          entry.value.fontFamily,
          anyOf('Baloo2', AppType.displayFamily),
          reason: '${entry.key} would fall back to the system face',
        );
      }
    });

    test('the body face asks for a weight on its axis', () {
      // Baloo2 ships only as a variable font, so a weight that is set with
      // fontWeight alone renders at the default and every heading on every
      // screen comes out the same thickness.
      for (final style in <TextStyle>[
        AppType.title,
        AppType.heading,
        AppType.subheading,
        AppType.body,
        AppType.bodyDim,
        AppType.button,
        AppType.buttonLit,
        AppType.hud,
        AppType.hudSmall,
      ]) {
        final axes = style.fontVariations ?? const <FontVariation>[];
        expect(
          axes.any((axis) => axis.axis == 'wght'),
          isTrue,
          reason: 'a Baloo2 style with no wght axis renders at one weight',
        );
      }
    });

    test('the colour font is never given a colour', () {
      // BungeeSpice carries its own palette in a COLRv1 table and ignores a
      // colour set on it. A style that sets one is not wrong on screen, it is
      // worse: it reads as though the colour means something.
      expect(AppType.display.color, isNull);
      expect(AppType.display.fontFamily, AppType.displayFamily);
    });
  });
}
