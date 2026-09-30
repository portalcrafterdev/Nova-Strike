import 'package:flutter/material.dart';

import 'hand_indicator.dart';
import 'tutorial_controller.dart';

/// The dim, the hole, the hand and the caption.
///
/// Everything here is mounted in an [OverlayEntry] above the Navigator, which
/// is why the whole thing is wrapped in a transparent [Material]: nothing in an
/// overlay inherits the Scaffold's, and text without one falls back to a double
/// yellow underline, in release builds too. It keeps the colour and size it was
/// given, so it presents as correctly styled text that is also inexplicably
/// underlined.
class TutorialOverlay extends StatelessWidget {
  const TutorialOverlay({required this.controller, super.key});

  final TutorialController controller;

  /// How wide a line of caption may run, by window size.
  ///
  /// Capped by measure rather than by screen width: prose is bounded by how far
  /// the eye travels back to find the next line, so the cap stays well short of
  /// the screen however wide the screen gets.
  static double captionCap(double width) {
    if (width < 600) {
      return 300;
    }
    return width < 840 ? 360 : 420;
  }

  @override
  Widget build(BuildContext context) {
    final step = controller.current;
    if (step == null) {
      return const SizedBox.shrink();
    }

    // Either a widget's key or, for something the game draws rather than
    // Flutter lays out, a rectangle handed straight over.
    Rect? found;
    if (step.spot != null) {
      found = step.spot!();
    } else {
      final targetBox =
          step.target.currentContext?.findRenderObject() as RenderBox?;
      if (targetBox != null && targetBox.hasSize && !targetBox.size.isEmpty) {
        // Global coordinates, not coordinates relative to this widget. The
        // entry covers the whole screen so the two are the same, and measuring
        // through this build context is not: findRenderObject on a stateless
        // element reaches for the first descendant, and on the first build
        // there are none yet, so it reports null and then reports the previous
        // build's empty placeholder, which puts the hole at the origin with no
        // size.
        final origin = targetBox.localToGlobal(Offset.zero);
        found = Rect.fromLTWH(
          origin.dx,
          origin.dy,
          targetBox.size.width,
          targetBox.size.height,
        );
      }
    }

    // Never paint a scrim with no hole in it. That is a full screen black
    // block with no way through and no way out, so when there is nothing to
    // point at yet the overlay shows nothing and asks again next frame.
    if (found == null || found.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.refresh());
      return const SizedBox.shrink();
    }

    if (step.spot != null) {
      // Keep asking. A widget's key stays where it was put, but a spot is a
      // thing in the game, and a thing in the game moves. Measured once, the
      // ring stays where the enemy used to be while the enemy flies out from
      // under it, and the screen holds a mark around nothing.
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.refresh());
    }

    final hole = found.inflate(step.padding);
    final screen = MediaQuery.sizeOf(context);

    final anywhere = step.advance == TutorialAdvance.anywhere;
    // Decided here rather than at the step, so it cannot be got wrong by
    // whoever writes the next one.
    final gesture = anywhere ? HandGesture.point : step.gesture;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // The dim. Painting and blocking are separate jobs done by separate
          // widgets, because hit testing stops at the first opaque hit and
          // there is no way to let a tap fall through something painted over
          // the thing it should reach. A scrim with a visual hole in it still
          // absorbs the hole.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ScrimPainter(hole: hole, radius: step.radius),
              ),
            ),
          ),

          if (anywhere)
            // One blocker, not four. Four would leave the hole dead, and the
            // one place the player is being told to look would be the one
            // place that does nothing.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: controller.nudge,
              ),
            )
          else ...[
            // Four rectangles around the hole. The hole itself has no widget
            // over it at all, so the real control gets the real pointer.
            _blocker(
              Rect.fromLTRB(0, 0, screen.width, hole.top),
              controller.nudge,
            ),
            _blocker(
              Rect.fromLTRB(0, hole.bottom, screen.width, screen.height),
              controller.nudge,
            ),
            _blocker(
              Rect.fromLTRB(0, hole.top, hole.left, hole.bottom),
              controller.nudge,
            ),
            _blocker(
              Rect.fromLTRB(hole.right, hole.top, screen.width, hole.bottom),
              controller.nudge,
            ),
          ],

          HandIndicator(
            // Remounted on every refused tap, which is what replays the hand.
            key: ValueKey('${step.id}:${controller.nudges}'),
            tip: hole.center,
            gesture: gesture,
            travel: step.travel,
          ),

          _Caption(text: step.caption, hole: hole, screen: screen),
        ],
      ),
    );
  }

  /// One side of the hole, blocked.
  ///
  /// Opaque, never translucent. Opaque is what makes hit testing stop here:
  /// with translucent a tap is absorbed but a drag still reaches the widget
  /// underneath, so a slider under the scrim can still be dragged and a tap
  /// based test will never catch it.
  static Widget _blocker(Rect rect, VoidCallback onTap) {
    if (rect.width <= 0 || rect.height <= 0) {
      // The hole touches an edge. A degenerate Positioned is worse than none.
      return const SizedBox.shrink();
    }
    return Positioned.fromRect(
      rect: rect,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap),
    );
  }
}

class _ScrimPainter extends CustomPainter {
  const _ScrimPainter({required this.hole, required this.radius});

