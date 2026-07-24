import 'dart:math' as math;
import 'dart:ui';

import 'package:vector_math/vector_math_64.dart';

import '../../theme/palette.dart';
import 'camera3d.dart';
import 'mesh.dart';

/// Draws meshes with flat shading and a painter sort.
///
/// The renderer owns scratch buffers and reuses them for every model it draws,
/// so a screen full of ships allocates nothing per frame.
class MeshRenderer {
  MeshRenderer(this.camera);

  /// Direction the key light comes from, in world space.
  static final Vector3 lightDirection = Vector3(-0.4, 0.8, -0.45)..normalize();

  /// How dark a face facing away from the light goes.
  ///
  /// Kept high on purpose. The art these hulls are cut from is flat and
  /// saturated, so the light is there to separate one panel from the next
  /// rather than to model a real sun.
  static const double ambient = 0.78;

  /// The most corners a model may have.
  static const int maxVertices = 96;

  /// The most triangles a model may have.
  static const int maxFaces = 160;

  final Camera3D camera;

  final Matrix4 _model = Matrix4.identity();
  final Vector3 _worldVertex = Vector3.zero();
  final Vector3 _worldNormal = Vector3.zero();
  final Vector3 _faceCentre = Vector3.zero();
  final List<Offset> _screen = List<Offset>.filled(maxVertices, Offset.zero);
  final List<double> _depth = List<double>.filled(maxVertices, 0);
  final List<bool> _visible = List<bool>.filled(maxVertices, false);
  final List<double> _shade = List<double>.filled(maxFaces, 1);
  final List<int> _order = [];
  final List<double> _faceDepth = [];
  final Paint _paint = Paint()..style = PaintingStyle.fill;
  final Paint _edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = Metrics.meshEdgeWidth
    ..strokeJoin = StrokeJoin.round;
  final Path _path = Path();

  /// Draws [mesh] at a world position.
  ///
  /// [flash] blends the whole model toward white, which is how a hit reads.
  void draw(
    Canvas canvas,
    Mesh mesh, {
    required Vector3 position,
    double yaw = 0,
    double pitch = 0,
    double roll = 0,
    double scale = 1,
    double flash = 0,
    double opacity = 1,
    bool? cull,
  }) {
    if (mesh.vertices.length > maxVertices || mesh.faces.length > maxFaces) {
      return;
    }

    // A closed model hides its own back faces. An open one has to draw them,
    // because its inside is part of the shape.
    final hideBacks = cull ?? mesh.closed;

    _model
      ..setIdentity()
      ..rotateY(yaw)
      ..rotateX(pitch)
      ..rotateZ(roll);

    // Project every corner once, then reuse the results for each face.
    var anyVisible = false;
    var nearest = double.infinity;
    for (var i = 0; i < mesh.vertices.length; i++) {
      _worldVertex.setFrom(mesh.vertices[i]);
      _model.transform3(_worldVertex);
      _worldVertex
        ..scale(scale)
        ..add(position);
      final projected = camera.project(_worldVertex);
      if (projected == null) {
        _visible[i] = false;
        continue;
      }
      _visible[i] = true;
      anyVisible = true;
      _screen[i] = projected.screen;
      _depth[i] = projected.depth;
      if (projected.depth < nearest) {
        nearest = projected.depth;
      }
    }
    if (!anyVisible) {
      return;
    }

    _order.clear();
    _faceDepth.clear();
    for (var i = 0; i < mesh.faces.length; i++) {
      final face = mesh.faces[i];
      if (!_visible[face.a] || !_visible[face.b] || !_visible[face.c]) {
        continue;
      }

      // Turn the face normal into world space once. It answers both questions
      // that matter: whether the face is turned toward the lens, and how much
      // light it catches.
      _worldNormal.setFrom(mesh.normals[i]);
      _model.transform3(_worldNormal);

      _faceCentre
        ..setFrom(mesh.vertices[face.a])
        ..add(mesh.vertices[face.b])
        ..add(mesh.vertices[face.c])
        ..scale(1 / 3);
      _model.transform3(_faceCentre);
      _faceCentre
        ..scale(scale)
        ..add(position);

      final facingLens =
          _worldNormal.x * (camera.position.x - _faceCentre.x) +
          _worldNormal.y * (camera.position.y - _faceCentre.y) +
          _worldNormal.z * (camera.position.z - _faceCentre.z);
      if (hideBacks && facingLens <= 0) {
        continue;
      }

      // A back face on an open model is lit from the side turned toward the
      // player, otherwise the inside of the shape goes flat black.
      final lambert = facingLens >= 0
          ? _worldNormal.dot(lightDirection)
          : -_worldNormal.dot(lightDirection);
      _shade[i] = ambient + (1 - ambient) * math.max(0.0, lambert);

      _order.add(i);
      _faceDepth.add((_depth[face.a] + _depth[face.b] + _depth[face.c]) / 3);
    }

    // Painter sort: furthest face first.
    _sortByDepth();

    // Panel lines are what let a model read as a shape rather than a smudge,
    // but on something far away they would swallow it, so they fade in as the
    // model grows on screen.
    final onScreen = mesh.radius * scale * camera.scaleAt(nearest);
    final edgeAlpha =
        ((onScreen - Metrics.meshEdgeFadeMin) /
                (Metrics.meshEdgeFadeMax - Metrics.meshEdgeFadeMin))
            .clamp(0.0, 1.0) *
        opacity *
        (1 - flash.clamp(0.0, 1.0));
    final drawEdges = edgeAlpha > 0.02;
    if (drawEdges) {
      _edge.color = Palette.meshEdge.withValues(
        alpha: Palette.meshEdge.a * edgeAlpha,
      );
    }

    for (final index in _order) {
      final face = mesh.faces[index];

      _path
        ..reset()
        ..moveTo(_screen[face.a].dx, _screen[face.a].dy)
        ..lineTo(_screen[face.b].dx, _screen[face.b].dy)
        ..lineTo(_screen[face.c].dx, _screen[face.c].dy)
        ..close();

      _paint.color = shadeOf(face.color, _shade[index], flash, opacity);
      canvas.drawPath(_path, _paint);
      if (drawEdges) {
        canvas.drawPath(_path, _edge);
      }
    }
  }

  /// Applies the light, the hit flash and the fade to a face colour.
  static Color shadeOf(Color base, double shade, double flash, double opacity) {
    final lit = Color.from(
      alpha: base.a * opacity,
      red: base.r * shade,
      green: base.g * shade,
      blue: base.b * shade,
    );
    if (flash <= 0) {
      return lit;
    }
    final mix = flash.clamp(0.0, 1.0);
    return Color.from(
      alpha: lit.a,
      red: lit.r + (1 - lit.r) * mix,
      green: lit.g + (1 - lit.g) * mix,
      blue: lit.b + (1 - lit.b) * mix,
    );
  }

  /// Insertion sort, which is the right choice for the handful of faces a low
  /// poly model has and which never allocates.
  void _sortByDepth() {
    for (var i = 1; i < _order.length; i++) {
      final face = _order[i];
      final depth = _faceDepth[i];
      var j = i - 1;
      while (j >= 0 && _faceDepth[j] < depth) {
        _order[j + 1] = _order[j];
        _faceDepth[j + 1] = _faceDepth[j];
        j--;
      }
      _order[j + 1] = face;
      _faceDepth[j + 1] = depth;
    }
  }
}
