import 'dart:math' as math;
import 'dart:ui';

import 'package:vector_math/vector_math_64.dart';

/// A low poly model.
///
/// Meshes are built once per shape and shared by every component that uses
/// them, so a screen full of enemies costs one model, not one per enemy.
class Mesh {
  /// Builds a model and repairs it.
  ///
  /// Triangles are wound so their normal points away from the middle of the
  /// model. That way the shading and the back face test agree no matter what
  /// order the corners were listed in by hand.
  factory Mesh(List<Vector3> vertices, List<Face> faces) {
    final wound = _windOutward(vertices, faces);
    return Mesh._(
      vertices,
      wound,
      _buildNormals(vertices, wound),
      _isClosed(wound),
    );
  }

  Mesh._(this.vertices, this.faces, this.normals, this.closed);

  /// Corner positions in model space.
  final List<Vector3> vertices;

  /// One entry per triangle.
  final List<Face> faces;

  /// Model space normal per triangle, used for flat shading.
  final List<Vector3> normals;

  /// True when every edge is shared by exactly two triangles.
  ///
  /// A closed model can safely hide the faces turned away from the lens. An
  /// open one cannot, because the inside of it is meant to be seen.
  final bool closed;

  int get triangleCount => faces.length;

  /// Turns a hand listed set of triangles into a consistently wound surface
  /// whose normals all point out of the model.
  ///
  /// Two neighbours agree when they walk the edge they share in opposite
  /// directions, so the orientation is spread outward from one triangle to the
  /// rest. Which way is out is then settled by the signed volume: a surface
  /// wound inside out encloses a negative volume, so it is turned over. This
  /// works on a dented hull as well as a smooth one, which a test against the
  /// middle of the model would not.
  static List<Face> _windOutward(List<Vector3> vertices, List<Face> faces) {
    final wound = List<Face>.of(faces);
    final byEdge = <int, List<int>>{};
    for (var i = 0; i < wound.length; i++) {
      final face = wound[i];
      byEdge.putIfAbsent(_edgeKey(face.a, face.b), () => []).add(i);
      byEdge.putIfAbsent(_edgeKey(face.b, face.c), () => []).add(i);
      byEdge.putIfAbsent(_edgeKey(face.c, face.a), () => []).add(i);
    }

    final settled = List<bool>.filled(wound.length, false);
    final group = <int>[];
    final queue = <int>[];

    for (var start = 0; start < wound.length; start++) {
      if (settled[start]) {
        continue;
      }
      group.clear();
      queue
        ..clear()
        ..add(start);
      settled[start] = true;

      while (queue.isNotEmpty) {
        final index = queue.removeLast();
        group.add(index);
        final face = wound[index];
        _spread(wound, byEdge, settled, queue, face.a, face.b);
        _spread(wound, byEdge, settled, queue, face.b, face.c);
        _spread(wound, byEdge, settled, queue, face.c, face.a);
      }

      var volume = 0.0;
      for (final index in group) {
        final face = wound[index];
        volume += vertices[face.a].dot(
          vertices[face.b].cross(vertices[face.c]),
        );
      }
      if (volume < 0) {
        for (final index in group) {
          final face = wound[index];
          wound[index] = Face(face.a, face.c, face.b, face.color);
        }
      }
    }
    return wound;
  }

  /// Hands the orientation of one triangle to the neighbour across an edge.
  static void _spread(
    List<Face> wound,
    Map<int, List<int>> byEdge,
    List<bool> settled,
    List<int> queue,
    int from,
    int to,
  ) {
    for (final index in byEdge[_edgeKey(from, to)]!) {
      if (settled[index]) {
        continue;
      }
      settled[index] = true;
      final face = wound[index];
      // Neighbours that walk the shared edge the same way disagree, so one of
      // them has to be turned over.
      final sameWay =
          (face.a == from && face.b == to) ||
          (face.b == from && face.c == to) ||
          (face.c == from && face.a == to);
      if (sameWay) {
        wound[index] = Face(face.a, face.c, face.b, face.color);
      }
      queue.add(index);
    }
  }

