import 'dart:math' as math;
import 'dart:ui';

/// One flat filled shape inside a sprite.
///
/// The points are given in sprite space, which is the screen the game is read
/// on: x runs right and y runs down. The path is built once when the sprite is
/// built, so drawing a shape is a transform and a fill rather than a walk over
/// a list of corners every frame.
class SpritePart {
  SpritePart(this.points, this.fill, {this.outlined = true})
    : path = _pathOf(points);

  /// The corners, in the order they are walked. Kept alongside the path so a
  /// wreck can cut the shape up without having to read it back out of one.
  final List<Offset> points;

  /// The shape, closed, in sprite space.
  final Path path;

  /// The flat colour it is filled with. There is no lighting: a flat sprite
  /// gets its shape from its outline and from the colours next to it.
  final Color fill;

  /// Whether the dark keyline is drawn round it.
  ///
  /// Off for the small lit details that sit inside a hull, because an outline
  /// round a canopy a few pixels across reads as a smudge.
  final bool outlined;

  static Path _pathOf(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    return path..close();
  }
}

/// A flat, top down shape drawn straight onto the canvas.
///
/// This is what replaced the models. The game was always seen through a lens
/// with no perspective, so every corner of every model landed on the screen
/// through the same fixed multiply. Nothing was gained by carrying the third
/// dimension through the renderer, and a great deal was lost: the hulls came
/// out shaded and muted rather than reading as arcade art at a glance.
class Sprite2D {
  Sprite2D(this.parts) : bounds = _boundsOf(parts);

  /// Painted in order, so the last part is the one on top.
  final List<SpritePart> parts;

  /// The box the whole sprite fits in, used to fit one into a widget.
  final Rect bounds;

  static Rect _boundsOf(List<SpritePart> parts) {
    if (parts.isEmpty) {
      return Rect.zero;
    }
    var box = parts.first.path.getBounds();
    for (final part in parts.skip(1)) {
      box = box.expandToInclude(part.path.getBounds());
    }
    return box;
  }
}

/// Every shape in the game.
///
/// The families are told apart by proportion, the way they were when they were
/// models: one airframe with different numbers for the ships that fly, and a
/// hand drawn outline for the things that do not.
///
/// A shape is authored nose forward in the player's terms, so a builder never
/// has to think in reverse. Passing a facing of -1 turns it round for
/// something flying at the player.
class Sprites {
  const Sprites._();

  /// Turns the right hand half of an outline into a whole symmetric shape.
  ///
  /// Points are given as x and z pairs walking the outline in one direction,
  /// nose first, with x at or above zero. The mirror is walked back the other
  /// way so the shape closes without a seam, and a point sitting on the centre
  /// line is not repeated.
  ///
  /// z is negated on the way in because up the lane is up the screen.
  static List<Offset> _sym(List<List<double>> half) {
    final points = <Offset>[];
    for (final point in half) {
      points.add(Offset(point[0], -point[1]));
    }
    for (var i = half.length - 1; i >= 0; i--) {
      if (half[i][0].abs() < 0.001) {
        continue;
      }
      points.add(Offset(-half[i][0], -half[i][1]));
    }
    return points;
  }

  /// A closed outline given as whole x and z pairs, used where a shape is not
  /// symmetric about the centre line.
  static List<Offset> _outline(List<List<double>> points) {
    return [for (final point in points) Offset(point[0], -point[1])];
  }

  /// An even sided outline, for the round bodies.
  static List<Offset> _ring(
    int count, {
    required double radiusX,
    required double radiusZ,
    double turn = 0,
    double atX = 0,
    double atZ = 0,
  }) {
    return [
      for (var i = 0; i < count; i++)
        Offset(
          atX + math.cos(i * math.pi * 2 / count + turn) * radiusX,
          -(atZ + math.sin(i * math.pi * 2 / count + turn) * radiusZ),
        ),
    ];
  }

  /// A rectangle centred on a point, for pods, barrels and thruster housings.
  static List<Offset> _box({
    required double x,
    required double z,
    required double halfWidth,
    required double halfDepth,
  }) {
    return _outline([
      [x - halfWidth, z + halfDepth],
      [x + halfWidth, z + halfDepth],
      [x + halfWidth, z - halfDepth],
      [x - halfWidth, z - halfDepth],
    ]);
  }

  /// A colour lifted toward white, used for canopies and lit plates.
  static Color _lift(Color base, double amount) =>
      Color.lerp(base, const Color(0xFFFFFFFF), amount)!;

  /// The canopy colour for an enemy, a lifted version of its own hull.
  static Color _canopy(Color body) => _lift(body, 0.38);

