import 'package:flutter/material.dart';

import '../../app.dart';
import '../../audio/sfx.dart';
import '../../levels/boss_catalog.dart';
import '../../levels/chapter_names.dart';
import '../../levels/difficulty_curve.dart';
import '../../levels/level_spec.dart';
import '../../state/player_progress.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../widgets/ad_banner.dart';
import '../widgets/difficulty_bar.dart';
import '../widgets/menu_parts.dart';
import '../widgets/nova_button.dart';
import '../widgets/star_field.dart';
import 'game_screen.dart';

/// The level select. One chapter at a time, fifteen levels in each.
///
/// It used to scroll through all hundred chapters at once, five levels across.
/// On a portrait phone that left each level about twenty pixels wide, which is
/// too small to read a number on and well under what a thumb can hit. A
/// chapter at a time gives each level a tile worth tapping, and paging between
/// them costs one arrow rather than a scroll through fifteen hundred.
class LevelMap extends StatefulWidget {
  const LevelMap({super.key});

  static const String route = '/levels';

  @override
  State<LevelMap> createState() => _LevelMapState();
}

class _LevelMapState extends State<LevelMap> {
  /// Three across. Five was from when this was going to be landscape.
  static const int _across = 3;

  int? _chapter;

  /// The chapter being shown, defaulting to the one the player is in.
  int chapterFor(PlayerProgress progress) =>
      _chapter ?? Tuning.chapterOf(progress.highestLevelUnlocked);

  void _step(int by, PlayerProgress progress) {
    final next = (chapterFor(progress) + by).clamp(1, Tuning.totalChapters);
    setState(() => _chapter = next);
  }

