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
    required this.settings,
    required this.progress,
    required this.difficulty,
    required this.play,
    required this.endless,
    required this.levels,
    required this.hangar,
    required this.upgrade,
    required this.profile,
  });

  factory MenuTutorialTargets.forMenu() => MenuTutorialTargets._(
    purse: GlobalKey(debugLabel: 'menu.purse'),
    settings: GlobalKey(debugLabel: 'menu.settings'),
    progress: GlobalKey(debugLabel: 'menu.progress'),
    difficulty: GlobalKey(debugLabel: 'menu.difficulty'),
    play: GlobalKey(debugLabel: 'menu.play'),
    endless: GlobalKey(debugLabel: 'menu.endless'),
    levels: GlobalKey(debugLabel: 'menu.levels'),
    hangar: GlobalKey(debugLabel: 'menu.hangar'),
    upgrade: GlobalKey(debugLabel: 'menu.upgrade'),
    profile: GlobalKey(debugLabel: 'menu.profile'),
  );

  final GlobalKey purse;
  final GlobalKey settings;
  final GlobalKey progress;
  final GlobalKey difficulty;
  final GlobalKey play;
  final GlobalKey endless;
  final GlobalKey levels;
  final GlobalKey hangar;
  final GlobalKey upgrade;
  final GlobalKey profile;
}

/// The first run lesson on the home screen: every control, in reading order.
///
/// All but the last are [TutorialAdvance.anywhere], because they are naming
/// what a button does rather than asking for it to be pressed. Pressing most
/// of them would leave the menu, and a step that navigates has to be the last
/// one or the next mark would be measuring a key mounted on a screen that has
/// gone. So the sequence explains its way down the screen and finishes on the
/// one control worth actually pressing.
///
/// It is a long sequence for a first run. That is the cost of naming every
/// button, and it is paid once: the flag is written when PLAY is tapped.
List<TutorialStep> menuTutorialSteps(MenuTutorialTargets targets) => [
  TutorialStep(
    id: 'purse',
    target: targets.purse,
    caption: 'Coins and stars you have earned so far.',
    advance: TutorialAdvance.anywhere,
  ),
  TutorialStep(
    id: 'settings',
    target: targets.settings,
    caption: 'Sound, haptics and how the game is set up live in here.',
    advance: TutorialAdvance.anywhere,
    radius: 26,
  ),
  TutorialStep(
    id: 'progress',
    target: targets.progress,
    caption: 'How far through the campaign you are. There are 1500 levels.',
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
    id: 'endless',
    target: targets.endless,
    caption: 'Endless never finishes. Fly as far as you can for a score.',
    advance: TutorialAdvance.anywhere,
    radius: 24,
  ),
  TutorialStep(
    id: 'levels',
    target: targets.levels,
    caption: 'Every level you have unlocked, one chapter at a time.',
    advance: TutorialAdvance.anywhere,
  ),
  TutorialStep(
    id: 'hangar',
    target: targets.hangar,
    caption: 'New ships to fly. Each one handles differently.',
    advance: TutorialAdvance.anywhere,
  ),
  TutorialStep(
    id: 'upgrade',
    target: targets.upgrade,
    caption: 'Spend your coins here to make your ship stronger.',
    advance: TutorialAdvance.anywhere,
  ),
  TutorialStep(
    id: 'profile',
    target: targets.profile,
    caption: 'Who you are signed in as, your badges and the world rankings.',
    advance: TutorialAdvance.anywhere,
  ),
  TutorialStep(
    id: 'play',
    target: targets.play,
    caption: 'Tap PLAY to fly your next mission.',
    gesture: HandGesture.tap,
    radius: 26,
  ),
];

/// The flag, versioned so a rewritten lesson can be shown again to somebody who
/// saw the old one.
const String menuTutorialFlag = 'tutorial.menu.v2';
