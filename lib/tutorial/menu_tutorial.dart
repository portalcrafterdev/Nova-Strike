import 'package:flutter/material.dart';

import 'hand_indicator.dart';
import 'tutorial_controller.dart';

/// The keys the menu's coach marks point at.
///
/// Built through a factory rather than handed out loose, because two steps
/// aimed at one widget have to share one key object: a second key mounted on
/// nothing leaves the sequence stalled with no mark on screen and no way
/// forward. Nothing on this menu shares one today, and the factory is what
/// keeps that decision visible when something does.
class MenuTutorialTargets {
  const MenuTutorialTargets._({
    required this.purse,
    required this.difficulty,
    required this.play,
  });

  factory MenuTutorialTargets.forMenu() => MenuTutorialTargets._(
    purse: GlobalKey(debugLabel: 'menu.purse'),
    difficulty: GlobalKey(debugLabel: 'menu.difficulty'),
    play: GlobalKey(debugLabel: 'menu.play'),
  );

  /// The coins and stars pills.
  final GlobalKey purse;

  /// The three settings.
  final GlobalKey difficulty;

  /// The way in.
  final GlobalKey play;
}

/// The first run lesson on the home screen.
///
/// Three marks, and only the last of them is a thing to press. The first two
/// point at readouts the player cannot interact with at all, which is exactly
/// what [TutorialAdvance.anywhere] is for: without it they could only be
/// explained by a step waiting forever for an interaction the widget does not
/// offer.
///
/// It ends on PLAY on purpose. That step navigates away, and a step that
/// navigates has to be the last one or the next mark would be measuring a key
/// mounted on a screen that has gone.
List<TutorialStep> menuTutorialSteps(MenuTutorialTargets targets) => [
  TutorialStep(
    id: 'purse',
    target: targets.purse,
    caption: 'Coins and stars you have earned. Spend coins in the hangar.',
    advance: TutorialAdvance.anywhere,
  ),
  TutorialStep(
    id: 'difficulty',
    target: targets.difficulty,
    caption: 'Pick how hard it should be. Each one keeps its own progress.',
    advance: TutorialAdvance.anywhere,
    radius: 20,
  ),
  TutorialStep(
    id: 'play',
    target: targets.play,
    caption: 'Tap PLAY to fly your first mission.',
    gesture: HandGesture.tap,
    radius: 26,
  ),
];

/// The flag, versioned so a rewritten lesson can be shown again to somebody who
/// saw the old one.
const String menuTutorialFlag = 'tutorial.menu.v1';