  Future<void> _play(BuildContext context, int level) async {
    final scope = AppScope.of(context);
    scope.audio.play(Sfx.buttonTap);
    final navigator = Navigator.of(context);
    await scope.ads.onGameStart();
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => GameScreen(levelNumber: level)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return StarField(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Menu screens only. Never over the play area.
        bottomNavigationBar: AdBanner(ads: scope.ads),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: scope.progress,
            builder: (context, _) {
              final progress = scope.progress;
              final chapter = chapterFor(progress);
              final first = (chapter - 1) * Tuning.levelsPerChapter + 1;
              final last = chapter * Tuning.levelsPerChapter;
              final earned = [
                for (var l = first; l <= last; l++) progress.starsFor(l),
              ].fold<int>(0, (sum, s) => sum + s);
              final possible = Tuning.levelsPerChapter * Tuning.starsPerLevel;

              // What PLAY at the bottom does. The level the player is up to
              // when that is in this chapter, and otherwise the furthest one
              // they have reached here, so browsing back never offers a level
              // they have not unlocked.
              final upNext = progress.highestLevelUnlocked.clamp(first, last);
              final canPlay = progress.isUnlocked(upNext);

              return Column(
                children: [
                  _Header(
                    chapter: chapter,
                    earned: earned,
                    possible: possible,
                    onBack: () {
                      scope.audio.play(Sfx.buttonTap);
                      Navigator.of(context).pop();
                    },
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      children: [
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: Tuning.levelsPerChapter,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: _across,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.82,
                              ),
                          itemBuilder: (context, index) {
                            final level = first + index;
                            return _LevelTile(
                              level: level,
                              unlocked: progress.isUnlocked(level),
                              isNext: level == progress.highestLevelUnlocked,
                              stars: progress.starsFor(level),
                              onTap: () => _play(context, level),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        _BossCard(
                          chapter: chapter,
                          progress: progress,
                          onTap: () => _play(context, last),
                        ),
                        const SizedBox(height: 14),
                        // Kept here rather than dropped. Each setting runs its
                        // own campaign, so this is the one screen where
                        // changing it shows its effect immediately in the
                        // tiles above.
                        DifficultyBar(
                          progress: progress,
                          onChanged: (difficulty) async {
                            scope.audio.play(Sfx.buttonTap);
                            await progress.setDifficulty(difficulty);
                            // Each setting keeps its own place, so follow it.
                            setState(() => _chapter = null);
                          },
                        ),
                      ],
                    ),
                  ),
                  _Footer(
                    chapter: chapter,
                    level: upNext,
                    enabled: canPlay,
                    onPrevious: chapter > 1
                        ? () {
                            scope.audio.play(Sfx.buttonTap);
                            _step(-1, progress);
                          }
                        : null,
                    onNext: chapter < Tuning.totalChapters
                        ? () {
                            scope.audio.play(Sfx.buttonTap);
                            _step(1, progress);
                          }
                        : null,
                    onPlay: canPlay ? () => _play(context, upNext) : null,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Which chapter, what it is called, and how much of it is done.
class _Header extends StatelessWidget {
  const _Header({
    required this.chapter,
    required this.earned,
    required this.possible,
    required this.onBack,
  });

  final int chapter;
  final int earned;
  final int possible;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Column(
        children: [
          Row(
            children: [
              RoundIconButton(
                icon: Icons.chevron_left_rounded,
                label: 'Back',
                onPressed: onBack,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Chapter $chapter',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.heading,
                    ),
                    Text(
                      ChapterNames.of(chapter),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodyDim,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _StarCount(earned: earned, possible: possible),
            ],
          ),
          const SizedBox(height: 12),
          _ChapterBar(earned: earned, possible: possible),
        ],
      ),
    );
  }
}

class _StarCount extends StatelessWidget {
  const _StarCount({required this.earned, required this.possible});

  final int earned;
  final int possible;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
      decoration: ShapeDecoration(
        shape: novaShape(edge: Palette.panelEdge, bevel: 20),
        color: Palette.panelFill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 19, color: Palette.star),
          const SizedBox(width: 6),
          Text('$earned', style: AppType.hud.copyWith(fontSize: 17)),
          Text(
            '/$possible',
            style: AppType.hudSmall.copyWith(color: Palette.uiTextLocked),
          ),
        ],
      ),
    );
  }
}

/// How much of this chapter is behind the player, as a bar.
class _ChapterBar extends StatelessWidget {
  const _ChapterBar({required this.earned, required this.possible});

  final int earned;
  final int possible;

  @override
  Widget build(BuildContext context) {
    final fraction = possible <= 0 ? 0.0 : (earned / possible).clamp(0.0, 1.0);
    return SizedBox(
      height: 14,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Measured rather than laid out as a fraction, so the first star in
          // a chapter is a visible nub instead of a sliver under a pixel.
          final filled = (constraints.maxWidth * fraction).clamp(
            earned == 0 ? 0.0 : 14.0,
            constraints.maxWidth,
          );
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Palette.uiBackground,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: Palette.panelEdge, width: 2),
                ),
              ),
              Container(
                width: filled,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: const LinearGradient(
                    colors: [Palette.panelFillLit, Palette.panelFillFun],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One level: a big tile with its number, and its stars underneath.
class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.unlocked,
    required this.isNext,
    required this.stars,
    required this.onTap,
  });

  final int level;
  final bool unlocked;

  /// The one the player is up to. It gets the amber and a badge, because on a
  /// grid of fifteen the question is always which one to tap.
  final bool isNext;
  final int stars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kind = Tuning.kindOf(level);
    final tone = !unlocked
        ? NovaTone.quiet
        : isNext
        ? NovaTone.primary
        : NovaTone.go;
    final shape = novaShape(
      edge: unlocked ? null : Palette.panelEdge,
      bevel: Metrics.tileBevel,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: shape,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: unlocked
                          ? [tone.fill, tone.fillLow]
                          : const [Palette.panelFillLow, Palette.panelFillLow],
                    ),
                    shadows: [
                      ...novaLift(),
                      if (isNext)
                        const BoxShadow(
                          color: Palette.glow,
                          blurRadius: Metrics.panelGlowBlur,
                          spreadRadius: -6,
                        ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    shape: shape,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: unlocked ? onTap : null,
                      child: Center(
                        child: unlocked
                            ? Text(
                                '$level',
                                style: AppType.hud.copyWith(
                                  fontSize: 28,
                                  color: tone.ink,
                                ),
                              )
                            : const Icon(
                                Icons.lock_rounded,
                                size: 28,
                                color: Palette.uiTextLocked,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              if (isNext)
                Positioned(
                  right: -6,
                  top: -8,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Palette.panelFillFun,
                      border: Border.all(color: Palette.uiBackground, width: 3),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 16,
                      color: Palette.uiInkOnFun,
                    ),
                  ),
                ),
              if (kind == LevelKind.boss)
                Positioned(
                  left: -4,
                  top: -8,
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    size: 24,
                    color: unlocked ? Palette.star : Palette.uiTextLocked,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 18,
          child: isNext
              ? Text(
                  'NEXT UP',
                  style: AppType.hudSmall.copyWith(
                    color: Palette.panelFillLit,
                    fontSize: 11,
                  ),
                )
              : unlocked
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < Tuning.starsPerLevel; i++)
                      Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: i < stars ? Palette.star : Palette.starEmpty,
                      ),
                  ],
                )
              : Text(
                  '$level',
                  style: AppType.hudSmall.copyWith(
                    color: Palette.uiTextLocked,
                    fontSize: 13,
                  ),
                ),
        ),
      ],
    );
  }
}

