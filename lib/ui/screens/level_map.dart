import 'package:flutter/material.dart';

import '../../app.dart';
import '../../audio/sfx.dart';
import '../../levels/difficulty_curve.dart';
import '../../levels/level_spec.dart';
import '../../state/player_progress.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../widgets/nova_button.dart';
import '../widgets/star_field.dart';
import 'game_screen.dart';

/// The level select. One row of chapters, fifteen levels in each.
///
/// The list is built lazily with a fixed row height, so 1500 levels cost the
/// same to show as fifteen.
class LevelMap extends StatefulWidget {
  const LevelMap({super.key});

  static const String route = '/levels';

  @override
  State<LevelMap> createState() => _LevelMapState();
}

class _LevelMapState extends State<LevelMap> {
  /// One chapter per row, all fifteen levels across the landscape screen.
  static const double _chapterExtent = 112;

  /// A chapter is fifteen levels, and in landscape they all fit on one line.
  static const int _levelsAcross = Tuning.levelsPerChapter;

  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToCurrent());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _jumpToCurrent() {
    if (!_controller.hasClients) {
      return;
    }
    final progress = AppScope.of(context).progress;
    final chapter = Tuning.chapterOf(progress.highestLevelUnlocked);
    final offset = (chapter - 1) * _chapterExtent;
    _controller.jumpTo(
      offset.clamp(0, _controller.position.maxScrollExtent).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return StarField(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text('SELECT LEVEL', style: AppType.subheading),
          centerTitle: true,
        ),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: scope.progress,
            builder: (context, _) {
              return ListView.builder(
                controller: _controller,
                itemExtent: _chapterExtent,
                itemCount: Tuning.totalChapters,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) => _ChapterBlock(
                  chapter: index + 1,
                  progress: scope.progress,
                  onSelect: (level) {
                    scope.audio.play(Sfx.buttonTap);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GameScreen(levelNumber: level),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ChapterBlock extends StatelessWidget {
  const _ChapterBlock({
    required this.chapter,
    required this.progress,
    required this.onSelect,
  });

  final int chapter;
  final PlayerProgress progress;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final first = (chapter - 1) * Tuning.levelsPerChapter + 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CHAPTER $chapter',
            style: AppType.hudSmall.copyWith(color: Palette.uiAccent),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: Tuning.levelsPerChapter,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _LevelMapState._levelsAcross,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.05,
              ),
              itemBuilder: (context, index) {
                final level = first + index;
                return _LevelTile(
                  level: level,
                  unlocked: progress.isUnlocked(level),
                  stars: progress.starsFor(level),
                  onTap: () => onSelect(level),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.unlocked,
    required this.stars,
    required this.onTap,
  });

  final int level;
  final bool unlocked;
  final int stars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kind = Tuning.kindOf(level);
    final accent = switch (kind) {
      LevelKind.boss => Palette.bossHealthBar,
      LevelKind.elite => Palette.uiAccentWarm,
      LevelKind.survival => Palette.gemFreeze,
      LevelKind.escort => Palette.gemDrones,
      LevelKind.gate => Palette.gemChain,
      LevelKind.normal => Palette.panelEdge,
    };

    // Chamfered like every other panel, and solid, so a level number is read
    // against the tile rather than against whatever star is behind it.
    final shape = novaShape(
      edge: unlocked ? accent : Palette.panelEdge,
      width: kind == LevelKind.normal ? 1 : 1.6,
      bevel: Metrics.tileBevel,
    );

    return Material(
      color: unlocked ? Palette.panelFill : Palette.panelFillLow,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: unlocked ? onTap : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!unlocked)
              const Icon(Icons.lock, size: 14, color: Palette.uiTextDim)
            else ...[
              Text(
                '$level',
                style: AppType.hud.copyWith(
                  color: kind == LevelKind.boss
                      ? Palette.bossHealthBar
                      : Palette.uiText,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(Tuning.starsPerLevel, (i) {
                  return Icon(
                    Icons.star,
                    size: 9,
                    color: i < stars ? Palette.star : Palette.starEmpty,
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