  static int _edgeKey(int x, int y) => x < y ? x * 1024 + y : y * 1024 + x;

  /// A model is closed when every edge is shared by exactly two triangles.
  static bool _isClosed(List<Face> faces) {
    final counts = <int, int>{};
    void count(int x, int y) {
      final key = _edgeKey(x, y);
      counts[key] = (counts[key] ?? 0) + 1;
    }

    for (final face in faces) {
      count(face.a, face.b);
      count(face.b, face.c);
      count(face.c, face.a);
    }
    return counts.isNotEmpty && counts.values.every((value) => value == 2);
  }

  static List<Vector3> _buildNormals(List<Vector3> vertices, List<Face> faces) {
    return [
      for (final face in faces)
        (vertices[face.b] - vertices[face.a]).cross(
          vertices[face.c] - vertices[face.a],
        )..normalize(),
    ];
  }

  /// The largest distance from the origin, used to size hitboxes and to cull.
  double get radius {
    var most = 0.0;
    for (final vertex in vertices) {
      final length = vertex.length;
      if (length > most) {
        most = length;
      }
    }
    return most;
  }
}

/// One triangle of a mesh.
class Face {
  const Face(this.a, this.b, this.c, this.color);

  final int a;
  final int b;
  final int c;
  final Color color;
}

/// Builders for every shape in the game.
///
/// Everything is generated from numbers rather than loaded from a model file,
/// which keeps the download small and lets a colour change happen in code.
class Meshes {
  const Meshes._();

