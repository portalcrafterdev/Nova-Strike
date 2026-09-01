import 'package:flutter/material.dart';

import '../../app.dart';
import '../../state/achievement_catalog.dart';
import '../../state/player_progress.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../widgets/ad_banner.dart';
import '../widgets/nova_button.dart';
import '../widgets/star_field.dart';

/// Every badge in the game, earned or not.
///
/// Read from the save on the phone rather than from Google, so it works signed
/// out, offline, and before anyone has been to the Play Console. What the
/// store knows is a copy of this, not the other way round.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  static const String route = '/achievements';

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final progress = scope.progress;

    return StarField(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        bottomNavigationBar: AdBanner(ads: scope.ads),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text('ACHIEVEMENTS', style: AppType.subheading),
          centerTitle: true,
        ),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: progress,
            builder: (context, _) {
              final earned = AchievementCatalog.earnedIn(progress).length;
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: AchievementCatalog.all.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _Summary(
                      earned: earned,
                      total: AchievementCatalog.all.length,
                    );
                  }
                  return _Row(
                    badge: AchievementCatalog.all[index - 1],
                    progress: progress,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.earned, required this.total});

  final int earned;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: novaShape(edge: Palette.panelEdge),
          color: Palette.panelFill,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$earned OF $total EARNED', style: AppType.hud),
                  Icon(
                    Icons.emoji_events,
                    size: 18,
                    color: earned == total ? Palette.star : Palette.uiTextDim,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : earned / total,
                  minHeight: 5,
                  backgroundColor: Palette.panelEdge,
                  color: Palette.uiAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.badge, required this.progress});

  final AchievementDef badge;
  final PlayerProgress progress;

  @override
  Widget build(BuildContext context) {
    final done = badge.earnedBy(progress);
    // A hidden badge that has not been earned shows as a locked slot rather
    // than as its name, so the far end of the campaign is not spoiled by
    // scrolling a list.
    final secret = badge.hidden && !done;
    final tint = done ? Palette.uiAccent : Palette.uiTextDim;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: done ? 1 : 0.55,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: novaShape(
              edge: done ? Palette.uiAccent : Palette.panelEdge,
              width: done ? 1.4 : 1,
            ),
            color: done ? Palette.panelFillLit : Palette.panelFill,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  secret ? Icons.lock_outline : badge.icon,
                  size: 26,
                  color: tint,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              secret ? 'HIDDEN' : badge.name.toUpperCase(),
                              style: AppType.hudSmall.copyWith(color: tint),
                            ),
                          ),
                          Text(
                            '${badge.points}',
                            style: AppType.bodyDim.copyWith(
                              color: done ? Palette.star : Palette.uiTextDim,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        secret
                            ? 'Earn it to find out what it was.'
                            : badge.description,
                        style: AppType.bodyDim,
                      ),
                      // Only the counting badges get a bar. A yes or no badge
                      // with a bar at zero reads as broken rather than as not
                      // done yet.
                      if (badge.hasBar && !done && !secret) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: badge.fractionIn(progress),
                            minHeight: 4,
                            backgroundColor: Palette.panelEdge,
                            color: Palette.uiAccent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${badge.progressIn(progress)} / ${badge.target}',
                          style: AppType.bodyDim,
                        ),
                      ],
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