  /// The ink a face is drawn in.
  ///
  /// Near black rather than black, so an eye on a pale canopy reads as an eye
  /// rather than as a hole punched through the hull.
  static const Color _faceInk = Color(0xFF12103A);

  /// How many sides an eye is cut from. Eight is round enough at the size one
  /// is drawn and a quarter of the points a real circle would cost.
  static const int _eyeSides = 8;

  /// The airframe every ship in the game is cut from.
  ///
  /// Seen from above it is a fuselage that tapers to a point at the nose, a
  /// swept wing either side of it, a pair of stabilisers at the tail, a canopy
  /// and a lit exhaust. Families are told apart by proportion and colour, so an
  /// enemy reads as a ship from the same yard rather than a shard of something.
  ///
  /// The wing is laid down before the fuselage so the body sits over it, which
  /// is all that is left of what used to be done with depth sorting.
  static Sprite2D _airframe({
    required Color body,
    required Color trim,
    required Color accent,
    required double nose,
    required double span,
    required double sweep,
    required double keelZ,
    required double tailSpan,
    required double tail,
    bool pods = false,
    bool canards = false,
    bool face = false,
    Color? podColor,
    double facing = 1,
    double s = 1,
  }) {
    double z(double value) => value * facing * s;
    double u(double value) => value * s;

    /// A point along the length of the hull, 0 at the nose and 1 at the tail.
    double along(double t) => nose + (tail - nose) * t;

    // Half width of the fuselage, measured off the wing so a family with a
    // wider wing gets a wider body to carry it.
    final bodyWidth = math.max(span * 0.20, 1.2);
    final rack = podColor ?? accent;
    final parts = <SpritePart>[];

    // The wing: a swept plate with its root buried in the fuselage and its tip
    // trailing behind the leading edge.
    final rootLead = along(0.30);
    final tipChord = (rootLead - keelZ) * 0.34;
    parts.add(
      SpritePart(_sym([
        [u(bodyWidth * 0.72), z(rootLead)],
        [u(span), z(sweep)],
        [u(span * 0.94), z(sweep - tipChord)],
        [u(bodyWidth * 0.72), z(keelZ)],
      ]), trim),
    );

    // The stabilisers, a smaller echo of the wing at the tail.
    parts.add(
      SpritePart(_sym([
        [u(bodyWidth * 0.5), z(along(0.84))],
        [u(tailSpan), z(tail + 2)],
        [u(tailSpan * 0.82), z(tail - 3)],
        [u(bodyWidth * 0.5), z(tail - 1)],
      ]), trim),
    );

    // The rack the player buys: a pod on each wing, and canards up front on
    // top of that further up. An upgrade should be visible on the hull.
    if (pods) {
      for (final side in const [-1.0, 1.0]) {
        parts.add(
          SpritePart(
            _box(
              x: u(side * span * 0.68),
              z: z(sweep + tipChord * 0.4),
              halfWidth: u(span * 0.11),
              halfDepth: u((rootLead - sweep).abs() * 0.42 + 2),
            ),
            rack,
          ),
        );
      }
    }
    if (canards) {
      for (final side in const [-1.0, 1.0]) {
        parts.add(
          SpritePart(
            _outline([
              [u(side * bodyWidth * 0.6), z(along(0.14))],
              [u(side * span * 0.48), z(along(0.06))],
              [u(side * span * 0.44), z(along(0.24))],
              [u(side * bodyWidth * 0.6), z(along(0.26))],
            ]),
            rack,
          ),
        );
      }
    }

    // The fuselage, over the top of everything bolted to it.
    parts.add(
      SpritePart(_sym([
        [0, z(nose)],
        [u(bodyWidth * 0.58), z(along(0.28))],
        [u(bodyWidth), z(along(0.58))],
        [u(bodyWidth * 0.82), z(along(0.88))],
        [u(bodyWidth * 0.58), z(tail)],
      ]), body),
    );

    // The canopy and the exhaust, the two lit details on the hull.
    //
    // A hull that carries a face gets a rounder and wider one. The narrow
    // diamond every other ship wears is too tight a container for two eyes:
    // they end up sitting on its shoulders, where they read as rivets rather
    // than as anything looking back at you.
    if (face) {
      parts.add(
        SpritePart(
          _ring(
            12,
            radiusX: u(bodyWidth * 0.66),
            radiusZ: u((along(0.16) - along(0.62)).abs() / 2),
            atX: 0,
            atZ: z(along(0.39)),
          ),
          accent,
          outlined: false,
        ),
      );
    } else {
      parts.add(
        SpritePart(_sym([
          [0, z(along(0.18))],
          [u(bodyWidth * 0.55), z(along(0.38))],
          [0, z(along(0.60))],
        ]), accent, outlined: false),
      );
    }
    parts.add(
      SpritePart(_sym([
        [u(bodyWidth * 0.5), z(tail + 2)],
        [u(bodyWidth * 0.5), z(tail - 1)],
      ]), _lift(accent, 0.35), outlined: false),
    );

    // A pair of eyes in the canopy.
    //
    // This is the cheapest change in the whole look and the one a child reads
    // first: it turns a vehicle into somebody. It is off by default because it
    // only works on a hull big enough to carry it. On a drone a few pixels
    // across the eyes collapse into one dark smudge, which reads as damage
    // rather than as a face.
    if (face) {
      final eyeX = u(bodyWidth * 0.30);
      final eyeR = u(bodyWidth * 0.26);
      for (final side in const [-1.0, 1.0]) {
        parts.add(
          SpritePart(
            _ring(
              _eyeSides,
              radiusX: eyeR,
              radiusZ: eyeR,
              atX: eyeX * side,
              atZ: z(along(0.33)),
            ),
            _faceInk,
            outlined: false,
          ),
        );
      }
      // A small open mouth under them. Flattened, because a round one reads
      // as a third eye at the size this is drawn at.
      parts.add(
        SpritePart(
          _ring(
            _eyeSides,
            radiusX: u(bodyWidth * 0.24),
            radiusZ: u(bodyWidth * 0.13),
            atX: 0,
            atZ: z(along(0.48)),
          ),
          _faceInk,
          outlined: false,
        ),
      );
    }

    return Sprite2D(parts);
  }

