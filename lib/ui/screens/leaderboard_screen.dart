import 'package:flutter/material.dart';

import '../../app.dart';
import '../../audio/audio_controller.dart';
import '../../audio/sfx.dart';
import '../../levels/difficulty_curve.dart';
import '../../levels/level_spec.dart';
import '../../services/game_services_controller.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../widgets/ad_banner.dart';
import '../widgets/nova_button.dart';
import '../widgets/star_field.dart';

/// The player's standing with Google Play Games or Apple Game Center.
///
/// The game is offline, so this screen never blocks on the store. It leads
/// with the numbers held on the phone, which are always there, and offers the
/// store underneath as something extra rather than as the point of the screen.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  static const String route = '/leaderboard';

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final games = scope.games;
    final progress = scope.progress;

    return StarField(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Menu screens only. Never over the play area.
        bottomNavigationBar: AdBanner(ads: scope.ads),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text('LEADERBOARD', style: AppType.subheading),
          centerTitle: true,
        ),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([games, progress]),
            builder: (context, _) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _Panel(
                    title: 'YOUR RUN',
                    child: Column(
                      children: [
                        _StatRow(
                          icon: Icons.flag,
                          tint: Palette.uiAccent,
                          label: 'Levels cleared',
                          value:
                              '${progress.highestLevelIn(Difficulty.medium) - 1}'
                              ' of ${Tuning.totalLevels}',
                        ),
                        _StatRow(
                          icon: Icons.star,
                          tint: Palette.star,
                          label: 'Stars',
                          value: '${progress.totalStars}',
                        ),
                        _StatRow(
                          icon: Icons.monetization_on,
                          tint: Palette.coin,
                          label: 'Coins',
                          value: '${progress.coins}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Panel(
                    title: games.serviceName.toUpperCase(),
                    child: _StoreSection(games: games, audio: scope.audio),
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

/// The part of the screen that changes with the store's answer.
class _StoreSection extends StatelessWidget {
  const _StoreSection({required this.games, required this.audio});

  final GameServicesController games;
  final AudioController audio;

  @override
  Widget build(BuildContext context) {
    switch (games.status) {
      case GameServicesStatus.unsupported:
        return const _Note(
          icon: Icons.desktop_access_disabled,
          text:
              'Leaderboards need a phone. This build is running somewhere '
              'without a store attached.',
        );

      case GameServicesStatus.signingIn:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );

      case GameServicesStatus.signedOut:
      case GameServicesStatus.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Note(
              icon: games.status == GameServicesStatus.failed
                  ? Icons.error_outline
                  : Icons.person_outline,
              text: games.status == GameServicesStatus.failed
                  ? 'Could not sign in. ${games.lastError ?? ''}'.trim()
                  : 'Sign in to put your run on the global board and to keep '
                        'your badges.',
              tint: games.status == GameServicesStatus.failed
                  ? Palette.uiAccentWarm
                  : null,
            ),
            const SizedBox(height: 12),
            NovaButton(
              label: 'SIGN IN',
              primary: true,
              icon: Icons.login,
              onPressed: () {
                audio.play(Sfx.buttonTap);
                games.signIn();
              },
            ),
            if (!games.idsConfigured) ...[
              const SizedBox(height: 12),
              const _SetupNote(),
            ],
          ],
        );

      case GameServicesStatus.signedIn:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!games.idsConfigured) ...[
              const _SetupNote(),
              const SizedBox(height: 12),
            ],
            _Note(
              icon: Icons.verified_user,
              text: games.playerName == null
                  ? 'Signed in.'
                  : 'Signed in as ${games.playerName}.',
              tint: Palette.uiAccent,
            ),
            const SizedBox(height: 12),
            NovaButton(
              label: 'LEVEL RANKING',
              primary: true,
              icon: Icons.leaderboard,
              onPressed: () {
                audio.play(Sfx.buttonTap);
                games.showLeaderboards(board: games.ids.highestLevel);
              },
            ),
            const SizedBox(height: 10),
            NovaButton(
              label: 'STAR RANKING',
              icon: Icons.star_outline,
              onPressed: () {
                audio.play(Sfx.buttonTap);
                games.showLeaderboards(board: games.ids.totalStars);
              },
            ),
            const SizedBox(height: 10),
            NovaButton(
              label: 'BADGES',
              icon: Icons.emoji_events,
              onPressed: () {
                audio.play(Sfx.buttonTap);
                games.showAchievements();
              },
            ),
          ],
        );
    }
  }
}

/// Says what is still missing before a score can leave the phone.
///
/// Shown to whoever is building the game, not really to a player: on a
/// finished build the ids are in and this never appears. It is here rather
/// than in a README because the state it describes is one you land in by
/// running the game, and that is where the answer should be.
class _SetupNote extends StatelessWidget {
  const _SetupNote();

  @override
  Widget build(BuildContext context) {
    return const _Note(
      icon: Icons.build_circle_outlined,
      text:
          'Boards and badges have no ids yet, so scores stay on this phone. '
          'Create them in the console and paste the ids into '
          'lib/services/play_ids.dart.',
    );
  }
}

/// A titled panel, cut to the same shape as every button on every screen.
class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: novaShape(edge: Palette.panelEdge),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.panelFill, Palette.panelFillLow],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppType.hudSmall),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color tint;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 17, color: tint),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: AppType.body)),
          Text(value, style: AppType.hud),
        ],
      ),
    );
  }
}

/// One line of explanation with an icon, used wherever the store has something
/// to say that is not a number.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, this.tint});

  final IconData icon;
  final String text;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: tint ?? Palette.uiTextDim),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: tint == null
                ? AppType.bodyDim
                : AppType.bodyDim.copyWith(color: tint),
          ),
        ),
      ],
    );
  }
}
