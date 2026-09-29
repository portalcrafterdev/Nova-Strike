import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/theme/palette.dart';
import 'package:novastrike/theme/typography.dart';
import 'package:novastrike/ui/widgets/nova_button.dart';

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
  buttonSurfaceTests();

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

/// The soft candy treatment: how a control is lit, and how it answers a
/// finger. Both are easy to break without anything throwing, because a
/// gradient that is wrong still paints and a button that changes size while
/// held still works.
void buttonSurfaceTests() {
  group('the light on a control', () {
    test('fades out down the face instead of stopping', () {
      // A highlight that ends somewhere reads as a shape drawn on the button
      // rather than as light falling on it. That was what made the first
      // attempt at this look cheap, so it is checked rather than remembered.
      for (final tone in const [
        NovaTone.primary,
        NovaTone.fun,
        NovaTone.go,
        NovaTone.quiet,
      ]) {
        final gloss = novaGloss(tone);
        final stops = gloss.stops!;

        // How much light each stop ADDS to the unlit fill, not how bright it
        // ends up. The absolute brightness falls down the face whatever the
        // light does, because the fill itself darkens, so measuring that
        // cannot tell a fade from a flat band and passes either way.
        final added = <double>[
          for (var i = 0; i < stops.length; i++)
            gloss.colors[i].computeLuminance() -
                Color.lerp(tone.fill, tone.fillLow, stops[i])!
                    .computeLuminance(),
        ];

        for (var i = 1; i < added.length; i++) {
          expect(
            added[i],
            lessThanOrEqualTo(added[i - 1] + 1e-9),
            reason:
                'the light does not fade between stops ${i - 1} and $i, so '
                'it is a band with a hard edge where it stops',
          );
        }
        expect(
          added.first,
          greaterThan(0.02),
          reason: 'the top of the face is not lit at all',
        );
        expect(
          added[2],
          closeTo(0, 1e-6),
          reason: 'the light has not run out by the middle of the face',
        );
        expect(
          gloss.colors.last.computeLuminance(),
          lessThan(tone.fillLow.computeLuminance()),
          reason: 'the bottom edge does not turn under, so the face is flat',
        );
      }
    });

    test('is what separates an unoutlined control from the sky', () {
      // The menu's quiet controls lost their drawn edge, so the only thing
      // left holding a tile off the background is the light on its top. Judged
      // at the 3 to 1 the standard asks of a boundary that is not text: below
      // that a button stops having a visible edge at all, and on a dim phone
      // outdoors the menu becomes a set of labels floating on a starfield.
      final top = novaGloss(NovaTone.quiet).colors.first;
      for (final sky in const [Palette.uiBackground, Palette.spaceDeep]) {
        expect(
          _contrast(top, sky),
          greaterThanOrEqualTo(3),
          reason: 'an unoutlined control does not stand off the sky',
        );
      }
    });

    test('the shade under a control is violet, not black, and only one', () {
      final shadows = novaLift();
      // One shadow. There used to be a hard coloured slab under this, drawn
      // as the side of a key; it competed with the light on top and on the
      // amber button it read as a dirty stripe. Anything returned here with
      // no blur is that slab coming back.
      expect(shadows.length, 1, reason: 'a control has more than one shadow');
      final ambient = shadows.single;
      expect(
        ambient.blurRadius,
        greaterThan(0),
        reason: 'the shade is hard edged, so it is a band and not a shadow',
      );
      // Grey over a saturated purple sky does not read as shade, it reads as
      // dirt. The shade has to keep the blue in it.
      expect(
        ambient.color.b,
        greaterThan(ambient.color.r),
        reason: 'the shade has no colour in it',
      );
    });
  });

  group('a button being held', () {
    testWidgets('travels down without moving anything around it', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NovaButton(
                label: 'PLAY',
                primary: true,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final box = tester.getRect(find.byType(NovaButton));
      final face = tester.getRect(find.text('PLAY'));

      final finger = await tester.startGesture(face.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // The gap the face leaves at the top is given back as padding. Without
      // that the button is shorter while held, and every button under it
      // jumps up the screen at the moment somebody is aiming at one.
      expect(
        tester.getRect(find.byType(NovaButton)),
        box,
        reason: 'the button changed size while held, shifting the screen',
      );
      expect(
        tester.getRect(find.text('PLAY')).top,
        greaterThan(face.top),
        reason: 'the face did not travel down, so nothing looks pressed',
      );

      await finger.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        tester.getRect(find.text('PLAY')).top,
        closeTo(face.top, 0.01),
        reason: 'the face stayed down after the finger left',
      );
    });
  });
}
