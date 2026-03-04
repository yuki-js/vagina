// This is a standalone Dart script (not Flutter)
// Run with: dart run tool/generate_sound_effects.dart
//
// Generates 5 PCM16 WAV sound effects for call/tool lifecycle UX.
// Current direction (per feedback):
// - NO noise layers
// - Sample rate: 44.1kHz
// - dial_tone.wav: JP-style "purururu" feel (pulse-y), length >= 1.5s (loopable)
// - call_end.wav: keep descending G major arpeggio, shorter, less rigid
// - tool_cancelled.wav: dissonance → resolution, <= 0.2s
// - tool_error.wav: more error-like, <= 0.2s
// - tool_executing.wav: phrase-y waiting motif ("hun hun hun"), not a drone
// - end/error/cancelled use custom waveforms instead of plain sine
//
// Constraints:
// - Uses only: dart:io, dart:math, dart:typed_data
// - Writes assets into: assets/audio/
// - Writes valid RIFF/WAVE headers (PCM, 16-bit, mono)

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int _sampleRate = 44100;
const int _numChannels = 1;
const int _bitsPerSample = 16;

// ----------------------------
// Custom waveform oscillators
// ----------------------------
//
// These replace plain sin() to give each sound its own timbre character.
// All accept a phase value (radians) and return [-1, +1].

/// Base oscillator type. Takes phase in radians, returns sample value.
typedef _Oscillator = double Function(double phase);

/// Warm wave: polynomial waveshaping of sine.
/// Adds natural-sounding even + odd harmonic content.
/// Fuller and rounder than pure sine — good for musical phrases (call_end).
double _warmWave(double phase) {
  final s = sin(phase);
  // Chebyshev-ish polynomial: T1 + small T2 + small T3 contribution
  // This naturally introduces 2nd and 3rd harmonic content
  // without needing explicit additive synthesis.
  return s * (1.0 - 0.18 * s.abs()) + 0.12 * s * s * s;
}

/// Bell wave: asymmetric per-cycle shape with fast attack and gentle decay.
/// Creates a plucked / struck-bell-like timbre — good for the cancelled "resolve" feel.
double _bellWave(double phase) {
  // Normalize phase to [0, 2π) cycle position
  final p = (phase % (2.0 * pi)) / (2.0 * pi); // [0, 1)

  // Combine sine with an exponential-weighted decay within the cycle,
  // producing an asymmetric waveshape where the positive half is sharper
  // and the negative half rings out more gently.
  final env = 0.4 + 0.6 * exp(-3.0 * p);
  final base = sin(phase) * env;

  // Add a touch of 2nd partial shifted in phase to break symmetry
  final partial2 = 0.15 * sin(2.0 * phase + 0.8);

  return base + partial2;
}

/// Edgy wave: wave-folding of sine to create odd-harmonic-rich content.
/// More metallic/gritty — good for error/alert sounds.
/// Not as harsh as a square wave, but clearly not a sine.
double _edgyWave(double phase) {
  final s = sin(phase);
  // Soft wave folding: when the signal exceeds a threshold, fold it back.
  // This creates odd harmonics similar to tube distortion.
  const threshold = 0.6;
  double v = s;
  if (v > threshold) {
    v = 2.0 * threshold - v;
  } else if (v < -threshold) {
    v = -2.0 * threshold - v;
  }
  // Normalize back to roughly [-1, 1]
  return v / threshold;
}

void main() {
  final outputDir = Directory('assets/audio');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  generateDialTone(outputDir);
  generateCallEndTone(outputDir);
  generateExecutingLoop(outputDir);
  generateErrorTone(outputDir);
  generateCancelTone(outputDir);

  // ignore: avoid_print
  print('All sound effects generated successfully!');
}