  /// A player hull: a swept delta wing with a raised canopy.
  ///
  /// The numbers come from the ship catalog, so a new hull is a row of data
  /// rather than a new shape.
  static Sprite2D ship({
    required Color hull,
    required Color hullDark,
    required Color accent,
    bool pods = false,
    bool canards = false,
    bool face = false,
    Color? podColor,
    double nose = 26,
    double span = 20,
    double sweep = -14,
    double tailSpan = 7,
  }) {
    return _airframe(
      body: hull,
      trim: hullDark,
      accent: accent,
      pods: pods,
      canards: canards,
      face: face,
      podColor: podColor,
      nose: nose,
      span: span,
      sweep: sweep,
      keelZ: -10,
      tailSpan: tailSpan,
      tail: -16,
    );
  }

  /// A missile: the same hull shrunk to a finned dart, so the ordnance looks
  /// like it came off the same rack as the ship that launched it.
  static Sprite2D missile({
    required Color body,
    required Color trim,
    required Color accent,
  }) {
    return _airframe(
      body: body,
      trim: trim,
      accent: accent,
      nose: 9,
      span: 3.4,
      sweep: -5,
      keelZ: -3,
      tailSpan: 2.8,
      tail: -7,
    );
  }

  /// A flak shell: shorter and fatter than a missile, because it is a canister
  /// of shrapnel rather than something that has to fly a long way.
  static Sprite2D shell({
    required Color body,
    required Color trim,
    required Color accent,
  }) {
    return _airframe(
      body: body,
      trim: trim,
      accent: accent,
      nose: 7,
      span: 5,
      sweep: -2,
      keelZ: -2,
      tailSpan: 4,
      tail: -5,
    );
  }

  /// The scout: a light interceptor, the shape the rest are measured against.
  static Sprite2D scout({
    required Color body,
    required Color trim,
    double s = 1,
  }) {
    return _airframe(
      body: body,
      trim: trim,
      accent: _canopy(body),
      facing: -1,
      s: s,
      nose: 16,
      span: 11,
      sweep: -8,
      keelZ: -6,
      tailSpan: 6,
      tail: -11,
    );
  }

  /// The darter: a long needle on short wings, built to read as fast.
  static Sprite2D darter({
    required Color body,
    required Color trim,
    double s = 1,
  }) {
    return _airframe(
      body: body,
      trim: trim,
      accent: _canopy(body),
      facing: -1,
      s: s,
      nose: 22,
      span: 11,
      sweep: -6,
      keelZ: -9,
      tailSpan: 4,
      tail: -13,
    );
  }

