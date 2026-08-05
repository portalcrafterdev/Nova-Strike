// Generates placeholder audio for Nova Strike.
//
// Run with: dart run tool/gen_audio.dart
//
// Every file written here is a stand in, synthesised from plain maths so the
// audio system can be built and tested before real sound design lands. Replace
// the files, not this script, when the real assets arrive.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int sampleRate = 22050;

void main() {
  final sfxDir = Directory('assets/audio/sfx')..createSync(recursive: true);
  final musicDir = Directory('assets/audio/music')..createSync(recursive: true);

  final effects = <String, List<double> Function()>{
    'laser_fire': () => _sweep(0.10, 900, 320, wave: _square, decay: 18),
    'laser_heavy': () => _sweep(0.30, 260, 120, wave: _saw, decay: 5),
    'missile_launch': () => _mix(_noise(0.22, decay: 9),
        _sweep(0.22, 180, 420, wave: _saw, decay: 6)),
    'missile_hit': () => _explosion(0.45),
    'rail_fire': () => _mix(_sweep(0.26, 1400, 240, wave: _square, decay: 11),
        _sweep(0.26, 120, 70, wave: _sine, decay: 7)),
    'flak_burst': () => _mix(_noise(0.30, decay: 7),
        _sweep(0.30, 300, 90, wave: _square, decay: 8)),
    'pod_fire': () => _sweep(0.08, 700, 380, wave: _saw, decay: 22),
    'arc_zap': () => _mix(_noise(0.14, decay: 20),
        _sweep(0.14, 1800, 600, wave: _square, decay: 14)),
    'enemy_hit': () => _noise(0.05, decay: 45),
    'enemy_explode': () => _explosion(0.40),
    'boss_hit': () => _sweep(0.12, 200, 90, wave: _sine, decay: 16),
    'boss_explode': () => _explosion(0.90),
    'player_hit': () => _sweep(0.25, 520, 90, wave: _saw, decay: 9),
    'player_explode': () => _explosion(0.80),
    'shield_up': () => _sweep(0.28, 280, 760, wave: _sine, decay: 4),
    'shield_break': () => _mix(_noise(0.25, decay: 12),
        _sweep(0.25, 700, 180, wave: _square, decay: 10)),
    'power_up_pickup': () => _arpeggio(const [660, 880, 1320], 0.09),
    'wave_incoming': () => _arpeggio(const [440, 440], 0.16, wave: _square),
    'level_complete': () => _arpeggio(const [523, 659, 784, 1047], 0.22),
    'level_failed': () => _arpeggio(const [392, 330, 262], 0.26, wave: _saw),
    'button_tap': () => _sweep(0.04, 1200, 800, wave: _square, decay: 40),
    'coin_collect': () => _arpeggio(const [988, 1319], 0.06),
    'upgrade_buy': () => _arpeggio(const [523, 784, 1047], 0.13),
  };

  effects.forEach((name, build) {
    final file = File('${sfxDir.path}/$name.wav');
    file.writeAsBytesSync(_wav(build()));
    stdout.writeln('wrote ${file.path}');
  });

  const tracks = <String, List<int>>{
    'menu': [220, 262, 196, 247],
    'battle_a': [147, 165, 175, 131],
    'battle_b': [196, 175, 208, 165],
    'battle_c': [165, 220, 147, 196],
    'boss': [110, 117, 131, 98],
  };

  tracks.forEach((name, roots) {
    final file = File('${musicDir.path}/$name.wav');
    file.writeAsBytesSync(_wav(_track(roots, name == 'boss')));
    stdout.writeln('wrote ${file.path}');
  });
}

double _sine(double phase) => sin(phase * 2 * pi);

double _square(double phase) => (phase % 1.0) < 0.5 ? 0.6 : -0.6;

double _saw(double phase) => 2 * (phase % 1.0) - 1;

final Random _rng = Random(7);

