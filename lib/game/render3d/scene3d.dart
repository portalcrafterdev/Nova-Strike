import 'dart:ui';

import 'package:flame/components.dart' hide Vector3;
import 'package:vector_math/vector_math_64.dart';

import 'camera3d.dart';
import 'mesh_renderer.dart';

/// Anything in the world that draws itself in three dimensions.
///
/// Components keep their own update logic, but they do not paint themselves.
/// The scene paints them, because correct overlap needs one depth sort across
/// everything on screen rather than a fixed order per component.
mixin Renderable3D on Component {
  /// Where the thing is in the world.
  Vector3 get worldPosition;

  /// Drawn last within its depth slot when true, which suits beams and glows.
  bool get drawsOnTop => false;

  /// Paints the thing. Called by the scene, never by Flame.
  void render3d(Canvas canvas, MeshRenderer renderer, Camera3D camera);
}

/// Owns the camera and paints every renderable in depth order.
///
/// One component doing all the drawing is what makes the painter sort
/// possible, and it keeps the per frame cost to a single sort.
class Scene3D extends Component {
  Scene3D({required this.camera})
    : renderer = MeshRenderer(camera),
      super(priority: 100);

  final Camera3D camera;
  final MeshRenderer renderer;

  final List<Renderable3D> _entries = [];
  final List<double> _depths = [];
  final List<int> _order = [];

  /// Entities register themselves when they mount.
  void register(Renderable3D entry) {
    _entries.add(entry);
  }

  void unregister(Renderable3D entry) {
    _entries.remove(entry);
  }

  void clear() {
    _entries.clear();
  }

  int get entryCount => _entries.length;

  @override
  void render(Canvas canvas) {
    if (_entries.isEmpty) {
      return;
    }

    _depths.clear();
    _order.clear();
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      _order.add(i);
      // Further up the lane paints first, so what is closer to the player
      // paints over it. Things marked as drawing on top jump the queue.
      _depths.add(entry.drawsOnTop ? -1 : entry.worldPosition.z);
    }

    _sort();

    for (final index in _order) {
      _entries[index].render3d(canvas, renderer, camera);
    }
  }

  /// Furthest up the lane first, so nearer things paint over them.
  void _sort() {
    for (var i = 1; i < _order.length; i++) {
      final entry = _order[i];
      final depth = _depths[i];
      var j = i - 1;
      while (j >= 0 && _depths[j] < depth) {
        _order[j + 1] = _order[j];
        _depths[j + 1] = _depths[j];
        j--;
      }
      _order[j + 1] = entry;
      _depths[j + 1] = depth;
    }
  }
}
