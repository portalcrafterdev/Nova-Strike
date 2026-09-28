import 'package:flutter/material.dart';

import '../../app.dart';
import '../../audio/sfx.dart';
import '../../levels/difficulty_curve.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../widgets/ad_banner.dart';
import '../widgets/difficulty_bar.dart';
import '../widgets/mascot_ship.dart';
import '../widgets/menu_parts.dart';
import '../widgets/nova_button.dart';
import '../widgets/play_games_bar.dart';
import '../widgets/star_field.dart';
import 'game_screen.dart';
import 'hangar_screen.dart';
import 'achievements_screen.dart';
import 'leaderboard_screen.dart';
import 'level_map.dart';
import 'settings_screen.dart';
import 'upgrade_screen.dart';

/// The first screen: play, pick a level, spend coins, change settings.
class MainMenu extends StatelessWidget {
  const MainMenu({super.key});

  static const String route = '/menu';

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final progress = scope.progress;

    return Scaffold(
      backgroundColor: Palette.spaceDeep,
      // Menu screens only. Never over the play area.
      bottomNavigationBar: AdBanner(ads: scope.ads),
      body: StarField(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([progress, scope.games]),
            builder: (context, _) {
              // The game runs portrait, so the title sits above the way in.
              // Centred when the screen has room for it and scrolling when it
              // does not, because a short phone must not clip the way in.
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // What you have, then who you are, sit at the top out of
                      // the way. Settings is an icon rather than a row on the
                      // list, because it is the one thing here a player opens
                      // once and then never again.
                      Row(
                        children: [
                          StatPill(
                            icon: Icons.monetization_on_rounded,
                            tint: Palette.coin,
                            value: '${progress.coins}',
                          ),
                          const SizedBox(width: 10),
                          StatPill(
                            icon: Icons.star_rounded,
                            tint: Palette.star,
                            value: '${progress.totalStars}',
                          ),
                          const Spacer(),
                          RoundIconButton(
                            icon: Icons.settings_rounded,
                            label: 'Settings',
                            onPressed: () {
                              scope.audio.play(Sfx.buttonTap);
                              Navigator.of(
                                context,
                              ).pushNamed(SettingsScreen.route);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Center(child: MascotShip()),
                      const SizedBox(height: 2),
                      // The wordmark is the one place the colour font is
                      // worth its weight. Nothing here sets a colour on it,
                      // because a COLRv1 face carries its own and would
                      // ignore one anyway.
                      const Text(
                        'NOVA\nSTRIKE',
                        textAlign: TextAlign.center,
                        style: AppType.display,
                      ),
                      const SizedBox(height: 12),
                      ProgressPill(
                        level: progress.highestLevelUnlocked,
                        total: Tuning.totalLevels,
                      ),
                      const SizedBox(height: 12),
                      // The setting sits directly above PLAY, because it
                      // decides what PLAY is about to hand the player and it
                      // changes the level number in the bar above it.
                      DifficultyBar(
                        progress: progress,
                        onChanged: (difficulty) {
                          scope.audio.play(Sfx.buttonTap);
                          progress.setDifficulty(difficulty);
                        },
                      ),
                      const SizedBox(height: 4),
                      NovaButton(
                        label: 'PLAY',
                        primary: true,
                        icon: Icons.play_arrow_rounded,
                        height: 76,
                        onPressed: () async {
                          scope.audio.play(Sfx.buttonTap);
                          final navigator = Navigator.of(context);
                          // Before the level, not over it. The ad has to be
                          // gone by the time the ship is flying.
                          await scope.ads.onGameStart();
                          navigator.push(
                            MaterialPageRoute<void>(
                              builder: (_) => GameScreen(
                                levelNumber: progress.highestLevelUnlocked,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      NovaButton(
                        label: 'ENDLESS',
                        icon: Icons.all_inclusive_rounded,
                        tone: NovaTone.fun,
                        height: 58,
                        onPressed: () async {
                          scope.audio.play(Sfx.buttonTap);
                          final navigator = Navigator.of(context);
                          await scope.ads.onGameStart();
                          navigator.push(
                            MaterialPageRoute<void>(
                              builder: (_) => const GameScreen(
                                levelNumber: 1,
                                endless: true,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      // Three tiles rather than three more full width rows.
                      // Everything below PLAY is somewhere you go between
                      // runs, and it should look like a shelf rather than
                      // like more ways to start the game.
                      Row(
                        children: [
                          Expanded(
                            child: MenuTile(
                              icon: Icons.grid_view_rounded,
                              label: 'LEVELS',
                              tint: Palette.uiAccent,
                              onPressed: () {
                                scope.audio.play(Sfx.buttonTap);
                                Navigator.of(
                                  context,
                                ).pushNamed(LevelMap.route);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: MenuTile(
                              icon: Icons.rocket_launch_rounded,
                              label: 'HANGAR',
                              tint: Palette.shipInterceptor,
                              onPressed: () {
                                scope.audio.play(Sfx.buttonTap);
                                Navigator.of(
                                  context,
                                ).pushNamed(HangarScreen.route);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: MenuTile(
                              icon: Icons.arrow_upward_rounded,
                              label: 'UPGRADE',
                              tint: Palette.star,
                              onPressed: () {
                                scope.audio.play(Sfx.buttonTap);
                                Navigator.of(
                                  context,
                                ).pushNamed(UpgradeScreen.route);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Signing in belongs next to who the player is, not
                      // behind a screen they have to think to open.
                      PlayGamesBar(
                        games: scope.games,
                        onSignIn: () {
                          scope.audio.play(Sfx.buttonTap);
                          if (scope.games.isSignedIn) {
                            Navigator.of(
                              context,
                            ).pushNamed(LeaderboardScreen.route);
                          } else {
                            scope.games.signIn();
                          }
                        },
                        onOpenBadges: () {
                          scope.audio.play(Sfx.buttonTap);
                          Navigator.of(
                            context,
                          ).pushNamed(AchievementsScreen.route);
                        },
                        onOpenRanks: () {
                          scope.audio.play(Sfx.buttonTap);
                          Navigator.of(
                            context,
                          ).pushNamed(LeaderboardScreen.route);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
