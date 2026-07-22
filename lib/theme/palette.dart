import 'dart:ui';

/// Colors and visual constants for the whole game.
///
/// Every colour and every layout number used by a component lives here so a
/// look pass never means hunting through component files.
class Palette {
  const Palette._();

  // Background.
  static const Color spaceDeep = Color(0xFF04060F);
  static const Color spaceMid = Color(0xFF0A1026);
  static const Color nebulaA = Color(0x332B4CFF);
  static const Color nebulaB = Color(0x2AFF3D9A);
  static const Color starFar = Color(0x66A9C7FF);
  static const Color starMid = Color(0xAACFE3FF);
  static const Color starNear = Color(0xFFFFFFFF);

  // Player.
  static const Color playerHull = Color(0xFFEAF2FF);
  static const Color playerHullDark = Color(0xFF2E74CE);
  static const Color playerAccent = Color(0xFF45D6EE);

  /// The pods the ship grows as the ordnance rack is upgraded.
  static const Color playerPod = Color(0xFFF2A93B);
  static const Color playerBullet = Color(0xFF9BFFF0);
  static const Color playerBulletGlow = Color(0x669BFFF0);

  static const Color thruster = Color(0xFF63D9FF);
  static const Color thrusterHot = Color(0xFFFFF2C4);

  // The other hulls the player can buy and fly.
  static const Color shipInterceptor = Color(0xFFB6FF8A);
  static const Color shipInterceptorDark = Color(0xFF2F7A3A);
  static const Color shipInterceptorAccent = Color(0xFFFFF06B);
  static const Color shipBulwark = Color(0xFFFFA98A);
  static const Color shipBulwarkDark = Color(0xFF8C3F2E);
  static const Color shipBulwarkAccent = Color(0xFF7FE7FF);

  /// Enemy fire when the high contrast setting is on.
  ///
  /// Orange against the player's teal is the pairing most likely to give
  /// trouble, so this moves incoming fire to a hue nothing else in the game
  /// uses.
  static const Color enemyBulletContrast = Color(0xFFFFFFFF);
  static const Color enemyBulletContrastGlow = Color(0x88C86BFF);

  // Secondary weapons. Each one gets its own colour on purpose, because in a
  // busy lane the colour is how the player tells their own ordnance apart.
  static const Color missileHull = Color(0xFFE8EEF7);
  static const Color missileHullDark = Color(0xFF5A6478);
  static const Color missileFlame = Color(0xFFFFB25C);
  static const Color railBolt = Color(0xFFFFE68A);
  static const Color railBoltGlow = Color(0x66FFC94D);
  static const Color flakShell = Color(0xFFBFD4B0);
  static const Color flakShellDark = Color(0xFF4C6046);
  static const Color flakBurst = Color(0xFFD8FF8A);
  static const Color podBolt = Color(0xFF7FD2FF);
  static const Color podBoltGlow = Color(0x667FD2FF);
  static const Color arcCoil = Color(0xFFCBA6FF);

  // Enemies. Index by enemy type ordinal through enemyColors.
  static const Color enemyScout = Color(0xFFF0503C);
  static const Color enemyDarter = Color(0xFFC64BE0);
  static const Color enemyGunner = Color(0xFFF2A93B);
  static const Color enemyBomber = Color(0xFF4CAF7D);
  static const Color enemyShielder = Color(0xFF7B6BE8);
  static const Color enemySplitter = Color(0xFF26B5A6);
  static const Color enemyTurret = Color(0xFF8C8C99);
  static const Color enemyKamikaze = Color(0xFFE03B3B);
  static const Color enemyBullet = Color(0xFFFF9E7A);
  static const Color enemyBulletGlow = Color(0x66FF9E7A);
  static const Color hitFlash = Color(0xFFFFFFFF);

  // Boss.
  static const Color bossHull = Color(0xFF8E7FD4);
  static const Color bossHullDark = Color(0xFF4A3F7A);
  static const Color bossCore = Color(0xFF3FE0F0);

