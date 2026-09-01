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
    // The badges are kept on the phone, so that button stands on its own even
    // where there is no store to sign into. Only the sign in pill and the
    // rankings need one.
    final badges = NovaIconButton(
      icon: Icons.emoji_events,
      tooltip: 'Achievements',
      onPressed: onOpenBadges,
    );

    if (!games.isSupported) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Align(alignment: Alignment.centerRight, child: badges),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: _SignInPill(games: games, onSignIn: onSignIn)),
          const SizedBox(width: 8),
          badges,
          const SizedBox(width: 8),
          NovaIconButton(
            icon: Icons.leaderboard,
            tooltip: 'Rankings',
            onPressed: onOpenRanks,
          ),
        ],
      ),
    );
  }
}

class _SignInPill extends StatelessWidget {
  const _SignInPill({required this.games, required this.onSignIn});

  final GameServicesController games;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final signingIn = games.status == GameServicesStatus.signingIn;
    final signedIn = games.isSignedIn;
    final failed = games.status == GameServicesStatus.failed;

    final Color tint = signedIn
        ? Palette.uiAccent
        : failed
        ? Palette.uiAccentWarm
        : Palette.uiTextDim;

    final String label;
    if (signingIn) {
      label = 'SIGNING IN';
    } else if (signedIn) {
      label = games.playerName?.toUpperCase() ?? 'SIGNED IN';
    } else {
      // The service is named rather than described, because the player is
      // about to be handed that service's own sheet and the two should match.
      label = 'SIGN IN WITH ${games.serviceName.toUpperCase()}';
    }

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: novaShape(edge: signedIn ? Palette.uiAccent : Palette.panelEdge),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.panelFill, Palette.panelFillLow],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        shape: novaShape(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // Tapping while signed in goes to the boards, which is the only
          // thing left to want from here.
          onTap: signingIn ? null : onSignIn,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                if (signingIn)
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    signedIn
                        ? Icons.verified_user
                        : failed
                        ? Icons.error_outline
                        : Icons.sports_esports,
                    size: 16,
                    color: tint,
                  ),
                const SizedBox(width: 9),
                // Scaled down rather than clipped, because the longest of
                // these labels is the service's own name and it must not come
                // out as SIGN IN WITH GOOGLE PLAY GAM.
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: AppType.hudSmall.copyWith(color: tint),
                    ),
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
