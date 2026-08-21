// Draws the game's logo and writes every icon the two platforms ask for.
//
// The mark is the player's own hull, rendered by the game's own renderer from
// the game's own mesh, so the icon on the home screen is the ship you fly
// rather than a picture of one. Run it after changing the hull or the palette:
//
//   BRANDING=1 flutter test test/branding_test.dart
//
// It is skipped by default so a normal test run never writes files.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/game/render/camera.dart';
import 'package:novastrike/game/render/sprite.dart';
import 'package:novastrike/game/render/sprite_renderer.dart';
import 'package:novastrike/theme/palette.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// The bare airframe. No pods and no canards: at icon size those break away
/// from the fuselage and the mark stops being one silhouette.
final Sprite2D _hull = Sprites.ship(
  hull: Palette.playerHull,
  hullDark: Palette.playerHullDark,
  accent: Palette.playerAccent,
);

/// How much of the icon's width the ship spans.
///
/// Two values, because an adaptive icon is masked to a circle and anything
/// outside the middle two thirds can be cut off by the launcher.
///
/// Both were bigger. The hull is mostly wing, so a ship sized to fill the
/// frame put two pale triangles in the corners and left nothing for the eye to
/// land on. Pulled in, the silhouette reads as a ship at the size a launcher
/// actually draws it.
const double _fullBleed = 0.62;
const double _safeZone = 0.40;

/// A colour with more of itself in it, for the nebulae behind the mark.
Color _lift(Color base, double amount) =>
    base.withValues(alpha: (base.a + amount).clamp(0.0, 1.0));

/// Paints the logo into [size] pixels square.
///
/// [ship] is the fraction of the width the hull spans, and [background] turns
/// the sky on. A transparent logo for a document wants it off.
void _paintLogo(
  Canvas canvas,
  double size, {
  required double ship,
  bool background = true,
  bool hull = true,
}) {
  final rect = Rect.fromLTWH(0, 0, size, size);
  final middle = Offset(size / 2, size / 2);

  if (background) {
    canvas.drawRect(rect, Paint()..color = Palette.spaceDeep);
    // Two nebulae on opposite corners. Stronger and further apart than they
    // were: at icon size a wash this subtle just read as flat navy.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = Gradient.radial(
          Offset(size * 0.26, size * 0.20),
          size * 0.92,
          [_lift(Palette.menuNebulaA, 0.55), const Color(0x00000000)],
        ),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = Gradient.radial(
          Offset(size * 0.80, size * 0.84),
          size * 0.78,
          [_lift(Palette.menuNebulaB, 0.5), const Color(0x00000000)],
        ),
    );
    // A vignette, so the corners drop away and the middle is where the eye
    // goes. It also stops the icon fighting whatever mask a launcher puts on.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = Gradient.radial(middle, size * 0.72, [
          const Color(0x00000000),
          Palette.spaceDeep.withValues(alpha: 0.85),
        ], const [0.55, 1.0]),
    );
  }

  if (!hull) {
    return;
  }

  // The light the hull sits in, and only ever over the sky. On the adaptive
  // foreground it came out as a pale disc of haze around the ship, which a
  // launcher then masked and drew over whatever wallpaper the player has.
  if (background) {
    canvas.drawCircle(
      middle,
      size * 0.44,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = Gradient.radial(middle, size * 0.44, [
          Palette.glow,
          const Color(0x00000000),
        ]),
    );
  }

  // The exhaust plume. The old mark was a hull sitting still: a shape, not a
  // ship going anywhere. A tapered trail out of the tail gives the icon a
  // direction and puts one warm note against all the blue.
  final plumeTop = size * (0.5 + ship * 0.16);
  canvas.drawPath(
    Path()
      ..moveTo(size * 0.5 - size * ship * 0.13, plumeTop)
      ..lineTo(size * 0.5 + size * ship * 0.13, plumeTop)
      ..lineTo(size * 0.5 + size * ship * 0.03, size * 0.93)
      ..lineTo(size * 0.5 - size * ship * 0.03, size * 0.93)
      ..close(),
    Paint()
      // Light adds over the sky. Over nothing it only washes out, and the
      // adaptive foreground layer is drawn over nothing.
      ..blendMode = background ? BlendMode.plus : BlendMode.srcOver
      ..shader = Gradient.linear(
        Offset(size * 0.5, plumeTop),
        Offset(size * 0.5, size * 0.93),
        [Palette.thrusterHot, Palette.thruster.withValues(alpha: 0)],
      ),
  );

  // Fitted to the hull's own bounds rather than to a guessed constant, so a
  // change to the shape cannot quietly leave the mark rattling around inside
  // its box.
  final box = _hull.bounds;
  final halfWidth = math.max(box.left.abs(), box.right.abs());
  final extent = math.max(halfWidth * 2, box.height);

  final camera = GameCamera(
    viewportWidth: size,
    viewportHeight: size,
    zoom: size * ship / extent,
    laneOrigin: size / 2,
  );
  // The hull is drawn nose forward of the origin, so it is nudged back by half
  // its own length to sit in the middle of the frame. Sprite space runs down
  // the screen where the lane runs up it, which is why this is not negated.
  SpriteRenderer(
    camera,
  ).draw(canvas, _hull, position: Vector3(0, 0, box.center.dy));
}

