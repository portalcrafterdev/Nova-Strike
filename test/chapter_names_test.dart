import 'package:flutter_test/flutter_test.dart';
import 'package:novastrike/levels/chapter_names.dart';
import 'package:novastrike/levels/difficulty_curve.dart';

void main() {
  group('every chapter has a name', () {
    test('chapter one is the one the design asked for', () {
      expect(ChapterNames.of(1), 'Sunrise Belt');
    });

    test('no two chapters in this campaign share a name', () {
      final seen = <String, int>{};
      for (var chapter = 1; chapter <= Tuning.totalChapters; chapter++) {
        final name = ChapterNames.of(chapter);
        final clash = seen[name];
        expect(
          clash,
          isNull,
          reason: 'chapter $chapter is also called $name, like chapter $clash',
        );
        seen[name] = chapter;
      }
      expect(seen, hasLength(Tuning.totalChapters));
    });

    test('and none would clash at ten thousand levels either', () {
      // The campaign is meant to grow to ten thousand levels, which is six
      // hundred and sixty seven chapters. The table is sized for that on
      // purpose, so this is the check that says so out loud rather than
      // leaving it as a coincidence somebody later trims away.
      const chapters = 10000 ~/ Tuning.levelsPerChapter;
      expect(ChapterNames.distinct, greaterThanOrEqualTo(chapters));

      final seen = <String>{};
      for (var chapter = 1; chapter <= chapters; chapter++) {
        expect(
          seen.add(ChapterNames.of(chapter)),
          isTrue,
          reason: 'chapter $chapter reuses a name',
        );
      }
    });

    test('a chapter past the table still gets a name of its own', () {
      final beyond = ChapterNames.distinct + 1;
      expect(ChapterNames.of(beyond), isNotEmpty);
      expect(ChapterNames.of(beyond), isNot(ChapterNames.of(1)));
    });

    test('the same chapter is always the same place', () {
      // Nothing is stored, so this has to come out of the number alone or two
      // players would be talking about different places by the same name.
      expect(ChapterNames.of(47), ChapterNames.of(47));
      expect(ChapterNames.of(1), isNot(ChapterNames.of(2)));
    });

    test('the region changes slowly rather than every chapter', () {
      // The first word is what gives a long campaign a sense of crossing
      // regions. If it changed every chapter the names would read as noise.
      final firstWord = ChapterNames.of(1).split(' ').first;
      expect(ChapterNames.of(2).split(' ').first, firstWord);
      expect(ChapterNames.of(3).split(' ').first, firstWord);
    });
  });
}
