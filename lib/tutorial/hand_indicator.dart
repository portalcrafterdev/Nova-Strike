import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// What the hand is being asked to demonstrate.
enum HandGesture {
  /// The finger comes down and ripples leave it. The composition does this
  /// itself, so the playhead is driven straight from the run.
  tap,

  /// The hand glides along a path, with a faint track behind it and an
  /// arrowhead at the end. The composition holds its resting frame while the
  /// travel happens in Dart.
  swipe,

  /// The hand hovers and bobs without pressing.
  ///
  /// Not decoration and not optional. A finger jabbing with ripples coming off
  /// it says "press this" while the caption says "tap anywhere", which points
  /// the player at the one place the instruction does not mean. The overlay
  /// forces this for every anywhere step, overriding whatever the step asked
  /// for, because leaving that to whoever writes the step means it will be
  /// wrong in a month and the mistake is invisible in review.
  point,
}

/// Everything about the asset that the code depends on.
///
/// Kept together because a swapped file breaks all of it at once and throws
/// nothing: it would simply render in its own colours, at its own speed, with
/// the hand in the wrong place. assets/lottie/SOURCE.md carries the same
/// numbers, and a test measures the fingertip back out of a render.
class HandArt {
  const HandArt._();

  static const String asset = 'assets/lottie/hand_tap.json';

  /// 41 frames at 25fps. The run has to be exactly one cycle long: Lottie maps
  /// a controller's 0 to 1 onto the whole composition, so a controller
  /// spanning four cycles plays the composition once at quarter speed.
  static const Duration cycle = Duration(milliseconds: 1640);

  /// Where the fingertip sits inside the box, as a fraction of it.
  ///
  /// Nearly a third of the way down, because the 600x600 canvas carries a lot
  /// of air above the hand. Measured off a render with the delegates applied,
  /// not derived from the transform chain and not taken off the bare file,
  /// which is wrong the moment the stroke is thinned because that moves the
  /// outer edge in.
  static const Offset hotspot = Offset(0.402, 0.296);

  // The file ships black fill on black outline, which on a dark scrim reads as
  // a transparent hand with a black border. The colours live here rather than
  // in the JSON so the palette stays next to the rest of the app's and a
  // swapped file cannot quietly arrive in somebody else's scheme.
  static const Color fill = Color(0xFFFFFFFF);
  static const Color line = Color(0xFF000000);
  static const Color ripple = Color(0xFFFFFFFF);

  static final LottieDelegates delegates = LottieDelegates(
    values: [
      ValueDelegate.color(const [
        'hand_tap_01 Outlines',
        'Group 1',
        'Fill 1',
      ], value: fill),
      ValueDelegate.strokeColor(const [
        'hand_tap_01 Outlines',
        'Group 2',
        'Stroke 1',
      ], value: line),
      // '**' is a wildcard for the rest of the path.
      ValueDelegate.strokeColor(const ['Shape Layer 3', '**'], value: ripple),
      ValueDelegate.strokeColor(const ['Shape Layer 4', '**'], value: ripple),
    ],
  );
}

/// How far the hand reaches below its own fingertip.
///
/// A hand is mostly below the point it is pointing with, so over a target near
/// the bottom of the screen most of it would be off screen.
double handReach(double box) => box * (1 - HandArt.hotspot.dy);

/// The hand drawn over the thing being taught.
///
/// Placed by its fingertip rather than by its box, turned upside down when it
/// would otherwise fall off the bottom of the screen, and given its travel in
/// Dart rather than in the asset.
class HandIndicator extends StatefulWidget {
  const HandIndicator({
    required this.tip,
    required this.gesture,
    this.travel = Offset.zero,
    this.box = 120,
    this.cycles = 3,
    super.key,
  });

  /// Where the fingertip must land, in overlay coordinates.
  final Offset tip;

  final HandGesture gesture;

  /// For [HandGesture.swipe]: how far and which way it goes.
  ///
  /// A runtime value, because a Lottie file fixes its motion at author time
  /// and rotating a baked sideways sweep to point downward lays the hand on
  /// its side.
  final Offset travel;

  /// Side of the hand's square box.
  final double box;

  /// How many passes before it settles.
  ///
  /// Finite on purpose. Lottie's repeat defaults to true, and a looping
  /// animation hangs pumpAndSettle forever rather than failing it, so an
  /// infinite hand is a test suite that never finishes and never says why.
  final int cycles;

