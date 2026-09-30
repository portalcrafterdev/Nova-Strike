import 'package:flutter/material.dart';

import 'tutorial_controller.dart';

/// The keys the upgrade page's coach marks point at.
///
/// The row keys belong to the first row in the list, whatever that row happens
/// to be, because the lesson is about how a row works rather than about that
/// particular upgrade.
class UpgradeTutorialTargets {
  const UpgradeTutorialTargets._({
    required this.purse,
    required this.row,
    required this.price,
  });

  factory UpgradeTutorialTargets.forScreen() => UpgradeTutorialTargets._(
    purse: GlobalKey(debugLabel: 'upgrade.purse'),
    row: GlobalKey(debugLabel: 'upgrade.row'),
    price: GlobalKey(debugLabel: 'upgrade.price'),
  );

  /// The coin count at the top of the page.
  final GlobalKey purse;

  /// The whole of the first upgrade.
  final GlobalKey row;

  /// Its buy button.
  final GlobalKey price;
}

/// The lesson shown the first time the upgrade page is opened.
///
/// Every step explains rather than asks, and that is deliberate here in a way
/// it usually is not. The only thing to press on this page spends the player's
/// coins, and a tutorial must not decide for somebody that they are buying
/// something. An anywhere step puts one blocker over the whole screen, so the
/// buy button underneath cannot be hit by accident while the mark is up.
List<TutorialStep> upgradeTutorialSteps(UpgradeTutorialTargets targets) => [
  TutorialStep(
    id: 'purse',
    target: targets.purse,
    caption: 'The coins you have to spend. You earn them by flying levels.',
    advance: TutorialAdvance.anywhere,
  ),
  TutorialStep(
    id: 'row',
    target: targets.row,
    caption:
        'One upgrade. The bars underneath show how many of its five tiers '
        'you have bought.',
    advance: TutorialAdvance.anywhere,
  ),
  TutorialStep(
    id: 'price',
    target: targets.price,
    caption: 'Tap the price to buy the next tier. Each one costs more.',
    advance: TutorialAdvance.anywhere,
    radius: 14,
  ),
];

/// Versioned, so a rewritten lesson can be shown again to somebody who saw the
/// old one.
const String upgradeTutorialFlag = 'tutorial.upgrade.v1';