  /// The airframe every ship in the game is cut from.
  ///
  /// One body, different numbers. The player ship and all eight enemy families
  /// are built the same way: a six sided fuselage that tapers to a point at the
  /// nose and to an exhaust at the tail, a swept wing with real thickness on
  /// each side, a raised canopy and a pair of canted tail fins. Families are
  /// told apart by proportion and colour, so an enemy reads as a ship from the
  /// same yard rather than a shard of something.
  ///
  /// The parts are separate closed shells rather than one welded surface. That
  /// is what lets a wing have an edge without leaving a hole in the hull, and
  /// the renderer only ever needs each shell to be watertight on its own.
  ///
  /// Every z value is given in the player's terms, nose forward. [facing] of
  /// -1 turns the hull around for an enemy flying at the player, so no builder
  /// has to think in reverse.
  static Mesh _airframe({
    required Color body,
    required Color trim,
    required Color accent,
    required double nose,
    required double span,
    required double sweep,
    required double wingDrop,
    required double spine,
    required double spineZ,
    required double keel,
    required double keelZ,
    required double tailSpan,
    required double tail,
    bool pods = false,
    bool canards = false,
    Color? podColor,
    double facing = 1,
    double s = 1,
  }) {
    double z(double value) => value * facing * s;
    double u(double value) => value * s;

    final vertices = <Vector3>[];
    final faces = <Face>[];

    /// A point along the length of the hull, 0 at the nose and 1 at the tail.
    double along(double t) => nose + (tail - nose) * t;

    // Half width of the fuselage. Everything else is measured against it, so a
    // family with a wider wing gets a wider body to carry it.
    final bodyWidth = math.max(span * 0.20, 1.2);

    // A ring is one cross section of the fuselage: six points around a shape
    // that is rounded on top and flatter underneath, the way a real airframe
    // sits over its own undercarriage.
    const ringX = <double>[0, 0.92, 0.78, 0, -0.78, -0.92];
    const ringY = <double>[1, 0.30, -0.55, -1, -0.55, 0.30];

    int addRing(double atZ, double scale) {
      final first = vertices.length;
      final width = bodyWidth * scale;
      final top = spine * 0.62 * scale;
      final bottom = keel * 0.85 * scale;
      for (var i = 0; i < 6; i++) {
        final height = ringY[i] >= 0 ? ringY[i] * top : ringY[i] * bottom;
        vertices.add(Vector3(u(ringX[i] * width), u(height), z(atZ)));
      }
      return first;
    }

    // The two lower segments of every ring are the belly, which is kept in the
    // darker trim so the ship reads as lit from above.
    Color ringColor(int segment) => segment == 2 || segment == 3 ? trim : body;

    void strip(int from, int to) {
      for (var i = 0; i < 6; i++) {
        final j = (i + 1) % 6;
        faces
          ..add(Face(from + i, to + i, to + j, ringColor(i)))
          ..add(Face(from + i, to + j, from + j, ringColor(i)));
      }
    }

    final noseIndex = vertices.length;
    vertices.add(Vector3(0, 0, z(nose)));
    final forward = addRing(along(0.30), 0.55);
    final middle = addRing(along(0.60), 1.0);
    final aft = addRing(along(0.90), 0.72);
    final exhaustIndex = vertices.length;
    vertices.add(Vector3(0, u(spine * 0.05), z(tail)));

    for (var i = 0; i < 6; i++) {
      final j = (i + 1) % 6;
      faces.add(Face(noseIndex, forward + i, forward + j, ringColor(i)));
    }
    strip(forward, middle);
    strip(middle, aft);
    for (var i = 0; i < 6; i++) {
      final j = (i + 1) % 6;
      faces.add(Face(exhaustIndex, aft + j, aft + i, accent));
    }

    // A wing: a thin plate with a swept leading edge, a short tip chord and a
    // root buried in the fuselage. Given thickness rather than drawn flat,
    // because a wing with no edge on it is what made the old hulls read as
    // paper darts.
    void wing(double side) {
      final rootX = bodyWidth * 0.75;
      final rootLead = along(0.34);
      final rootTrail = keelZ;
      final tipChord = (rootLead - rootTrail) * 0.30;
      final rootThick = math.max(spine * 0.16, 0.35);
      final tipThick = rootThick * 0.4;
      final rootY = -keel * 0.12;

      final corners = <List<double>>[
        [side * rootX, rootY, rootLead, rootThick],
        [side * span, -wingDrop, sweep + tipChord * 0.5, tipThick],
        [side * span, -wingDrop, sweep - tipChord * 0.5, tipThick],
        [side * rootX, rootY, rootTrail, rootThick],
      ];

      final base = vertices.length;
      for (final lift in const [1.0, -1.0]) {
        for (final corner in corners) {
          vertices.add(
            Vector3(
              u(corner[0]),
              u(corner[1] + corner[3] * lift),
              z(corner[2]),
            ),
          );
        }
      }
      faces
        ..add(Face(base, base + 1, base + 2, body))
        ..add(Face(base, base + 2, base + 3, body))
        ..add(Face(base + 4, base + 6, base + 5, trim))
        ..add(Face(base + 4, base + 7, base + 6, trim));
      for (var i = 0; i < 4; i++) {
        final j = (i + 1) % 4;
        faces
          ..add(Face(base + i, base + 4 + i, base + 4 + j, trim))
          ..add(Face(base + i, base + 4 + j, base + j, trim));
      }
    }

    // A tail fin, canted outward. Two of them are what tells the eye at a
    // glance which way a ship is pointing.
    void fin(double side) {
      final baseX = side * math.max(bodyWidth * 0.55, tailSpan * 0.30);
      final thick = math.max(bodyWidth * 0.16, 0.3);
      final root = spine * 0.35;
      final top = spine * 0.72 + tailSpan * 0.20;

      final outline = <List<double>>[
        [baseX, root, along(0.72)],
        [baseX, root, along(0.99)],
        [baseX + side * tailSpan * 0.55, top, along(0.94)],
      ];

      final base = vertices.length;
      for (final offset in const [1.0, -1.0]) {
        for (final point in outline) {
          vertices.add(
            Vector3(u(point[0] + thick * offset), u(point[1]), z(point[2])),
          );
        }
      }
      faces
        ..add(Face(base, base + 1, base + 2, trim))
        ..add(Face(base + 3, base + 5, base + 4, trim));
      for (var i = 0; i < 3; i++) {
        final j = (i + 1) % 3;
        faces
          ..add(Face(base + i, base + 3 + i, base + 3 + j, trim))
          ..add(Face(base + i, base + 3 + j, base + j, trim));
      }
    }

    wing(-1);
    wing(1);
    fin(-1);
    fin(1);

    // The canopy: a raised ridge over the forward fuselage. It is the one part
    // that says where the pilot sits, so it gets the accent colour.
    final front = along(0.20);
    final back = spineZ;
    final canopyWidth = bodyWidth * 0.42;
    final sill = spine * 0.52;
    final ridge = spine * 1.02;
    final inset = (front - back) * 0.25;
    final canopy = vertices.length;
    vertices
      ..add(Vector3(u(-canopyWidth), u(sill), z(front)))
      ..add(Vector3(u(canopyWidth), u(sill), z(front)))
      ..add(Vector3(u(canopyWidth), u(sill), z(back)))
      ..add(Vector3(u(-canopyWidth), u(sill), z(back)))
      ..add(Vector3(0, u(ridge), z(front - inset)))
      ..add(Vector3(0, u(ridge), z(back + inset)));
    faces
      ..add(Face(canopy, canopy + 1, canopy + 2, trim))
      ..add(Face(canopy, canopy + 2, canopy + 3, trim))
      ..add(Face(canopy + 1, canopy + 2, canopy + 5, accent))
      ..add(Face(canopy + 1, canopy + 5, canopy + 4, accent))
      ..add(Face(canopy, canopy + 4, canopy + 5, accent))
      ..add(Face(canopy, canopy + 5, canopy + 3, accent))
      ..add(Face(canopy, canopy + 1, canopy + 4, accent))
      ..add(Face(canopy + 2, canopy + 3, canopy + 5, accent));

    // Ordnance the player has actually bought, bolted where it would go on a
    // real airframe. The rack the ship carries is visible on the ship, so an
    // upgrade is something you can see rather than a number on a screen.
    if (pods) {
      final chord = (along(0.32) - along(0.80)).abs() * 0.5;
      for (final side in const [-1.0, 1.0]) {
        _box(
          vertices,
          faces,
          x: u(side * span * 0.56),
          y: u(-wingDrop * 0.35),
          z: z(along(0.56)),
          halfWidth: u(math.max(span * 0.07, 0.7)),
          halfHeight: u(math.max(spine * 0.30, 0.7)),
          halfDepth: u(chord),
          top: podColor ?? accent,
          side: podColor ?? accent,
        );
      }
    }
    if (canards) {
      for (final side in const [-1.0, 1.0]) {
        _slab(
          vertices,
          faces,
          outline: [
            [u(side * bodyWidth * 1.0), z(along(0.10))],
            [u(side * bodyWidth * 3.6), z(along(0.30))],
            [u(side * bodyWidth * 1.0), z(along(0.34))],
          ],
          thickness: u(math.max(spine * 0.10, 0.3)),
          top: accent,
          side: trim,
          y: u(spine * 0.28),
        );
      }
    }

    return Mesh(vertices, faces);
  }

