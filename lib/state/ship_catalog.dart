import 'dart:ui';

import '../theme/palette.dart';

/// The hulls the player can fly.
enum ShipId { vanguard, interceptor, bulwark }

/// One hull, and how flying it changes the run.
///
/// The multipliers are deliberately a trade in every direction. A hull that is
/// better at everything is not a choice, it is an upgrade, and the game already
/// has upgrades.
class ShipDef {
  const ShipDef({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.fireRate,
    required this.damage,
    required this.speed,
    required this.livesBonus,
    required this.hull,
    required this.hullDark,
    required this.accent,
    required this.nose,
    required this.span,
    required this.sweep,
    required this.tailSpan,
  });

  final ShipId id;
  final String name;
  final String description;

  /// Coins to unlock. The starting hull is free.
  final int cost;

  /// How much faster the guns cycle than the baseline.
  final double fireRate;

  /// How much harder each shot lands than the baseline.
  final double damage;

  /// How quickly the hull answers the finger.
  final double speed;

  /// Lives added to, or taken off, the run.
  final int livesBonus;

  final Color hull;
  final Color hullDark;
  final Color accent;

  // Shape, fed straight to the shared hull builder.
  final double nose;
  final double span;
  final double sweep;
  final double tailSpan;

  String get key => id.name;
}

/// Every hull in the game.
class ShipCatalog {
  const ShipCatalog._();

  /// The hull a new player starts with.
  static const ShipId starter = ShipId.vanguard;

  static const List<ShipDef> ships = [
    ShipDef(
      id: ShipId.vanguard,
      name: 'Vanguard',
      description: 'The hull everything else is measured against',
      cost: 0,
      fireRate: 1.0,
      damage: 1.0,
      speed: 1.0,
      livesBonus: 0,
      hull: Palette.playerHull,
      hullDark: Palette.playerHullDark,
      accent: Palette.playerAccent,
      nose: 26,
      span: 20,
      sweep: -14,
      tailSpan: 7,
    ),
    ShipDef(
      id: ShipId.interceptor,
      name: 'Interceptor',
      description: 'Quick and fast firing, but it comes apart easily',
      cost: 900,
      fireRate: 1.35,
      damage: 0.78,
      speed: 1.3,
      livesBonus: -1,
      hull: Palette.shipInterceptor,
      hullDark: Palette.shipInterceptorDark,
      accent: Palette.shipInterceptorAccent,
      nose: 31,
      span: 15,
      sweep: -17,
      tailSpan: 5,
    ),
    ShipDef(
      id: ShipId.bulwark,
      name: 'Bulwark',
      description: 'Slow and heavy handed, with a life to spare',
      cost: 1600,
      fireRate: 0.8,
      damage: 1.45,
      speed: 0.82,
      livesBonus: 1,
      hull: Palette.shipBulwark,
      hullDark: Palette.shipBulwarkDark,
      accent: Palette.shipBulwarkAccent,
      nose: 22,
      span: 24,
      sweep: -10,
      tailSpan: 10,
    ),
  ];

  static ShipDef of(ShipId id) =>
      ships.firstWhere((ship) => ship.id == id, orElse: () => ships.first);

  static ShipId? byKey(String key) {
    for (final ship in ships) {
      if (ship.key == key) {
        return ship.id;
      }
    }
    return null;
  }
}