  /// The thruster housings at the back of a boss hull.
  static const Color bossThruster = Color(0xFFF2A93B);
  static const Color bossShield = Color(0xFF7FD4FF);
  static const Color bossHealthBar = Color(0xFFFF5C5C);
  static const Color bossHealthBack = Color(0x88121826);

  // Pickups.
  static const Color gemDouble = Color(0xFF7FE7FF);
  static const Color gemSpread = Color(0xFFFFD166);
  static const Color gemLaser = Color(0xFFFF6BD6);
  static const Color gemShield = Color(0xFF5CE1B0);
  static const Color gemMagnet = Color(0xFFB07CFF);
  static const Color gemSlow = Color(0xFF9AA8C7);
  static const Color gemDrones = Color(0xFF8AB4FF);
  static const Color gemChain = Color(0xFFFFF06B);
  static const Color gemFreeze = Color(0xFFB9F2FF);

  /// The arc a chain shot draws between the things it jumps to.
  static const Color chainArc = Color(0xFFFFF6B0);
  static const Color coin = Color(0xFFFFD166);

  /// The darker face colour for a pickup.
  ///
  /// A gem alternates a lit face with a shaded one. Shading it toward the
  /// interface background turned every second face black against space, so it
  /// is shaded toward its own colour instead and stays readable.
  static Color pickupTrim(Color body) => Color.lerp(body, spaceMid, 0.45)!;

  /// The wingman drones. Close enough to the ship to read as friendly, far
  /// enough from it that they are never mistaken for the ship itself.
  static const Color droneHull = Color(0xFF8AB4FF);
  static const Color droneHullDark = Color(0xFF35538F);
  static const Color shieldRing = Color(0xFF5CE1B0);
  static const Color laserBeam = Color(0xFFFF6BD6);

  /// Panel lines drawn between the faces of a model, so a low poly hull reads
  /// as a hull instead of a coloured blob.
  static const Color meshEdge = Color(0x99080C18);

  // Obstacles.
  // The escorted freighter, and the gate at the end of a gate level.
  static const Color freighterHull = Color(0xFFCFE0B8);
  static const Color freighterHullDark = Color(0xFF4E6046);
  static const Color freighterCore = Color(0xFFFFC24D);
  static const Color gateRing = Color(0xFF8AF0FF);
  static const Color gateGlow = Color(0xFFFFF06B);

  static const Color obstacleRock = Color(0xFF7C8AA6);
  static const Color obstacleRockDark = Color(0xFF3A465E);

  // Warnings and overlays.
  static const Color dangerGlow = Color(0x55FF3B3B);

  /// The bracket that marks where the next wave is about to arrive.
  static const Color warning = Color(0xFFFFC24D);
  static const Color uiBackground = Color(0xFF070B16);
  static const Color uiPanel = Color(0xFF111A2E);
  static const Color uiPanelLight = Color(0xFF1B2740);
  static const Color uiAccent = Color(0xFF7FE7FF);
  static const Color uiAccentWarm = Color(0xFFFFD166);
  static const Color uiText = Color(0xFFEAF2FF);
  static const Color uiTextDim = Color(0xFF8FA0BF);
  static const Color uiLocked = Color(0x4044507F);
  static const Color star = Color(0xFFFFD166);
  static const Color starEmpty = Color(0xFF2A3450);

  // Menu surfaces.
  //
  // Solid, not glass. A panel that the star field showed through read as dirt
  // on the surface rather than as depth, and the stars crawling behind a label
  // made the label harder to read, not the screen prettier. The sky stays
  // behind the panels, where it belongs.

  /// A panel at rest is lit from above, so it carries a gradient rather than a
  /// flat fill. Two stops, top and bottom.
  static const Color panelFill = Color(0xFF17213A);
  static const Color panelFillLow = Color(0xFF0D1424);

  /// The one lit action on a screen. Bright enough to be the thing the eye
  /// lands on without another colour entering the palette.
  static const Color panelFillLit = Color(0xFF2C7FA6);
  static const Color panelFillLitLow = Color(0xFF17506B);

  /// The hairline that catches the light along an edge.
  static const Color panelEdge = Color(0x59A8C8E8);
  static const Color panelEdgeLit = Color(0xFF7FE7FF);