  /// The canopy colour for an enemy, a lifted version of its own hull.
  static Color _canopy(Color body) =>
      Color.lerp(body, const Color(0xFFFFFFFF), 0.38)!;

  /// A player hull: a swept delta wing with a raised canopy.
  ///
  /// The numbers come from the ship catalog, so a new hull is a row of data
  /// rather than a new model.
  static Mesh ship({
    required Color hull,
    required Color hullDark,
    required Color accent,
    bool pods = false,
    bool canards = false,
    Color? podColor,
    double nose = 26,
    double span = 20,
    double sweep = -14,
    double spine = 7,
    double keel = 4,
    double tailSpan = 7,
  }) {
    return _airframe(
      body: hull,
      trim: hullDark,
      accent: accent,
      pods: pods,
      canards: canards,
      podColor: podColor,
      nose: nose,
      span: span,
      sweep: sweep,
      wingDrop: 2,
      spine: spine,
      spineZ: -6,
      keel: keel,
      keelZ: -10,
      tailSpan: tailSpan,
      tail: -16,
    );
  }

  /// A missile: the same hull shrunk to a finned dart, so the ordnance looks
  /// like it came off the same rack as the ship that launched it.
  static Mesh missile({
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
      wingDrop: 0,
      spine: 2.6,
      spineZ: -3,
      keel: 2.6,
      keelZ: -3,
      tailSpan: 2.8,
      tail: -7,
    );
  }

