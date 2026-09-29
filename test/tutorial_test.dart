import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/tutorial/flight_tutorial.dart';
import 'package:novastrike/tutorial/hand_indicator.dart';
import 'package:novastrike/tutorial/tutorial_controller.dart';
import 'package:novastrike/tutorial/tutorial_overlay.dart';

/// A screen with one real button and one real slider under the coach mark.
///
/// The button records its own presses, which is how the tests tell a real tap
/// from the tutorial synthesising one, and the slider is there because a
/// translucent blocker absorbs taps while still letting a drag through.
class _Harness extends StatefulWidget {
  const _Harness({
    required this.controller,
    required this.targetKey,
    this.onPressed,
    this.onSlide,
  });

  final TutorialController controller;
  final GlobalKey targetKey;
  final VoidCallback? onPressed;
  final ValueChanged<double>? onSlide;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  double _value = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: TutorialLauncher(
        controller: widget.controller,
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  key: widget.targetKey,
                  onPressed: () {
                    widget.onPressed?.call();
                    widget.controller.report('one');
                  },
                  child: const Text('DO IT'),
                ),
                SizedBox(
                  width: 300,
                  child: Slider(
                    value: _value,
                    onChanged: (v) {
                      setState(() => _value = v);
                      widget.onSlide?.call(v);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

TutorialController _controllerWith(
  List<TutorialStep> steps, {
  bool everyTime = true,
}) {
  return TutorialController(
    steps: steps,
    flag: 'test.v1',
    everyTime: everyTime,
    store: MemoryTutorialStore(),
  );
}

void main() {
  setUp(() {
    TutorialController.debugDisabled = false;
    TutorialController.debugStore = null;
  });

  // A real phone, not the 800x600 default. At the default a drag can miss its
  // target entirely, and a test whose gesture could never have succeeded
  // passes for the wrong reason.
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('the mark lets the real control work', () {
    testWidgets('the real handler runs and the step advances', (tester) async {
      phone(tester);
      var pressed = 0;
      final key = GlobalKey();
      final controller = _controllerWith([
        TutorialStep(id: 'one', target: key, caption: 'Press it.'),
      ]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _Harness(
          controller: controller,
          targetKey: key,
          onPressed: () => pressed++,
        ),
      );
      await tester.pump();
      expect(controller.isRunning, isTrue);

      await tester.tap(find.byKey(key));
      await tester.pump();

      // Both halves matter. The press proves the tutorial is not standing in
      // front of the button and synthesising it; the advance proves the mark
      // noticed.
      expect(pressed, 1, reason: 'the real handler did not run');
      expect(controller.isRunning, isFalse, reason: 'the step did not advance');
    });

    testWidgets('a drag under the scrim does nothing', (tester) async {
      phone(tester);
      var slid = 0;
      final key = GlobalKey();
      final controller = _controllerWith([
        TutorialStep(id: 'one', target: key, caption: 'Press it.'),
      ]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _Harness(
          controller: controller,
          targetKey: key,
          onSlide: (_) => slid++,
        ),
      );
      await tester.pump();

      // A timed drag, not a tap. With translucent blockers a tap is absorbed
      // but a drag still reaches the widget underneath, so a tap based test
      // would pass while the slider was still draggable.
      await tester.timedDrag(
        find.byType(Slider),
        const Offset(120, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pump();

      expect(slid, 0, reason: 'the slider moved through the scrim');
    });

    testWidgets('and the same drag works once the mark is gone', (
      tester,
    ) async {
      // The control half. Without it the test above could be passing because
      // the gesture never worked in the first place.
      phone(tester);
      var slid = 0;
      final key = GlobalKey();
      final controller = _controllerWith([
        TutorialStep(id: 'one', target: key, caption: 'Press it.'),
      ]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _Harness(
          controller: controller,
          targetKey: key,
          onSlide: (_) => slid++,
        ),
      );
      await tester.pump();
      controller.finish();
      await tester.pump();

      await tester.timedDrag(
        find.byType(Slider),
        const Offset(120, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pump();

      expect(slid, greaterThan(0), reason: 'the drag never worked at all');
    });

    testWidgets('a refused tap nudges without advancing', (tester) async {
      phone(tester);
      final key = GlobalKey();
      final controller = _controllerWith([
        TutorialStep(id: 'one', target: key, caption: 'Press it.'),
        TutorialStep(id: 'two', target: key, caption: 'Again.'),
      ]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_Harness(controller: controller, targetKey: key));
      await tester.pump();

      final handBefore = tester.widget<HandIndicator>(
        find.byType(HandIndicator),
      );
      // The very top of the screen is scrim, never the hole.
      await tester.tapAt(const Offset(200, 8));
      await tester.pump();

      expect(controller.nudges, 1, reason: 'the refusal was not counted');
      expect(controller.current?.id, 'one', reason: 'a refusal advanced it');
      final handAfter = tester.widget<HandIndicator>(
        find.byType(HandIndicator),
      );
      expect(
        handAfter.key,
        isNot(handBefore.key),
        reason: 'the hand was not replayed',
      );
    });
  });

  group('a step that only explains', () {
    testWidgets('advances from a tap on the hole itself', (tester) async {
      phone(tester);
      final key = GlobalKey();
      final controller = _controllerWith([
        TutorialStep(
          id: 'one',
          target: key,
          caption: 'Just look at it.',
          advance: TutorialAdvance.anywhere,
        ),
      ]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_Harness(controller: controller, targetKey: key));
      await tester.pump();

      // Four blockers would leave the hole dead, and the one place the player
      // is being told to look would be the one place that does nothing.
      await tester.tap(find.byKey(key), warnIfMissed: false);
      await tester.pump();

      expect(controller.isRunning, isFalse);
    });

    testWidgets('draws point even when the step asked for tap', (tester) async {
      phone(tester);
      final key = GlobalKey();
      final controller = _controllerWith([
        TutorialStep(
          id: 'one',
          target: key,
          caption: 'Just look at it.',
          gesture: HandGesture.tap,
          advance: TutorialAdvance.anywhere,
        ),
      ]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_Harness(controller: controller, targetKey: key));
      await tester.pump();

      // A finger jabbing with ripples coming off it says "press this" while
      // the caption says "tap anywhere".
      final hand = tester.widget<HandIndicator>(find.byType(HandIndicator));
      expect(hand.gesture, HandGesture.point);
    });
  });

  group('the caption', () {
    testWidgets('is capped well short of the screen', (tester) async {
      phone(tester);
      final key = GlobalKey();
      final controller = _controllerWith([
        TutorialStep(
          id: 'one',
          target: key,
          caption:
              'A caption long enough that it would happily run the whole '
              'width of the screen if nothing stopped it from doing so.',
        ),
      ]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_Harness(controller: controller, targetKey: key));
      await tester.pump();

      final box = tester.getSize(find.byType(Text).last);
      expect(
        box.width,
        lessThanOrEqualTo(TutorialOverlay.captionCap(400)),
        reason: 'the cap did not bite, so the Align is missing',
      );
      expect(box.width, lessThan(400));
    });

    testWidgets('sits below a target at the top of the screen', (tester) async {
      phone(tester);
      final key = GlobalKey();
      final controller = _controllerWith([
        TutorialStep(id: 'one', target: key, caption: 'Below me.'),
      ]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: TutorialLauncher(
            controller: controller,
            child: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(key: key, width: 120, height: 40),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final target = tester.getRect(find.byKey(key));
      final caption = tester.getRect(find.text('Below me.'));
      expect(caption.top, greaterThan(target.bottom));
    });

    testWidgets('does not move while it types', (tester) async {
      phone(tester);
      final key = GlobalKey();
      final controller = _controllerWith([
        TutorialStep(
          id: 'one',
          target: key,
          caption: 'A line that takes a little while to come out in full.',
        ),
      ]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_Harness(controller: controller, targetKey: key));
      await tester.pump();

      final first = tester.getRect(find.byType(Text).last);
      await tester.pump(const Duration(milliseconds: 250));
      final middle = tester.getRect(find.byType(Text).last);
      await tester.pump(const Duration(seconds: 2));
      final settled = tester.getRect(find.byType(Text).last);

      // A box that grows to fit moves every frame, and the panel is pinned to
      // the hole it describes, so a crawling box drags the eye off the one
      // thing the player is being told to look at.
      expect(middle, first);
      expect(settled, first);
    });

    testWidgets('a refused tap does not restart the typing', (tester) async {
      phone(tester);
      final key = GlobalKey();
      final controller = _controllerWith([
        TutorialStep(
          id: 'one',
          target: key,
          caption: 'Somebody is halfway through reading this sentence.',
        ),
      ]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_Harness(controller: controller, targetKey: key));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Fully typed. A refusal must replay the hand without snatching the
      // sentence back.
      await tester.tapAt(const Offset(200, 8));
      await tester.pump();

      final span = tester.widget<Text>(find.byType(Text).last).textSpan!;
      final visible = (span as TextSpan).children!.first as TextSpan;
      expect(
        visible.text,
        'Somebody is halfway through reading this sentence.',
        reason: 'the refusal restarted the typing',
      );
    });
  });

  group('the sequence cannot strand the player', () {
    testWidgets('disposing the controller takes the scrim away', (
      tester,
    ) async {
      phone(tester);
      final key = GlobalKey();
      final controller = _controllerWith([
        TutorialStep(id: 'one', target: key, caption: 'Press it.'),
      ]);

      await tester.pumpWidget(_Harness(controller: controller, targetKey: key));
      await tester.pump();
      expect(find.byType(HandIndicator), findsOneWidget);

      controller.dispose();
      await tester.pump();

      // An overlay outliving its controller is an undismissable black screen.
      expect(find.byType(HandIndicator), findsNothing);
    });

    testWidgets('leaving the screen takes it away too', (tester) async {
      phone(tester);
      final key = GlobalKey();
      final controller = _controllerWith([
        TutorialStep(id: 'one', target: key, caption: 'Press it.'),
      ]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_Harness(controller: controller, targetKey: key));
      await tester.pump();
      expect(find.byType(HandIndicator), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();

      expect(find.byType(HandIndicator), findsNothing);
    });

    testWidgets('debugDisabled stops it starting at all', (tester) async {
      phone(tester);
      TutorialController.debugDisabled = true;
      final key = GlobalKey();
      final controller = _controllerWith([
        TutorialStep(id: 'one', target: key, caption: 'Press it.'),
      ]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_Harness(controller: controller, targetKey: key));
      await tester.pump();

      expect(controller.isRunning, isFalse);
      expect(find.byType(HandIndicator), findsNothing);
    });

    testWidgets('a seen sequence does not run again', (tester) async {
      phone(tester);
      final store = MemoryTutorialStore();
      await store.markSeen('test.v1');
      final key = GlobalKey();
      final controller = TutorialController(
        steps: [TutorialStep(id: 'one', target: key, caption: 'Press it.')],
        flag: 'test.v1',
        store: store,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_Harness(controller: controller, targetKey: key));
      await tester.pump();

      expect(controller.isRunning, isFalse);
    });
  });

  group('report is safe to call unconditionally', () {
    test('an id that is not the current step is ignored', () {
      final key = GlobalKey();
      final controller = _controllerWith([
        TutorialStep(id: 'one', target: key, caption: 'a'),
        TutorialStep(id: 'two', target: key, caption: 'b'),
      ]);
      addTearDown(controller.dispose);

      // Nothing running: this must be a no-op rather than a crash, because the
      // call site never asks whether a tutorial is up.
      controller.report('one');
      expect(controller.isRunning, isFalse);
      expect(controller.index, 0);
    });
  });

  group('the flight lesson', () {
    test('both drags share one key, because they share one widget', () {
      // Two keys for one widget leaves the second lesson pointing at a key
      // mounted on nothing, and the sequence stalls with no mark on screen and
      // no way forward.
      final targets = FlightTutorialTargets.wholeScreen();
      expect(identical(targets.up, targets.down), isTrue);

      final steps = flightTutorialSteps(targets);
      expect(identical(steps[0].target, steps[1].target), isTrue);
    });

    test('it teaches by doing, not by explaining', () {
      // Both steps wait for the player to move the ship. A lesson about the
      // controls that advances on a tap anywhere has taught nothing.
      for (final step in flightTutorialSteps(
        FlightTutorialTargets.wholeScreen(),
      )) {
        expect(step.advance, TutorialAdvance.target);
        expect(step.gesture, HandGesture.swipe);
      }
    });

    test('the two drags are shown going opposite ways', () {
      final steps = flightTutorialSteps(FlightTutorialTargets.wholeScreen());
      expect(steps[0].travel.dy, lessThan(0), reason: 'up is not upward');
      expect(steps[1].travel.dy, greaterThan(0), reason: 'down is not down');
    });

    testWidgets('steering up then down finishes it', (tester) async {
      phone(tester);
      final targets = FlightTutorialTargets.wholeScreen();
      final controller = TutorialController(
        steps: flightTutorialSteps(targets),
        flag: flightTutorialFlag,
        store: MemoryTutorialStore(),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: TutorialLauncher(
            controller: controller,
            child: Scaffold(
              body: SizedBox.expand(key: targets.up),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(controller.current?.id, FlightLesson.up);

      // Dragging back down first must not skip the lesson that is up.
      controller.report(FlightLesson.down);
      expect(controller.current?.id, FlightLesson.up);

      controller.report(FlightLesson.up);
      await tester.pump();
      expect(controller.current?.id, FlightLesson.down);

      controller.report(FlightLesson.down);
      await tester.pump();
      expect(controller.isRunning, isFalse);
    });
  });

  group('the hand asset', () {
    test('still matches what the code measured off it', () {
      // A swapped file throws nothing. It renders in its own colours, at its
      // own speed, with the hand in the wrong place, so the numbers the code
      // depends on are checked against the file itself.
      final file = File('assets/lottie/hand_tap.json');
      expect(file.existsSync(), isTrue, reason: 'the hand is not in the repo');

      final json =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json['w'], 600, reason: 'the hotspot is in units of the box');
      expect(json['h'], 600);
      expect(json['fr'], 25);
      expect(json['ip'], 0);
      expect(json['op'], 41);

      // 41 frames at 25fps. The run has to be exactly one cycle long or Lottie
      // plays the whole composition at a fraction of its speed.
      expect(HandArt.cycle.inMilliseconds, closeTo(41 / 25 * 1000, 1));

      // The names the colour delegates key on. Renaming a layer in the file
      // silently drops the recolour and the hand goes back to black on black,
      // which on a dark scrim looks transparent.
      final layers = (json['layers'] as List).cast<Map<String, dynamic>>();
      final names = layers.map((l) => l['nm'] as String).toSet();
      expect(names, containsAll(['hand_tap_01 Outlines', 'Shape Layer 3']));

      final hand = layers.firstWhere(
        (l) => l['nm'] == 'hand_tap_01 Outlines',
      );
      final groups = (hand['shapes'] as List).cast<Map<String, dynamic>>();
      expect(groups.map((g) => g['nm']), containsAll(['Group 1', 'Group 2']));
      // Earlier groups paint on top, so the stroke has to come first or the
      // fill covers the outline that gives the hand its edge.
      expect(
        groups.indexWhere((g) => g['nm'] == 'Group 2'),
        lessThan(groups.indexWhere((g) => g['nm'] == 'Group 1')),
        reason: 'the fill would cover the outline',
      );
    });

    test('the hand is placed by its fingertip, not its middle', () {
      // Nearly a third of the way down the box. A hand centred on its target
      // points somewhere below it by enough to look like a layout bug.
      expect(HandArt.hotspot.dy, greaterThan(0.2));
      expect(HandArt.hotspot.dy, lessThan(0.4));
      expect(handReach(100), closeTo(70.4, 0.1));
    });
  });
}