/// What the chapter is building up to.
class _BossCard extends StatelessWidget {
  const _BossCard({
    required this.chapter,
    required this.progress,
    required this.onTap,
  });

  final int chapter;
  final PlayerProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final level = chapter * Tuning.levelsPerChapter;
    final name =
        BossCatalog.archetypes[(chapter - 1) % Tuning.bossArchetypeCount].name;
    final reached = progress.isUnlocked(level);
    final remaining = level - progress.highestLevelUnlocked;
    final shape = novaShape(edge: Palette.panelEdge, bevel: 24);

    return DecoratedBox(
      decoration: ShapeDecoration(shape: shape, color: Palette.panelFill),
      child: Material(
        color: Colors.transparent,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: reached ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: Palette.uiPanelLight,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: novaLift(depth: Metrics.liftDepthSmall),
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    size: 34,
                    color: reached ? Palette.star : Palette.uiTextLocked,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Level $level: Boss',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.body.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          fontVariations: const [FontVariation('wght', 800)],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reached
                            ? 'The $name is waiting.'
                            : 'Beat $remaining more '
                                  '${remaining == 1 ? 'level' : 'levels'} to '
                                  'reach the $name',
                        style: AppType.bodyDim.copyWith(fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paging between chapters, with the way in between the arrows.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.chapter,
    required this.level,
    required this.enabled,
    required this.onPrevious,
    required this.onNext,
    required this.onPlay,
  });

  final int chapter;
  final int level;
  final bool enabled;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Row(
        children: [
          _Arrow(
            icon: Icons.chevron_left_rounded,
            label: 'Previous chapter',
            onPressed: onPrevious,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: NovaButton(
              label: 'PLAY LEVEL $level',
              primary: true,
              icon: Icons.play_arrow_rounded,
              height: 68,
              compact: true,
              enabled: enabled,
              onPressed: onPlay,
            ),
          ),
          const SizedBox(width: 10),
          _Arrow(
            icon: Icons.chevron_right_rounded,
            label: 'Next chapter',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final shape = novaShape(edge: Palette.panelEdge, bevel: 18);
    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: Semantics(
        button: true,
        label: label,
        child: SizedBox(
          width: 54,
          height: 54,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: shape,
              color: Palette.panelFill,
              shadows: novaLift(depth: Metrics.liftDepthSmall),
            ),
            child: Material(
              color: Colors.transparent,
              shape: shape,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: Icon(icon, size: 26, color: Palette.uiTextSoft),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
