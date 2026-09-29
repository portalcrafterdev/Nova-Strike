import 'dart:ui';

/// Colors and visual constants for the whole game.
///
/// Every colour and every layout number used by a component lives here so a
/// look pass never means hunting through component files.
class Palette {
  const Palette._();

  // Background.
  //
  // Violet rather than the near black this started as. A bullet hell still
  // needs a dark sky for the bullets to read against, so this is only lifted
  // as far as it can go while keeping a pale bullet obviously brighter than
  // what is behind it. What it buys is a game that does not look bleak.
  static const Color spaceDeep = Color(0xFF120A30);
  static const Color spaceMid = Color(0xFF2A1462);
  static const Color nebulaA = Color(0x335E3FD6);
  static const Color nebulaB = Color(0x2AFF6FB5);
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

  /// The white hot middle of the beam. The three passes are added together, so
  /// this sits on top of the body colour rather than replacing it.
  static const Color laserCore = Color(0xFFFFE4F6);

  /// The keyline drawn round every sprite.
  ///
  /// A flat shape has no shading to separate it from what is behind it, so the
  /// outline is doing that job on its own. It is nearly black rather than pure
  /// black so a hull never looks cut out of the sky.
  static const Color spriteOutline = Color(0xE6050813);

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
  static const Color uiBackground = Color(0xFF140B34);
  static const Color uiPanel = Color(0xFF2A1A63);
  static const Color uiPanelLight = Color(0xFF3B2680);
  static const Color uiAccent = Color(0xFF8AF0FF);
  static const Color uiAccentWarm = Color(0xFFFFD166);
  static const Color uiText = Color(0xFFFFFFFF);

  /// Between [uiText] and [uiTextDim]. For a label that is still being read
  /// rather than glanced at, such as the one under a tile.
  static const Color uiTextSoft = Color(0xFFD6C9FF);

  static const Color uiTextDim = Color(0xFF9B88DC);

  /// A label on something that cannot be tapped yet.
  static const Color uiTextLocked = Color(0xFF6C59AC);

  /// Ink on a lit fill.
  ///
  /// The one action on a screen is now a bright amber, and white on amber is
  /// the single pairing in this palette that fails to read. Anything sitting
  /// on [panelFillLit] takes this instead.
  static const Color uiInkOnLit = Color(0xFF452500);

  static const Color uiLocked = Color(0x406C59AC);
  static const Color star = Color(0xFFFFC93D);
  static const Color starEmpty = Color(0xFF3A2A72);

  // The lives on the heads up display. Big, round and obviously a heart,
  // because a row of small ticks is the last thing a child reads on a screen
  // with forty things moving on it.
  static const Color heartFull = Color(0xFFFF5C7A);
  static const Color heartFullEdge = Color(0xFF7A1330);
  static const Color heartEmpty = Color(0xFF2E1D63);
  static const Color heartEmptyEdge = Color(0xFF4A3390);

  // Menu surfaces.
  //
  // Solid, not glass. A panel that the star field showed through read as dirt
  // on the surface rather than as depth, and the stars crawling behind a label
  // made the label harder to read, not the screen prettier. The sky stays
  // behind the panels, where it belongs.

  /// A panel at rest is lit from above, so it carries a gradient rather than a
  /// flat fill. Two stops, top and bottom.
  static const Color panelFill = Color(0xFF2A1A63);
  static const Color panelFillLow = Color(0xFF241458);

  /// The one lit action on a screen. Bright enough to be the thing the eye
  /// lands on without another colour entering the palette.
  static const Color panelFillLit = Color(0xFFFFC63D);
  static const Color panelFillLitLow = Color(0xFFF5B324);

  /// The second and third button colours.
  ///
  /// Three fills, and each one means something: amber is the way forward,
  /// pink is the other way to play, teal is the setting you are on. Anything
  /// that is none of those stays the violet panel, which is most of the
  /// screen. A fourth colour would stop the first three meaning anything.
  static const Color panelFillFun = Color(0xFFFF6FB5);
  static const Color panelFillFunLow = Color(0xFFF55BA6);
  static const Color panelLedgeFun = Color(0xFFC23C82);
  static const Color uiInkOnFun = Color(0xFF4A0B2B);

  static const Color panelFillGo = Color(0xFF45E0D0);
  static const Color panelFillGoLow = Color(0xFF32CFBF);
  static const Color panelLedgeGo = Color(0xFF14A394);
  static const Color uiInkOnGo = Color(0xFF073B36);

