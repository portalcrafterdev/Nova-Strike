// Every boss in the game, checked one archetype at a time.
//
// Six of the ten carry weak points or a shield arc, and the core takes nothing
// at all until those are gone. That is the design. What was not the design was
// the readout: it showed core hit points and nothing else, so the bar sat at
// full while the player emptied their guns into the opening of the fight and
// then dropped in one step the moment the core was exposed.
import 'package:flame_test/flame_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/game/components/boss.dart';
import 'package:novastrike/game/nova_game.dart';
import 'package:novastrike/levels/boss_catalog.dart';
import 'package:novastrike/levels/difficulty_curve.dart';
import 'package:novastrike/levels/level_generator.dart';
import 'package:novastrike/audio/audio_controller.dart';
import 'package:novastrike/state/player_progress.dart';
import 'package:novastrike/state/save_service.dart';
import 'package:novastrike/ui/overlays/hud.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nova_game_test.dart' show buildGame, clearingTick, tick;

/// The level whose boss is archetype [index], counting from zero.
///
/// Archetype is `(chapter - 1) % 10` and every fifteenth level is a boss, so
/// the first ten boss levels walk the whole catalogue.
int bossLevelFor(int index) => (index + 1) * Tuning.levelsPerChapter;

/// Runs the level until the boss has arrived and finished its entry.
///
/// The wait for the entry is a plain tick rather than a clearing one. Killing
/// something every single frame keeps the world inside the hit stop a heavy
/// kill triggers, and at two percent speed the entry never finishes.
Future<Boss> bossOf(NovaGame game) async {
  for (var i = 0; i < 90 && game.boss == null; i++) {
    await clearingTick(game, 1);
  }
  final boss = game.boss;
  expect(boss, isNotNull, reason: 'the boss never arrived');

  for (var i = 0; i < 20 && boss!.isEntering; i++) {
    await tick(game, Tuning.bossEntryDuration);
  }
  expect(boss!.isEntering, isFalse, reason: 'the boss never finished arriving');
  return boss;
}

