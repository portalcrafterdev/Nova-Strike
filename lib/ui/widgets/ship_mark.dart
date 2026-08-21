import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import '../../game/render/camera.dart';
import '../../game/render/sprite.dart';
import '../../game/render/sprite_renderer.dart';
import '../../theme/palette.dart';

/// The badge above the game name: the player's own hull.
///
/// Drawn by the same renderer that draws it in a level, from the same model,
/// so the mark on the menu is the ship you fly rather than a picture of one.
class ShipMark extends StatelessWidget {
  const ShipMark({this.size = Metrics.shipMarkSize, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MarkPainter(size)),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.extent);

  final double extent;

  /// The bare hull, with no rack fitted.
  ///
  /// The pods and canards are readable at the size a ship is flown at and
  /// cluttered at the size a mark is read at: the canards break away from the
  /// fuselage and the pods become two loose bars. A mark wants one silhouette,
  /// so this is the airframe on its own.
  static final Sprite2D _sprite = Sprites.ship(
    hull: Palette.playerHull,
    hullDark: Palette.playerHullDark,
    accent: Palette.playerAccent,
  );

  static final Paint _halo = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    // The light the hull sits in, so the mark reads as lit rather than pasted
    // onto the sky.
    final rect = Offset.zero & size;
    _halo.shader = const RadialGradient(
      colors: [Palette.glow, Color(0x00000000)],
    ).createShader(rect);
    canvas.drawRect(rect, _halo);

    final camera = GameCamera(
      viewportWidth: size.width,
      viewportHeight: size.height,
      zoom: size.shortestSide / Metrics.shipMarkFit,
      laneOrigin: size.height / 2,
    );
    SpriteRenderer(camera).draw(canvas, _sprite, position: Vector3.zero());
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.extent != extent;
}

/// A hairline with a diamond set in it, used under a title.
class RuleMark extends StatelessWidget {
  const RuleMark({this.color = Palette.uiAccent, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _line(true)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Transform.rotate(
            angle: 0.785,
            child: Container(width: 6, height: 6, color: color),
          ),
        ),
        Expanded(child: _line(false)),
      ],
    );
  }

  Widget _line(bool fadeLeft) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: fadeLeft
              ? [const Color(0x00000000), color]
              : [color, const Color(0x00000000)],
        ),
      ),
    );
  }
}