  /// The solid band under a button.
  ///
  /// This is what replaced the hairline edge, and it is the change that makes
  /// a control look pressable rather than drawn. It is a flat offset shadow
  /// with no blur, so it reads as the side of a physical key.
  static const Color panelLedge = Color(0xFF170D40);
  static const Color panelLedgeLit = Color(0xFFC77F00);

  /// The border round a panel. Solid now rather than a hairline, because a
  /// thick outline is what makes a shape read as a toy.
  static const Color panelEdge = Color(0xFF533AA8);
  static const Color panelEdgeLit = Color(0xFFFFD97A);

  /// What the lit action and the title throw off. Used as a shadow colour, so
  /// it carries its own alpha rather than being faded at the call site.
  static const Color glow = Color(0x55FFC63D);

  /// The soft shadow a control casts on the sky below its ledge.
  ///
  /// Deep violet rather than black. Black over this background does not read
  /// as shade, it reads as dirt: the sky is a saturated purple, and an
  /// unsaturated grey laid over it kills the colour instead of darkening it.
  static const Color shadowAmbient = Color(0x8C0A0420);

  /// The two clouds behind a menu. Deeper than the ones the levels are flown
  /// through, because a menu holds still and can carry more colour than a
  /// screen with forty things moving on it.
  static const Color menuNebulaA = Color(0x665E3FD6);
  static const Color menuNebulaB = Color(0x4CFF6FB5);

  /// How dark the edges of a menu go, so the middle of the screen stays the
  /// part the eye lands on. Lighter than it was, because the sky it is closing
  /// in on is no longer nearly black to start with.
  static const Color vignette = Color(0xAA140B34);
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
  /// back into as well as room above to climb into. Only as much room as the
  /// pull back actually uses, though: every unit beyond that is dead screen
  /// under the ship, which on a portrait phone is the band a thumb is already
  /// covering and the last place worth spending height.
  static const double laneOrigin = 100;

  /// How far the ship may fly from the middle, left and right.
  static const double playHalfWidth = 120;

  /// How far up and down the lane the ship may fly.
  ///
  /// A vertical shooter lives or dies on this. Too small and the ship is on
  /// rails; too large and the player can sit on top of the spawn line.
  /// Pulled in with [laneOrigin]. The retreat and the room kept for it are
  /// one number seen from two sides, and moving the line down without moving
  /// this drops the ship through the bottom of the screen.
  static const double playerBandBack = -20;
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

  /// Width of the keyline round a sprite, in pixels on the glass.
  static const double spriteOutlineWidth = 1.6;
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

  /// Half width of the column the beam burns, in world units. The look below
  /// is measured against it, so what is drawn and what is hit stay in step.
  static const double laserWidth = 9;

  /// The three passes, as a share of that half width.
  ///
  /// The halo is drawn at the full width on purpose: it is faint, and it is
  /// the only thing telling the player how wide the column they are burning
  /// actually is. The body and the core are far narrower, which is what turns
  /// a slab of colour into a beam.
  static const double laserBodyWidth = 0.34;
  static const double laserCoreWidth = 0.12;
  static const double laserHaloAlpha = 0.11;

  /// How many nested bands the halo is built from. More is a softer edge and
  /// one more rectangle a frame, which is nothing next to a screen of bullets.
  static const int laserHaloSteps = 4;
  static const double laserBodyAlpha = 0.5;

  /// The flicker, in radians per second and as a share of the width.
  static const double laserPulseRate = 22;
  static const double laserPulseDepth = 0.12;

  /// The flare at the muzzle, as a share of the beam half width.
  static const double laserFlareRadius = 1.15;

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

  /// How far and how fast a boss sways on the spot, so a hull holding station
  /// still reads as something under power.
  static const double bossSwayAngle = 0.05;
  static const double bossSwayRate = 0.6;

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

  /// The boss's own bar. Thick enough to read as a gauge: at ten pixels it
  /// was one more thin line on a display that already had several.
  static const double bossHealthBarHeight = 22;

  /// The pod and shield bars under it. Thinner than the health bar, because
  /// they are what stands in front of the fight rather than the fight itself.
  ///
  /// They lost their written labels to a pair of icons, which is what let them
  /// sit side by side on one line instead of stacking and pushing the play
  /// area down every time a boss had both.
  static const double bossArmourBarHeight = 7;
  static const double bossHealthBarTop = 24;

  /// Height of the dark band drawn behind the top of the display, below the
  /// safe area inset. Enemies enter from the top of the screen, which is where
  /// the score and the level number sit, so without a band they fly straight
  /// across the text and neither one reads.
  static const double hudBandHeight = 104;