/// Puts one shot into the boss, into a pod first while any is standing.
void shootBoss(NovaGame game, Boss boss, double amount) {
  for (final pod in boss.pods) {
    if (pod.isMounted && pod.hp > 0) {
      pod.takeDamage(amount);
      return;
    }
  }
  boss.takeDamage(amount, at: boss.position.clone());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  test('the first ten boss levels cover every archetype exactly once', () {
    final seen = <String>{};
    for (var i = 0; i < BossCatalog.archetypes.length; i++) {
      final spec = LevelGenerator.generate(bossLevelFor(i)).boss;
      expect(
        spec,
        isNotNull,
        reason: 'level ${bossLevelFor(i)} has no boss on it',
      );
      seen.add(spec!.name);
    }
    expect(
      seen,
      hasLength(BossCatalog.archetypes.length),
      reason: 'two boss levels share an archetype',
    );
  });

  for (var index = 0; index < BossCatalog.archetypes.length; index++) {
    final archetype = BossCatalog.archetypes[index];
    final level = bossLevelFor(index);

    group('${archetype.name} on level $level', () {
      testWithGame<NovaGame>('can be brought down', () => buildGame(level), (
        game,
      ) async {
        await game.ready();
        final boss = await bossOf(game);
        final bite = boss.spec.maxHp / 40;

        for (var i = 0; i < 400 && boss.isMounted && boss.hp > 0; i++) {
          shootBoss(game, boss, bite);
          await clearingTick(game, 1 / 30);
        }

        expect(
          boss.hp,
          lessThanOrEqualTo(0),
          reason: '${archetype.name} cannot be killed',
        );
      });

      testWithGame<NovaGame>(
        'shows the damage as it lands',
        () => buildGame(level),
        (game) async {
          await game.ready();
          final boss = await bossOf(game);
          final bite = boss.spec.maxHp / 60;

          // Split in two, because the two halves of a fight fail differently.
          // While armour stands the core cannot be touched at all, so the
          // question is whether anything on screen moves. Once it is gone the
          // question is whether the health bar moves.
          final armoured = <double>[];
          final exposed = <double>[];

          for (var i = 0; i < 120 && boss.isMounted && boss.hp > 0; i++) {
            final blocked = boss.podsAlive || boss.hasShield;
            shootBoss(game, boss, bite);
            await clearingTick(game, 1 / 30);

            final armour = game.bossArmourNotifier.value;
            if (blocked) {
              armoured.add(
                boss.podsAlive ? armour.pods : armour.shield,
              );
            } else {
              exposed.add(game.bossHealthNotifier.value);
            }
          }

          if (archetype.weakPoints > 0 || archetype.hasShieldArc) {
            expect(
              armoured.length,
              greaterThan(3),
              reason: '${archetype.name} armour was gone before it was read',
            );
            expect(
              armoured.toSet().length,
              greaterThan(3),
              reason:
                  '${archetype.name} reads the same shot after shot while its '
                  'armour is taking the hits, so the opening of the fight '
                  'looks like nothing is happening',
            );
            expect(
              armoured.first,
              greaterThan(armoured.last),
              reason: '${archetype.name} armour never reads as worn down',
            );
          } else {
            expect(
              armoured,
              isEmpty,
              reason: '${archetype.name} reported armour it does not have',
            );
          }

          expect(
            exposed.length,
            greaterThan(3),
            reason: '${archetype.name} core was never exposed',
          );
          expect(
            exposed.toSet().length,
            greaterThan(3),
            reason: '${archetype.name} health bar does not move as it is hit',
          );
          expect(exposed.first, greaterThan(exposed.last));
        },
      );
    });
  }

  testWithGame<NovaGame>(
    'a shielded boss reports its arc from the moment it arrives',
    // Aegis Warden is the first archetype carrying an arc.
    () => buildGame(bossLevelFor(3)),
    (game) async {
      await game.ready();
      final boss = await bossOf(game);

      expect(boss.spec.hasShieldArc, isTrue);
      final armour = game.bossArmourNotifier.value;
      expect(armour.hasShield, isTrue, reason: 'the arc is not reported');
      // The ship fires on its own, so the arc has already taken a little by
      // the time the boss has finished arriving. It should be barely dented,
      // not full to the last decimal.
      expect(armour.shield, greaterThan(0.5));
      expect(
        game.bossHealthNotifier.value,
        closeTo(1, 0.001),
        reason: 'the core took damage through an intact arc',
      );
    },
  );

  testWithGame<NovaGame>(
    'a boss with no armour reports none',
    // Hammerhead has neither pods nor an arc, so its bar is the whole story
    // and the display must not grow rows for layers that do not exist.
    () => buildGame(bossLevelFor(0)),
    (game) async {
      await game.ready();
      final boss = await bossOf(game);

      expect(boss.spec.hasShieldArc, isFalse);
      expect(boss.spec.weakPoints, 0);
      final armour = game.bossArmourNotifier.value;
      expect(armour.hasShield, isFalse);
      expect(armour.hasPods, isFalse);
    },
  );

  testWithGame<NovaGame>(
    'the arc coming back for the last phase is reported too',
    () => buildGame(bossLevelFor(3)),
    (game) async {
      // Phase three restores half the arc on the archetypes that carry one.
      // Left unreported, the health bar simply stops moving again and the
      // player is given no reason why.
      await game.ready();
      final boss = await bossOf(game);

      for (final pod in boss.pods) {
        pod.takeDamage(pod.maxHp);
      }
      boss.shieldHp = 0;
      boss.takeDamage(
        boss.spec.maxHp * (1 - Tuning.bossPhaseThreeThreshold) + 1,
        at: boss.position.clone(),
      );
      await clearingTick(game, 0.1);

      expect(boss.phase, 3);
      expect(boss.shieldHp, greaterThan(0), reason: 'the arc did not return');
      expect(
        game.bossArmourNotifier.value.shield,
        closeTo(boss.shieldFraction, 0.001),
        reason: 'the returning arc is not on the display',
      );
    },
  );

  testWithGame<NovaGame>(
    'a pod being worn down moves the readout before it dies',
    // Vulcan Array is the first archetype with pods and no arc, so the pod
    // reading is not masked by a shield.
    () => buildGame(bossLevelFor(1)),
    (game) async {
      await game.ready();
      final boss = await bossOf(game);
      expect(boss.spec.weakPoints, greaterThan(0));

      final before = game.bossArmourNotifier.value.pods;
      final pod = boss.pods.firstWhere((p) => p.isMounted && p.hp > 0);
      // A scratch, nowhere near enough to destroy it.
      pod.takeDamage(pod.maxHp * 0.25);

      final after = game.bossArmourNotifier.value.pods;
      expect(
        after,
        lessThan(before),
        reason: 'wearing a pod down shows nothing until it dies',
      );
      expect(pod.hp, greaterThan(0), reason: 'the pod was destroyed outright');
    },
  );

  hudTests();
}

