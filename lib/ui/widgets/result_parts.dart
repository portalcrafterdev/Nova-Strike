import 'package:flutter/material.dart';

import '../../levels/difficulty_curve.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import 'nova_button.dart';

/// A number with thousands separators, for the one place a score is read
/// rather than watched ticking up.
///
/// Written out rather than pulled from intl, because the game ships no other
/// localised text and a whole package for one comma is not worth the weight.
String formatCount(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      out.write(',');
    }
    out.write(digits[i]);
  }
  return out.toString();
}

/// The timing of a result sheet arriving.
///
/// Held in one place because the parts have to agree: the stars cannot start
/// before the banner has landed, and the panel should not start before the
/// stars have finished being counted. Spread these across the widgets that
/// use them and the sequence drifts the first time one duration is tuned.
class ResultTiming {
  const ResultTiming._();

  /// The whole sequence, which every interval below is a fraction of.
  static const Duration total = Duration(milliseconds: 2100);

  static const Duration bannerBegin = Duration.zero;
  static const Duration bannerFor = Duration(milliseconds: 340);
  static const Duration starsBegin = Duration(milliseconds: 300);
  static const Duration hintBegin = Duration(milliseconds: 1150);
  static const Duration panelBegin = Duration(milliseconds: 1250);
  static const Duration countBegin = Duration(milliseconds: 1360);
  static const Duration countFor = Duration(milliseconds: 720);

  /// The way out arrives almost at once and never waits on the celebration.
  /// A player who has seen this sheet a hundred times should not have to sit
  /// through it again to reach the next level.
  static const Duration buttonsBegin = Duration(milliseconds: 120);

  /// One interval of [total], as the fractions a [CurvedAnimation] wants.
  static Interval window(
    Duration begin,
    Duration length, {
    Curve curve = Curves.easeOutCubic,
  }) {
    final span = total.inMilliseconds;
    final start = (begin.inMilliseconds / span).clamp(0.0, 1.0);
    final end = ((begin.inMilliseconds + length.inMilliseconds) / span).clamp(
      0.0,
      1.0,
    );
    return Interval(start, end <= start ? 1.0 : end, curve: curve);
  }
}

/// Fades a part of a result in and lifts it into place.
///
/// The lift is small on purpose. A sheet whose parts fly in from off screen
/// takes longer to read than one where they simply arrive.
class Reveal extends StatelessWidget {
  const Reveal({
    required this.animation,
    required this.begin,
    required this.child,
    this.length = const Duration(milliseconds: 380),
    this.lift = 18,
    super.key,
  });

  final Animation<double> animation;
  final Duration begin;
  final Duration length;
  final double lift;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final step = CurvedAnimation(
      parent: animation,
      curve: ResultTiming.window(begin, length),
    );
    return AnimatedBuilder(
      animation: step,
      builder: (context, inner) => Opacity(
        opacity: step.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - step.value) * lift),
          child: inner,
        ),
      ),
      child: child,
    );
  }
}

/// The banner at the top of a result, dropped in with a little weight.
class ResultBanner extends StatelessWidget {
  const ResultBanner({
    required this.text,
    required this.animation,
    super.key,
  });

  final String text;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final step = CurvedAnimation(
      parent: animation,
      curve: ResultTiming.window(
        ResultTiming.bannerBegin,
        ResultTiming.bannerFor,
        // Lands slightly past its size and settles back, which is what makes
        // it read as having arrived rather than as having faded up.
        curve: Curves.easeOutBack,
      ),
    );
    return AnimatedBuilder(
      animation: step,
      builder: (context, child) => Opacity(
        opacity: step.value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: step.value <= 0 ? 0.01 : step.value,
          child: child,
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppType.display,
      ),
    );
  }
}

/// A number that runs up to its value instead of being printed.
///
/// The counting is the point: a total that is simply there was decided by the
/// game, and a total that climbs was earned by the player. It lands on the
/// exact value rather than on whatever the last frame happened to round to.
class CountUp extends StatelessWidget {
  const CountUp({
    required this.value,
    required this.animation,
    required this.style,
    super.key,
  });