  /// Added to it during a boss fight, which puts a name, a phase and up to two
  /// armour bars above the play area.
  static const double hudBandBossExtra = 84;

  /// The readout pills across the top of the play area.
  ///
  /// Shorter than the 46 the menu uses and outlined at 2 rather than 3: these
  /// sit over the game rather than on a page of their own, and a menu weight
  /// outline at this height closes the pill up until it reads as a solid bar.
  static const double hudPillHeight = 30;
  static const double hudPillRound = 15;
  static const double hudPillEdge = 2;

  /// The level pill, which is the one readout that names where you are.
  static const double hudLevelPillHeight = 38;

  /// How opaque the solid part of that band is. Enough to read white text over
  /// a red enemy, not so much that the enemy disappears behind it.
  static const double hudBandAlpha = 0.72;

  /// Where the band starts fading out, as a fraction of its height. The fade
  /// is what stops a ship crossing a visible hard edge on its way in.
  static const double hudBandFadeStart = 0.55;

  /// How far inside the side edges an enemy has to be before the first run
  /// lesson will point at it.
  static const double enemyMarkInset = 28;

  /// And how far down, as a fraction of the screen.
  ///
  /// Well below the display rather than just clear of it. Measured from the
  /// bottom of the display, the mark fires on the frame an enemy first clips
  /// the top corner: it is technically on screen, it is behind the hand that
  /// is pointing at it, and because the game freezes on that same frame the
  /// player is shown a ring in the corner with apparently nothing in it.
  static const double enemyMarkTopFraction = 0.30;

  /// And how far up from the bottom. The caption sits low on the glass, so an
  /// enemy marked down there would have the explanation laid over it.
  static const double enemyMarkClearance = 300;

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

  /// How round the corners of a panel are.
  ///
  /// This replaced a chamfer. A cut corner reads as machined, which is exactly
  /// the wrong note: the whole interface is meant to look moulded. All four
  /// corners, equally.
  static const double panelRound = 26;

  /// How high a control floats above the sky, as the offset of the one soft
  /// shadow it casts.
  ///
  /// There used to be a solid coloured band here as well, drawn as the side of
  /// a key. It was removed: under every button it read as a second edge
  /// fighting the light on top, and under the amber one it read as a stripe of
  /// dirt.
  static const double liftDepth = 7;

  /// The same, under a small control, where the full height looks clumsy.
  static const double liftDepthSmall = 5;

  /// What that drops to while the control is held.
  ///
  /// Not zero. The shadow closing right up is what says the button has been
  /// pushed onto the screen, and a shadow that vanishes says it has left it.
  static const double liftPressed = 2;

  /// How far the face itself travels while held, and the room kept below it
  /// for that to happen in.
  ///
  /// Small. With no band to sink onto, a long travel reads as the button
  /// sliding rather than being pressed.
  static const double pressSink = 4;

  /// How long the face takes to travel down, and back.
  ///
  /// Short enough to feel like the button answered the finger rather than
  /// thought about it.
  static const Duration pressFor = Duration(milliseconds: 90);

  /// The corner on a button.
  ///
  /// Rounder than a panel. A panel is a surface things sit on and wants a
  /// quiet edge; a button is an object meant to be grabbed, and the fuller
  /// corner is what makes it look grabbable.
  static const double buttonRound = 30;

  /// Smallest comfortable target. Everything tappable is checked against it.
  static const double tapTarget = 56;

  /// Height of a way into the game on the menu.
  ///
  /// One number for both of them. PLAY and ENDLESS started as two heights
  /// written at the call site and drifted apart, which read as PLAY being
  /// swollen rather than as ENDLESS being secondary. What makes PLAY the main
  /// action is the amber fill and the glow, not being taller than its
  /// neighbour.
  static const double menuActionHeight = 70;

  /// The ship badge above the game name, and how much of it fills its box.
  static const double shipMarkSize = 132;
  static const double shipMarkFit = 92;

  /// The corner on a level tile. A tile is close to square, so it takes a
  /// rounder corner than a button before it starts to look like a circle.
  static const double tileBevel = 20;

  /// How far the lit action's glow reaches.
  static const double panelGlowBlur = 24;

  // Particle counts.
  static const int explosionParticlesSmall = 14;
  static const int explosionParticlesLarge = 46;
  static const double explosionLifespanSmall = 0.45;
  static const double explosionLifespanLarge = 0.9;
  static const double thrusterInterval = 0.02;
}
