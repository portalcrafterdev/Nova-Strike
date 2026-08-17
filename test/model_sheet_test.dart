// Renders every model in the game to one image, using the game's own camera
// and renderer.
//
// This is a look at the art, not an assertion about it. Run it when a hull
// changes shape, open the file it writes, and see what the player will see:
//
//   flutter test test/model_sheet_test.dart
//
// It is skipped by default so a normal test run never writes files.
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/game/render3d/camera3d.dart';
import 'package:novastrike/game/render3d/mesh.dart';
import 'package:novastrike/game/render3d/mesh_renderer.dart';
import "package:novastrike/game/components/enemy_ship.dart";
import "package:novastrike/levels/level_spec.dart";
import 'package:novastrike/state/ship_catalog.dart';
import 'package:novastrike/theme/palette.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

const double _cell = 220;
const int _columns = 5;

/// Every model worth looking at, with the pitch it is normally seen at.
Map<String, Mesh> _sheet() {
  final models = <String, Mesh>{};
  for (final ship in ShipCatalog.ships) {
    models['${ship.name} hull'] = Meshes.ship(
      hull: ship.hull,
      hullDark: ship.hullDark,
      accent: ship.accent,
      nose: ship.nose,
      span: ship.span,
      sweep: ship.sweep,
      spine: ship.spine,
      keel: ship.keel,
      tailSpan: ship.tailSpan,
    );
  }
  models['vanguard rack'] = Meshes.ship(
    hull: Palette.playerHull,
    hullDark: Palette.playerHullDark,
    accent: Palette.playerAccent,
    pods: true,
    canards: true,
    podColor: Palette.playerPod,
  );
  for (final type in EnemyType.values) {
    models[type.name] = EnemyShip.meshOf(type);
  }
  models['boss'] = Meshes.capital(
    hull: Palette.bossHull,
    hullDark: Palette.bossHullDark,
    core: Palette.bossCore,
    glow: Palette.bossThruster,
    width: 60,
    height: 20,
    depth: 42,
  );
  models['weak point'] = Meshes.weakPoint(
    hull: Palette.bossHull,
    hullDark: Palette.bossHullDark,
    core: Palette.bossCore,
    radius: 13,
  );
  models['missile'] = Meshes.missile(
    body: Palette.missileHull,
    trim: Palette.missileHullDark,
    accent: Palette.missileFlame,
  );
  models['flak shell'] = Meshes.shell(
    body: Palette.flakShell,
    trim: Palette.flakShellDark,
    accent: Palette.flakBurst,
  );
  return models;
}

void main() {
  test('model sheet', () async {
    final models = _sheet();
    final rows = (models.length / _columns).ceil();
    final width = _cell * _columns;
    final height = _cell * rows;

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = Palette.spaceDeep,
    );

    final camera = Camera3D(
      viewportWidth: _cell,
      viewportHeight: _cell,
      zoom: 2.4,
      laneOrigin: _cell / 2,
    );
    final renderer = MeshRenderer(camera);

    var index = 0;
    for (final entry in models.entries) {
      final column = index % _columns;
      final row = index ~/ _columns;
      canvas.save();
      canvas.translate(column * _cell, row * _cell);
      canvas.clipRect(Rect.fromLTWH(0, 0, _cell, _cell));
      renderer.draw(
        canvas,
        entry.value,
        position: Vector3(0, 0, 0),
        pitch: 0,
        scale: 1.0,
      );
      final label =
          ParagraphBuilder(
              ParagraphStyle(fontSize: 13, textAlign: TextAlign.center),
            )
            ..pushStyle(TextStyle(color: Palette.uiTextDim))
            ..addText(entry.key);
      final paragraph = label.build()
        ..layout(const ParagraphConstraints(width: _cell));
      canvas.drawParagraph(paragraph, const Offset(0, _cell - 22));
      canvas.restore();
      index++;
    }

    final image = await recorder.endRecording().toImage(
      width.round(),
      height.round(),
    );
    final data = await image.toByteData(format: ImageByteFormat.png);
    final out = File(Platform.environment['MODEL_SHEET'] ?? 'model_sheet.png');
    out.writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote ${out.absolute.path}');
  }, skip: Platform.environment['MODEL_SHEET'] == null);
}
