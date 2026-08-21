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
import 'package:novastrike/game/render3d/camera3d.dart';
import 'package:novastrike/game/render3d/mesh.dart';
import 'package:novastrike/game/render3d/mesh_renderer.dart';
import 'package:novastrike/theme/palette.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// The bare airframe. No pods and no canards: at icon size those break away
/// from the fuselage and the mark stops being one silhouette.
final Mesh _hull = Meshes.ship(
  hull: Palette.playerHull,
  hullDark: Palette.playerHullDark,
  accent: Palette.playerAccent,
);

/// How much of the icon's width the ship spans.
///
/// Two values, because an adaptive icon is masked to a circle and anything
/// outside the middle two thirds can be cut off by the launcher.
const double _fullBleed = 0.74;
const double _safeZone = 0.46;

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
    canvas.drawRect(
      rect,
      Paint()
        ..shader = Gradient.radial(
          Offset(size * 0.34, size * 0.30),
          size * 0.78,
          [Palette.menuNebulaA, const Color(0x00000000)],
        ),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = Gradient.radial(
          Offset(size * 0.74, size * 0.76),
          size * 0.62,
          [Palette.menuNebulaB, const Color(0x00000000)],
        ),
    );
  }

  if (!hull) {
    return;
  }

  // The light the hull sits in. Without it the ship reads as pasted on rather
  // than as the brightest thing in the frame.
  canvas.drawCircle(
    middle,
    size * 0.42,
    Paint()
      ..shader = Gradient.radial(middle, size * 0.42, [
        Palette.glow,
        const Color(0x00000000),
      ]),
  );

  // Fitted to the model's own bounds rather than to a guessed constant, so a
  // change to the hull cannot quietly leave the mark rattling around inside
  // its box.
  var halfWidth = 0.0;
  var minZ = double.infinity;
  var maxZ = -double.infinity;
  for (final vertex in _hull.vertices) {
    if (vertex.x.abs() > halfWidth) {
      halfWidth = vertex.x.abs();
    }
    if (vertex.z < minZ) {
      minZ = vertex.z;
    }
    if (vertex.z > maxZ) {
      maxZ = vertex.z;
    }
  }
  final extent = math.max(halfWidth * 2, maxZ - minZ);

  final camera = Camera3D(
    viewportWidth: size,
    viewportHeight: size,
    zoom: size * ship / extent,
    laneOrigin: size / 2,
  );
  // The hull is modelled nose forward of the origin, so it is nudged back by
  // half its own length to sit in the middle of the frame.
  MeshRenderer(
    camera,
  ).draw(canvas, _hull, position: Vector3(0, 0, -(minZ + maxZ) / 2));
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
