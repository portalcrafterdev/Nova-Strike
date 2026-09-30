import 'dart:math' as math;

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
        _TopBand(game: game),
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
                      // Lives are drawn as a fixed row of three, with the ones
                      // already spent left in place and hollowed out rather
                      // than removed. A row that shortens as you lose tells
                      // you how many you have; a row that empties tells you
                      // how many you have left out of how many there were,
                      // which is the thing actually worth knowing.
                      builder: (context, lives, _) {
                        // A revive can push the count past what the run
                        // started with, so the row grows rather than dropping
                        // the extra heart on the floor.
                        final total = math
                            .max(game.progress.lives, lives)
                            .clamp(1, 8);
                        return Row(
                          children: List.generate(
                            total,
                            (i) => Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                i < lives
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 26,
                                color: i < lives
                                    ? Palette.heartFull
                                    : Palette.heartEmptyEdge,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    _LevelPill(game: game),
                    const Spacer(),
                    NovaIconButton(
                      icon: Icons.pause,
                      onPressed: game.pauseGame,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Both ends, nothing in the middle. The coin count used to sit
                // between two spacers, which put it dead centre of the screen:
                // the column enemies fly down, directly under the level
                // number, so a wave arriving crossed it and an explosion
                // erased it. Readouts belong at the edges, where nothing is
                // flying.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: _TallyPill(game: game)),
                    Flexible(
                      child: _HudPill(child: _Objective(game: game)),
                    ),
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

/// One readout across the top of the play area.
///
/// Filled and outlined rather than bare text. The display is drawn over the
/// game, so what sits behind a number changes from frame to frame, and white
/// text over a bright explosion is unreadable at exactly the moment somebody
/// wants to check it. The band behind the top of the screen helps and is not
/// enough on its own, because the brightest thing on any frame is whatever
/// just died. A pill brings its own background with it.
class _HudPill extends StatelessWidget {
  const _HudPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Metrics.hudPillHeight,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: ShapeDecoration(
        shape: novaShape(
          edge: Palette.panelEdge,
          width: Metrics.hudPillEdge,
          bevel: Metrics.hudPillRound,
        ),
        color: Palette.panelFillLow,
      ),
      child: child,
    );
  }
}

/// Score and coins, in one pill.
///
/// One pill rather than two, because they are the two halves of the same
/// running tally and because two pills plus the objective do not fit across a
/// 320 wide phone once the score reaches six figures.
class _TallyPill extends StatelessWidget {
  const _TallyPill({required this.game});

  final NovaGame game;

  @override
  Widget build(BuildContext context) {
    return _HudPill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ValueListenableBuilder<int>(
              valueListenable: game.scoreNotifier,
              builder: (context, score, _) => Text(
                'SCORE $score',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.hudSmall,
              ),
            ),
          ),
          const SizedBox(width: 9),
          // A rule between them, so the two numbers do not read as one.
          const SizedBox(
            height: 13,
            child: VerticalDivider(
              width: Metrics.hudPillEdge,
              thickness: Metrics.hudPillEdge,
              color: Palette.panelEdge,
            ),
          ),
          const SizedBox(width: 9),
          // Big enough to recognise. At the 12 it was, the coin was four
          // pixels of gold and read as a full stop.
          const Icon(Icons.monetization_on, size: 15, color: Palette.coin),
          const SizedBox(width: 5),
          ValueListenableBuilder<int>(
            valueListenable: game.coinsNotifier,
            builder: (context, coins, _) => Text(
              '$coins',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.hudSmall.copyWith(color: Palette.uiText),
            ),
          ),
        ],
      ),
    );
  }
}

/// Which level this is, as the one readout that names where you are.
///
/// Taller than the others and sitting on a ledge, because it is the heading of
/// the screen rather than a counter on it.
class _LevelPill extends StatelessWidget {
  const _LevelPill({required this.game});