  /// What the lit action and the title throw off. Used as a shadow colour, so
  /// it carries its own alpha rather than being faded at the call site.
  static const Color glow = Color(0x557FE7FF);

  /// The two clouds behind a menu. Deeper than the ones the levels are flown
  /// through, because a menu holds still and can carry more colour than a
  /// screen with forty things moving on it.
  static const Color menuNebulaA = Color(0x662B4CFF);
  static const Color menuNebulaB = Color(0x4CFF3D9A);

  /// How dark the edges of a menu go, so the middle of the screen stays the
  /// part the eye lands on.
  static const Color vignette = Color(0xCC02040A);
}

/// Layout and visual timing constants.
///
/// The game world is a fixed logical resolution so every number below means
/// the same thing on every device.
class Metrics {
  const Metrics._();

  /// Logical screen width. The camera scales this to the real screen.
  ///
  /// The game runs portrait, so the lane is narrow and long and runs up the
  /// screen the way a vertical shooter has always done.
  static const double worldWidth = 540;

  /// Logical screen height.
  static const double worldHeight = 960;

  // The camera. The world is right handed: x right, y up out of the play
  // plane, z up the lane. The lens looks straight down with no perspective,
  // so this is a flat game and y is only there to give models thickness.

  /// Screen pixels per world unit.
  ///
  /// Chosen so the full width of the lane fills the screen with a little air
  /// either side.
  static const double cameraZoom = 2.1;

  /// How far up from the bottom of the screen the line at z zero sits.
  ///
  /// The ship starts on that line, so it needs room below it to be pulled
  /// back into as well as room above to climb into.
  static const double laneOrigin = 150;

  /// How far the ship may fly from the middle, left and right.
  static const double playHalfWidth = 120;

  /// How far up and down the lane the ship may fly.
  ///
  /// A vertical shooter lives or dies on this. Too small and the ship is on
  /// rails; too large and the player can sit on top of the spawn line.
  static const double playerBandBack = -48;
  static const double playerBandForward = 170;

  /// A guard on the axis the game does not use.
  ///
  /// Everything is played at y zero. This only exists so a stray value can
  /// still be culled rather than drifting for ever.
  static const double playHalfHeight = 55;

  /// Where enemies enter from, measured up the lane.
  ///
  /// Just past the top of the screen, so a wave flies in rather than fading
  /// up out of nothing.
  static const double spawnDepth = 460;

  /// Depth below the ship at which anything left over is culled.
  static const double despawnDepth = -110;

  /// How far outside the play box something may drift before it is culled.
  static const double despawnMargin = 280;

  // Star field.
  static const int starsFar = 40;
  static const int starsMid = 30;
  static const int starsNear = 18;
  static const double starSpeedFar = 14;
  static const double starSpeedMid = 42;
  static const double starSpeedNear = 110;
  static const double starRadiusFar = 0.9;
  static const double starRadiusMid = 1.4;
  static const double starRadiusNear = 2.0;

  static const int nebulaBlobs = 5;
  static const double nebulaSpeed = 6;

  // Model sizes, in world units. The meshes define the shapes, these say how
  // big they are drawn and how big they are to hit.
  static const double playerScale = 1.0;

  /// How much bigger enemies are drawn than their catalog size.
  ///
  /// Enemies fly straight at the lens, which is the angle that shows the least
  /// of a shape, so they need extra size to stay readable at range.
  static const double enemyScale = 0.95;

  /// Tilt applied to a hull before it is drawn.
  ///
  /// Zero, because the lens already looks straight down at the plan view of
  /// every model. Any tilt here only squashes a ship along the lane.
  static const double enemyPitch = 0;

  /// Tilt applied to the player hull before it is drawn. Zero, for the same
  /// reason the enemies have none: the lens is already overhead.
  static const double playerPitch = 0;

  /// Enemies do not turn and do not bank. The lens looks straight down, so
  /// every degree of either shows the hull at an angle, and a wave of ships all
  /// leaning different ways is what stops a player reading it at a glance.