/// 1) dial_tone.wav — JP-style "プルルル" (pulse-y, not vibrato)
///
/// Used while connecting (loops). Keeps plain sine (fundamental only).
void generateDialTone(Directory outputDir) {
  const durationSeconds = 1.6;
  const fadeSeconds = 0.040;

  final samples = _render(durationSeconds, (t) {
    final trem = _pulseTremolo(
      t,
      hz: 14.0,
      depth: 0.70,
      duty: 0.35,
      edge: 0.06,
    );

    // Dial tone stays as pure sine (fundamental only), per earlier feedback.
    final sig = _oscillate(t, hz: 400.0, amp: 0.36, osc: sin);

    return sig * trem;
  }, fadeInSeconds: fadeSeconds, fadeOutSeconds: fadeSeconds);

  _writeWavFile(
    file: File('${outputDir.path}/dial_tone.wav'),
    pcmSamples: samples,
  );
}

/// 2) call_end.wav — Descending G major arpeggio
///
/// Uses _warmWave for a fuller, more musical timbre.
void generateCallEndTone(Directory outputDir) {
  const noteDuration = 0.060;

  // G major descending: G5 → D5 → B4 → G4
  final notes = <double>[783.99, 587.33, 493.88, 392.00];
  final detuneCents = <double>[-5.0, 4.0, -3.0, 2.0];

  final parts = <Int16List>[];
  for (var i = 0; i < notes.length; i++) {
    parts.add(
      _toneWithWaveform(
        durationSeconds: noteDuration,
        fundamentalHz: _applyDetuneCents(notes[i], detuneCents[i]),
        harmonics: const [
          (1.0, 0.30),
          (2.0, 0.11),
          (3.0, 0.045),
        ],
        attack: 0.006,
        decay: 0.014,
        sustain: 0.60,
        release: 0.024,
        osc: _warmWave,
      ),
    );
  }

  final combined = _concatInt16(parts);

  _writeWavFile(
    file: File('${outputDir.path}/call_end.wav'),
    pcmSamples: combined,
  );
}

/// 3) tool_executing.wav — Phrase-y waiting motif ("hun hun hun")
///
/// Keeps existing approach (sine-based harmonics for soft bed + hum events).
void generateExecutingLoop(Directory outputDir) {
  const durationSeconds = 6.0;
  const fadeSeconds = 0.200;

  final samples = _render(durationSeconds, (t) {
    // Soft bed: warm A2.
    final bed = _harmonicSignal(
          t,
          fundamentalHz: 110.0,
          harmonics: const [
            (1.0, 0.010),
            (2.0, 0.0035),
            (3.0, 0.0015),
          ],
          osc: sin,
        ) *
        0.55;

    // 3 phrase events: "hun" at 0.2s, 2.2s, 4.2s.
    final motif = _humEvent(t, center: 0.20, freqHz: 196.0) +
        _humEvent(t, center: 2.20, freqHz: 220.0) +
        _humEvent(t, center: 4.20, freqHz: 196.0);

    return bed + motif;
  }, fadeInSeconds: fadeSeconds, fadeOutSeconds: fadeSeconds);

  _writeWavFile(
    file: File('${outputDir.path}/tool_executing.wav'),
    pcmSamples: samples,
  );
}

/// 4) tool_error.wav — Error-like, <= 0.2s
///
/// Uses _edgyWave for a grittier, more alerting timbre.
void generateErrorTone(Directory outputDir) {
  final hit1 = _dyadWithWaveform(
    durationSeconds: 0.075,
    f1: 880.0,
    f2: 622.25,
    attack: 0.004,
    decay: 0.012,
    sustain: 0.55,
    release: 0.030,
    a1: 0.24,
    a2: 0.22,
    osc: _edgyWave,
  );

  final hit2 = _dyadWithWaveform(
    durationSeconds: 0.085,
    f1: 740.0,
    f2: 554.37,
    attack: 0.004,
    decay: 0.014,
    sustain: 0.50,
    release: 0.038,
    a1: 0.22,
    a2: 0.21,
    osc: _edgyWave,
  );

  final combined = _concatInt16([hit1, hit2]);

  _writeWavFile(
    file: File('${outputDir.path}/tool_error.wav'),
    pcmSamples: combined,
  );
}

