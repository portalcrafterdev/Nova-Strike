import 'dart:ui';

import 'package:flame/components.dart';

import '../../theme/palette.dart';

/// Adds a short white flash when something is hit.
///
/// Sixty milliseconds is enough to read as a hit without washing the sprite
/// out, and it costs one cached paint rather than a new effect component.
mixin HitFlash on Component {
  static final Paint flashPaint = Paint()..color = Palette.hitFlash;

  double _flashTimer = 0;

  bool get isFlashing => _flashTimer > 0;

  /// Strength of the flash right now, 0 to 1, for blending.
  double get flashAmount =>
      _flashTimer <= 0 ? 0 : _flashTimer / Metrics.hitFlashDuration;

  void startFlash() {
    _flashTimer = Metrics.hitFlashDuration;
  }

  void updateFlash(double dt) {
    if (_flashTimer > 0) {
      _flashTimer -= dt;
    }
  }
}
