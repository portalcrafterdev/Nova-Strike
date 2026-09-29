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
}

/// How far the hand travels while demonstrating a drag.
const double _travel = 150;

/// Learning to fly: drag forward, then drag back.
///
/// Both are [TutorialAdvance.target] steps, so the player has to actually move
/// the ship. Nothing here is explained at them; the lesson is the doing of it,
/// and the game runs for a moment between the two so they see what their own
/// finger did.
List<TutorialStep> flightTutorialSteps(FlightTutorialTargets targets) => [
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
];

/// Versioned, so a rewritten lesson can be shown again to somebody who saw the
/// old one.
const String flightTutorialFlag = 'tutorial.flight.v1';
