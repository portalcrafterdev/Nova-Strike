import 'package:flutter/material.dart';

import '../../ads/ads_controller.dart';
import '../../audio/sfx.dart';
import '../../game/nova_game.dart';
import '../../levels/difficulty_curve.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../widgets/confetti.dart';
import '../widgets/nova_button.dart';
import '../widgets/result_parts.dart';
import '../widgets/space_scrim.dart';

/// Shown when a level is cleared: stars, what it paid, and the way on.
///
/// One column, result above the choices. Half of a portrait screen is not wide
/// enough for a button to say NEXT LEVEL without eliding it.
///
/// The sheet arrives rather than appears. Banner, then stars counted out one
/// at a time, then the takings running up to their totals. It is the only
/// moment in a level that is purely a reward, and a reward that is already
/// finished by the time the player looks at it is not felt as one. The way
/// out is the exception: it fades in at once and never waits on any of this.
///
/// The interstitial goes on the way to the next level rather than on arrival
/// here. The player has just earned something and the first thing they should
/// see is what they earned. [ads] is optional so the sheet can be built
/// without an ad controller.
class LevelCompleteSheet extends StatefulWidget {
  const LevelCompleteSheet({required this.game, this.ads, super.key});

  final NovaGame game;
  final AdsController? ads;

  @override
  State<LevelCompleteSheet> createState() => _LevelCompleteSheetState();
}

class _LevelCompleteSheetState extends State<LevelCompleteSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  NovaGame get game => widget.game;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: ResultTiming.total,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entrance.status != AnimationStatus.dismissed) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    game.audio.play(Sfx.buttonTap);
    // Awaited. The ad has to be finished with before the next level starts
    // underneath it, and this is the one moment in the game where waiting is
    // the point rather than a cost.
    await widget.ads?.onLevelCleared(game.levelNumber);
    if (mounted) {
      game.nextLevel();
    }
  }

  /// What the player is one star short of, or null on a perfect run.
  ///
  /// Named rather than counted. "Two of three" tells a child nothing they can
  /// act on; "finish without losing a life" tells them exactly what to do
  /// differently, which is the only reason to show this at all.
  String? get _nextStar {
    if (game.lostALife) {
      return 'One more star if you finish without losing a life';
    }
    if (game.coinsSpawned > 0 && game.coinsCollected < game.coinsSpawned) {
      return 'One more star if you pick up every coin';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final stars = game.earnedStars;
    final isLast = game.levelNumber >= Tuning.totalLevels;
    final hint = _nextStar;
    final badge = game.badgesJustEarned.isEmpty
        ? null
        : game.badgesJustEarned.first;

    return SpaceScrim(
      child: Confetti(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        ResultBanner(
                          text: 'LEVEL\nCLEAR',
                          animation: _entrance,
                        ),
                        const SizedBox(height: 14),
                        StarRow(
                          earned: stars,
                          // A note per star, rising as they land. The pitch is
                          // what turns three of the same ping into a count.
                          onLanded: (i) => game.audio.play(
                            Sfx.coinCollect,
                            pitch: 1 + i * 0.14,
                          ),
                        ),
                        if (hint != null) ...[
                          const SizedBox(height: 12),
                          Reveal(
                            animation: _entrance,
                            begin: ResultTiming.hintBegin,
                            child: Center(
                              child: ConstrainedBox(
                                // Wrapped rather than run edge to edge. A line
                                // of text touching both sides of the screen is
                                // the one thing that stops this reading as a
                                // card.
                                constraints: const BoxConstraints(
                                  maxWidth: 290,
                                ),
                                child: Text(
                                  hint,
                                  textAlign: TextAlign.center,
                                  style: AppType.bodyDim.copyWith(
                                    color: Palette.uiTextSoft,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        ResultPanel(
                          animation: _entrance,
                          rows: [
                            ResultRow(
                              icon: Icons.monetization_on_rounded,
                              tint: Palette.coin,
                              label: 'Coins picked up',
                              count: game.coinReward,
                            ),
                            ResultRow(
                              icon: Icons.insights_rounded,
                              tint: Palette.uiAccent,
                              label: 'Score',
                              count: game.runScore,
                            ),
                            if (badge != null)
                              ResultRow(
                                icon: Icons.emoji_events_rounded,
                                tint: Palette.star,
                                label: 'New badge',
                                value: badge.name,
                                valueTint: Palette.star,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Reveal(
                  animation: _entrance,
                  begin: ResultTiming.buttonsBegin,
                  lift: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isLast) ...[
                        NovaButton(
                          label: 'NEXT LEVEL',
                          primary: true,
                          icon: Icons.play_arrow_rounded,
                          height: 76,
                          onPressed: _next,
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: NovaButton(
                              label: 'REPLAY',
                              icon: Icons.refresh_rounded,
                              height: 62,
                              compact: true,
                              onPressed: () {
                                game.audio.play(Sfx.buttonTap);
                                game.retry();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            // HOME, not MAP. This calls onQuit, which leaves
                            // the level for the main menu. A button that
                            // names somewhere it does not go is worse than
                            // one with a vague name.
                            child: NovaButton(
                              label: 'HOME',
                              icon: Icons.home_rounded,
                              height: 62,
                              compact: true,
                              onPressed: () {
                                game.audio.play(Sfx.buttonTap);
                                game.onQuit?.call();
                              },
                            ),
                          ),
                        ],
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
