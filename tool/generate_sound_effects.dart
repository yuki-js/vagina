// This is a standalone Dart script (not Flutter)
// Run with: dart run tool/generate_sound_effects.dart
//
// Generates 3 small 24kHz mono PCM16 WAV sound effects used for tool call lifecycle UX.
//
// Constraints:
// - Uses only: dart:io, dart:math, dart:typed_data
// - Writes assets into: assets/audio/
// - Writes valid RIFF/WAVE headers (PCM, 16-bit, mono, 24000Hz)

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int _sampleRate = 24000;
const int _numChannels = 1;
const int _bitsPerSample = 16;

void main() {
  final outputDir = Directory('assets/audio');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  // Generate all 3 sound effects.
  generateExecutingLoop(outputDir);
  generateErrorTone(outputDir);
  generateCancelTone(outputDir);

  print('All sound effects generated successfully!');
}

/// 1) tool_executing.wav — Looping ambient sound during tool execution
/// - 1.5s long (intended to loop)
/// - Mix of 220Hz + 330Hz + 440Hz soft sines
/// - Low amplitude (peak <= ~0.105)
/// - 100ms fade-in + 100ms fade-out to avoid clicks at loop boundary
void generateExecutingLoop(Directory outputDir) {
  const double durationSeconds = 1.5;
  const double fadeSeconds = 0.100;

  // Amplitudes are chosen so that the *maximum possible* sum never exceeds ~0.105.
  // (Each sine is in [-amp, +amp], so max sum is amp1+amp2+amp3.)
  const freqsHz = <double>[220.0, 330.0, 440.0];
  const amps = <double>[0.040, 0.035, 0.030];

  final samples = _sineMix(
    durationSeconds: durationSeconds,
    frequenciesHz: freqsHz,
    amplitudes: amps,
    fadeInSeconds: fadeSeconds,
    fadeOutSeconds: fadeSeconds,
  );

  _writeWavFile(
    file: File('${outputDir.path}/tool_executing.wav'),
    pcmSamples: samples,
  );
}

/// 2) tool_error.wav — Error notification sound
/// - Two-tone descending beep: 800Hz for 100ms → 50ms silence → 500Hz for 150ms
/// - Moderate amplitude
void generateErrorTone(Directory outputDir) {
  const double amp = 0.35;

  final part1 = _sineTone(
    durationSeconds: 0.100,
    frequencyHz: 800.0,
    amplitude: amp,
    fadeInSeconds: 0.005,
    fadeOutSeconds: 0.010,
  );
  final silence = _silence(durationSeconds: 0.050);
  final part2 = _sineTone(
    durationSeconds: 0.150,
    frequencyHz: 500.0,
    amplitude: amp,
    fadeInSeconds: 0.005,
    fadeOutSeconds: 0.015,
  );

  final combined = _concatInt16([part1, silence, part2]);

  _writeWavFile(
    file: File('${outputDir.path}/tool_error.wav'),
    pcmSamples: combined,
  );
}

/// 3) tool_cancelled.wav — Cancellation notification sound
/// - Single brief tone around 350-400Hz, 120ms, with quick fade-out
void generateCancelTone(Directory outputDir) {
  final samples = _sineTone(
    durationSeconds: 0.120,
    frequencyHz: 380.0,
    amplitude: 0.18,
    fadeInSeconds: 0.005,
    fadeOutSeconds: 0.030,
  );

  _writeWavFile(
    file: File('${outputDir.path}/tool_cancelled.wav'),
    pcmSamples: samples,
  );
}

// ----------------------------
// Synthesis helpers
// ----------------------------

Int16List _sineMix({
  required double durationSeconds,
  required List<double> frequenciesHz,
  required List<double> amplitudes,
  required double fadeInSeconds,
  required double fadeOutSeconds,
}) {
  assert(frequenciesHz.length == amplitudes.length);

  final int totalSamples = (durationSeconds * _sampleRate).round();
  final int fadeInSamples = (fadeInSeconds * _sampleRate).round();
  final int fadeOutSamples = (fadeOutSeconds * _sampleRate).round();

  final out = Int16List(totalSamples);
  const double twoPi = 2.0 * pi;

  for (var i = 0; i < totalSamples; i++) {
    final t = i / _sampleRate;

    var v = 0.0;
    for (var k = 0; k < frequenciesHz.length; k++) {
      v += sin(twoPi * frequenciesHz[k] * t) * amplitudes[k];
    }

    // Apply fades to remove boundary clicks. For loopable sounds, having the last
    // sample exactly match the first sample (often near 0.0) is important.
    final w = _fadeWindow(i, totalSamples, fadeInSamples, fadeOutSamples);
    v *= w;

    out[i] = _floatToPcm16(v);
  }

  return out;
}

