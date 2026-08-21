import 'package:flutter/material.dart';

import '../../app.dart';
import '../../audio/sfx.dart';
import '../../state/ship_catalog.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../widgets/nova_button.dart';
import '../widgets/star_field.dart';

/// Where the player picks a hull.
///
/// Each one is a trade rather than an upgrade, so the screen leads with what a
/// hull gives up as plainly as with what it gives.
class HangarScreen extends StatelessWidget {
  const HangarScreen({super.key});

  static const String route = '/hangar';

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final progress = scope.progress;

    return StarField(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: Palette.uiText,
          title: Text('HANGAR', style: AppType.heading),
        ),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: progress,
            builder: (context, _) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(Icons.paid, color: Palette.coin, size: 18),
                        const SizedBox(width: 6),
                        Text('${progress.coins}', style: AppType.hud),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Portrait, so the hulls are stacked and each one gets the
                    // width it needs to show what it trades away.
                    Expanded(
                      child: ListView(
                        children: [
                          for (final ship in ShipCatalog.ships) ...[
                            _ShipCard(
                              ship: ship,
                              owned: progress.owns(ship.id),
                              selected: progress.shipId == ship.id,
                              affordable: progress.coins >= ship.cost,
                              onTap: () async {
                                scope.audio.play(Sfx.buttonTap);
                                if (progress.owns(ship.id)) {
                                  await progress.selectShip(ship.id);
                                  return;
                                }
                                if (await progress.buyShip(ship.id)) {
                                  scope.audio.play(Sfx.upgradeBuy);
                                  await progress.selectShip(ship.id);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ShipCard extends StatelessWidget {
  const _ShipCard({
    required this.ship,
    required this.owned,
    required this.selected,
    required this.affordable,
    required this.onTap,
  });

  final ShipDef ship;
  final bool owned;
  final bool selected;
  final bool affordable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Palette.panelFillLit : Palette.panelFill,
      shape: novaShape(
        edge: selected ? ship.hull : Palette.panelEdge,
        width: selected ? 2 : 1,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: owned || affordable ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: ship.hull,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ship.name.toUpperCase(),
                      style: AppType.hud,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(ship.description, style: AppType.hudSmall),
              const SizedBox(height: 12),
              _Trait(label: 'FIRE RATE', value: ship.fireRate),
              _Trait(label: 'DAMAGE', value: ship.damage),
              _Trait(label: 'HANDLING', value: ship.speed),
              _Lives(bonus: ship.livesBonus),
              // A gap rather than a Spacer. These cards are in a scrolling
              // list, so they have no height to push against, and a Spacer
              // there throws on every card and takes the whole screen with it.
              const SizedBox(height: 8),
              Text(
                selected
                    ? 'FLYING'
                    : owned
                    ? 'SELECT'
                    : affordable
                    ? 'BUY ${ship.cost}'
                    : 'NEEDS ${ship.cost}',
                style: AppType.hud.copyWith(
                  color: selected
                      ? ship.hull
                      : owned || affordable
                      ? Palette.uiAccent
                      : Palette.uiTextDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One stat, shown against the baseline hull rather than in raw numbers.
class _Trait extends StatelessWidget {
  const _Trait({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final percent = ((value - 1) * 100).round();
    final text = percent == 0
        ? 'STANDARD'
        : percent > 0
        ? '+$percent%'
        : '$percent%';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppType.hudSmall),
          Text(
            text,
            style: AppType.hudSmall.copyWith(
              color: percent == 0
                  ? Palette.uiTextDim
                  : percent > 0
                  ? Palette.uiAccent
                  : Palette.bossHealthBar,
            ),
          ),
        ],
      ),
    );
  }
}

class _Lives extends StatelessWidget {
  const _Lives({required this.bonus});

  final int bonus;

  @override
  Widget build(BuildContext context) {
    if (bonus == 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('LIVES', style: AppType.hudSmall),
          Text(
            bonus > 0 ? '+$bonus' : '$bonus',
            style: AppType.hudSmall.copyWith(
              color: bonus > 0 ? Palette.uiAccent : Palette.bossHealthBar,
            ),
          ),
        ],
      ),
    );
  }
}