  final int value;
  final Animation<double> animation;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final step = CurvedAnimation(
      parent: animation,
      curve: ResultTiming.window(
        ResultTiming.countBegin,
        ResultTiming.countFor,
      ),
    );
    return AnimatedBuilder(
      animation: step,
      builder: (context, _) => Text(
        formatCount(step.value >= 1 ? value : (value * step.value).round()),
        maxLines: 1,
        style: style,
      ),
    );
  }
}

/// The three stars at the top of a result, with the middle one larger.
///
/// The size difference is not decoration. Three stars in a row all the same
/// size read as a progress bar; one raised in the middle reads as a prize.
///
/// They land one at a time rather than being there when the sheet opens. This
/// is the whole reward for the level, and a reward that has already happened
/// by the time you look at it is not felt as one. The empty slots are drawn
/// from the first frame, so what is being counted out is always legible.
class StarRow extends StatefulWidget {
  const StarRow({required this.earned, this.onLanded, super.key});

  final int earned;

  /// Called as each earned star lands, with its index. The sheet uses it to
  /// put a note under each one.
  final void Function(int index)? onLanded;

  /// How long one star takes to arrive, and how far apart they start.
  static const Duration fall = Duration(milliseconds: 460);
  static const Duration stagger = Duration(milliseconds: 260);

  static const double bigStar = 96;
  static const double smallStar = 72;

  @override
  State<StarRow> createState() => _StarRowState();
}

class _StarRowState extends State<StarRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Animation<double>> _steps;

  /// Which stars have already been announced, so a rebuild during the run
  /// cannot play the same note twice.
  final Set<int> _announced = <int>{};

  @override
  void initState() {
    super.initState();
    final total =
        ResultTiming.starsBegin +
        StarRow.stagger * (Tuning.starsPerLevel - 1) +
        StarRow.fall;
    _controller = AnimationController(vsync: this, duration: total);

    final span = total.inMilliseconds;
    final lead = ResultTiming.starsBegin.inMilliseconds;
    _steps = [
      for (var i = 0; i < Tuning.starsPerLevel; i++)
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            (lead + StarRow.stagger.inMilliseconds * i) / span,
            (lead +
                    StarRow.stagger.inMilliseconds * i +
                    StarRow.fall.inMilliseconds) /
                span,
            // Overshoot and settle. A star that stops dead on arrival reads as
            // a sprite being switched on; one that springs reads as landing.
            curve: Curves.elasticOut,
          ),
        ),
    ];

    _controller.addListener(_announce);
    // Started from didChangeDependencies instead, because whether to animate
    // at all depends on the MediaQuery and that is not readable here.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.status != AnimationStatus.dismissed) {
      return;
    }
    // Somebody who has asked their phone to stop animating things is told the
    // result rather than shown it arriving.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  void _announce() {
    for (var i = 0; i < widget.earned && i < _steps.length; i++) {
      // Half way through its own spring, which is where the star reads as
      // having hit rather than as still on its way.
      if (_steps[i].value >= 0.5 && _announced.add(i)) {
        widget.onLanded?.call(i);
      }
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_announce)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final middle = Tuning.starsPerLevel ~/ 2;
    return SizedBox(
      height: StarRow.bigStar,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < Tuning.starsPerLevel; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _Star(
                filled: i < widget.earned,
                size: i == middle ? StarRow.bigStar : StarRow.smallStar,
                arrival: _steps[i],
              ),
            ),
        ],
      ),
    );
  }
}

class _Star extends StatelessWidget {
  const _Star({
    required this.filled,
    required this.size,
    required this.arrival,
  });

  final bool filled;
  final double size;
  final Animation<double> arrival;