/// A tone sliding from one pitch to another with an exponential decay.
List<double> _sweep(
  double seconds,
  double startHz,
  double endHz, {
  double Function(double) wave = _sine,
  double decay = 8,
}) {
  final count = (seconds * sampleRate).round();
  final out = List<double>.filled(count, 0);
  var phase = 0.0;
  for (var i = 0; i < count; i++) {
    final t = i / count;
    final hz = startHz + (endHz - startHz) * t;
    phase += hz / sampleRate;
    out[i] = wave(phase) * exp(-decay * t) * 0.6;
  }
  return out;
}

/// Filtered noise, which is the backbone of every impact sound.
List<double> _noise(double seconds, {double decay = 20}) {
  final count = (seconds * sampleRate).round();
  final out = List<double>.filled(count, 0);
  var last = 0.0;
  for (var i = 0; i < count; i++) {
    final t = i / count;
    final white = _rng.nextDouble() * 2 - 1;
    last = last * 0.6 + white * 0.4;
    out[i] = last * exp(-decay * t) * 0.7;
  }
  return out;
}

/// Noise plus a falling body, which reads as an explosion.
List<double> _explosion(double seconds) {
  return _mix(
    _noise(seconds, decay: 6),
    _sweep(seconds, 160, 40, wave: _sine, decay: 5),
  );
}

/// A short run of notes.
List<double> _arpeggio(
  List<int> notes,
  double noteSeconds, {
  double Function(double) wave = _sine,
}) {
  final out = <double>[];
  for (final note in notes) {
    out.addAll(
      _sweep(
        noteSeconds,
        note.toDouble(),
        note.toDouble(),
        wave: wave,
        decay: 6,
      ),
    );
  }
  return out;
}

List<double> _mix(List<double> a, List<double> b) {
  final length = max(a.length, b.length);
  final out = List<double>.filled(length, 0);
  for (var i = 0; i < length; i++) {
    final left = i < a.length ? a[i] : 0.0;
    final right = i < b.length ? b[i] : 0.0;
    out[i] = (left + right) * 0.7;
  }
  return out;
}

/// A looping backing track: four bars of bass with an arpeggio over the top.
List<double> _track(List<int> roots, bool heavy) {
  const barSeconds = 4.0;
  final total = (barSeconds * roots.length * sampleRate).round();
  final out = List<double>.filled(total, 0);
  final barSamples = (barSeconds * sampleRate).round();

  for (var bar = 0; bar < roots.length; bar++) {
    final root = roots[bar].toDouble();
    final chord = [root, root * 1.2, root * 1.5, root * 2];
    final start = bar * barSamples;

    // Bass line, one note per beat.
    for (var beat = 0; beat < 8; beat++) {
      final noteStart = start + (beat * barSamples / 8).round();
      final note = _sweep(
        barSeconds / 8,
        root / 2,
        root / 2,
        wave: heavy ? _saw : _sine,
        decay: 3,
      );
      for (var i = 0; i < note.length && noteStart + i < total; i++) {
        out[noteStart + i] += note[i] * 0.5;
      }
    }

    // Arpeggio over the chord, sixteen steps to the bar.
    for (var step = 0; step < 16; step++) {
      final noteStart = start + (step * barSamples / 16).round();
      final hz = chord[step % chord.length] * (heavy ? 1 : 2);
      final note = _sweep(
        barSeconds / 16,
        hz,
        hz,
        wave: _square,
        decay: 9,
      );
      for (var i = 0; i < note.length && noteStart + i < total; i++) {
        out[noteStart + i] += note[i] * 0.16;
      }
    }
  }
  return out;
}

/// Wraps samples in a 16 bit mono RIFF header.
Uint8List _wav(List<double> samples) {
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    final clamped = samples[i].clamp(-1.0, 1.0);
    data.setInt16(i * 2, (clamped * 32767).round(), Endian.little);
  }
  final pcm = data.buffer.asUint8List();

  final header = ByteData(44);
  void writeAscii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      header.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  writeAscii(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  writeAscii(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);

  return Uint8List.fromList([...header.buffer.asUint8List(), ...pcm]);
}