/// 5) tool_cancelled.wav — "dissonance → resolution" cue, <= 0.2s
///
/// Uses _bellWave for a plucked/struck-bell timbre.
void generateCancelTone(Directory outputDir) {
  final hit1 = _chordWithWaveform(
    durationSeconds: 0.085,
    freqsHz: const [493.88, 698.46], // B4 + F5 (tritone-ish)
    amps: const [0.18, 0.16],
    attack: 0.004,
    decay: 0.010,
    sustain: 0.55,
    release: 0.030,
    osc: _bellWave,
  );

  final gap = _silence(durationSeconds: 0.010);

  final hit2 = _chordWithWaveform(
    durationSeconds: 0.090,
    freqsHz: const [493.88, 622.25], // B4 + D#5 (major third resolve)
    amps: const [0.18, 0.14],
    attack: 0.004,
    decay: 0.012,
    sustain: 0.60,
    release: 0.032,
    osc: _bellWave,
  );

  final combined = _concatInt16([hit1, gap, hit2]);

  _writeWavFile(
    file: File('${outputDir.path}/tool_cancelled.wav'),
    pcmSamples: combined,
  );
}

// ----------------------------
// Rendering / synthesis
// ----------------------------

typedef _SampleFn = double Function(double t);

Int16List _render(
  double durationSeconds,
  _SampleFn fn, {
  required double fadeInSeconds,
  required double fadeOutSeconds,
}) {
  final totalSamples = (durationSeconds * _sampleRate).round();
  final fadeInSamples = (fadeInSeconds * _sampleRate).round();
  final fadeOutSamples = (fadeOutSeconds * _sampleRate).round();

  final out = Int16List(totalSamples);

  for (var i = 0; i < totalSamples; i++) {
    final t = i / _sampleRate;

    var v = fn(t);

    // Fade window to avoid boundary clicks.
    v *= _fadeWindow(i, totalSamples, fadeInSamples, fadeOutSamples);

    out[i] = _floatToPcm16(v);
  }

  return out;
}

/// Single oscillator at a given frequency.
double _oscillate(double t,
    {required double hz, required double amp, required _Oscillator osc}) {
  const twoPi = 2.0 * pi;
  return osc(twoPi * hz * t) * amp;
}

/// Additive harmonic signal using the given oscillator shape.
double _harmonicSignal(
  double t, {
  required double fundamentalHz,
  required List<(double, double)> harmonics,
  required _Oscillator osc,
}) {
  const twoPi = 2.0 * pi;
  var v = 0.0;
  for (final (mult, amp) in harmonics) {
    v += osc(twoPi * (fundamentalHz * mult) * t) * amp;
  }
  return v;
}

/// Tone with harmonics, ADSR, and custom waveform.
Int16List _toneWithWaveform({
  required double durationSeconds,
  required double fundamentalHz,
  required List<(double, double)> harmonics,
  required double attack,
  required double decay,
  required double sustain,
  required double release,
  required _Oscillator osc,
}) {
  final totalSamples = (durationSeconds * _sampleRate).round();
  final out = Int16List(totalSamples);

  for (var i = 0; i < totalSamples; i++) {
    final t = i / _sampleRate;

    var v = _harmonicSignal(
      t,
      fundamentalHz: fundamentalHz,
      harmonics: harmonics,
      osc: osc,
    );

    v *= _adsrEnvelope(
      sampleIndex: i,
      totalSamples: totalSamples,
      attack: attack,
      decay: decay,
      sustain: sustain,
      release: release,
    );

    out[i] = _floatToPcm16(v);
  }

  return out;
}

/// Two-voice dyad with custom waveform.
Int16List _dyadWithWaveform({
  required double durationSeconds,
  required double f1,
  required double f2,
  required double attack,
  required double decay,
  required double sustain,
  required double release,
  required double a1,
  required double a2,
  required _Oscillator osc,
}) {
  final totalSamples = (durationSeconds * _sampleRate).round();
  final out = Int16List(totalSamples);
  const twoPi = 2.0 * pi;

  for (var i = 0; i < totalSamples; i++) {
    final t = i / _sampleRate;

    var v = 0.0;
    v += osc(twoPi * f1 * t) * a1;
    v += osc(twoPi * f2 * t) * a2;

    v *= _adsrEnvelope(
      sampleIndex: i,
      totalSamples: totalSamples,
      attack: attack,
      decay: decay,
      sustain: sustain,
      release: release,
    );

    out[i] = _floatToPcm16(v);
  }

  return out;
}