  final Rect hole;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    // A path difference, not a clip. clipRRect has no clipOp parameter, only
    // clipRect does, so a rounded hole cannot be cut by clipping.
    final screen = Path()..addRect(Offset.zero & size);
    final cut = Path()
      ..addRRect(RRect.fromRectAndRadius(hole, Radius.circular(radius)));
    canvas.drawPath(
      Path.combine(PathOperation.difference, screen, cut),
      Paint()..color = const Color(0xCC0A0520),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(hole, Radius.circular(radius)),
      Paint()
        ..color = const Color(0xFFFFC63D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.hole != hole || old.radius != radius;
}

/// One line of caption, on whichever side of the hole has room for it.
class _Caption extends StatelessWidget {
  const _Caption({
    required this.text,
    required this.hole,
    required this.screen,
  });

  final String text;
  final Rect hole;
  final Size screen;

  /// Room a panel needs above or below the hole before that side is usable.
  static const double _needs = 96;

  /// Room it needs beside the hole. Far more than the vertical minimum,
  /// because a panel squeezed into a narrow column wraps one word, then one
  /// letter, per line.
  static const double _needsBeside = 180;

  static const double _gap = 18;
  static const double _margin = 16;

  @override
  Widget build(BuildContext context) {
    final cap = TutorialOverlay.captionCap(screen.width);
    final below = screen.height - hole.bottom;
    final above = hole.top;

    late final double? top;
    late final double? bottom;
    late final double left;
    late final double right;

    final roomLeft = hole.left;
    final roomRight = screen.width - hole.right;

    if (below >= _needs) {
      top = hole.bottom + _gap;
      bottom = null;
      left = _margin;
      right = _margin;
    } else if (above >= _needs) {
      top = null;
      bottom = screen.height - hole.top + _gap;
      left = _margin;
      right = _margin;
    } else if (roomLeft >= _needsBeside || roomRight >= _needsBeside) {
      // A target taller than the screen has to spare, such as a full height
      // control down one side. Beside it, on whichever side is clearer.
      top = hole.top.clamp(_margin, screen.height - _needs);
      bottom = null;
      if (roomRight >= roomLeft) {
        left = hole.right + _gap;
        right = _margin;
      } else {
        left = _margin;
        right = screen.width - hole.left + _gap;
      }
    } else {
      // The target is the whole screen, which is what a lesson about dragging
      // anywhere looks like. There is nothing left to avoid covering, so the
      // panel simply sits low on the glass, clear of the display at the top
      // and of the ship at the very bottom.
      //
      // Without this branch the beside case computes a left edge past the
      // right one, the panel is squeezed to nothing, and the caption comes out
      // as a column one letter wide.
      top = null;
      bottom = screen.height * 0.22;
      left = _margin;
      right = _margin;
    }

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      // Positioned with both left and right hands the child tight constraints,
      // which forces the panel to the full width whatever maxWidth it was
      // given. The Align loosens them; only then does the ConstrainedBox bite.
      // This is the most common reason a cap does not work.
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: cap),
          // So the panel never eats a tap meant for the scrim.
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xF21B1147),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF533AA8), width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: _TypedLine(text: text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The caption, revealed a character at a time.
class _TypedLine extends StatefulWidget {
  const _TypedLine({required this.text});

  final String text;

  /// About a frame and a half per character, and never longer than this for
  /// the whole line. A long caption types faster rather than taking
  /// proportionally longer: a coach mark stands between the player and the
  /// game and must not make them wait to be allowed to read a sentence.
  static const Duration perGlyph = Duration(milliseconds: 20);
  static const Duration longest = Duration(milliseconds: 900);

  @override
  State<_TypedLine> createState() => _TypedLineState();
}

class _TypedLineState extends State<_TypedLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _type;
  late List<String> _glyphs;

  @override
  void initState() {
    super.initState();
    // Split by grapheme cluster, not by code unit: code units cut an accent
    // off the letter it belongs to and a surrogate pair down the middle.
    _glyphs = widget.text.characters.toList();
    _type = AnimationController(vsync: this, duration: _durationFor(_glyphs));
  }

  static Duration _durationFor(List<String> glyphs) {
    final wanted = _TypedLine.perGlyph * glyphs.length;
    return wanted > _TypedLine.longest ? _TypedLine.longest : wanted;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_type.status != AnimationStatus.dismissed) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _type.value = 1;
    } else {
      _type.forward();
    }
  }

  @override
  void didUpdateWidget(_TypedLine old) {
    super.didUpdateWidget(old);
    // Only when the line actually changes. The overlay rebuilds on every
    // refused tap and every look for a target that was not laid out yet, and a
    // refused tap should replay the hand without snatching back a sentence
    // somebody is halfway through reading.
    if (widget.text == old.text) {
      return;
    }
    _glyphs = widget.text.characters.toList();
    _type
      ..duration = _durationFor(_glyphs)
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _type.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 15,
      height: 1.35,
      fontWeight: FontWeight.w600,
    );
    return AnimatedBuilder(
      animation: _type,
      builder: (context, _) {
        final shown = (_glyphs.length * _type.value).round();
        // The whole line is laid out from the first frame and the tail is
        // painted transparent rather than left out. Three reasons: a box that
        // grows to fit moves every frame and drags the eye off the thing the
        // caption is pointing at, wrapping is settled once so no word jumps
        // lines mid reveal, and find.text still finds the caption while it
        // types because the span's plain text is the whole line throughout.
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(text: _glyphs.take(shown).join()),
              TextSpan(
                text: _glyphs.skip(shown).join(),
                style: const TextStyle(color: Color(0x00000000)),
              ),
            ],
          ),
          style: style,
        );
      },
    );
  }
}
