import 'dart:async';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

/// Service for playing audio from Azure OpenAI Realtime API
class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  final List<Uint8List> _audioQueue = [];
  bool _isPlaying = false;
  bool _isProcessing = false;
  
  // Audio format settings (must match API output format)
  static const int _sampleRate = 24000;
  static const int _channels = 1;
  static const int _bitsPerSample = 16;
  
  // Maximum batch size to prevent memory issues (100KB)
  static const int _maxBatchSize = 100 * 1024;
  
  // Playback timeout to prevent hanging
  static const Duration _playbackTimeout = Duration(seconds: 30);

  bool get isPlaying => _isPlaying;

  /// Add PCM audio data to the playback queue
  void addAudioData(Uint8List pcmData) {
    _audioQueue.add(pcmData);
    if (!_isProcessing) {
      _processQueue();
    }
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    
    _isProcessing = true;
    _isPlaying = true;

    while (_audioQueue.isNotEmpty) {
      // Collect audio data up to max batch size
      final allData = <int>[];
      while (_audioQueue.isNotEmpty && allData.length < _maxBatchSize) {
        final chunk = _audioQueue.removeAt(0);
        // Only add if it won't exceed max batch size
        if (allData.length + chunk.length <= _maxBatchSize) {
          allData.addAll(chunk);
        } else {
          // Put the chunk back and process what we have
          _audioQueue.insert(0, chunk);
          break;
        }
      }
      
      if (allData.isEmpty) continue;
      
      // Convert PCM16 to WAV format
      final wavData = _pcmToWav(Uint8List.fromList(allData));
      
      // Play the audio with timeout
      try {
        await _player.setAudioSource(
          BytesAudioSource(wavData),
        );
        await _player.play();
        // Wait for playback to complete with timeout
        await _player.processingStateStream
            .firstWhere((state) => state == ProcessingState.completed)
            .timeout(_playbackTimeout, onTimeout: () {
              return ProcessingState.completed;
            });
      } catch (e) {
        // Continue processing even if playback fails
      }
    }

    _isPlaying = false;
    _isProcessing = false;
  }

  /// Convert raw PCM16 data to WAV format
  Uint8List _pcmToWav(Uint8List pcmData) {
    final byteRate = _sampleRate * _channels * _bitsPerSample ~/ 8;
    final blockAlign = _channels * _bitsPerSample ~/ 8;
    final dataSize = pcmData.length;
    final fileSize = 36 + dataSize;

    final header = ByteData(44);
    
    // RIFF header
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57);  // 'W'
    header.setUint8(9, 0x41);  // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'
    
    // fmt chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Subchunk1Size
    header.setUint16(20, 1, Endian.little);  // AudioFormat (PCM = 1)
    header.setUint16(22, _channels, Endian.little);
    header.setUint32(24, _sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, _bitsPerSample, Endian.little);
    
    // data chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataSize, Endian.little);

    // Combine header and PCM data
    final wavData = Uint8List(44 + dataSize);
    wavData.setAll(0, header.buffer.asUint8List());
    wavData.setAll(44, pcmData);
    
    return wavData;
  }

  /// Stop all playback and clear queue
  Future<void> stop() async {
    _audioQueue.clear();
    _isPlaying = false;
    _isProcessing = false;
    await _player.stop();
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  /// Dispose the player
  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}

/// Custom audio source for playing bytes directly
class BytesAudioSource extends StreamAudioSource {
  final Uint8List _bytes;

  BytesAudioSource(this._bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}
