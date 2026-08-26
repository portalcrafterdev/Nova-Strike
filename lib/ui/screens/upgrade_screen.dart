import 'package:flutter/material.dart';

import '../../app.dart';
import '../../audio/sfx.dart';
import '../../levels/difficulty_curve.dart';
import '../../state/player_progress.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../widgets/ad_banner.dart';
import '../widgets/nova_button.dart';
import '../widgets/star_field.dart';

/// Spends coins on the six permanent upgrades.
///
/// Costs rise geometrically, so the last tier of anything is a real decision
/// rather than a formality.
class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  static const String route = '/upgrades';

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
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
          title: Text('UPGRADES', style: AppType.subheading),
          centerTitle: true,
        ),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: progress,
            builder: (context, _) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.monetization_on,
                          color: Palette.coin,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text('${progress.coins}', style: AppType.heading),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      itemCount: PlayerProgress.upgrades.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final def = PlayerProgress.upgrades[index];
                        return _UpgradeRow(
                          def: def,
                          tier: progress.tierOf(def.id),
                          cost: progress.costOf(def.id),
                          affordable: progress.canAfford(def.id),
                          onBuy: () {
                            if (progress.buyUpgrade(def.id)) {
                              scope.audio.play(Sfx.upgradeBuy);
                            }
                          },
                        );
                      },
                    ),
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

class _UpgradeRow extends StatelessWidget {
  const _UpgradeRow({
    required this.def,
    required this.tier,
    required this.cost,
    required this.affordable,
    required this.onBuy,
  });

  final UpgradeDef def;
  final int tier;
  final int? cost;
  final bool affordable;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final maxed = cost == null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: ShapeDecoration(
        color: Palette.panelFill,
        shape: novaShape(edge: Palette.panelEdge),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.name, style: AppType.subheading),
                const SizedBox(height: 2),
                Text(def.description, style: AppType.bodyDim),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(Tuning.upgradeMaxTier, (i) {
                    return Container(
                      width: 22,
                      height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: i < tier
                            ? Palette.uiAccent
                            : Palette.uiPanelLight,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (maxed)
            Text(
              'MAX',
              style: AppType.button.copyWith(color: Palette.uiAccentWarm),
            )
          else
            Material(
              color: affordable ? Palette.uiAccent : Palette.uiPanelLight,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: affordable ? onBuy : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.monetization_on,
                        size: 14,
                        color: affordable
                            ? Palette.uiBackground
                            : Palette.uiTextDim,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$cost',
                        style: AppType.button.copyWith(
                          color: affordable
                              ? Palette.uiBackground
                              : Palette.uiTextDim,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
