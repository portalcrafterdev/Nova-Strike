import 'package:flutter/material.dart';

import 'hand_indicator.dart';
import 'tutorial_controller.dart';

/// The keys the flight lesson points at.
///
/// Both lessons are taught on the same piece of glass, so they must share one
/// key object. Two keys for one widget leaves the second lesson pointing at a
/// key mounted on nothing, and the sequence stalls with no mark on screen and
/// no way forward. The private constructor and the factory are what enforce
/// that, rather than a comment somebody deletes.
class FlightTutorialTargets {
  const FlightTutorialTargets._({required this.up, required this.down});

  /// One key for both, because there is one surface catching both drags.
  factory FlightTutorialTargets.wholeScreen() {
    final glass = GlobalKey(debugLabel: 'flight.glass');
    return FlightTutorialTargets._(up: glass, down: glass);
  }

  final GlobalKey up;
  final GlobalKey down;
}

/// Ids the game screen reports as the player flies.
class FlightLesson {
  const FlightLesson._();

  static const String up = 'fly_up';
  static const String down = 'fly_down';
  static const String shoot = 'shoot';
}

/// How far the hand travels while demonstrating a drag.
const double _travel = 150;

/// Learning to fly: drag forward, then drag back.
///
/// Both are [TutorialAdvance.target] steps, so the player has to actually move
/// the ship. Nothing here is explained at them; the lesson is the doing of it,
/// and the game runs for a moment between the two so they see what their own
/// finger did.
List<TutorialStep> flightTutorialSteps(
  FlightTutorialTargets targets, {
  Rect? Function()? enemy,
}) => [
  TutorialStep(
    id: FlightLesson.up,
    target: targets.up,
    caption: 'Drag anywhere and pull up. Your ship follows your finger.',
    gesture: HandGesture.swipe,
    travel: const Offset(0, -_travel),
    padding: 0,
    radius: 28,
  ),
  TutorialStep(
    id: FlightLesson.down,
    target: targets.down,
    caption: 'Now drag back down. Keep your thumb clear of your ship.',
    gesture: HandGesture.swipe,
    travel: const Offset(0, _travel),
    padding: 0,
    radius: 28,
  ),
  // The third lesson waits for something to teach with. Until an enemy is on
  // the glass its spot is null, the overlay draws nothing, and the game runs
  // on as normal: a lesson about shooting cannot begin before there is
  // anything to shoot, and nothing arrives while the game is held still.
  //
  // It explains rather than asks, which is the opposite of the two above, and
  // it has to be. The gun is on a timer of its own and the player has no
  // button for it, so there is no action to wait for. What they need told is
  // the one thing the screen cannot show them: that lining up is the whole of
  // aiming, because nothing they do makes the ship fire.
  if (enemy != null)
    TutorialStep(
      id: FlightLesson.shoot,
      target: targets.up,
      spot: enemy,
      caption:
          'Your ship fires on its own. Slide under an enemy and your shots '
          'will find it.',
      advance: TutorialAdvance.anywhere,
      padding: 16,
      radius: 40,
    ),
];

/// The one level the flight lesson is taught on.
const int flightLessonLevel = 1;

/// Whether this run is the one that teaches flying.
///
/// Level 1 and only level 1, every time it is opened rather than once ever.
/// Two reasons for tying it to a level instead of to a flag. A player whose
/// first game is level 40, because they came back to an old save or jumped
/// there from the map, was being taught the controls in the middle of a fight
/// hard enough to kill them while they read. And on level 1 the lesson costs
/// nothing to anyone who does not need it: two drags, which is what they were
/// about to do anyway.
///
/// Endless is excluded even though it starts at level 1. It is not the
/// campaign's first level, and somebody choosing endless has already played.
bool teachesFlightOn({required int level, required bool endless}) =>
    !endless && level == flightLessonLevel;

/// Kept because the controller takes one, and read only if [teachesFlightOn]
/// is ever paired with a once only sequence again. The flight lesson runs in
/// every time mode, where the flag is never consulted.
const String flightTutorialFlag = 'tutorial.flight.v1';