  /// The largest a bullet may be drawn, in world pixels.
  ///
  /// A bullet leaving the muzzle is closer to the lens than anything else on
  /// screen, so perspective alone would draw it as a dinner plate over the
  /// ship that fired it. Collision is unaffected: this is a drawing cap.
  static const double bulletMaxRadius = 5.0;

  /// How far the glow around a bullet reaches past the bullet itself.
  static const double bulletGlowScale = 1.45;

  /// Size of one thruster particle, and the largest it may be drawn.
  ///
  /// The trail sits closer to the lens than anything else in the game, so
  /// without a cap perspective alone turns it into a pair of dinner plates
  /// over the ship it is coming out of.
  static const double thrusterRadius = 3.2;
  static const double thrusterMaxRadius = 2.8;

  /// The largest one explosion particle may be drawn.
  ///
  /// A burst that goes off beside the lens would otherwise cover the ship it
  /// happened to, which reads as a fault rather than as an explosion.
  static const double explosionMaxRadius = 11;

  /// Width of the panel lines drawn between model faces.
  static const double meshEdgeWidth = 1.1;

  /// On screen radius in pixels where panel lines start and finish fading in.
  static const double meshEdgeFadeMin = 7;
  static const double meshEdgeFadeMax = 20;
  static const double playerHitRadius = 7;
  static const double bulletRadius = 3.2;

  /// Collision radius of a railgun lance, which is a heavier shot than the
  /// stream from the main cannon and is drawn to match.
  static const double railBoltRadius = 6.5;

  /// How much bigger bullets are drawn with the large bullets setting on.
  /// Drawn size only. What a bullet can hit never changes.
  static const double largeBulletScale = 1.7;
  static const double enemyBulletRadius = 3.4;
  static const double powerUpRadius = 8;
  static const double coinRadius = 5;
  static const double shieldRadius = 24;
  static const double laserWidth = 9;

  // Wreckage. A dead ship comes apart into the triangles it was built from.
  static const double debrisLifespan = 1.1;

  /// The most pieces one wreck is broken into.
  ///
  /// A hull carries far more triangles than a break needs to read, so the
  /// largest ones are kept and the slivers are left out. The break looks the
  /// same and a screen of simultaneous deaths costs a fraction of the draws.
  static const int debrisMaxPieces = 22;

  /// How hard the pieces are thrown apart, in world units per second.
  static const double debrisSpread = 78;

  /// How much of the dead ship's own motion the pieces carry with them.
  static const double debrisInherit = 0.45;

  /// Tumble rate of a piece, in radians per second.
  static const double debrisSpin = 5.5;

  /// How quickly the pieces lose their speed.
  static const double debrisDrag = 1.1;

  // Hit stop. A very short freeze on impact, which is the cheapest thing there
  // is for making a hit feel like it landed. Long enough to feel, short enough
  // that it never reads as a stutter.

  /// Time scale held during a freeze. Not quite zero, so nothing on a timer
  /// can stall on a divide.
  static const double hitStopScale = 0.02;

  /// Freeze when the player is hit.
  static const double hitStopPlayer = 0.07;

  /// Freeze when something with real hit points dies.
  static const double hitStopHeavy = 0.045;

  /// Freeze when a boss crosses into a new phase.
  static const double hitStopPhase = 0.11;

  // A frame of light across the whole screen, for the moments a shake is not
  // enough on its own.
  static const double screenFlashStrength = 0.34;
  static const double screenFlashLifespan = 0.26;

  // The bracket that warns a wave is about to arrive.
  static const double warningLifespan = 1.0;
  static const double warningWidth = 2.2;
  static const double warningReach = 26;

  /// How far ahead of a wave the warning appears.
  static const double warningLead = 1.0;

  /// How long the banner announcing a new weapon stays on screen.
  static const double armamentBannerSeconds = 3.2;

  // Shockwaves. A ring thrown out by something big, carrying no damage.
  static const double shockwaveReach = 90;
  static const double shockwaveLifespan = 0.5;
  static const double shockwaveBossReach = 260;
  static const double shockwaveBossLifespan = 0.9;
  static const double shockwaveWidth = 3.4;

  /// Width of a chain lightning arc at full brightness.
  static const double chainArcWidth = 2.6;