  final NovaGame game;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: Metrics.hudLevelPillHeight,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: ShapeDecoration(
            shape: novaShape(
              edge: Palette.panelEdge,
              bevel: Metrics.hudLevelPillHeight / 2,
            ),
            gradient: novaGloss(NovaTone.quiet),
            shadows: novaLift(depth: Metrics.liftDepthSmall),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<int>(
                valueListenable: game.levelNotifier,
                builder: (context, level, _) =>
                    Text('LEVEL $level', style: AppType.hud),
              ),
              // The difficulty, and only when it is not the default. It used
              // to be run on to the level number behind two spaces, which
              // made one string out of two separate facts and left the pair
              // of them looking like a typesetting mistake.
              if (game.progress.difficulty != Difficulty.medium) ...[
                const SizedBox(width: 9),
                Text(
                  DifficultyTuning.labelOf(game.progress.difficulty),
                  style: AppType.hudSmall.copyWith(color: Palette.uiTextSoft),
                ),
              ],
            ],
          ),
        ),
        // Under the pill rather than inside it, so a modifier arriving does
        // not change the width of the thing naming the level.
        ValueListenableBuilder<String>(
          valueListenable: game.modifierNotifier,
          builder: (context, modifier, _) {
            if (modifier.isEmpty) {
              return const SizedBox.shrink();
            }
            return Text(
              modifier,
              style: AppType.hudSmall.copyWith(color: Palette.uiAccentWarm),
            );
          },
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
  const _TopBand({required this.game});

  final NovaGame game;

  @override
  Widget build(BuildContext context) {
    const shade = Palette.uiBackground;
    return IgnorePointer(
      // A boss adds a name, a phase and two more bars to the top of the
      // screen, and the band has to grow with them. Left fixed, the bar sits
      // on the boss's own hull and neither one reads.
      child: ValueListenableBuilder<double>(
        valueListenable: game.bossHealthNotifier,
        builder: (context, health, child) => SizedBox(
          width: double.infinity,
          height:
              MediaQuery.paddingOf(context).top +
              Metrics.hudBandHeight +
              (health >= 0 ? Metrics.hudBandBossExtra : 0),
          child: child,
        ),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.hudSmall,
            ),
          );
        }
        return ValueListenableBuilder<double>(
          valueListenable: game.survivalNotifier,
          builder: (context, seconds, _) => Text(
            seconds >= 0 ? '$objective ${seconds.ceil()}' : objective,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
            Row(
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  size: 20,
                  color: Palette.star,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: game.bossNameNotifier,
                    builder: (context, name, _) => Text(
                      name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.hud.copyWith(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Which phase, out of how many. A bar on its own says how much
                // is left; this says how much harder it is about to get, and
                // the two together are what make the fight readable.
                Text(
                  'PHASE ${Tuning.bossPhaseAt(health)} OF '
                  '${Tuning.bossPhases}',
                  style: AppType.hudSmall.copyWith(color: Palette.uiTextSoft),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _HealthBar(value: health),
            const SizedBox(height: 6),
            // The layers in front of the core. Without these the bar above
            // sits at full through the whole opening of six of the ten fights
            // and then drops all at once.
            //
            // Shown whenever the boss has the layer, even at empty, rather
            // than only while it has something left. A row that appears and
            // disappears mid fight moves everything under it, and a broken
            // shield you can still see is the clearest possible signal that
            // the shots are finally reaching the core.
            ValueListenableBuilder<BossArmour>(
              valueListenable: game.bossArmourNotifier,
              builder: (context, armour, _) {
                if (!armour.hasShield && !armour.hasPods) {
                  return const SizedBox.shrink();
                }
                return Row(
                  children: [
                    if (armour.hasShield)
                      Expanded(
                        child: _ArmourBar(
                          value: armour.shield,
                          tint: Palette.bossShield,
                          icon: Icons.shield_rounded,
                          label: 'Shield',
                        ),
                      ),
                    if (armour.hasShield && armour.hasPods)
                      const SizedBox(width: 10),
                    if (armour.hasPods)
                      Expanded(
                        child: _ArmourBar(
                          value: armour.pods,
                          tint: Palette.shipInterceptor,
                          icon: Icons.battery_full_rounded,
                          label: 'Side pods',
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// The boss's own health, as the one heavy bar on the screen.
///
/// Thick, hard cornered at the ends and outlined, so it reads as a gauge
/// rather than as one more thin line in a heads up display that already has
/// several. Measured rather than laid out as a fraction, so the last sliver
/// of a boss is still a visible sliver.
class _HealthBar extends StatelessWidget {
  const _HealthBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final fraction = value.clamp(0.0, 1.0);
    return Container(
      height: Metrics.bossHealthBarHeight,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Palette.uiBackground,
        borderRadius: BorderRadius.circular(Metrics.bossHealthBarHeight / 2),
        border: Border.all(color: Palette.panelEdge, width: 2.5),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final filled = constraints.maxWidth * fraction;
          return Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: fraction <= 0
                  ? 0
                  : filled.clamp(6.0, constraints.maxWidth),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  Metrics.bossHealthBarHeight / 2,
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFF8FA8), Palette.bossHealthBar],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A thin bar for one layer of boss armour, marked with an icon so the player
/// knows what they are chewing through rather than watching an anonymous
/// second bar.
class _ArmourBar extends StatelessWidget {
  const _ArmourBar({
    required this.value,
    required this.tint,
    required this.icon,
    required this.label,
  });

  final double value;
  final Color tint;
  final IconData icon;

  /// Read out by a screen reader, and the reason the icon can stay wordless.
  final String label;

  @override
  Widget build(BuildContext context) {
    final fraction = value.clamp(0.0, 1.0);
    return Semantics(
      label: label,
      value: '${(fraction * 100).round()} percent',
      child: Row(
        children: [
          Icon(icon, size: 15, color: fraction > 0 ? tint : Palette.uiLocked),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: Metrics.bossArmourBarHeight + 4,
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: Palette.uiBackground,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Palette.uiPanelLight, width: 2),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) => Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: constraints.maxWidth * fraction,
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