  /// A flak shell: shorter and fatter than a missile, because it is a canister
  /// of shrapnel rather than something that has to fly a long way.
  static Mesh shell({
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
      wingDrop: 0,
      spine: 4.4,
      spineZ: -2,
      keel: 4.4,
      keelZ: -2,
      tailSpan: 4,
      tail: -5,
    );
  }

  /// Adds a closed slab with a flat top and bottom and a straight rim.
  ///
  /// The [outline] is given as x and z pairs in the plane the game is played
  /// across, which is the plane the reference art is drawn in. Everything that
  /// is a body rather than an aircraft is built from one of these: a shape seen
  /// from above, given enough thickness to catch the light.
  ///
  /// The outline must be convex, because the top and bottom are closed with a
  /// fan from the first point.
  static void _slab(
    List<Vector3> vertices,
    List<Face> faces, {
    required List<List<double>> outline,
    required double thickness,
    required Color top,
    required Color side,
    double y = 0,
  }) {
    final base = vertices.length;
    final count = outline.length;
    for (final lift in const [1.0, -1.0]) {
      for (final point in outline) {
        vertices.add(Vector3(point[0], y + thickness * lift, point[1]));
      }
    }
    for (var i = 1; i < count - 1; i++) {
      faces
        ..add(Face(base, base + i, base + i + 1, top))
        ..add(Face(base + count, base + count + i + 1, base + count + i, side));
    }
    for (var i = 0; i < count; i++) {
      final j = (i + 1) % count;
      faces
        ..add(Face(base + i, base + count + i, base + count + j, side))
        ..add(Face(base + i, base + count + j, base + j, side));
    }
  }

  /// Adds a closed box, used for pods, barrels and thruster housings.
  static void _box(
    List<Vector3> vertices,
    List<Face> faces, {
    required double x,
    required double y,
    required double z,
    required double halfWidth,
    required double halfHeight,
    required double halfDepth,
    required Color top,
    required Color side,
  }) {
    _slab(
      vertices,
      faces,
      outline: [
        [x - halfWidth, z - halfDepth],
        [x + halfWidth, z - halfDepth],
        [x + halfWidth, z + halfDepth],
        [x - halfWidth, z + halfDepth],
      ],
      thickness: halfHeight,
      top: top,
      side: side,
      y: y,
    );
  }

  /// Adds a closed six sided lump, used for cores and glowing centres.
  static void _core(
    List<Vector3> vertices,
    List<Face> faces, {
    required double x,
    required double y,
    required double z,
    required double radius,
    required double height,
    required Color color,
  }) {
    final base = vertices.length;
    vertices
      ..add(Vector3(x, y + height, z))
      ..add(Vector3(x, y - height, z))
      ..add(Vector3(x + radius, y, z))
      ..add(Vector3(x, y, z + radius))
      ..add(Vector3(x - radius, y, z))
      ..add(Vector3(x, y, z - radius));
    for (var i = 0; i < 4; i++) {
      final a = base + 2 + i;
      final b = base + 2 + (i + 1) % 4;
      faces
        ..add(Face(base, a, b, color))
        ..add(Face(base + 1, b, a, color));
    }
  }

  /// A regular outline, for the round bodies.
  static List<List<double>> _ring(
    int count, {
    required double radiusX,
    required double radiusZ,
    double turn = 0,
  }) {
    return [
      for (var i = 0; i < count; i++)
        [
          math.cos(i * math.pi * 2 / count + turn) * radiusX,
          math.sin(i * math.pi * 2 / count + turn) * radiusZ,
        ],
    ];
  }

  /// The scout: a light interceptor, the shape the rest are measured against.
  static Mesh scout({required Color body, required Color trim, double s = 1}) {
    return _airframe(
      body: body,
      trim: trim,
      accent: _canopy(body),
      facing: -1,
      s: s,
      nose: 16,
      span: 11,
      sweep: -8,
      wingDrop: 1,
      spine: 6,
      spineZ: -3,
      keel: 4,
      keelZ: -6,
      tailSpan: 6,
      tail: -11,
    );
  }

