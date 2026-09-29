// The heads up display, as laid out over the play area.
//
// The display is the one part of the game drawn on top of the thing it is
// describing, so its failures are positional rather than logical: a number in
// the wrong place is still the right number, and nothing throws. These tests
// are about where the readouts sit and whether they fit.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/audio/audio_controller.dart';
import 'package:novastrike/state/player_progress.dart';
import 'package:novastrike/state/save_service.dart';
import 'package:novastrike/game/nova_game.dart';
import 'package:novastrike/levels/level_generator.dart';
import 'package:novastrike/ui/overlays/hud.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<NovaGame> buildHudGame({int level = 4}) async {
  final save = SaveService();
  await save.init();
  return NovaGame(
    audio: AudioController(save),
    progress: PlayerProgress(save),
    levelNumber: level,
  )..spec = LevelGenerator.generate(level);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the coin count keeps out of the lane enemies fly down', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final game = await buildHudGame();
    game.coinsNotifier.value = 7;
    game.waveNotifier.value = const WaveProgress(1, 2);
    await tester.pumpWidget(
      MaterialApp(home: Material(child: Hud(game: game))),
    );
    await tester.pump();

    // Enemies enter from the top and fly down the middle, and the level pill
    // is centred up there too. A readout parked between the two is crossed by
    // every wave and wiped out by every explosion. Readouts belong at the
    // edges: everything on this row is wholly in one half or the other, and
    // nothing straddles the middle.
    //
    // Stated as a side of the screen rather than as a position, both so the
    // row can be rearranged without rewriting this and because the test font
    // is far wider than Baloo 2, which puts every measurement here further
    // toward the middle than the phone ever will.
    expect(
      tester.getRect(find.text('7')).right,
      lessThan(200),
      reason: 'the coin count reaches the middle of the screen, in the way',
    );
    expect(
      tester.getRect(find.text('SCORE 0')).right,
      lessThan(200),
      reason: 'the score reaches the middle of the screen, in the way',
    );
    expect(
      tester.getRect(find.text('WAVE 1/2')).left,
      greaterThan(200),
      reason: 'the wave count reaches the middle of the screen, in the way',
    );
  });

  testWidgets('the top readouts fit across the narrowest phone', (
    tester,
  ) async {
    // 320 wide is the narrowest Android phone still in use. The pills carry
    // their longest plausible contents: a six figure score, four figures of
    // coins, and a timed objective rather than a short wave count.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final game = await buildHudGame();
    game.scoreNotifier.value = 999999;
    game.coinsNotifier.value = 9999;
    game.objectiveNotifier.value = 'SURVIVE';
    game.survivalNotifier.value = 99;

    await tester.pumpWidget(
      MaterialApp(home: Material(child: Hud(game: game))),
    );
    await tester.pump();

    // A Row that runs out of room paints a yellow bar and throws, and the
    // throw is the part a test can see.
    expect(tester.takeException(), isNull);
  });

  testWidgets('every readout carries its own background', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final game = await buildHudGame();
    game.waveNotifier.value = const WaveProgress(1, 2);
    await tester.pumpWidget(
      MaterialApp(home: Material(child: Hud(game: game))),
    );
    await tester.pump();

    // The band behind the top of the screen is not enough on its own: the
    // brightest thing on any frame is whatever just died, and it dies in
    // front of the band, not behind it. Each readout is filled so it stays
    // legible over an explosion.
    for (final label in <String>['SCORE 0', 'LEVEL 1', 'WAVE 1/2']) {
      final filled = find
          .ancestor(
            of: find.text(label),
            matching: find.byType(DecoratedBox),
          )
          .evaluate()
          .any((element) {
            final decoration = (element.widget as DecoratedBox).decoration;
            return decoration is ShapeDecoration &&
                (decoration.color != null || decoration.gradient != null);
          });
      expect(filled, isTrue, reason: '"$label" is bare text over the game');
    }
  });
}
