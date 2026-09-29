import 'package:flutter/material.dart';

import '../../ads/ads_controller.dart';
import '../../audio/sfx.dart';
import '../../game/nova_game.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../widgets/mascot_ship.dart';
import '../widgets/nova_button.dart';
import '../widgets/result_parts.dart';
import '../widgets/space_scrim.dart';

/// Shown when the ship runs out of lives.
///
/// Retry restarts the same level immediately. There is no ad gate and no wait,
/// because friction here is what makes players quit. One column, result above
/// the choices, so a button is never too narrow to say what it does.
///
/// Losing is the most common thing that happens in this game and the moment a
/// child is most likely to put it down. So the sheet is a shrug rather than a
/// verdict: a knocked out ship, how far they got, and two ways straight back
/// in. Nothing here tells them off.
///
/// The one ad on this screen is the extra life, and it is an offer rather than
/// a toll. Watching it hands back a life and drops the player back into the
/// fight they just lost, keeping their score and their place in the level.
/// Ignoring it costs nothing, because TRY AGAIN sits right underneath it and
/// is still instant and still free.
class GameOverSheet extends StatefulWidget {
  const GameOverSheet({required this.game, this.ads, super.key});

  final NovaGame game;
  final AdsController? ads;

  @override
  State<GameOverSheet> createState() => _GameOverSheetState();
}

class _GameOverSheetState extends State<GameOverSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  bool _busy = false;

  NovaGame get game => widget.game;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: ResultTiming.total);
    // A last chance to fetch one. The game asks for a rewarded ad as soon as
    // the player is down to their last life, so by here it is normally already
    // waiting, and this only matters when that load failed or never ran.
    widget.ads?.prepareReward();
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

  Future<void> _watchForLife() async {
    final ads = widget.ads;
    if (ads == null || _busy || !game.canRevive) {
      return;
    }
    game.audio.play(Sfx.buttonTap);
    setState(() => _busy = true);
    final earned = await ads.showRewarded();
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (earned) {
      // Only on a watched ad. Skipping out early pays nothing, which is what
      // the store means by a reward.
      game.revive();
    }
  }

  /// How far they got, in the terms the heads up display was using a second
  /// ago. "Wave 3 of 4" is something to beat; "you died" is not.
  String get _reached {
    final wave = game.waveNotifier.value;
    if (game.endless) {
      return 'You reached level ${game.levelNumber}. Good run.';
    }
    if (wave.total <= 0) {
      return 'So close.';
    }
    final at = wave.current.clamp(1, wave.total);
    if (at >= wave.total) {
      return 'You made it to the last wave. So close.';
    }
    return 'You made it to wave $at of ${wave.total}. So close.';
  }

  @override
  Widget build(BuildContext context) {
    final ads = widget.ads;
    if (ads == null) {
      return _build(canWatch: false);
    }
    // Rebuilt when the controller changes, so an ad that finishes loading a
    // moment after this sheet opened still puts the button on screen. Reading
    // the flag once and never listening was why the offer could be missing
    // even with an ad sitting ready.
    return ListenableBuilder(
      listenable: ads,
      builder: (context, _) => _build(
        // Offered only when there is an ad loaded and the run has not already
        // spent its revive. A button promising a life that then does nothing
        // is worse than no button at all.
        canWatch: ads.canOfferReward && game.canRevive,
      ),
    );
  }

  Widget _build({required bool canWatch}) {
    return SpaceScrim(
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
                      const SizedBox(height: 10),
                      Reveal(
                        animation: _entrance,
                        begin: ResultTiming.bannerBegin,
                        lift: 0,
                        child: const Center(child: _Bubble()),
                      ),
                      const SizedBox(height: 10),
                      ResultBanner(text: 'OOPS', animation: _entrance),
                      const SizedBox(height: 8),
                      Reveal(
                        animation: _entrance,
                        begin: ResultTiming.hintBegin,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 300),
                            child: Text(
                              _reached,
                              textAlign: TextAlign.center,
                              style: AppType.body.copyWith(
                                color: Palette.uiTextSoft,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      StatBoxRow(
                        animation: _entrance,
                        boxes: [
                          StatBox(label: 'SCORE', count: game.runScore),
                          StatBox(
                            label: 'COINS',
                            count: game.coinsCollected,
                            tint: Palette.coin,
                          ),
                          StatBox(
                            label: 'BEST',
                            count: game.endless
                                ? game.progress.endlessBest
                                : game.progress.bestScore,
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
                    if (canWatch) ...[
                      _ExtraLifeOffer(
                        busy: _busy,
                        onPressed: _watchForLife,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: NovaButton(
                            label: 'TRY AGAIN',
                            // The main action unless the extra life is on
                            // offer. Two loud buttons on one sheet is no
                            // emphasis at all.
                            primary: !canWatch,
                            icon: Icons.refresh_rounded,
                            height: 66,
                            // Sharing a row with HOME leaves under 200
                            // pixels, and TRY AGAIN is ellipsised at the full
                            // size. Its weight on this sheet comes from the
                            // amber fill and the width, not the type size.
                            compact: true,
                            onPressed: () {
                              game.audio.play(Sfx.buttonTap);
                              game.retry();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 112,
                          child: NovaButton(
                            label: 'HOME',
                            icon: Icons.home_rounded,
                            height: 66,
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
    );
  }
}

/// The knocked out ship, held in a soft ring.
///
/// The ring is doing real work: without it the ship floats in the middle of a
/// dark screen and reads as debris. Inside a bubble it reads as a portrait.
class _Bubble extends StatelessWidget {
  const _Bubble();

  static const double _size = 168;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Palette.uiPanelLight.withValues(alpha: 0.45),
        border: Border.all(color: Palette.panelEdge, width: 4),
      ),
      child: const MascotShip(size: 100, dazed: true),
    );
  }
}

/// The rewarded ad, offered as a thing the player gets rather than a thing
/// they have to sit through.
///
/// Green, because it is the only way back into the fight they just lost, and
/// because it must not be confused with the amber of TRY AGAIN underneath it.
/// The second line says exactly what it costs: nobody should tap this and be
/// surprised by a video.
class _ExtraLifeOffer extends StatelessWidget {
  const _ExtraLifeOffer({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const tone = NovaTone(
      fill: Palette.shipInterceptor,
      fillLow: Color(0xFFA5F073),
      ledge: Color(0xFF6FBF44),
      ink: Color(0xFF1B3D08),
    );
    final shape = novaShape(bevel: 26);

    return Padding(
      padding: const EdgeInsets.only(bottom: Metrics.ledgeDepth),
      child: Opacity(
        opacity: busy ? 0.6 : 1,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: shape,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [tone.fill, tone.fillLow],
            ),
            shadows: const [
              BoxShadow(
                color: Color(0xFF6FBF44),
                offset: Offset(0, Metrics.ledgeDepth),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: busy ? null : onPressed,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: tone.ink,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: busy
                          ? const Padding(
                              padding: EdgeInsets.all(15),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Palette.shipInterceptor,
                              ),
                            )
                          : const Icon(
                              Icons.play_arrow_rounded,
                              size: 28,
                              color: Palette.shipInterceptor,
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            busy ? 'LOADING' : 'EXTRA LIFE',
                            maxLines: 1,
                            style: AppType.button.copyWith(
                              fontSize: 23,
                              color: tone.ink,
                            ),
                          ),
                          Text(
                            'Watch a short video and carry on',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.bodyDim.copyWith(
                              fontSize: 13.5,
                              color: tone.ink.withValues(alpha: 0.82),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