/// What the player actually sees of all this.
void hudTests() {
  testWidgets('the boss bar shows the layer taking the hits', (tester) async {
    final save = SaveService();
    await save.init();
    final game = NovaGame(
      audio: AudioController(save),
      progress: PlayerProgress(save),
      levelNumber: bossLevelFor(3),
    )..spec = LevelGenerator.generate(bossLevelFor(3));

    Future<void> show() async {
      await tester.pumpWidget(
        MaterialApp(home: Material(child: Hud(game: game))),
      );
      await tester.pump();
    }

    // The bars carry icons rather than written labels now, which is what let
    // them sit side by side instead of stacking. They are found by the
    // description a screen reader would announce.
    final pods = find.bySemanticsLabel('Side pods');
    final shield = find.bySemanticsLabel('Shield');

    // A shielded boss with pods still standing shows both.
    game.bossNameNotifier.value = 'AEGIS WARDEN';
    game.bossHealthNotifier.value = 1;
    game.bossArmourNotifier.value = const BossArmour(shield: 0.8, pods: 0.5);
    await show();
    expect(find.text('AEGIS WARDEN'), findsOneWidget);
    expect(pods, findsOneWidget);
    expect(shield, findsOneWidget);
    expect(find.text('PHASE 1 OF 3'), findsOneWidget);

    // Pods broken, arc still up. The empty bar stays on screen: a row that
    // vanishes mid fight shifts everything under it, and a visibly broken
    // layer is the clearest signal there is that the shots are getting past.
    game.bossArmourNotifier.value = const BossArmour(shield: 0.4, pods: 0);
    await tester.pump();
    expect(pods, findsOneWidget);
    expect(shield, findsOneWidget);

    // A boss whose archetype has neither never grows the row at all. That is
    // the difference between empty and absent, and it is the one the display
    // has to get right.
    game.bossArmourNotifier.value = BossArmour.none;
    await tester.pump();
    expect(pods, findsNothing);
    expect(shield, findsNothing);
    expect(find.text('AEGIS WARDEN'), findsOneWidget);
  });

  testWidgets('the boss bar counts the phase off its own health', (
    tester,
  ) async {
    // Two sources of truth for the phase is a bug waiting for the frame where
    // one updates before the other, so the readout is derived from the same
    // thresholds the boss itself switches on.
    final save = SaveService();
    await save.init();
    final game = NovaGame(
      audio: AudioController(save),
      progress: PlayerProgress(save),
      levelNumber: bossLevelFor(3),
    )..spec = LevelGenerator.generate(bossLevelFor(3));

    game.bossNameNotifier.value = 'AEGIS WARDEN';
    game.bossArmourNotifier.value = BossArmour.none;

    for (final step in <List<Object>>[
      [1.0, 'PHASE 1 OF 3'],
      [Tuning.bossPhaseTwoThreshold, 'PHASE 2 OF 3'],
      [0.5, 'PHASE 2 OF 3'],
      [Tuning.bossPhaseThreeThreshold, 'PHASE 3 OF 3'],
      [0.02, 'PHASE 3 OF 3'],
    ]) {
      game.bossHealthNotifier.value = step.first as double;
      await tester.pumpWidget(
        MaterialApp(home: Material(child: Hud(game: game))),
      );
      await tester.pump();
      expect(find.text(step.last as String), findsOneWidget);
    }
  });
}