  @override
  Widget build(BuildContext context) {
    // The empty slot is not animated. It is the shape of what was missed and
    // it should be there from the start, so the ones that do land are landing
    // into somewhere rather than out of nowhere.
    final star = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Two stars stacked: a darker one a little larger behind, which
          // gives the shape an outline without needing a stroked icon.
          Icon(
            Icons.star_rounded,
            size: size,
            color: filled ? const Color(0xFF8A5A00) : Palette.starEmpty,
          ),
          Icon(
            Icons.star_rounded,
            size: size * 0.84,
            color: filled ? Palette.star : Palette.uiPanel,
          ),
        ],
      ),
    );

    if (!filled) {
      return star;
    }

    return AnimatedBuilder(
      animation: arrival,
      builder: (context, child) {
        // elasticOut leaves and re-enters the 0 to 1 range, so the scale is
        // clamped at the bottom only: the overshoot above one is the point,
        // and a negative scale would flip the star inside out.
        final t = arrival.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: t <= 0 ? 0 : t, child: child),
        );
      },
      child: star,
    );
  }
}

/// A row of small boxes, each a label over a number.
///
/// Used where a result has two or three figures worth comparing against each
/// other. A panel of lines is for reading down; this is for reading across.
class StatBoxRow extends StatelessWidget {
  const StatBoxRow({
    required this.boxes,
    required this.animation,
    super.key,
  });

  final List<StatBox> boxes;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    // Stretch would ask for infinite height inside a scroll view, and the
    // boxes have to be the same height or the row looks broken when one
    // number wraps. IntrinsicHeight is the one that gives both, and three
    // boxes is far too few for its cost to matter.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < boxes.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: Reveal(
                animation: animation,
                begin:
                    ResultTiming.panelBegin + Duration(milliseconds: 110 * i),
                lift: 10,
                child: _Box(box: boxes[i], animation: animation),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One box in a [StatBoxRow].
class StatBox {
  const StatBox({required this.label, required this.count, this.tint});

  final String label;
  final int count;

  /// Overrides the colour of the number, for the one that is worth a glance.
  final Color? tint;
}

class _Box extends StatelessWidget {
  const _Box({required this.box, required this.animation});

  final StatBox box;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: novaShape(edge: Palette.panelEdge, bevel: 20),
        color: Palette.panelFill,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              box.label,
              maxLines: 1,
              style: AppType.hudSmall.copyWith(letterSpacing: 1),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: CountUp(
                value: box.count,
                animation: animation,
                style: AppType.hud.copyWith(
                  fontSize: 23,
                  color: box.tint ?? Palette.uiText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One line inside a [ResultPanel].
class ResultRow {
  const ResultRow({
    required this.icon,
    required this.tint,
    required this.label,
    this.value,
    this.count,
    this.valueTint,
  }) : assert(
         value != null || count != null,
         'a row shows either a name or a number',
       );

  final IconData icon;
  final Color tint;
  final String label;

  /// A name, shown as it is.
  final String? value;

  /// A number, which runs up to itself instead of being printed.
  final int? count;

  /// Overrides the colour of the value, for the one row that names a thing
  /// rather than counting one.
  final Color? valueTint;
}

/// What a run paid, as a panel of labelled numbers.
class ResultPanel extends StatelessWidget {
  const ResultPanel({required this.rows, required this.animation, super.key});

  final List<ResultRow> rows;

  /// The sheet's entrance, which the lines and the counting hang off.
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Reveal(
      animation: animation,
      begin: ResultTiming.panelBegin,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: novaShape(edge: Palette.panelEdge, bevel: 24),
          color: Palette.panelFill,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < rows.length; i++)
                Reveal(
                  animation: animation,
                  // Each line a beat after the one above it, so the panel
                  // reads top to bottom rather than arriving as a block.
                  begin:
                      ResultTiming.panelBegin +
                      Duration(milliseconds: 110 * i),
                  lift: 10,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (i > 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: SizedBox(
                            height: 3,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Palette.uiPanelLight,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      _Line(row: rows[i], animation: animation),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.row, required this.animation});

  final ResultRow row;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final style = AppType.hud.copyWith(
      fontSize: row.count == null ? 17 : 21,
      color: row.valueTint ?? Palette.uiText,
    );
    return Row(
      children: [
        Icon(row.icon, size: 26, color: row.tint),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            row.label,
            style: AppType.body.copyWith(color: Palette.uiTextSoft),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: row.count != null
                ? CountUp(value: row.count!, animation: animation, style: style)
                : Text(row.value!, maxLines: 1, style: style),
          ),
        ),
      ],
    );
  }
}