Int16List _sineTone({
  required double durationSeconds,
  required double frequencyHz,
  required double amplitude,
  required double fadeInSeconds,
  required double fadeOutSeconds,
}) {
  final int totalSamples = (durationSeconds * _sampleRate).round();
  final int fadeInSamples = (fadeInSeconds * _sampleRate).round();
  final int fadeOutSamples = (fadeOutSeconds * _sampleRate).round();

  final out = Int16List(totalSamples);
  const double twoPi = 2.0 * pi;

  for (var i = 0; i < totalSamples; i++) {
    final t = i / _sampleRate;

    var v = sin(twoPi * frequencyHz * t) * amplitude;
    v *= _fadeWindow(i, totalSamples, fadeInSamples, fadeOutSamples);

    out[i] = _floatToPcm16(v);
  }

  return out;
}

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
    // Ensure last sample fades to exactly 0.0
    w *= (total - 1 - i) / fadeOutSamples;
  }

  if (w < 0.0) return 0.0;
  if (w > 1.0) return 1.0;
  return w;
}

int _floatToPcm16(double v) {
  // Clamp to [-1.0, +1.0] to prevent integer overflow.
  if (v > 1.0) v = 1.0;
  if (v < -1.0) v = -1.0;

  // Use 32767 so +1.0 maps to max positive int16.
  final s = (v * 32767.0).round();
  return s;
}

// ----------------------------
// WAV writing
// ----------------------------

void _writeWavFile({required File file, required Int16List pcmSamples}) {
  final pcmBytes = _pcm16ToBytes(pcmSamples);
  final wavBytes = _wrapPcm16AsWav(pcmBytes);

  file.writeAsBytesSync(wavBytes, flush: true);

  final bytesOnDisk = file.lengthSync();
  final durationSeconds = pcmSamples.length / _sampleRate;
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
///
/// Header layout matches the known-good structure in:
/// lib/services/audio/call_audio_service.dart (PCM16, 24kHz, mono)
Uint8List _wrapPcm16AsWav(Uint8List pcm16Data) {
  final dataSize = pcm16Data.length;
  final header = ByteData(44);

  // "RIFF" chunk descriptor
  header.setUint8(0, 0x52); // 'R'
  header.setUint8(1, 0x49); // 'I'
  header.setUint8(2, 0x46); // 'F'
  header.setUint8(3, 0x46); // 'F'
  header.setUint32(4, 36 + dataSize, Endian.little); // fileSize - 8

  // "WAVE" format
  header.setUint8(8, 0x57); // 'W'
  header.setUint8(9, 0x41); // 'A'
  header.setUint8(10, 0x56); // 'V'
  header.setUint8(11, 0x45); // 'E'

  // "fmt " sub-chunk
  header.setUint8(12, 0x66); // 'f'
  header.setUint8(13, 0x6D); // 'm'
  header.setUint8(14, 0x74); // 't'
  header.setUint8(15, 0x20); // ' '
  header.setUint32(16, 16, Endian.little); // PCM fmt chunk size
  header.setUint16(20, 1, Endian.little); // Audio format 1 = PCM
  header.setUint16(22, _numChannels, Endian.little);
  header.setUint32(24, _sampleRate, Endian.little);
  header.setUint32(
    28,
    _sampleRate * _numChannels * _bitsPerSample ~/ 8,
    Endian.little,
  );
  header.setUint16(32, _numChannels * _bitsPerSample ~/ 8, Endian.little);
  header.setUint16(34, _bitsPerSample, Endian.little);

  // "data" sub-chunk
  header.setUint8(36, 0x64); // 'd'
  header.setUint8(37, 0x61); // 'a'
  header.setUint8(38, 0x74); // 't'
  header.setUint8(39, 0x61); // 'a'
  header.setUint32(40, dataSize, Endian.little);

  // Combine header and PCM data.
  final wavData = Uint8List(44 + dataSize);
  wavData.setRange(0, 44, header.buffer.asUint8List());
  wavData.setRange(44, 44 + dataSize, pcm16Data);
  return wavData;
}
