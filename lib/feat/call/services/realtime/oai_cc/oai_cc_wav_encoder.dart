import 'dart:convert';
import 'dart:typed_data';

/// Encodes raw PCM audio into the WAV payload format expected by the
/// Chat Completions audio input path.
final class OaiCcWavEncoder {
  const OaiCcWavEncoder._();

  static String encodeBase64(
    Uint8List rawPcm, {
    int sampleRate = 24000,
    int channels = 1,
    int bitsPerSample = 16,
  }) {
    final wavBytes = _addWavHeader(rawPcm, sampleRate, channels, bitsPerSample);
    return base64Encode(wavBytes);
  }

  static Uint8List _addWavHeader(
    Uint8List rawPcm,
    int sampleRate,
    int channels,
    int bitsPerSample,
  ) {
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final subChunk2Size = rawPcm.length;
    final chunkSize = 36 + subChunk2Size;

    final header = ByteData(44);
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, chunkSize, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6d); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // space
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, subChunk2Size, Endian.little);

    final wavBytes = Uint8List(44 + subChunk2Size);
    wavBytes.setRange(0, 44, header.buffer.asUint8List());
    wavBytes.setRange(44, wavBytes.length, rawPcm);
    return wavBytes;
  }
}
