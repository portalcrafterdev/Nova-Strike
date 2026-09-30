import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/palette.dart';

/// Scattered paper behind a result, for the one screen that is a celebration.
///
/// Still, not falling. A win sheet is read, and anything moving behind text
/// competes with it; the paper is there to say something good happened, which
/// it does perfectly well lying where it landed. It also costs one paint and
/// no ticker, which matters on a sheet that opens straight off a level.
///
/// Laid out from a fixed seed so it is the same scatter every time rather than
/// a new one each build, which would flicker on every rebuild of the sheet.
class Confetti extends StatelessWidget {
  const Confetti({required this.child, this.pieces = 14, super.key});

  final Widget child;
  final int pieces;

  /// The seed the scatter is drawn from. A fixed one, so the sheet looks the
  /// same each time the player reaches it.
  static const int seed = 20260928;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _ConfettiPainter(pieces)),
          ),
        ),
        child,
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces);

  final int pieces;

  static const List<Color> _colours = [
    Palette.panelFillLit,
    Palette.panelFillGo,
    Palette.panelFillFun,
    Palette.shipInterceptor,
    Palette.uiAccent,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final random = math.Random(Confetti.seed);
    final paint = Paint();
    for (var i = 0; i < pieces; i++) {
      // Kept to the top half and out of the middle third, which is where the
      // banner and the stars sit. Paper over a word is litter, not confetti.
      final fromLeft = random.nextBool();
      final x = fromLeft
          ? random.nextDouble() * size.width * 0.22
          : size.width * (0.78 + random.nextDouble() * 0.22);
      final y = size.height * (0.04 + random.nextDouble() * 0.30);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((random.nextDouble() - 0.5) * 2.2);
      paint.color = _colours[random.nextInt(_colours.length)]
          .withValues(alpha: 0.85);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: 9 + random.nextDouble() * 4,
            height: 14 + random.nextDouble() * 6,
          ),
          const Radius.circular(3),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.pieces != pieces;
}