/// Multi-voice chord with custom waveform.
Int16List _chordWithWaveform({
  required double durationSeconds,
  required List<double> freqsHz,
  required List<double> amps,
  required double attack,
  required double decay,
  required double sustain,
  required double release,
  required _Oscillator osc,
}) {
  assert(freqsHz.length == amps.length);

  final totalSamples = (durationSeconds * _sampleRate).round();
  final out = Int16List(totalSamples);
  const twoPi = 2.0 * pi;

  for (var i = 0; i < totalSamples; i++) {
    final t = i / _sampleRate;

    var v = 0.0;
    for (var k = 0; k < freqsHz.length; k++) {
      v += osc(twoPi * freqsHz[k] * t) * amps[k];
    }

    v *= _adsrEnvelope(
      sampleIndex: i,
      totalSamples: totalSamples,
      attack: attack,
      decay: decay,
      sustain: sustain,
      release: release,
    );

    out[i] = _floatToPcm16(v);
  }

  return out;
}

/// Pulse-y tremolo: depth=0 => 1.0, depth=1 => full pulsing.
double _pulseTremolo(
  double t, {
  required double hz,
  required double depth,
  required double duty,
  required double edge,
}) {
  if (depth <= 0) return 1.0;

  final phase = (t * hz) % 1.0;
  final p = _smoothPulse(phase, duty: duty, edge: edge);

  final base = 1.0 - depth;
  return base + depth * p;
}

/// Smooth pulse in [0..1] from phase [0..1].
double _smoothPulse(double phase,
    {required double duty, required double edge}) {
  final d = duty.clamp(0.05, 0.95);
  final e = edge.clamp(0.0, 0.45);

  if (e == 0) {
    return phase < d ? 1.0 : 0.0;
  }

  if (phase < e) {
    final x = phase / e;
    return 0.5 - 0.5 * cos(pi * x);
  }

  if (phase < d - e) {
    return 1.0;
  }

  if (phase < d) {
    final x = (phase - (d - e)) / e;
    return 0.5 + 0.5 * cos(pi * x);
  }

  return 0.0;
}

/// "Hum" event for tool_executing: warm voice-like burst.
double _humEvent(double t, {required double center, required double freqHz}) {
  const duration = 0.72;
  final dt = t - center;
  if (dt < 0 || dt > duration) return 0.0;

  final x = dt / duration;
  final win = exp(-7.5 * pow(x - 0.35, 2));

  final inner = _pulseTremolo(t, hz: 3.2, depth: 0.55, duty: 0.60, edge: 0.25);

  // Hum events use _warmWave for a richer "hun" sound.
  final sig = _harmonicSignal(
    t,
    fundamentalHz: freqHz,
    harmonics: const [
      (1.0, 0.060),
      (2.0, 0.020),
      (3.0, 0.009),
      (4.0, 0.0035),
    ],
    osc: _warmWave,
  );

  return sig * win * inner;
}

double _applyDetuneCents(double hz, double cents) {
  return hz * pow(2.0, cents / 1200.0);
}

/// ADSR envelope generator (0.0-1.0)
double _adsrEnvelope({
  required int sampleIndex,
  required int totalSamples,
  required double attack,
  required double decay,
  required double sustain,
  required double release,
}) {
  final int attackSamples = max(1, (attack * _sampleRate).round());
  final int decaySamples = max(1, (decay * _sampleRate).round());
  final int releaseSamples = max(1, (release * _sampleRate).round());

  final int releaseStart = max(0, totalSamples - releaseSamples);
  final int sustainStart = attackSamples + decaySamples;

  if (sampleIndex < attackSamples) {
    return sampleIndex / attackSamples;
  }

  if (sampleIndex < sustainStart) {
    final dp = (sampleIndex - attackSamples) / decaySamples;
    return 1.0 - (1.0 - sustain) * dp;
  }

  if (sampleIndex < releaseStart) {
    return sustain;
  }

  final rp = (sampleIndex - releaseStart) / releaseSamples;
  final v = sustain * (1.0 - rp);
  return v < 0 ? 0.0 : v;
}