  /// The darter: a long needle on short wings, built to read as fast.
  static Mesh darter({required Color body, required Color trim, double s = 1}) {
    return _airframe(
      body: body,
      trim: trim,
      accent: _canopy(body),
      facing: -1,
      s: s,
      nose: 22,
      span: 11,
      sweep: -6,
      wingDrop: 1,
      spine: 5,
      spineZ: -6,
      keel: 3,
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
  static Mesh gunner({required Color body, required Color trim, double s = 1}) {
    final vertices = <Vector3>[];
    final faces = <Face>[];
    double u(double value) => value * s;

    _slab(
      vertices,
      faces,
      outline: [
        [u(-8), u(-11)],
        [u(8), u(-11)],
        [u(14), u(-1)],
        [u(9), u(9)],
        [u(-9), u(9)],
        [u(-14), u(-1)],
      ],
      thickness: u(4),
      top: body,
      side: trim,
    );
    // The lit plate on the back of the hull, which the art gives it instead of
    // a canopy because there is nobody sitting in the front of this thing.
    _slab(
      vertices,
      faces,
      outline: [
        [u(-4), u(-4)],
        [u(4), u(-4)],
        [u(4), u(3)],
        [u(-4), u(3)],
      ],
      thickness: u(1),
      top: _canopy(body),
      side: trim,
      y: u(4),
    );
    for (final side in const [-1.0, 1.0]) {
      _box(
        vertices,
        faces,
        x: u(side * 16),
        y: 0,
        z: u(1),
        halfWidth: u(3.5),
        halfHeight: u(3.5),
        halfDepth: u(9),
        top: body,
        side: trim,
      );
    }
    return Mesh(vertices, faces);
  }

  /// The bomber: a rounded shell with nothing sharp on it.
  ///
  /// Round is the point. Everything else in a wave has a nose, so the one
  /// thing that does not reads as slow and heavy before it does anything.
  static Mesh bomber({required Color body, required Color trim, double s = 1}) {
    final vertices = <Vector3>[];
    final faces = <Face>[];
    double u(double value) => value * s;

    const count = 8;
    final base = vertices.length;
    vertices.add(Vector3(0, u(7), 0));
    for (final level in const [0.45, -0.45]) {
      for (var i = 0; i < count; i++) {
        final angle = i * math.pi * 2 / count;
        final shrink = 1 - level.abs() * 0.35;
        vertices.add(
          Vector3(
            math.cos(angle) * u(11) * shrink,
            u(7) * level,
            math.sin(angle) * u(14) * shrink,
          ),
        );
      }
    }
    vertices.add(Vector3(0, u(-7), 0));
    final upper = base + 1;
    final lower = upper + count;
    final bottom = lower + count;
    for (var i = 0; i < count; i++) {
      final j = (i + 1) % count;
      faces
        ..add(Face(base, upper + i, upper + j, body))
        ..add(Face(upper + i, lower + i, lower + j, i.isEven ? body : trim))
        ..add(Face(upper + i, lower + j, upper + j, i.isEven ? body : trim))
        ..add(Face(bottom, lower + j, lower + i, trim));
    }
    // The two dark fins the art puts on its flanks, which stop the shell from
    // reading as a floating egg.
    for (final side in const [-1.0, 1.0]) {
      _box(
        vertices,
        faces,
        x: u(side * 12),
        y: 0,
        z: u(4),
        halfWidth: u(2),
        halfHeight: u(4),
        halfDepth: u(4),
        top: trim,
        side: trim,
      );
    }
    return Mesh(vertices, faces);
  }

  /// The shielder: a hard hexagonal hull behind a curved barrier.
  ///
  /// The barrier is part of the model rather than an effect, because it is the
  /// thing the player has to get around and it should never blink out.
  static Mesh shielder({
    required Color body,
    required Color trim,
    double s = 1,
  }) {
    final vertices = <Vector3>[];
    final faces = <Face>[];
    double u(double value) => value * s;

    _slab(
      vertices,
      faces,
      outline: _ring(6, radiusX: u(11), radiusZ: u(12), turn: math.pi / 6),
      thickness: u(5),
      top: body,
      side: trim,
    );
    _core(
      vertices,
      faces,
      x: 0,
      y: u(5),
      z: 0,
      radius: u(5),
      height: u(3),
      color: _canopy(body),
    );
    // Three plates set on an arc across the front.
    for (var i = -1; i <= 1; i++) {
      final angle = i * 0.42;
      _box(
        vertices,
        faces,
        x: math.sin(angle) * u(17),
        y: 0,
        z: -math.cos(angle) * u(17),
        halfWidth: u(5),
        halfHeight: u(2),
        halfDepth: u(2),
        top: _canopy(body),
        side: trim,
      );
    }
    return Mesh(vertices, faces);
  }

  /// The splitter: one hull with a seam down it, waiting to come apart.
  ///
  /// Built as two halves with a gap between them, so what happens when it dies
  /// is written on it before it dies.
  static Mesh splitter({
    required Color body,
    required Color trim,
    double s = 1,
  }) {
    final vertices = <Vector3>[];
    final faces = <Face>[];
    double u(double value) => value * s;

    for (final side in const [-1.0, 1.0]) {
      _slab(
        vertices,
        faces,
        outline: [
          [side * u(1.5), u(-13)],
          [side * u(9), u(-6)],
          [side * u(11), u(4)],
          [side * u(6), u(11)],
          [side * u(1.5), u(9)],
        ],
        thickness: u(5),
        top: body,
        side: trim,
      );
      _core(
        vertices,
        faces,
        x: side * u(6),
        y: u(5),
        z: u(1),
        radius: u(2.6),
        height: u(1.6),
        color: _canopy(body),
      );
    }
    return Mesh(vertices, faces);
  }

  /// The turret: a gun mount that happens to fly.
  ///
  /// A drum with a barrel out of the front of it. It never manoeuvres, so it
  /// is given no wing at all and reads as something bolted down.
  static Mesh turret({required Color body, required Color trim, double s = 1}) {
    final vertices = <Vector3>[];
    final faces = <Face>[];
    double u(double value) => value * s;

    _slab(
      vertices,
      faces,
      outline: _ring(10, radiusX: u(13), radiusZ: u(13)),
      thickness: u(5),
      top: body,
      side: trim,
    );
    _core(
      vertices,
      faces,
      x: 0,
      y: u(4),
      z: 0,
      radius: u(6),
      height: u(4),
      color: _canopy(body),
    );
    _box(
      vertices,
      faces,
      x: 0,
      y: 0,
      z: u(-15),
      halfWidth: u(3),
      halfHeight: u(3),
      halfDepth: u(7),
      top: trim,
      side: trim,
    );
    return Mesh(vertices, faces);
  }

  /// The kamikaze: a spear with just enough wing to steer.
  static Mesh kamikaze({
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
      wingDrop: 1,
      spine: 4,
      spineZ: -5,
      keel: 4,
      keelZ: -8,
      tailSpan: 4,
      tail: -14,
    );
  }

  /// A lump of rock. The seed picks one of a few shapes, so a field of them
  /// does not look stamped out.
  static Mesh asteroid({
    required Color body,
    required Color trim,
    required int seed,
    double s = 1,
  }) {
    final rng = math.Random(seed);
    final vertices = <Vector3>[];
    const rings = [
      [0.0, 1.0],
      [0.55, 0.85],
      [-0.55, 0.85],
    ];
    for (final ring in rings) {
      for (var i = 0; i < 5; i++) {
        final angle = i * math.pi * 2 / 5 + ring[0];
        final radius = (0.75 + rng.nextDouble() * 0.5) * 11 * s * ring[1];
        vertices.add(
          Vector3(
            math.cos(angle) * radius,
            ring[0] * 9 * s + (rng.nextDouble() - 0.5) * 3 * s,
            math.sin(angle) * radius,
          ),
        );
      }
    }
    vertices
      ..add(Vector3(0, 12 * s, 0))
      ..add(Vector3(0, -12 * s, 0));

    final faces = <Face>[];
    for (var ring = 0; ring < 2; ring++) {
      for (var i = 0; i < 5; i++) {
        final a = ring * 5 + i;
        final b = ring * 5 + (i + 1) % 5;
        faces
          ..add(Face(a, b, b + 5, i.isEven ? body : trim))
          ..add(Face(a, b + 5, a + 5, i.isEven ? trim : body));
      }
    }
    for (var i = 0; i < 5; i++) {
      faces
        ..add(Face(15, (i + 1) % 5, i, i.isEven ? body : trim))
        ..add(Face(16, 10 + i, 10 + (i + 1) % 5, i.isEven ? trim : body));
    }
    return Mesh(vertices, faces);
  }

  static Mesh gem({
    required Color body,
    required Color trim,
    double size = 14,
  }) {
    final vertices = [
      Vector3(0, size, 0),
      Vector3(0, -size, 0),
      Vector3(size, 0, 0),
      Vector3(-size, 0, 0),
      Vector3(0, 0, size),
      Vector3(0, 0, -size),
    ];
    final faces = [
      Face(0, 4, 2, body),
      Face(0, 2, 5, trim),
      Face(0, 5, 3, body),
      Face(0, 3, 4, trim),
      Face(1, 2, 4, trim),
      Face(1, 5, 2, body),
      Face(1, 3, 5, trim),
      Face(1, 4, 3, body),
    ];
    return Mesh(vertices, faces);
  }

  /// A wide hull for the bosses.
  ///
  /// A broad angular plate with a lit core sitting in the middle of it and a
  /// pair of thruster housings at the back. The core is what the player aims
  /// at, so it is built as its own solid and given the brightest colour on
  /// screen.
  static Mesh capital({
    required Color hull,
    required Color hullDark,
    required Color core,
    required Color glow,
    required double width,
    required double height,
    required double depth,
  }) {
    final w = width / 2;
    final h = height / 2;
    final d = depth / 2;

    final vertices = <Vector3>[];
    final faces = <Face>[];

    // Seen from above: a point at the back, wide shoulders, and a flat face
    // turned toward the player.
    const outline = <List<double>>[
      [0, 1.0],
      [0.62, 0.5],
      [0.96, -0.15],
      [0.6, -0.8],
      [-0.6, -0.8],
      [-0.96, -0.15],
      [-0.62, 0.5],
    ];
    _slab(
      vertices,
      faces,
      outline: [
        for (final point in outline) [point[0] * w, point[1] * d],
      ],
      thickness: h,
      top: hull,
      side: hullDark,
    );
    _core(
      vertices,
      faces,
      x: 0,
      y: h * 0.85,
      z: -d * 0.14,
      radius: w * 0.26,
      height: h * 0.95,
      color: core,
    );
    for (final side in const [-1.0, 1.0]) {
      _box(
        vertices,
        faces,
        x: side * w * 0.20,
        y: 0,
        z: -d * 1.02,
        halfWidth: w * 0.08,
        halfHeight: h * 0.55,
        halfDepth: d * 0.14,
        top: glow,
        side: glow,
      );
    }
    return Mesh(vertices, faces);
  }

  /// A weak point on a boss: a lit block on the end of a short mount.
  ///
  /// Destroying these is what exposes the core, so each one carries the same
  /// glow the core does and nothing else on the hull is allowed to.
  static Mesh weakPoint({
    required Color hull,
    required Color hullDark,
    required Color core,
    required double radius,
  }) {
    final vertices = <Vector3>[];
    final faces = <Face>[];
    _slab(
      vertices,
      faces,
      outline: _ring(6, radiusX: radius, radiusZ: radius * 1.1),
      thickness: radius * 0.55,
      top: hull,
      side: hullDark,
    );
    _core(
      vertices,
      faces,
      x: 0,
      y: radius * 0.5,
      z: -radius * 0.12,
      radius: radius * 0.62,
      height: radius * 0.5,
      color: core,
    );
    return Mesh(vertices, faces);
  }
}
