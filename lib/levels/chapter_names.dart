/// A name for every chapter, worked out from its number.
///
/// The levels themselves are generated rather than authored, and the names
/// follow the same rule for the same reason: a hundred hand written names is
/// an afternoon, and six hundred and sixty is not. Nothing is stored, so the
/// name for a chapter is the same on every device and costs nothing.
///
/// The first word changes only every [_seconds] chapters, which is what gives
/// a long campaign the feeling of crossing regions rather than of reading a
/// list. Chapter 1 is Sunrise Belt.
class ChapterNames {
  const ChapterNames._();

  /// Twenty six by twenty six is six hundred and seventy six distinct names,
  /// which covers a campaign of ten thousand levels with room over. Past that
  /// the number is appended rather than a name being reused, because two
  /// chapters sharing a name is worse than one having a clumsy one.
  static const List<String> _firsts = [
    'Sunrise', 'Amber', 'Cobalt', 'Verdant', 'Crimson', 'Silver', 'Ember',
    'Azure', 'Golden', 'Violet', 'Frost', 'Solar', 'Onyx', 'Coral', 'Ivory',
    'Cinder', 'Jade', 'Scarlet', 'Umbra', 'Zephyr', 'Halcyon', 'Obsidian',
    'Nebular', 'Quasar', 'Pulsar', 'Void',
  ];

  static const List<String> _seconds = [
    'Belt', 'Reach', 'Drift', 'Expanse', 'Passage', 'Verge', 'Rift', 'Field',
    'Chain', 'Hollow', 'Spiral', 'Crossing', 'Shoals', 'Gate', 'Run', 'Deep',
    'Fringe', 'Basin', 'Marches', 'Straits', 'Cluster', 'Arc', 'Wake', 'Span',
    'Trail', 'Divide',
  ];

  /// How many names exist before one has to carry its chapter number.
  static int get distinct => _firsts.length * _seconds.length;

  static String of(int chapter) {
    final index = chapter - 1;
    if (index < 0) {
      return _name(0);
    }
    if (index < distinct) {
      return _name(index);
    }
    // Past the end of the table. Still stable, still unique, just less
    // graceful, and only reachable on a campaign far longer than this one.
    return '${_name(index % distinct)} ${(index ~/ distinct) + 1}';
  }

  static String _name(int index) =>
      '${_firsts[index ~/ _seconds.length]} ${_seconds[index % _seconds.length]}';
}
