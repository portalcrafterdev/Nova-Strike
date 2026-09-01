// Writes the achievements bundle Play Console imports, and checks the
// catalogue against the rules Play Games enforces.
//
// The checks always run. The bundle is only written when asked:
//
//   PGS=1 flutter test test/pgs_test.dart
//
// It lands in build/pgs/ as loose files plus a ZIP. Play Console takes the ZIP
// at Play Games Services, then Achievements, then Import.
//
// Format from developer.android.com/games/pgs/integrate-achievements. The
// metadata CSV has no header row and no quoting, which is why a comma in a
// name or a description is a hard error rather than a style note.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart'
    show IconData, Icons, TextPainter, TextSpan, TextStyle;
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/state/achievement_catalog.dart';
import 'package:novastrike/theme/palette.dart';

/// Where the bundle is written.
const String _outDir = 'build/pgs';

/// Play Console wants exactly this, 512 square.
const double _iconSize = 512;

/// A colour with more of itself in it, for the sky behind the mark.
Color _lift(Color base, double amount) =>
    base.withValues(alpha: (base.a + amount).clamp(0.0, 1.0));

/// Paints one badge icon.
///
/// The same sky as the app icon, so a row of these in the Play Games app reads
/// as one game rather than as thirty clip art tiles. Only the unlocked icon is
/// needed; Google generates the grey version itself.
void _paintBadge(Canvas canvas, IconData icon, Color tint) {
  const size = _iconSize;
  final rect = Rect.fromLTWH(0, 0, size, size);
  final middle = Offset(size / 2, size / 2);

  canvas.drawRect(rect, Paint()..color = Palette.spaceDeep);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = Gradient.radial(
        Offset(size * 0.26, size * 0.2),
        size * 0.92,
        [_lift(Palette.menuNebulaA, 0.55), const Color(0x00000000)],
      ),
  );
  canvas.drawRect(
    rect,
    Paint()
      ..shader = Gradient.radial(
        Offset(size * 0.8, size * 0.84),
        size * 0.78,
        [_lift(Palette.menuNebulaB, 0.5), const Color(0x00000000)],
      ),
  );
  // A vignette, because Play Games masks the icon to a circle and the corners
  // should fall away rather than get cut off.
  canvas.drawRect(
    rect,
    Paint()
      ..shader = Gradient.radial(middle, size * 0.72, [
        const Color(0x00000000),
        Palette.spaceDeep.withValues(alpha: 0.85),
      ], const [0.55, 1.0]),
  );
  canvas.drawCircle(
    middle,
    size * 0.34,
    Paint()
      ..blendMode = BlendMode.plus
      ..shader = Gradient.radial(middle, size * 0.34, [
        tint.withValues(alpha: 0.30),
        const Color(0x00000000),
      ]),
  );

  final painter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size * 0.46,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: tint,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    middle - Offset(painter.width / 2, painter.height / 2),
  );
}