Future<Uint8List> _render(
  double size, {
  double ship = 0,
  bool background = true,
  bool hull = true,
}) async {
  final recorder = PictureRecorder();
  _paintLogo(
    Canvas(recorder),
    size,
    ship: ship,
    background: background,
    hull: hull,
  );
  final image = await recorder.endRecording().toImage(
    size.round(),
    size.round(),
  );
  final data = await image.toByteData(format: ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<void> _write(String path, Uint8List bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
  // ignore: avoid_print
  print('wrote $path');
}

void main() {
  test('branding', () async {
    // Android launcher icons, one per density bucket.
    const android = <String, double>{
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    for (final entry in android.entries) {
      await _write(
        'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
        await _render(entry.value, ship: _fullBleed),
      );
    }

    // The adaptive icon, which is what Android 8 and later actually shows.
    //
    // Two layers the launcher moves against each other, each 108 units square
    // against the 72 the mask shows, so the hull is drawn well inside its own
    // frame and no launcher shape can clip a wing off.
    const adaptive = <String, double>{
      'mdpi': 108,
      'hdpi': 162,
      'xhdpi': 216,
      'xxhdpi': 324,
      'xxxhdpi': 432,
    };
    for (final entry in adaptive.entries) {
      await _write(
        'android/app/src/main/res/mipmap-${entry.key}/ic_launcher_fore.png',
        await _render(entry.value, ship: _safeZone, background: false),
      );
      await _write(
        'android/app/src/main/res/mipmap-${entry.key}/ic_launcher_back.png',
        await _render(entry.value, hull: false),
      );
    }

    // The mark on the window the system shows before Flutter has drawn
    // anything. On transparency, because the layer under it is the same deep
    // space colour the game uses.
    const launch = <String, double>{
      'drawable-mdpi': 120,
      'drawable-hdpi': 180,
      'drawable-xhdpi': 240,
      'drawable-xxhdpi': 360,
      'drawable-xxxhdpi': 480,
    };
    for (final entry in launch.entries) {
      await _write(
        'android/app/src/main/res/${entry.key}/launch_mark.png',
        await _render(entry.value, ship: _fullBleed, background: false),
      );
    }

    // iOS wants a file per size, at the names its manifest already lists.
    const ios = <String, double>{
      'Icon-App-20x20@1x': 20,
      'Icon-App-20x20@2x': 40,
      'Icon-App-20x20@3x': 60,
      'Icon-App-29x29@1x': 29,
      'Icon-App-29x29@2x': 58,
      'Icon-App-29x29@3x': 87,
      'Icon-App-40x40@1x': 40,
      'Icon-App-40x40@2x': 80,
      'Icon-App-40x40@3x': 120,
      'Icon-App-60x60@2x': 120,
      'Icon-App-60x60@3x': 180,
      'Icon-App-76x76@1x': 76,
      'Icon-App-76x76@2x': 152,
      'Icon-App-83.5x83.5@2x': 167,
      'Icon-App-1024x1024@1x': 1024,
    };
    for (final entry in ios.entries) {
      await _write(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/${entry.key}.png',
        await _render(entry.value, ship: _fullBleed),
      );
    }

    // One large copy to hand to a store listing or a document.
    await _write(
      'assets/images/logo.png',
      await _render(1024, ship: _fullBleed),
    );
    await _write(
      'assets/images/logo_mark.png',
      await _render(1024, ship: _fullBleed, background: false),
    );
  }, skip: Platform.environment['BRANDING'] == null);
}
