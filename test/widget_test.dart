import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/app.dart';
import 'package:novastrike/audio/audio_controller.dart';
import 'package:novastrike/levels/level_generator.dart';
import 'package:novastrike/state/player_progress.dart';
import 'package:novastrike/game/nova_game.dart';
import 'package:novastrike/state/save_service.dart';
import 'package:novastrike/ui/overlays/pause_overlay.dart';
import 'package:novastrike/ui/screens/game_over_sheet.dart';
import 'package:novastrike/ui/screens/level_complete_sheet.dart';
import 'package:novastrike/ui/screens/main_menu.dart';
import 'package:novastrike/ui/screens/settings_screen.dart';
import 'package:novastrike/ui/screens/upgrade_screen.dart';
import 'package:novastrike/ui/widgets/volume_slider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppScope> scopeFor(Widget child) async {
  final save = SaveService();
  await save.init();
  final progress = PlayerProgress(save)..load();
  return AppScope(
    audio: AudioController(save),
    progress: progress,
    save: save,
    child: MaterialApp(home: child),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('the main menu offers every way into the game', (tester) async {
    await tester.pumpWidget(await scopeFor(const MainMenu()));
    await tester.pump();

    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('LEVELS'), findsOneWidget);
    expect(find.text('UPGRADES'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('ENDLESS'), findsOneWidget);
    expect(find.text('HANGAR'), findsOneWidget);
    expect(find.textContaining('LEVEL 1 OF 1500'), findsOneWidget);
  });

  testWidgets('the settings screen has one slider per channel', (tester) async {
    await tester.pumpWidget(await scopeFor(const SettingsScreen()));
    await tester.pump();

    expect(find.byType(VolumeSlider), findsNWidgets(3));
    expect(find.text('Master'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Effects'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('dragging a slider changes the volume live', (tester) async {
    final scope = await scopeFor(const SettingsScreen());
    await tester.pumpWidget(scope);
    await tester.pump();

    final slider = find.byType(Slider).first;
    await tester.drag(slider, const Offset(-200, 0));
    await tester.pump();

    expect(scope.audio.master, lessThan(0.8));
    expect(find.text('80%'), findsNothing);

    // Let the persistence debounce run so no timer outlives the test.
    await tester.pump(AudioController.persistDebounce);
    expect(scope.save.loadAudioSettings().master, scope.audio.master);
  });

  testWidgets('muting keeps the slider values', (tester) async {
    final scope = await scopeFor(const SettingsScreen());
    await tester.pumpWidget(scope);
    await tester.pump();

    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    expect(scope.audio.muted, isTrue);
    expect(scope.audio.master, 0.8);
    expect(scope.audio.settings.effectiveSfx, 0);

    await tester.pump(AudioController.persistDebounce);
  });

  testWidgets('the upgrade screen lists every upgrade', (tester) async {
    await tester.pumpWidget(await scopeFor(const UpgradeScreen()));
    await tester.pump();

    // The list scrolls, so a row further down is not built until it is needed.
    for (final def in PlayerProgress.upgrades) {
      await tester.scrollUntilVisible(
        find.text(def.name),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(def.name), findsOneWidget);
    }
  });

  testWidgets('every sheet says what its buttons do', (tester) async {
    // These used to put the summary and the choices side by side, which left
    // each button half a portrait screen wide and turned QUIT TO MENU into
    // QUI and NEXT LEVEL into NEX. A button that cannot say what it does is
    // not a button.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final save = SaveService();
    await save.init();
    final game =
        NovaGame(
            audio: AudioController(save),
            progress: PlayerProgress(save),
            levelNumber: 1,
          )
          // The sheets read the level spec, which the game only builds when it
          // loads. Nothing here runs a game loop, so hand it one.
          ..spec = LevelGenerator.generate(1);

    final sheets = <Widget, List<String>>{
      PauseOverlay(game: game): ['RESUME', 'RESTART', 'QUIT TO MENU'],
      LevelCompleteSheet(game: game): ['NEXT LEVEL', 'REPLAY', 'MENU'],
      GameOverSheet(game: game): ['RETRY', 'MENU'],
    };

    for (final entry in sheets.entries) {
      await tester.pumpWidget(MaterialApp(home: Material(child: entry.key)));
      await tester.pump();

      for (final label in entry.value) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: ' does not fit on its button',
        );
      }
    }
  });
}