  /// The gunner: a weapons platform, all shoulder and no nose.
  ///
  /// Not an aircraft at all. It is a flat hull with a gun pod bolted to each
  /// side, which is what makes it read as something that came to shoot rather
  /// than something that came to fly.
  static Sprite2D gunner({
    required Color body,
    required Color trim,
    double s = 1,
  }) {
    double u(double value) => value * s;
    return Sprite2D([
      for (final side in const [-1.0, 1.0])
        SpritePart(
          _box(x: u(side * 16), z: u(1), halfWidth: u(3.5), halfDepth: u(9)),
          trim,
        ),
      SpritePart(
        _outline([
          [u(-8), u(-11)],
          [u(8), u(-11)],
          [u(14), u(-1)],
          [u(9), u(9)],
          [u(-9), u(9)],
          [u(-14), u(-1)],
        ]),
        body,
      ),
      // The lit plate on the back of the hull, which the art gives it instead
      // of a canopy because there is nobody sitting in the front of this thing.
      SpritePart(
        _box(x: 0, z: u(-0.5), halfWidth: u(4), halfDepth: u(3.5)),
        _canopy(body),
        outlined: false,
      ),
    ]);
  }

  /// The bomber: a rounded shell with nothing sharp on it.
  ///
  /// Round is the point. Everything else in a wave has a nose, so the one
  /// thing that does not reads as slow and heavy before it does anything.
  static Sprite2D bomber({
    required Color body,
    required Color trim,
    double s = 1,
  }) {
    double u(double value) => value * s;
    return Sprite2D([
      for (final side in const [-1.0, 1.0])
        SpritePart(
          _box(x: u(side * 12), z: u(4), halfWidth: u(2), halfDepth: u(4)),
          trim,
        ),
      SpritePart(_ring(10, radiusX: u(11), radiusZ: u(14)), body),
      SpritePart(
        _ring(8, radiusX: u(5.5), radiusZ: u(6.5)),
        trim,
        outlined: false,
      ),
      SpritePart(
        _ring(8, radiusX: u(2.6), radiusZ: u(3)),
        _canopy(body),
        outlined: false,
      ),
    ]);
  }

  /// The shielder: a hard hexagonal hull behind a curved barrier.
  ///
  /// The barrier is part of the shape rather than an effect, because it is the
  /// thing the player has to get around and it should never blink out.
  static Sprite2D shielder({
    required Color body,
    required Color trim,
    double s = 1,
  }) {
    double u(double value) => value * s;
    return Sprite2D([
      SpritePart(
        _ring(6, radiusX: u(11), radiusZ: u(12), turn: math.pi / 6),
        body,
      ),
      SpritePart(
        _ring(8, radiusX: u(5), radiusZ: u(5)),
        _canopy(body),
        outlined: false,
      ),
      // Three plates set on an arc across the front.
      for (var i = -1; i <= 1; i++)
        SpritePart(
          _box(
            x: math.sin(i * 0.42) * u(17),
            z: -math.cos(i * 0.42) * u(17),
            halfWidth: u(5),
            halfDepth: u(2),
          ),
          _canopy(body),
        ),
    ]);
  }

  /// The splitter: one hull with a seam down it, waiting to come apart.
  ///
  /// Built as two halves with a gap between them, so what happens when it dies
  /// is written on it before it dies.
  static Sprite2D splitter({
    required Color body,
    required Color trim,
    double s = 1,
  }) {
    double u(double value) => value * s;
    return Sprite2D([
      for (final side in const [-1.0, 1.0]) ...[
        SpritePart(
          _outline([
            [side * u(1.5), u(-13)],
            [side * u(9), u(-6)],
            [side * u(11), u(4)],
            [side * u(6), u(11)],
            [side * u(1.5), u(9)],
          ]),
          side < 0 ? body : trim,
        ),
        SpritePart(
          _ring(6, radiusX: u(2.6), radiusZ: u(2.6), atX: side * u(6), atZ: u(1)),
          _canopy(body),
          outlined: false,
        ),
      ],
    ]);
  }

  /// The turret: a gun mount that happens to fly.
  ///
  /// A drum with a barrel out of the front of it. It never manoeuvres, so it
  /// is given no wing at all and reads as something bolted down.
  static Sprite2D turret({
    required Color body,
    required Color trim,
    double s = 1,
  }) {
    double u(double value) => value * s;
    return Sprite2D([
      SpritePart(_box(x: 0, z: u(-15), halfWidth: u(3), halfDepth: u(7)), trim),
      SpritePart(_ring(10, radiusX: u(13), radiusZ: u(13)), body),
      SpritePart(
        _ring(10, radiusX: u(8), radiusZ: u(8)),
        trim,
        outlined: false,
      ),
      SpritePart(
        _ring(10, radiusX: u(6), radiusZ: u(6)),
        _canopy(body),
        outlined: false,
      ),
    ]);
  }

