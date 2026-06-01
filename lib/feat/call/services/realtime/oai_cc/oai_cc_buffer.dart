import 'dart:convert';
import 'dart:typed_data';

/// Manages accumulation of raw input PCM bytes and formatting them as a WAV payload.
final class OaiCcAudioBuffer {
  final BytesBuilder _builder = BytesBuilder();

  /// Returns the current length of raw PCM bytes accumulated in the buffer.
  int get lengthInBytes => _builder.length;

  /// Clear the buffer contents.
  void clear() {
    _builder.clear();
  }

  /// Append raw PCM audio chunks.
  void append(Uint8List chunk) {
    _builder.add(chunk);
  }

  /// Package the accumulated raw PCM bytes as a base64-encoded WAV format payload.
  /// Uses OpenAI Realtime defaults (24000 Hz, mono, 16-bit PCM).
  String toWavBase64({
    int sampleRate = 24000,
    int channels = 1,
    int bitsPerSample = 16,
  }) {
    final rawPcm = _builder.toBytes();
    final wavBytes = _addWavHeader(rawPcm, sampleRate, channels, bitsPerSample);
    return base64Encode(wavBytes);
  }

  /// Prefixes raw PCM bytes with a standard 44-byte WAV header.
  Uint8List _addWavHeader(Uint8List rawPcm, int sampleRate, int channels, int bitsPerSample) {
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final subChunk2Size = rawPcm.length;
    final chunkSize = 36 + subChunk2Size;

    final header = ByteData(44);

    // Chunk ID "RIFF"
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F

    // Chunk Size
    header.setUint32(4, chunkSize, Endian.little);

    // Format "WAVE"
    header.setUint8(8, 0x57);  // W
    header.setUint8(9, 0x41);  // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E

    // Subchunk1 ID "fmt "
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6d); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // space

    // Subchunk1 Size (16 for PCM)
    header.setUint32(16, 16, Endian.little);

    // Audio Format (1 for PCM)
    header.setUint16(20, 1, Endian.little);

    // Num Channels
    header.setUint16(22, channels, Endian.little);

    // Sample Rate
    header.setUint32(24, sampleRate, Endian.little);

    // Byte Rate
    header.setUint32(28, byteRate, Endian.little);

    // Block Align
    header.setUint16(32, blockAlign, Endian.little);

    // Bits Per Sample
    header.setUint16(34, bitsPerSample, Endian.little);

    // Subchunk2 ID "data"
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a

    // Subchunk2 Size
    header.setUint32(40, subChunk2Size, Endian.little);

    final finalBuffer = Uint8List(44 + subChunk2Size);
    finalBuffer.setRange(0, 44, header.buffer.asUint8List());
    finalBuffer.setRange(44, finalBuffer.length, rawPcm);

    return finalBuffer;
  }
}
