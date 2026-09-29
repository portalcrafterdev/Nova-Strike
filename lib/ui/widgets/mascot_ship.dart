import 'package:flutter/material.dart';

/// The ship on the menu, drawn as a character rather than as a vehicle.
///
/// This is deliberately not the sprite the game flies. That one is cut from
/// the airframe every hull in the game shares, and it has to stay readable at
/// forty pixels with thirty other things moving around it, which rules out the
/// heavy outline and the oversized face that make this one work. The menu has
/// none of those constraints and one job: introduce somebody.
///
/// Drawn rather than shipped as an image so it recolours with the palette and
/// costs nothing in the bundle.
class MascotShip extends StatelessWidget {
  const MascotShip({this.size = 118, this.dazed = false, super.key});

  final double size;

  /// Knocked out: crossed eyes, a frown, the colour drained and the engine
  /// off. Used on the sheet that appears when the run ends, where the ship
  /// having had a bad time is the whole message.
  final bool dazed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      // The art is 96 wide by 104 tall, and the box keeps that ratio so the
      // flame is never cut off the bottom.
      height: size * _MascotPainter.artHeight / _MascotPainter.artWidth,
      child: CustomPaint(painter: _MascotPainter(dazed: dazed)),
    );
  }
}

class _MascotPainter extends CustomPainter {
  const _MascotPainter({this.dazed = false});

  final bool dazed;

  static const double artWidth = 96;
  static const double artHeight = 104;

  /// The keyline round every part of the hull.
  ///
  /// One weight for all of it. A cartoon reads as one object because its
  /// outline is even; vary it and the parts come apart.
  static const Color _ink = Color(0xFF1B1147);
  static const double _stroke = 4.5;

  static const Color _wing = Color(0xFF6FA8FF);
  static const Color _body = Color(0xFFEAF2FF);
  static const Color _canopy = Color(0xFF45E0D0);
  static const Color _eye = Color(0xFF12103A);
  static const Color _flame = Color(0xFFFFC63D);

  // The knocked out set. Muted rather than grey: a ship drained to grey looks
  // broken for good, and this one is about to fly again.
  static const Color _wingOut = Color(0xFF5E86C8);
  static const Color _bodyOut = Color(0xFFC3CEE0);
  static const Color _canopyOut = Color(0xFF3BB8AB);

  Color get _wingColour => dazed ? _wingOut : _wing;
  Color get _bodyColour => dazed ? _bodyOut : _body;
  Color get _canopyColour => dazed ? _canopyOut : _canopy;

  static Path _poly(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  void _draw(Canvas canvas, Path path, Color fill, {bool outline = true}) {
    canvas.drawPath(path, Paint()..color = fill);
    if (outline) {
      canvas.drawPath(
        path,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    canvas.save();
    canvas.scale(size.width / artWidth, size.height / artHeight);

    // The flame first, so the hull sits over the top of where it leaves. A
    // knocked out ship has no engine running, which is half of why it reads
    // as stopped rather than as merely sad.
    if (!dazed) {
      final flame = Path()
        ..moveTo(40, 80)
        ..quadraticBezierTo(48, 103, 56, 80)
        ..quadraticBezierTo(48, 87, 40, 80)
        ..close();
      _draw(canvas, flame, _flame, outline: false);
    }

    _draw(
      canvas,
      _poly(const [
        Offset(48, 6),
        Offset(74, 62),
        Offset(64, 92),
        Offset(48, 80),
        Offset(32, 92),
        Offset(22, 62),
      ]),
      _wingColour,
    );

    _draw(
      canvas,
      _poly(const [
        Offset(48, 12),
        Offset(60, 62),
        Offset(48, 74),
        Offset(36, 62),
      ]),
      _bodyColour,
    );

    final canopy = Path()
      ..addOval(Rect.fromCenter(
        center: const Offset(48, 40),
        width: 27,
        height: 32,
      ));
    _draw(canvas, canopy, _canopyColour);

    // The face. Two eyes with a catchlight each and a small smile, which is
    // the whole of it: anything more detailed stops reading the moment the
    // mark is drawn at menu size.
    final ink = Paint()
      ..color = _eye
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    if (dazed) {
      // Crossed eyes. The oldest shorthand there is for having taken a hit,
      // and the one a child reads without being taught it.
      for (final x in const [43.0, 53.0]) {
        canvas.drawLine(Offset(x - 3, 35.5), Offset(x + 3, 41.5), ink);
        canvas.drawLine(Offset(x + 3, 35.5), Offset(x - 3, 41.5), ink);
      }
    } else {
      for (final x in const [43.0, 53.0]) {
        canvas.drawCircle(Offset(x, 38.5), 3.6, Paint()..color = _eye);
        canvas.drawCircle(
          Offset(x + 1.3, 37),
          1.3,
          Paint()..color = const Color(0xFFFFFFFF),
        );
      }
    }

    // Up for a smile, down for a frown. One sign flip.
    final mouth = Path()
      ..moveTo(43, dazed ? 49.5 : 46.5)
      ..quadraticBezierTo(48, dazed ? 45.5 : 50.5, 53, dazed ? 49.5 : 46.5);
    canvas.drawPath(mouth, ink..strokeWidth = 2.8);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MascotPainter oldDelegate) => oldDelegate.dazed != dazed;
}