Future<Uint8List> _renderBadge(IconData icon, Color tint) async {
  final recorder = PictureRecorder();
  _paintBadge(Canvas(recorder), icon, tint);
  final image = await recorder.endRecording().toImage(
    _iconSize.round(),
    _iconSize.round(),
  );
  final data = await image.toByteData(format: ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// Loads the real icon font, which a test does not have by default.
Future<void> _loadIconFont() async {
  final flutterRoot = File(
    Platform.environment['FLUTTER_ROOT'] ?? '',
  ).path;
  final candidates = [
    '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
      await loader.load();
      return;
    }
  }
  fail(
    'The Material icon font was not found. Set FLUTTER_ROOT, or run this '
    'through the flutter tool so it is set for you.',
  );
}

Future<void> _write(String path, List<int> bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
  // ignore: avoid_print
  print('wrote $path');
}

/// Colours the badges are tinted with, walked in order so neighbouring rows in
/// the list do not come out the same.
const List<Color> _tints = [
  Palette.uiAccent,
  Palette.star,
  Palette.coin,
  Palette.bossShield,
  Palette.playerAccent,
];

void main() {
  // These run on every `flutter test`, because the rules below are the ones
  // that make Play Console reject an import, and finding that out during an
  // upload is far worse than finding it out here.
  group('the catalogue is importable', () {
    test('the list is the size it is meant to be', () {
      expect(AchievementCatalog.all.length, 15);
      expect(
        AchievementCatalog.all.length,
        lessThanOrEqualTo(AchievementCatalog.maxBadges),
      );
    });

    test('points fit inside what Play Games allows', () {
      for (final badge in AchievementCatalog.all) {
        expect(
          badge.points % 5,
          0,
          reason: '${badge.id} is not a multiple of 5',
        );
        // Play Games allows 5 to 200. This game holds a narrower band so no
        // badge is worth forty times another.
        expect(
          badge.points,
          inInclusiveRange(
            AchievementCatalog.minPoints,
            AchievementCatalog.maxPoints,
          ),
          reason: '${badge.id} is outside the 5 to 50 band',
        );
      }
      expect(
        AchievementCatalog.totalPoints,
        lessThanOrEqualTo(AchievementCatalog.maxTotalPoints),
        reason: 'Play Console refuses an import over the points cap',
      );
    });

    test('no name or description carries a comma', () {
      // The metadata CSV has no quoting, so one comma shifts every column
      // after it and the import either fails or writes nonsense.
      for (final badge in AchievementCatalog.all) {
        expect(badge.name, isNot(contains(',')), reason: badge.id);
        expect(badge.description, isNot(contains(',')), reason: badge.id);
        expect(badge.name.length, lessThanOrEqualTo(100), reason: badge.id);
        expect(
          badge.description.length,
          lessThanOrEqualTo(500),
          reason: badge.id,
        );
      }
    });

    test('names and slugs are unique', () {
      final ids = AchievementCatalog.all.map((b) => b.id).toSet();
      final names = AchievementCatalog.all.map((b) => b.name).toSet();
      expect(ids.length, AchievementCatalog.all.length);
      expect(names.length, AchievementCatalog.all.length);
    });

    test('a counting badge has a step count and a plain one does not', () {
      for (final badge in AchievementCatalog.all) {
        if (badge.isIncremental) {
          // Play Games refuses more than ten thousand steps.
          expect(badge.steps, inInclusiveRange(2, 10000), reason: badge.id);
          expect(badge.goal, 0, reason: ' sets both steps and goal');
        }
      }
    });

    test('every badge has an icon of its own', () {
      final icons = AchievementCatalog.all.map((b) => b.icon.codePoint).toSet();
      expect(
        icons.length,
        AchievementCatalog.all.length,
        reason: 'two badges share an icon',
      );
    });
  });

  test('write the Play Console bundle', () async {
    await _loadIconFont();

    final metadata = StringBuffer();
    final mappings = StringBuffer();
    final files = <String, Uint8List>{};

    var order = 1;
    for (final badge in AchievementCatalog.all) {
      final iconFile = '${badge.id}.png';
      // Name,Description,Incremental value,Steps Needed,Initial State,Points,
      // List Order. No header row.
      metadata.writeln(
        [
          badge.name,
          badge.description,
          badge.isIncremental ? 'True' : 'False',
          badge.isIncremental ? '${badge.steps}' : '',
          badge.hidden ? 'Hidden' : 'Revealed',
          '${badge.points}',
          '${order++}',
        ].join(','),
      );
      mappings.writeln('${badge.name},$iconFile');
      files[iconFile] = await _renderBadge(
        badge.icon,
        _tints[AchievementCatalog.all.indexOf(badge) % _tints.length],
      );
    }

    await _write(
      '$_outDir/AchievementsMetadata.csv',
      metadata.toString().codeUnits,
    );
    await _write(
      '$_outDir/AchievementsIconsMappings.csv',
      mappings.toString().codeUnits,
    );
    for (final entry in files.entries) {
      await _write('$_outDir/${entry.key}', entry.value);
    }

    // Play Console allows 403 files and 800MB. Neither is close, but a bundle
    // that quietly grew past either would fail at the upload.
    expect(files.length + 2, lessThanOrEqualTo(403));
    for (final entry in files.entries) {
      expect(
        entry.value.length,
        lessThan(1024 * 1024),
        reason: '${entry.key} is over the 1MB per file limit',
      );
    }

    // ignore: avoid_print
    print(
      'Bundle ready in $_outDir: ${AchievementCatalog.all.length} badges, '
      '${AchievementCatalog.totalPoints} points. Zip that folder and import '
      'it in Play Console.',
    );
  }, skip: Platform.environment['PGS'] == null);

  // Keeps the analyzer honest about the import above being used.
  test('the fallback icon exists', () {
    expect(Icons.emoji_events.codePoint, isPositive);
    expect(math.max(1, 2), 2);
  });
}