  @override
  State<HandIndicator> createState() => _HandIndicatorState();
}

class _HandIndicatorState extends State<HandIndicator>
    with TickerProviderStateMixin {
  /// One pass of the gesture, re-run from a status listener.
  late final AnimationController _run;

  /// The composition's own playhead.
  ///
  /// Separate from [_run] because point and swipe hold a single frame while
  /// something else, the bob or the travel, moves. One controller cannot do
  /// both.
  late final AnimationController _frame;

  int _done = 0;

  @override
  void initState() {
    super.initState();
    // A placeholder until onLoaded has the real one off the composition.
    _run = AnimationController(vsync: this, duration: HandArt.cycle)
      ..addStatusListener(_onCycle)
      ..addListener(_drivePlayhead);
    _frame = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_run.status != AnimationStatus.dismissed || _done > 0) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      // Reduce motion gets a still hand holding its resting pose.
      _run.value = 0;
      _frame.value = 0;
    } else {
      _run.forward();
    }
  }

  void _drivePlayhead() {
    // Only a tap plays the composition. The others hold the resting frame.
    _frame.value = widget.gesture == HandGesture.tap ? _run.value : 0;
  }

  void _onCycle(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) {
      return;
    }
    _done++;
    if (_done < widget.cycles) {
      _run.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _run
      ..removeStatusListener(_onCycle)
      ..removeListener(_drivePlayhead)
      ..dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = widget.box;
    final height = MediaQuery.sizeOf(context).height;

    // Come down from above when reaching up from below would put the hand off
    // the bottom of the screen.
    final fromAbove = widget.tip.dy + handReach(box) > height;

    final art = Lottie.asset(
      HandArt.asset,
      controller: _frame,
      delegates: HandArt.delegates,
      fit: BoxFit.contain,
      onLoaded: (composition) {
        _frame.duration = composition.duration;
        // The hard coded value is only a placeholder until the file is here.
        _run.duration = composition.duration;
      },
    );

    return AnimatedBuilder(
      animation: _run,
      builder: (context, child) {
        final t = _run.value;
        final offset = switch (widget.gesture) {
          HandGesture.swipe => widget.travel * Curves.easeInOut.transform(t),
          // A small bob, so a hovering hand still reads as alive.
          HandGesture.point => Offset(0, -4 * math.sin(t * math.pi * 2)),
          HandGesture.tap => Offset.zero,
        };
        final tip = widget.tip + offset;

        Widget hand = child!;
        if (fromAbove) {
          // Turned, not mirrored. A mirrored hand does not read as a hand
          // reaching down, it reads as a glyph. Turning about the fingertip
          // also leaves the fingertip where it was, because that is the point
          // being turned about.
          hand = Transform.rotate(
            angle: math.pi,
            alignment: Alignment(
              HandArt.hotspot.dx * 2 - 1,
              HandArt.hotspot.dy * 2 - 1,
            ),
            child: hand,
          );
        }

        return Stack(
          children: [
            if (widget.gesture == HandGesture.swipe &&
                widget.travel != Offset.zero)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _TrackPainter(
                      from: widget.tip,
                      to: widget.tip + widget.travel,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: tip.dx - HandArt.hotspot.dx * box,
              top: tip.dy - HandArt.hotspot.dy * box,
              width: box,
              height: box,
              child: IgnorePointer(child: hand),
            ),
          ],
        );
      },
      child: art,
    );
  }
}

/// The track a swipe travels along, with an arrowhead at the far end.
///
/// Drawn here rather than in the asset for the same reason the travel is: the
/// direction is a runtime value and an asset fixes it at author time.
class _TrackPainter extends CustomPainter {
  const _TrackPainter({required this.from, required this.to});

  final Offset from;
  final Offset to;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0x88FFFFFF)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(from, to, line);

    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    const head = 14.0;
    final arrow = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - head * math.cos(angle - 0.4),
        to.dy - head * math.sin(angle - 0.4),
      )
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - head * math.cos(angle + 0.4),
        to.dy - head * math.sin(angle + 0.4),
      );
    canvas.drawPath(arrow, line);
  }

  @override
  bool shouldRepaint(_TrackPainter old) => old.from != from || old.to != to;
}