// ----------------------------
// Utilities / WAV
// ----------------------------

Int16List _silence({required double durationSeconds}) {
  final int totalSamples = (durationSeconds * _sampleRate).round();
  return Int16List(totalSamples);
}

Int16List _concatInt16(List<Int16List> parts) {
  var total = 0;
  for (final p in parts) {
    total += p.length;
  }

  final out = Int16List(total);
  var offset = 0;
  for (final p in parts) {
    out.setRange(offset, offset + p.length, p);
    offset += p.length;
  }
  return out;
}

double _fadeWindow(int i, int total, int fadeInSamples, int fadeOutSamples) {
  var w = 1.0;

  if (fadeInSamples > 0 && i < fadeInSamples) {
    w *= i / fadeInSamples;
  }

  if (fadeOutSamples > 0 && i >= total - fadeOutSamples) {
    w *= (total - 1 - i) / fadeOutSamples;
  }

  if (w < 0.0) return 0.0;
  if (w > 1.0) return 1.0;
  return w;
}

int _floatToPcm16(double v) {
  if (v > 1.0) v = 1.0;
  if (v < -1.0) v = -1.0;
  return (v * 32767.0).round();
}

void _writeWavFile({required File file, required Int16List pcmSamples}) {
  final pcmBytes = _pcm16ToBytes(pcmSamples);
  final wavBytes = _wrapPcm16AsWav(pcmBytes);

  file.writeAsBytesSync(wavBytes, flush: true);

  final bytesOnDisk = file.lengthSync();
  final durationSeconds = pcmSamples.length / _sampleRate;
  // ignore: avoid_print
  print(
    'Wrote ${file.path}: '
    '$bytesOnDisk bytes, '
    '${pcmSamples.length} samples, '
    '${durationSeconds.toStringAsFixed(3)}s',
  );
}

Uint8List _pcm16ToBytes(Int16List samples) {
  final bd = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    bd.setInt16(i * 2, samples[i], Endian.little);
  }
  return bd.buffer.asUint8List();
}

/// Wrap PCM16 mono data in a standard 44-byte RIFF/WAVE header.
Uint8List _wrapPcm16AsWav(Uint8List pcm16Data) {
  final dataSize = pcm16Data.length;
  final header = ByteData(44);

  header.setUint8(0, 0x52); // 'R'
  header.setUint8(1, 0x49); // 'I'
  header.setUint8(2, 0x46); // 'F'
  header.setUint8(3, 0x46); // 'F'
  header.setUint32(4, 36 + dataSize, Endian.little);

  header.setUint8(8, 0x57); // 'W'
  header.setUint8(9, 0x41); // 'A'
  header.setUint8(10, 0x56); // 'V'
  header.setUint8(11, 0x45); // 'E'

  header.setUint8(12, 0x66); // 'f'
  header.setUint8(13, 0x6D); // 'm'
  header.setUint8(14, 0x74); // 't'
  header.setUint8(15, 0x20); // ' '
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, _numChannels, Endian.little);
  header.setUint32(24, _sampleRate, Endian.little);
  header.setUint32(
    28,
    _sampleRate * _numChannels * _bitsPerSample ~/ 8,
    Endian.little,
  );
  header.setUint16(32, _numChannels * _bitsPerSample ~/ 8, Endian.little);
  header.setUint16(34, _bitsPerSample, Endian.little);

  header.setUint8(36, 0x64); // 'd'
  header.setUint8(37, 0x61); // 'a'
  header.setUint8(38, 0x74); // 't'
  header.setUint8(39, 0x61); // 'a'
  header.setUint32(40, dataSize, Endian.little);

  final wavData = Uint8List(44 + dataSize);
  wavData.setRange(0, 44, header.buffer.asUint8List());
  wavData.setRange(44, 44 + dataSize, pcm16Data);
  return wavData;
}
