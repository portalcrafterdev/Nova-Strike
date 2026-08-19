import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/palette.dart';

/// The backdrop every menu sits on.
///
/// A menu is not a page laid over the game, it is the same space the game is
/// played in: a nebula, three depths of stars drifting down at their own
/// rates, and a vignette so the middle of the screen stays where the eye
/// lands.
///
/// Three layers rather than one painter, because only the stars move. The
/// nebula underneath and the vignette on top are painted once and never again,
/// which keeps a menu down to one pass over a few small circles per frame
/// instead of four full screen fills.
class StarField extends StatefulWidget {
  const StarField({this.child, super.key});

  /// What sits in front of the sky. A screen normally passes its whole
  /// scaffold, made transparent, so the field runs behind the app bar too.
  final Widget? child;

  @override
  State<StarField> createState() => _StarFieldState();
}

class _StarFieldState extends State<StarField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: Metrics.menuDriftSeconds),
  )..repeat();

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(child: CustomPaint(painter: _NebulaPainter())),
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _drift,
            builder: (context, _) => CustomPaint(
              painter: _StarPainter(_drift.value),
              willChange: true,
            ),
          ),
        ),
        const RepaintBoundary(child: CustomPaint(painter: _VignettePainter())),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

/// One star: a position in unit space and which depth it belongs to.
class _Star {
  const _Star(this.x, this.y, this.depth);

  final double x;
  final double y;
  final int depth;
}

/// The sky itself: deep space with two clouds hanging in it.
class _NebulaPainter extends CustomPainter {
  const _NebulaPainter();

  static final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final rect = Offset.zero & size;
    final reach = size.longestSide * Metrics.menuNebulaRadius;

    _paint
      ..shader = null
      ..color = Palette.spaceDeep;
    canvas.drawRect(rect, _paint);

    _paint.shader =
        const RadialGradient(
          colors: [Palette.menuNebulaA, Color(0x00000000)],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.26, size.height * 0.28),
            radius: reach,
          ),
        );
    canvas.drawRect(rect, _paint);

    _paint.shader =
        const RadialGradient(
          colors: [Palette.menuNebulaB, Color(0x00000000)],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.78, size.height * 0.68),
            radius: reach * 0.8,
          ),
        );
    canvas.drawRect(rect, _paint);
    _paint.shader = null;
  }

  @override
  bool shouldRepaint(_NebulaPainter old) => false;
}

/// The only layer that moves.
class _StarPainter extends CustomPainter {
  const _StarPainter(this.t);

  /// How far through one drift cycle the field is, 0 to 1.
  final double t;

  static final List<_Star> _stars = _buildStars();
  static final List<Paint> _paints = [
    Paint()..color = Palette.starFar,
    Paint()..color = Palette.starMid,
    Paint()..color = Palette.starNear,
  ];

  static List<_Star> _buildStars() {
    final rng = math.Random(Metrics.menuStarSeed);
    return [
      for (var i = 0; i < Metrics.menuStarCount; i++)
        _Star(rng.nextDouble(), rng.nextDouble(), i % 3),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in _stars) {
      // Wraps at the bottom, so the field never runs out.
      final y =
          (star.y + t * Metrics.menuStarDrift[star.depth]) % 1.0 * size.height;
      canvas.drawCircle(
        Offset(star.x * size.width, y),
        Metrics.menuStarRadius[star.depth],
        _paints[star.depth],
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.t != t;
}

/// Closes the corners in, so the middle of the screen is where the eye lands.
class _VignettePainter extends CustomPainter {
  const _VignettePainter();

  static final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final rect = Offset.zero & size;
    _paint.shader = const RadialGradient(
      colors: [Color(0x00000000), Palette.vignette],
      stops: [Metrics.menuVignetteStart, 1],
    ).createShader(rect);
    canvas.drawRect(rect, _paint);
  }

  @override
  bool shouldRepaint(_VignettePainter old) => false;
}
