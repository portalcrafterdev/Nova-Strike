import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/app.dart';
import 'package:novastrike/ads/ads_backend.dart';
import 'package:novastrike/ads/ads_controller.dart';
import 'package:novastrike/audio/audio_controller.dart';
import 'package:novastrike/levels/difficulty_curve.dart';
import 'package:novastrike/levels/level_generator.dart';
import 'package:novastrike/levels/level_spec.dart';
import 'package:novastrike/services/game_services_controller.dart';
import 'package:novastrike/state/achievement_catalog.dart';
import 'package:novastrike/state/player_progress.dart';
import 'package:novastrike/game/nova_game.dart';
import 'package:novastrike/state/save_service.dart';
import 'package:novastrike/ui/overlays/pause_overlay.dart';
import 'package:novastrike/state/ship_catalog.dart';
import 'package:novastrike/ui/screens/achievements_screen.dart';
import 'package:novastrike/ui/screens/game_over_sheet.dart';
import 'package:novastrike/ui/screens/hangar_screen.dart';
import 'package:novastrike/ui/screens/leaderboard_screen.dart';
import 'package:novastrike/ui/screens/level_complete_sheet.dart';
import 'package:novastrike/ui/screens/level_map.dart';
import 'package:novastrike/ui/screens/main_menu.dart';
import 'package:novastrike/ui/screens/settings_screen.dart';
import 'package:novastrike/ui/screens/upgrade_screen.dart';
import 'package:novastrike/theme/palette.dart';
import 'package:novastrike/ui/widgets/menu_parts.dart';
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
    // The shipped id table, which is still placeholders, so no screen under
    // test ever reaches for a platform channel that has no answer here.
    games: GameServicesController(platform: TargetPlatform.android),
    ads: AdsController(backend: const NoAdsBackend()),
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
    expect(find.text('UPGRADE'), findsOneWidget);
    expect(find.text('ENDLESS'), findsOneWidget);
    expect(find.text('HANGAR'), findsOneWidget);

    // Settings lost its row and became the icon in the top corner. It is the
    // one thing on this menu a player opens once, so it is still here and
    // still one tap, but it no longer takes a slot from the ways to play.
    expect(
      find.byIcon(Icons.settings_rounded),
      findsOneWidget,
      reason: 'there is no way to reach settings from the menu',
    );

    // How far through the campaign the player is, now a bar with the two
    // numbers at its ends rather than one sentence.
    expect(find.text('LEVEL 1'), findsOneWidget);
    expect(find.text('1500'), findsOneWidget);
  });

  testWidgets('the campaign bar shows something on the first level', (
    tester,
  ) async {
    // One level in fifteen hundred is 0.07 percent. Drawn as a plain fraction
    // of the width that is a quarter of a pixel, so the bar reads as empty for
    // the first several hundred levels and looks broken to every new player.
    // Nobody building this notices, because the save being tested with is
    // always further along than the save a new player has.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: ProgressPill(level: 1, total: Tuning.totalLevels),
          ),
        ),
      ),
    );
    await tester.pump();

    final fills = tester
        .widgetList<Container>(find.byType(Container))
        .where((box) {
          final decoration = box.decoration;
          return decoration is BoxDecoration &&
              decoration.color == Palette.panelFillLit;
        })
        .toList();
    expect(fills, isNotEmpty, reason: 'the bar has no fill at all');

    final painted = tester.renderObject<RenderBox>(find.byWidget(fills.first));
    expect(
      painted.size.width,
      greaterThanOrEqualTo(painted.size.height),
      reason: 'the fill is thinner than it is tall, so it is not visible',
    );
  });

  testWidgets('the menu offers sign in without opening another screen', (
    tester,
  ) async {
    // Signing in is a once ever thing done on the way past. Behind two taps it
    // may as well not be there.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final scope = await scopeFor(const MainMenu());
    await tester.pumpWidget(scope);
    await tester.pump();

    expect(tester.takeException(), isNull, reason: 'the menu does not lay out');
    // The strip says what it is over two lines rather than one shouted one,
    // so the invitation and the service it signs into are checked separately.
    expect(
      find.text('Sign in'),
      findsOneWidget,
      reason: 'there is no way to sign in from the menu',
    );
    expect(
      find.text(scope.games.serviceName),
      findsOneWidget,
      reason: 'the strip does not say which service it signs into',
    );
    // And the way through to the boards is right beside it.
    expect(find.byIcon(Icons.leaderboard_rounded), findsOneWidget);
  });

  testWidgets('the ranks screen opens from the menu and stands on its own', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final scope = await scopeFor(const MainMenu());
    await tester.pumpWidget(
      AppScope(
        audio: scope.audio,
        progress: scope.progress,
        save: scope.save,
        games: scope.games,
        ads: scope.ads,
        child: const MaterialApp(home: LeaderboardScreen()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull, reason: 'the screen does not lay out');

    // The store is not set up in this build, so the screen has to be worth
    // opening on the strength of the numbers held on the phone alone.
    expect(find.text('YOUR RUN'), findsOneWidget);
    expect(find.text('Levels cleared'), findsOneWidget);
    expect(find.text('Stars'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
    // The ids are still placeholders in this build, so the screen has to say
    // why a score would go nowhere rather than pretending it went somewhere.
    // Both boards and all fifteen badges have real ids now, so the note that
    // explains what is still missing must not be on screen. It reappears by
    // itself if an id is ever removed or a badge added without one.
    expect(
      find.textContaining('still need ids'),
      findsNothing,
      reason: 'the screen claims ids are missing when they are all in',
    );
  });

  testWidgets('the menu picks the setting before it offers PLAY', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final scope = await scopeFor(const MainMenu());
    await tester.pumpWidget(scope);
    await tester.pump();

    expect(tester.takeException(), isNull, reason: 'the menu does not lay out');
    for (final difficulty in Difficulty.values) {
      expect(
        find.text(DifficultyTuning.labelOf(difficulty)),
        findsOneWidget,
        reason: '${difficulty.name} is not offered on the menu',
      );
    }
    expect(scope.progress.difficulty, DifficultyTuning.starting);

    // Easy is open from the start. Hard is not, and tapping it must do
    // nothing rather than quietly dropping the player into it.
    await tester.tap(find.text(DifficultyTuning.labelOf(Difficulty.hard)));
    await tester.pump();
    expect(scope.progress.difficulty, DifficultyTuning.starting);

    await tester.tap(find.text(DifficultyTuning.labelOf(Difficulty.easy)));
    await tester.pump();
    expect(scope.progress.difficulty, Difficulty.easy);
  });

  testWidgets('the achievements screen lists every badge', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // Enough progress that some are earned and some are not, so both states
    // are actually built rather than only the locked one.
    SharedPreferences.setMockInitialValues(<String, Object>{
      SaveService.keyHighestLevel: 40,
      SaveService.keyLifetimeEnemies: 250,
      SaveService.keyPerfectLevels: 3,
    });
    final scope = await scopeFor(const AchievementsScreen());
    await tester.pumpWidget(scope);
    await tester.pump();

    expect(tester.takeException(), isNull, reason: 'the screen does not lay out');
    expect(
      find.textContaining('OF ${AchievementCatalog.all.length} EARNED'),
      findsOneWidget,
    );

    // The list scrolls, so walk it and check every badge shows up. A hidden
    // one that is not earned shows as HIDDEN on purpose.
    final scrollable = find.byType(Scrollable).first;
    for (final badge in AchievementCatalog.all) {
      if (badge.hidden && !badge.earnedBy(scope.progress)) {
        continue;
      }
      await tester.scrollUntilVisible(
        find.text(badge.name.toUpperCase()),
        150,
        scrollable: scrollable,
      );
      expect(
        find.text(badge.name.toUpperCase()),
        findsOneWidget,
        reason: '${badge.id} is missing from the list',
      );
    }
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

  testWidgets('the hangar lays out and shows every hull', (tester) async {
    // The cards used to end in a Spacer, which needs a height to push against
    // and does not have one inside a scrolling list. Every card threw, and the
    // screen came up empty. There was no test on this screen at all, which is
    // how it shipped.
    await tester.pumpWidget(await scopeFor(const HangarScreen()));
    await tester.pump();

    expect(
      tester.takeException(),
      isNull,
      reason: 'the hangar does not lay out',
    );
    for (final ship in ShipCatalog.ships) {
      expect(
        find.text(ship.name.toUpperCase()),
        findsOneWidget,
        reason: '${ship.name} is missing from the hangar',
      );
    }
    // The hull the player starts on is the one being flown, and the ones they
    // have not bought say what they cost.
    expect(find.text('FLYING'), findsOneWidget);
    expect(find.textContaining('NEEDS'), findsWidgets);
  });

  testWidgets('a bought hull becomes the one being flown', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SaveService.keyCoins: 99999,
    });
    await tester.pumpWidget(await scopeFor(const HangarScreen()));
    await tester.pump();

    final interceptor = ShipCatalog.ships.firstWhere(
      (ship) => ship.id != ShipCatalog.starter,
    );
    await tester.tap(find.text('BUY ${interceptor.cost}'));
    // The sky behind the screen never stops moving, so this pumps a fixed
    // number of frames rather than waiting for the tree to go still.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));

    expect(find.text('FLYING'), findsOneWidget);
    expect(find.text('SELECT'), findsOneWidget);
  });

  testWidgets('a level on the map is big enough to read and to hit', (
    tester,
  ) async {
    // The map used to put all fifteen levels of a chapter on one line, from
    // when the game was going to be landscape. Portrait left each one about
    // twenty pixels across.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await scopeFor(const LevelMap()));
    await tester.pump();

    expect(tester.takeException(), isNull, reason: 'the map does not lay out');

    final tile = tester.getSize(find.text('1'));
    expect(
      tester.getSize(find.ancestor(
        of: find.text('1'),
        matching: find.byType(InkWell),
      ).first).width,
      greaterThanOrEqualTo(44),
      reason: 'a level tile is too small for a thumb',
    );
    expect(tile.height, greaterThan(0));
  });

  testWidgets('nothing sounds while the game is off the screen', (
    tester,
  ) async {
    // Pausing the music player when the app leaves was not enough on its own.
    // The player lives outside the engine, so a track asked for after the app
    // had already gone started anyway and the phone played it with the game
    // nowhere in sight.
    final save = SaveService();
    await save.init();
    final audio = AudioController(save);
    final games = GameServicesController(platform: TargetPlatform.android);
    final ads = AdsController(backend: const NoAdsBackend());
    await tester.pumpWidget(
      AppScope(
        audio: audio,
        progress: PlayerProgress(save)..load(),
        save: save,
        games: games,
        ads: ads,
        child: NovaStrikeApp(
          audio: audio,
          progress: PlayerProgress(save)..load(),
          save: save,
          games: games,
          ads: ads,
        ),
      ),
    );
    await tester.pump();
    expect(audio.appVisible, isTrue);

    for (final gone in const [
      AppLifecycleState.inactive,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
    ]) {
      await audio.setAppVisible(true);
      tester.binding.handleAppLifecycleStateChanged(gone);
      await tester.pump();
      expect(
        audio.appVisible,
        isFalse,
        reason: 'the game keeps making noise while $gone',
      );

      // A level starting behind the player's back must not start a track.
      await audio.playMusic('battle_a');
      expect(audio.currentTrack, 'battle_a', reason: 'the track is forgotten');
    }

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(audio.appVisible, isTrue);

    await audio.flush();
  });

  testWidgets('every sheet says what its buttons do', (tester) async {
    // These used to put the summary and the choices side by side, which left
    // each button half a portrait screen wide and turned QUIT TO MENU into
    // QUI and NEXT LEVEL into NEX. A button that cannot say what it does is
    // not a button.
    //
    // It earned its keep a second time when the button face grew from 16pt
    // monospace to 21pt Baloo2: QUIT TO MENU stopped fitting, and the label
    // was cut to HOME rather than the type being shrunk back.
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
      PauseOverlay(game: game): ['RESUME', 'RESTART', 'HOME'],
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
