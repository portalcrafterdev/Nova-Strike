import 'package:flutter/material.dart';

import '../../game/components/power_up.dart';
import '../../game/nova_game.dart';
import '../../levels/difficulty_curve.dart';
import '../../levels/level_spec.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../widgets/nova_button.dart';

/// The heads up display.
///
/// Everything here is a Flutter widget driven by notifiers on the game, so the
/// game loop never lays out text and the display never costs a frame.
class Hud extends StatefulWidget {
  const Hud({required this.game, super.key});

  final NovaGame game;

  @override
  State<Hud> createState() => _HudState();
}

class _HudState extends State<Hud> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;

    return Stack(
      children: [
        _EdgeGlow(livesNotifier: game.livesNotifier, pulse: _pulse),
        const _TopBand(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ValueListenableBuilder<int>(
                      valueListenable: game.livesNotifier,
                      builder: (context, lives, _) => Row(
                        children: List.generate(
                          lives.clamp(0, 8),
                          (_) => const Padding(
                            padding: EdgeInsets.only(right: 3),
                            child: Icon(
                              Icons.favorite,
                              size: 16,
                              color: Palette.bossHealthBar,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Column(
                      children: [
                        ValueListenableBuilder<int>(
                          valueListenable: game.levelNotifier,
                          builder: (context, level, _) => Text(
                            game.progress.difficulty == Difficulty.medium
                                ? 'LEVEL $level'
                                : 'LEVEL $level  '
                                      '${DifficultyTuning.labelOf(game.progress.difficulty)}',
                            style: AppType.hud,
                          ),
                        ),
                        ValueListenableBuilder<String>(
                          valueListenable: game.modifierNotifier,
                          builder: (context, modifier, _) {
                            if (modifier.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              modifier,
                              style: AppType.hudSmall.copyWith(
                                color: Palette.uiAccentWarm,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const Spacer(),
                    NovaIconButton(
                      icon: Icons.pause,
                      onPressed: game.pauseGame,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    ValueListenableBuilder<int>(
                      valueListenable: game.scoreNotifier,
                      builder: (context, score, _) =>
                          Text('SCORE $score', style: AppType.hudSmall),
                    ),
                    const Spacer(),
                    ValueListenableBuilder<int>(
                      valueListenable: game.coinsNotifier,
                      builder: (context, coins, _) => Row(
                        children: [
                          const Icon(
                            Icons.monetization_on,
                            size: 12,
                            color: Palette.coin,
                          ),
                          const SizedBox(width: 4),
                          Text('$coins', style: AppType.hudSmall),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _Objective(game: game),
                  ],
                ),
                const SizedBox(height: 6),
                _BossBar(game: game),
                _EscortBar(game: game),
                _Armament(game: game),
                const Spacer(),
                _PowerUpStrip(game: game),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A dark band behind the top of the display.
///
/// Enemies enter from the top of the screen, which is exactly where the level
/// number, the score and the objective sit. Without this they fly across the
/// text and neither the text nor the enemy reads. The band fades out toward
/// the bottom so a ship never crosses a hard edge on its way in.
class _TopBand extends StatelessWidget {
  const _TopBand();

  @override
  Widget build(BuildContext context) {
    const shade = Palette.uiBackground;
    return IgnorePointer(
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.paddingOf(context).top + Metrics.hudBandHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                shade.withValues(alpha: Metrics.hudBandAlpha),
                shade.withValues(alpha: Metrics.hudBandAlpha),
                shade.withValues(alpha: 0),
              ],
              stops: const [0, Metrics.hudBandFadeStart, 1],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the level is asking for, in the corner where the wave count sits.
///
/// Most levels count waves. The objective kinds count something else, and
/// showing a wave number on a level where waves are not the point would be
/// telling the player the wrong thing.
class _Objective extends StatelessWidget {
  const _Objective({required this.game});

  final NovaGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: game.objectiveNotifier,
      builder: (context, objective, _) {
        if (objective.isEmpty) {
          return ValueListenableBuilder<WaveProgress>(
            valueListenable: game.waveNotifier,
            // Past the scripted total the level is running on its clock
            // instead of its wave list, so the total is dropped rather than
            // shown as a fraction that can never be completed.
            builder: (context, wave, _) => Text(
              wave.current > wave.total
                  ? 'WAVE ${wave.current}'
                  : 'WAVE ${wave.current}/${wave.total}',
              style: AppType.hudSmall,
            ),
          );
        }
        return ValueListenableBuilder<double>(
          valueListenable: game.survivalNotifier,
          builder: (context, seconds, _) => Text(
            seconds >= 0 ? '$objective ${seconds.ceil()}' : objective,
            style: AppType.hudSmall.copyWith(color: Palette.uiAccentWarm),
          ),
        );
      },
    );
  }
}

/// The freighter's health, on an escort level.
class _EscortBar extends StatelessWidget {
  const _EscortBar({required this.game});

  final NovaGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: game.escortNotifier,
      builder: (context, health, _) {
        if (health < 0) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('FREIGHTER', style: AppType.hudSmall),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: health,
                  minHeight: 5,
                  backgroundColor: Palette.bossHealthBack,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Palette.freighterCore,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BossBar extends StatelessWidget {
  const _BossBar({required this.game});

  final NovaGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: game.bossHealthNotifier,
      builder: (context, health, _) {
        if (health < 0) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<String>(
              valueListenable: game.bossNameNotifier,
              builder: (context, name, _) => Text(
                name.toUpperCase(),
                textAlign: TextAlign.center,
                style: AppType.hudSmall.copyWith(color: Palette.bossHealthBar),
              ),
            ),
            const SizedBox(height: 5),
            // The layers in front of the core, each shown only while it is
            // what the player's shots are going into. Without these the bar
            // below sits at full through the whole opening of six of the ten
            // fights and then drops all at once.
            ValueListenableBuilder<BossArmour>(
              valueListenable: game.bossArmourNotifier,
              builder: (context, armour, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (armour.hasPods && armour.pods > 0) ...[
                    _ArmourBar(
                      value: armour.pods,
                      tint: Palette.bossCore,
                      label: 'PODS',
                    ),
                    const SizedBox(height: 3),
                  ],
                  if (armour.hasShield && armour.shield > 0) ...[
                    _ArmourBar(
                      value: armour.shield,
                      tint: Palette.bossShield,
                      label: 'SHIELD',
                    ),
                    const SizedBox(height: 3),
                  ],
                ],
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: health,
                minHeight: Metrics.bossHealthBarHeight,
                backgroundColor: Palette.bossHealthBack,
                color: Palette.bossHealthBar,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A thin bar for one layer of boss armour, named so the player knows what
/// they are chewing through rather than watching an anonymous second bar.
class _ArmourBar extends StatelessWidget {
  const _ArmourBar({
    required this.value,
    required this.tint,
    required this.label,
  });

  final double value;
  final Color tint;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: Metrics.bossArmourLabelWidth,
          child: Text(
            label,
            style: AppType.hudSmall.copyWith(
              color: tint,
              fontSize: Metrics.bossArmourLabelSize,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value,
              minHeight: Metrics.bossArmourBarHeight,
              backgroundColor: Palette.bossHealthBack,
              color: tint,
            ),
          ),
        ),
      ],
    );
  }
}

/// Chips showing which gems are running.
class _PowerUpStrip extends StatelessWidget {
  const _PowerUpStrip({required this.game});

  final NovaGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<PowerUpType>>(
      valueListenable: game.powerUpsNotifier,
      builder: (context, active, _) {
        if (active.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final type in active)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: type.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: type.color),
                  ),
                  child: Text(
                    type.label,
                    style: AppType.hudSmall.copyWith(color: type.color),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A red glow around the screen edge while the player is on the last life.
class _EdgeGlow extends StatelessWidget {
  const _EdgeGlow({required this.livesNotifier, required this.pulse});

  final ValueNotifier<int> livesNotifier;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: livesNotifier,
      builder: (context, lives, _) {
        if (lives != 1) {
          return const SizedBox.shrink();
        }
        return IgnorePointer(
          child: AnimatedBuilder(
            animation: pulse,
            builder: (context, _) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.1,
                  colors: [
                    const Color(0x00000000),
                    Palette.dangerGlow.withValues(
                      alpha: 0.25 + 0.35 * pulse.value,
                    ),
                  ],
                  stops: const [0.65, 1],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}

/// The one line banner shown on the level a new weapon is fitted.
///
/// It fades out on its own rather than sitting there, because after the first
/// few seconds the player can see the weapon firing and does not need to be
/// told about it any more.
class _Armament extends StatelessWidget {
  const _Armament({required this.game});

  final NovaGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: game.armamentNotifier,
      builder: (context, label, _) {
        if (label.isEmpty) {
          return const SizedBox.shrink();
        }
        return TweenAnimationBuilder<double>(
          key: ValueKey(label),
          tween: Tween<double>(begin: 1, end: 0),
          duration: Duration(
            milliseconds: (Metrics.armamentBannerSeconds * 1000).round(),
          ),
          curve: Curves.easeInQuad,
          builder: (context, value, child) =>
              Opacity(opacity: value.clamp(0.0, 1.0), child: child),
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppType.hudSmall.copyWith(color: Palette.uiAccent),
            ),
          ),
        );
      },
    );
  }
}
