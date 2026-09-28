import 'package:flutter/material.dart';

import '../../services/game_services_controller.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import 'nova_button.dart';

/// The sign in row on the menu, plus the way through to the rankings.
///
/// It sits on the menu rather than behind a screen because signing in is
/// something a player does once, on the way past, and a sign in buried two
/// taps deep may as well not exist. It is a slim pill rather than another full
/// button so it does not compete with PLAY.
class PlayGamesBar extends StatelessWidget {
  const PlayGamesBar({
    required this.games,
    required this.onSignIn,
    required this.onOpenRanks,
    required this.onOpenBadges,
    super.key,
  });

  final GameServicesController games;
  final VoidCallback onSignIn;
  final VoidCallback onOpenRanks;

  /// Opens the achievements list, which is kept on the phone.
  final VoidCallback onOpenBadges;

  @override
  Widget build(BuildContext context) {
    // One strip along the bottom of the menu holding who you are and the two
    // places your record lives. It is quiet on purpose: signing in is worth
    // offering on the first screen, and worth offering only once.
    final shape = novaShape(edge: Palette.panelEdge, bevel: 20);
    return DecoratedBox(
      decoration: ShapeDecoration(shape: shape, color: Palette.panelFill),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Row(
          children: [
            if (games.isSupported) ...[
              Expanded(child: _Identity(games: games, onSignIn: onSignIn)),
              const SizedBox(width: 8),
            ] else
              const Spacer(),
            // The badges are kept on the phone, so this stands on its own even
            // where there is no store to sign into.
            _SquareButton(
              icon: Icons.emoji_events_rounded,
              tint: Palette.star,
              label: 'Achievements',
              onPressed: onOpenBadges,
            ),
            if (games.isSupported) ...[
              const SizedBox(width: 8),
              _SquareButton(
                icon: Icons.leaderboard_rounded,
                tint: Palette.uiAccent,
                label: 'Rankings',
                onPressed: onOpenRanks,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The avatar and the two lines beside it, or the invitation to sign in.
class _Identity extends StatelessWidget {
  const _Identity({required this.games, required this.onSignIn});

  final GameServicesController games;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final signingIn = games.status == GameServicesStatus.signingIn;
    final signedIn = games.isSignedIn;
    final failed = games.status == GameServicesStatus.failed;

    final String title;
    final String note;
    if (signingIn) {
      title = 'Signing in';
      note = 'One moment';
    } else if (signedIn) {
      title = games.playerName ?? 'Signed in';
      note = 'Signed in';
    } else if (failed) {
      title = 'Could not sign in';
      note = 'Tap to try again';
    } else {
      title = 'Sign in';
      note = games.serviceName;
    }

    return InkWell(
      // Tapping while signed in goes to the boards, which is the only thing
      // left to want from here.
      onTap: signingIn ? null : onSignIn,
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: signedIn ? Palette.panelFillGo : Palette.panelFillLow,
            ),
            child: signingIn
                ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    failed ? Icons.error_outline : Icons.person_rounded,
                    size: 22,
                    color: signedIn
                        ? Palette.uiInkOnGo
                        : failed
                        ? Palette.uiAccentWarm
                        : Palette.uiTextDim,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    fontVariations: const [FontVariation('wght', 800)],
                  ),
                ),
                Text(
                  note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodyDim.copyWith(fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the two square buttons on the right of the strip.
class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.icon,
    required this.tint,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final Color tint;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final shape = novaShape(bevel: 14);
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: 44,
        height: 44,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: shape,
            color: Palette.uiPanelLight,
          ),
          child: Material(
            color: Colors.transparent,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: Icon(icon, size: 22, color: tint),
            ),
          ),
        ),
      ),
    );
  }
}
