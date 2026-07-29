import 'dart:math';

import 'package:flame/components.dart';

/// Shakes the camera for a short beat.
///
/// Shake is kept short and small on purpose. Overdone shake reads as broken
/// rather than exciting, so the amplitude decays to nothing inside a quarter
/// of a second.
class CameraShake extends Component {
  CameraShake(this.camera);

  final CameraComponent camera;
  final Random _rng = Random();
  final Vector2 _base = Vector2.zero();

  double _timeLeft = 0;
  double _duration = 0;
  double _amplitude = 0;
  bool _baseCaptured = false;

  bool get isShaking => _timeLeft > 0;

  /// Set from the accessibility setting when a level starts.
  bool reduced = false;

  /// Starts a shake, keeping the stronger of any shake already running.
  void shake(double amplitude, double duration) {
    // Some players find a shaking camera hard to read or hard to stomach, and
    // for them it is the difference between playing and not.
    if (reduced) {
      return;
    }
    if (!_baseCaptured) {
      _base.setFrom(camera.viewfinder.position);
      _baseCaptured = true;
    }
    if (amplitude < _amplitude && _timeLeft > 0) {
      return;
    }
    _amplitude = amplitude;
    _duration = duration;
    _timeLeft = duration;
  }

  @override
  void update(double dt) {
    if (_timeLeft <= 0) {
      return;
    }
    _timeLeft -= dt;
    if (_timeLeft <= 0) {
      camera.viewfinder.position = _base;
      _amplitude = 0;
      return;
    }
    final falloff = _duration <= 0 ? 0.0 : _timeLeft / _duration;
    final strength = _amplitude * falloff;
    camera.viewfinder.position = Vector2(
      _base.x + (_rng.nextDouble() * 2 - 1) * strength,
      _base.y + (_rng.nextDouble() * 2 - 1) * strength,
    );
  }
}
