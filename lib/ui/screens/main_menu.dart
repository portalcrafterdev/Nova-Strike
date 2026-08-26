import 'package:flutter/material.dart';

import '../../app.dart';
import '../../audio/sfx.dart';
import '../../levels/difficulty_curve.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../widgets/difficulty_bar.dart';
import '../widgets/nova_button.dart';
import '../widgets/play_games_bar.dart';
import '../widgets/ship_mark.dart';
import '../widgets/star_field.dart';
import 'game_screen.dart';
import 'hangar_screen.dart';
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const ShipMark(),
                          const SizedBox(height: 4),
                          Text('NOVA', style: AppType.titleGlow),
                          Text(
                            'STRIKE',
                            style: AppType.titleGlow.copyWith(
                              color: Palette.uiAccent,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const SizedBox(width: 210, child: RuleMark()),
                          const SizedBox(height: 12),
                          Text(
                            'LEVEL ${progress.highestLevelUnlocked} OF '
                            '${Tuning.totalLevels}',
                            style: AppType.hudSmall,
                          ),
                          const SizedBox(height: 16),
                          _Stat(
                            coins: progress.coins,
                            stars: progress.totalStars,
                          ),
                          const SizedBox(height: 14),
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
                            onOpenRanks: () {
                              scope.audio.play(Sfx.buttonTap);
                              Navigator.of(
                                context,
                              ).pushNamed(LeaderboardScreen.route);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // The setting sits directly above PLAY, because it
                      // decides what PLAY is about to hand the player and it
                      // changes the level number in the line above it.
                      DifficultyBar(
                        progress: progress,
                        onChanged: (difficulty) {
                          scope.audio.play(Sfx.buttonTap);
                          progress.setDifficulty(difficulty);
                        },
                      ),
                      const SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          NovaButton(
                            label: 'PLAY',
                            primary: true,
                            icon: Icons.play_arrow,
                            onPressed: () {
                              scope.audio.play(Sfx.buttonTap);
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => GameScreen(
                                    levelNumber: progress.highestLevelUnlocked,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          NovaButton(
                            label: 'ENDLESS',
                            icon: Icons.all_inclusive,
                            onPressed: () {
                              scope.audio.play(Sfx.buttonTap);
                              Navigator.of(context).push(
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
                          Row(
                            children: [
                              Expanded(
                                child: NovaButton(
                                  label: 'LEVELS',
                                  icon: Icons.grid_view,
                                  onPressed: () {
                                    scope.audio.play(Sfx.buttonTap);
                                    Navigator.of(
                                      context,
                                    ).pushNamed(LevelMap.route);
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: NovaButton(
                                  label: 'HANGAR',
                                  icon: Icons.rocket_launch,
                                  onPressed: () {
                                    scope.audio.play(Sfx.buttonTap);
                                    Navigator.of(
                                      context,
                                    ).pushNamed(HangarScreen.route);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Full width, because at half width the label comes
                          // out as UPGRA and a button that cannot say what it
                          // does is not a button.
                          NovaButton(
                            label: 'UPGRADES',
                            icon: Icons.upgrade,
                            onPressed: () {
                              scope.audio.play(Sfx.buttonTap);
                              Navigator.of(
                                context,
                              ).pushNamed(UpgradeScreen.route);
                            },
                          ),
                          const SizedBox(height: 12),
                          NovaButton(
                            label: 'SETTINGS',
                            icon: Icons.settings,
                            onPressed: () {
                              scope.audio.play(Sfx.buttonTap);
                              Navigator.of(
                                context,
                              ).pushNamed(SettingsScreen.route);
                            },
                          ),
                        ],
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

class _Stat extends StatelessWidget {
  const _Stat({required this.coins, required this.stars});

  final int coins;
  final int stars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Chip(icon: Icons.monetization_on, tint: Palette.coin, value: coins),
        const SizedBox(width: 12),
        _Chip(icon: Icons.star, tint: Palette.star, value: stars),
      ],
    );
  }
}

/// A readout in a chamfered pill: coins on the left, stars on the right.
class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.tint, required this.value});

  final IconData icon;
  final Color tint;
  final int value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: novaShape(edge: Palette.panelEdge),
        color: Palette.panelFill,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: tint, size: 16),
            const SizedBox(width: 8),
            Text('$value', style: AppType.hud),
          ],
        ),
      ),
    );
  }
}
