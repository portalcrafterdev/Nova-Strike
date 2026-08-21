import 'dart:ui';

import 'package:vector_math/vector_math_64.dart';

import '../../theme/palette.dart';
import 'camera.dart';
import 'sprite.dart';

/// Draws flat sprites.
///
/// A sprite is already the shape the screen sees, so drawing one is a canvas
/// transform and a fill per part. There is no projection per corner, no
/// lighting and no sort inside a shape, which is both what gives the game its
/// hard edged arcade look and why a screen full of ships costs so little.
///
/// The renderer owns its paints and reuses them for every shape it draws, so a
/// busy frame allocates nothing.
class SpriteRenderer {
  SpriteRenderer(this.camera);

  final GameCamera camera;

  final Paint _fill = Paint()..style = PaintingStyle.fill;
  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  /// Draws [sprite] at a world position.
  ///
  /// [yaw] turns it about the vertical axis, which on a flat sprite is simply
  /// a turn on the screen. [flash] blends the whole shape toward white, which
  /// is how a hit reads.
  void draw(
    Canvas canvas,
    Sprite2D sprite, {
    required Vector3 position,
    double yaw = 0,
    double scale = 1,
    double flash = 0,
    double opacity = 1,
  }) {
    final projected = camera.project(position);
    if (projected == null || opacity <= 0) {
      return;
    }
    final size = projected.scale * scale;
    if (size <= 0) {
      return;
    }

    canvas
      ..save()
      ..translate(projected.screen.dx, projected.screen.dy);
    if (yaw != 0) {
      canvas.rotate(yaw);
    }
    canvas.scale(size);

    // The keyline is a width on the glass rather than a width in the world, so
    // it is divided back out of the transform. Without this a boss would wear
    // a band and a bullet casing would wear a hairline.
    _line
      ..strokeWidth = Metrics.spriteOutlineWidth / size
      ..color = Palette.spriteOutline.withValues(
        alpha: Palette.spriteOutline.a * opacity,
      );

    for (final part in sprite.parts) {
      _fill.color = tint(part.fill, flash, opacity);
      canvas.drawPath(part.path, _fill);
      if (part.outlined) {
        canvas.drawPath(part.path, _line);
      }
    }

    canvas.restore();
  }

  /// Applies the hit flash and the fade to a fill colour.
  static Color tint(Color base, double flash, double opacity) {
    final faded = opacity >= 1
        ? base
        : Color.from(
            alpha: base.a * opacity,
            red: base.r,
            green: base.g,
            blue: base.b,
          );
    if (flash <= 0) {
      return faded;
    }
    final mix = flash.clamp(0.0, 1.0);
    return Color.from(
      alpha: faded.a,
      red: faded.r + (1 - faded.r) * mix,
      green: faded.g + (1 - faded.g) * mix,
      blue: faded.b + (1 - faded.b) * mix,
    );
  }
}