  /// The kamikaze: a spear with just enough wing to steer.
  static Sprite2D kamikaze({
    required Color body,
    required Color trim,
    double s = 1,
  }) {
    return _airframe(
      body: body,
      trim: trim,
      accent: _canopy(body),
      facing: -1,
      s: s,
      nose: 22,
      span: 8,
      sweep: -12,
      keelZ: -8,
      tailSpan: 4,
      tail: -14,
    );
  }

  /// A lump of rock. The seed picks the corners, so a field of them does not
  /// look stamped out.
  static Sprite2D asteroid({
    required Color body,
    required Color trim,
    required int seed,
    double s = 1,
  }) {
    final rng = math.Random(seed);
    const count = 9;
    final outer = <Offset>[];
    for (var i = 0; i < count; i++) {
      final radius = (0.72 + rng.nextDouble() * 0.5) * 11 * s;
      final angle = i * math.pi * 2 / count;
      outer.add(Offset(math.cos(angle) * radius, math.sin(angle) * radius));
    }
    // A crater set off centre, which is what stops a rock reading as a blob.
    final craterX = (rng.nextDouble() - 0.5) * 7 * s;
    final craterZ = (rng.nextDouble() - 0.5) * 7 * s;
    return Sprite2D([
      SpritePart(outer, body),
      SpritePart(
        _ring(7, radiusX: 4.2 * s, radiusZ: 3.6 * s, atX: craterX, atZ: craterZ),
        trim,
        outlined: false,
      ),
    ]);
  }

  /// A gem, for the power-ups and the coins: a cut stone with a lit facet.
  static Sprite2D gem({
    required Color body,
    required Color trim,
    double size = 14,
  }) {
    return Sprite2D([
      SpritePart(
        _outline([
          [0, size],
          [size * 0.78, 0],
          [0, -size],
          [-size * 0.78, 0],
        ]),
        body,
      ),
      SpritePart(
        _outline([
          [0, size],
          [size * 0.78, 0],
          [0, -size * 0.2],
        ]),
        trim,
        outlined: false,
      ),
      SpritePart(
        _outline([
          [0, size * 0.72],
          [size * 0.3, size * 0.2],
          [0, size * 0.1],
          [-size * 0.3, size * 0.2],
        ]),
        _lift(body, 0.55),
        outlined: false,
      ),
    ]);
  }

  /// A wide hull for the bosses.
  ///
  /// A broad angular plate with a lit core sitting in the middle of it and a
  /// pair of thruster housings at the back. The core is what the player aims
  /// at, so it carries the brightest colour on screen.
  static Sprite2D capital({
    required Color hull,
    required Color hullDark,
    required Color core,
    required Color glow,
    required double width,
    required double depth,
  }) {
    final w = width / 2;
    final d = depth / 2;

    // Seen from above: a point at the back, wide shoulders, and a flat face
    // turned toward the player.
    const shape = <List<double>>[
      [0, 1.0],
      [0.62, 0.5],
      [0.96, -0.15],
      [0.6, -0.8],
      [-0.6, -0.8],
      [-0.96, -0.15],
      [-0.62, 0.5],
    ];
    return Sprite2D([
      for (final side in const [-1.0, 1.0])
        SpritePart(
          _box(
            x: side * w * 0.20,
            z: d * 1.02,
            halfWidth: w * 0.08,
            halfDepth: d * 0.16,
          ),
          glow,
          outlined: false,
        ),
      SpritePart(
        _outline([
          for (final point in shape) [point[0] * w, point[1] * d],
        ]),
        hull,
      ),
      SpritePart(
        _outline([
          for (final point in shape) [point[0] * w * 0.62, point[1] * d * 0.62],
        ]),
        hullDark,
        outlined: false,
      ),
      SpritePart(
        _ring(10, radiusX: w * 0.26, radiusZ: w * 0.26),
        core,
        outlined: false,
      ),
    ]);
  }

  /// A weak point on a boss: a lit block on the end of a short mount.
  ///
  /// Destroying these is what exposes the core, so each one carries the same
  /// glow the core does and nothing else on the hull is allowed to.
  static Sprite2D weakPoint({
    required Color hull,
    required Color hullDark,
    required Color core,
    required double radius,
  }) {
    return Sprite2D([
      SpritePart(_ring(6, radiusX: radius, radiusZ: radius * 1.1), hull),
      SpritePart(
        _ring(6, radiusX: radius * 0.78, radiusZ: radius * 0.82),
        hullDark,
        outlined: false,
      ),
      SpritePart(
        _ring(8, radiusX: radius * 0.5, radiusZ: radius * 0.5),
        core,
        outlined: false,
      ),
    ]);
  }
}
