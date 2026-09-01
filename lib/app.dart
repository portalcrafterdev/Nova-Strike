import 'package:flutter/material.dart';

import 'ads/ads_controller.dart';
import 'audio/audio_controller.dart';
import 'services/game_services_controller.dart';
import 'state/player_progress.dart';
import 'state/save_service.dart';
import 'theme/palette.dart';
import 'theme/typography.dart';
import 'ui/screens/boot_screen.dart';
import 'ui/screens/achievements_screen.dart';
import 'ui/screens/leaderboard_screen.dart';
import 'ui/screens/level_map.dart';
import 'ui/screens/main_menu.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/hangar_screen.dart';
import 'ui/screens/upgrade_screen.dart';

/// Gives every screen the long lived services.
///
/// The game keeps no account of its own and talks to no server of its own, so
/// this is all the dependency injection it needs. [games] is the one exception
/// to the offline rule, and it is optional on purpose: a screen that does not
/// care about the store never has to be handed one.
class AppScope extends InheritedWidget {
  const AppScope({
    required this.audio,
    required this.progress,
    required this.save,
    required this.games,
    required this.ads,
    required super.child,
    super.key,
  });

  final AudioController audio;
  final PlayerProgress progress;
  final SaveService save;

  /// Google Play Games on Android, Game Center on iOS.
  final GameServicesController games;

  /// Every ad the game shows, and the rules about when it may show one.
  final AdsController ads;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing from the widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}

/// The root widget: theme, routes and the app lifecycle hooks that stop music
/// when the game goes to the background.
class NovaStrikeApp extends StatefulWidget {
  const NovaStrikeApp({
    required this.audio,
    required this.progress,
    required this.save,
    required this.games,
    required this.ads,
    super.key,
  });

  final AudioController audio;
  final PlayerProgress progress;
  final SaveService save;
  final GameServicesController games;
  final AdsController ads;

  @override
  State<NovaStrikeApp> createState() => _NovaStrikeAppState();
}

class _NovaStrikeAppState extends State<NovaStrikeApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      // Anything short of being on screen and in the player's hands counts as
      // gone. Inactive is in that list on purpose: it is the state a phone call
      // arriving or the notification shade coming down puts the app into, and
      // a game that keeps playing its battle music over a phone call is the
      // same fault as one that keeps playing after the home button.
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        widget.audio.setAppVisible(false);
      case AppLifecycleState.resumed:
        widget.audio.setAppVisible(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      audio: widget.audio,
      progress: widget.progress,
      save: widget.save,
      games: widget.games,
      ads: widget.ads,
      child: MaterialApp(
        title: 'Nova Strike',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Palette.uiBackground,
          colorScheme: const ColorScheme.dark(
            primary: Palette.uiAccent,
            secondary: Palette.uiAccentWarm,
            surface: Palette.uiPanel,
          ),
          textTheme: const TextTheme(
            bodyMedium: AppType.body,
            titleMedium: AppType.subheading,
          ),
        ),
        initialRoute: BootScreen.route,
        routes: {
          BootScreen.route: (_) => const BootScreen(),
          MainMenu.route: (_) => const MainMenu(),
          LevelMap.route: (_) => const LevelMap(),
          SettingsScreen.route: (_) => const SettingsScreen(),
          UpgradeScreen.route: (_) => const UpgradeScreen(),
          HangarScreen.route: (_) => const HangarScreen(),
          LeaderboardScreen.route: (_) => const LeaderboardScreen(),
          AchievementsScreen.route: (_) => const AchievementsScreen(),
        },
      ),
    );
  }
}