  // The warp gate ring at the end of a gate level.
  static const double gateRingWidth = 3.0;
  static const double gateGlowWidth = 1.6;

  // Warp out. The run home at the end of a level.

  /// How much faster the star field streams at full warp.
  static const double warpStarBoost = 16;

  /// How fast the ship pulls away down the lane at full warp.
  static const double warpShipSpeed = 900;

  /// How far the ship banks into a turn, in radians at full speed.
  static const double playerBankAngle = 0.55;

  /// How fast enemies spin about their own axis, in radians per second.
  static const double enemySpin = 0.6;

  // Effect timings, in seconds.
  static const double hitFlashDuration = 0.06;
  static const double shakeDurationSmall = 0.15;
  static const double shakeDurationLarge = 0.25;
  static const double shakeAmplitudeSmall = 4;
  static const double shakeAmplitudeLarge = 9;
  static const double slowMotionScale = 0.35;
  static const double slowMotionDuration = 0.7;
  static const double invulnerabilityBlinkRate = 12;
  static const double bossHealthBarHeight = 10;
  static const double bossHealthBarTop = 24;

  /// Height of the dark band drawn behind the top of the display, below the
  /// safe area inset. Enemies enter from the top of the screen, which is where
  /// the score and the level number sit, so without a band they fly straight
  /// across the text and neither one reads.
  static const double hudBandHeight = 104;

  /// How opaque the solid part of that band is. Enough to read white text over
  /// a red enemy, not so much that the enemy disappears behind it.
  static const double hudBandAlpha = 0.72;

  /// Where the band starts fading out, as a fraction of its height. The fade
  /// is what stops a ship crossing a visible hard edge on its way in.
  static const double hudBandFadeStart = 0.55;

  /// How far below the top of the world a boss settles.
  ///
  /// The heads up display owns the top of the screen, so a boss has to sit
  /// clear of it or the two draw on top of each other.
  static const double bossRestClearance = 132;
  static const double edgeGlowPulse = 1.6;

  // The menu backdrop. The same sky the levels are flown in, drifting slowly
  // behind every screen that is not a level.

  /// Stars painted behind a menu, split evenly across three depths.
  static const int menuStarCount = 170;

  /// Seed for those stars, so the sky is the same one every launch.
  static const int menuStarSeed = 20260821;

  /// Seconds for the nearest layer to cross the screen once. Slow on purpose:
  /// a menu should feel like drifting, not like flying.
  static const int menuDriftSeconds = 80;

  /// Drift rate of each depth, as a fraction of the nearest layer.
  static const List<double> menuStarDrift = [0.28, 0.55, 1.0];
  static const List<double> menuStarRadius = [0.7, 1.1, 1.7];

  /// How far the two nebula clouds reach, as a fraction of the screen.
  static const double menuNebulaRadius = 0.85;

  /// Where the vignette starts closing in, as a fraction of the way out from
  /// the middle of the screen.
  static const double menuVignetteStart = 0.42;

  /// Blur laid over a level by a sheet in front of it.
  static const double sheetBlur = 14;

  /// How much the sheet darkens what it blurs.
  static const double sheetTint = 0.72;

  /// Corner radius used where a panel is rounded rather than chamfered.
  static const double panelRadius = 14;

  /// How far the cut corners of a panel run in.
  ///
  /// All four, equally. Cutting only two made a button look like it had been
  /// knocked out of square rather than chamfered on purpose.
  static const double panelBevel = 13;

  /// Width of the lit bar down the leading edge of a button.
  static const double panelBar = 4;

  /// The ship badge above the game name, and how much of it fills its box.
  static const double shipMarkSize = 132;
  static const double shipMarkFit = 92;

  /// The cut on a level tile, which is far smaller than a button and needs a
  /// cut to match.
  static const double tileBevel = 8;

  /// How far the lit action's glow reaches.
  static const double panelGlowBlur = 24;

  // Particle counts.
  static const int explosionParticlesSmall = 14;
  static const int explosionParticlesLarge = 46;
  static const double explosionLifespanSmall = 0.45;
  static const double explosionLifespanLarge = 0.9;
  static const double thrusterInterval = 0.02;
}
