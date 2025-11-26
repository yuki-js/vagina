import 'dart:async';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'log_service.dart';

/// Service for playing audio from Azure OpenAI Realtime API
class AudioPlayerService {
  static const _tag = 'AudioPlayer';
  
  final AudioPlayer _player = AudioPlayer();
  final List<int> _audioBuffer = [];
  bool _isPlaying = false;
  bool _isProcessing = false;
  Timer? _bufferTimer;
  bool _responseComplete = false;
  
  // Audio format settings (must match API output format)
  static const int _sampleRate = 24000;
  static const int _channels = 1;
  static const int _bitsPerSample = 16;
  
  // Minimum buffer size before playing (0.5 seconds of audio)
  // 24000 samples/sec * 2 bytes/sample * 0.5 sec = 24000 bytes
  static const int _minBufferSize = 24000;
  
  // Maximum buffer size to prevent memory issues (5 seconds of audio)
  static const int _maxBufferSize = 24000 * 2 * 5;
  
  // Buffer timeout - start playing after this time even if buffer is small
  static const Duration _bufferTimeout = Duration(milliseconds: 500);
  
  // Playback timeout to prevent hanging
  static const Duration _playbackTimeout = Duration(seconds: 60);

  bool get isPlaying => _isPlaying;

  /// Add PCM audio data to the playback buffer
  void addAudioData(Uint8List pcmData) {
    logService.debug(_tag, 'Adding audio data to buffer: ${pcmData.length} bytes (total: ${_audioBuffer.length + pcmData.length})');
    _audioBuffer.addAll(pcmData);
    
    // Reset the buffer timer
    _bufferTimer?.cancel();
    
    // If buffer is large enough, start playing immediately
    if (_audioBuffer.length >= _minBufferSize) {
      logService.info(_tag, 'Buffer reached minimum size (${_audioBuffer.length} bytes), starting playback');
      _startPlayback();
    } else {
      // Otherwise, wait a bit for more data
      _bufferTimer = Timer(_bufferTimeout, () {
        if (_audioBuffer.isNotEmpty && !_isProcessing) {
          logService.info(_tag, 'Buffer timeout, starting playback with ${_audioBuffer.length} bytes');
          _startPlayback();
        }
      });
    }
  }

  /// Mark that the response is complete (audio.done received)
  void markResponseComplete() {
    logService.info(_tag, 'Response marked complete');
    _responseComplete = true;
    _bufferTimer?.cancel();
    
    // If we have remaining audio in buffer, play it
    if (_audioBuffer.isNotEmpty && !_isProcessing) {
      _startPlayback();
    }
  }

  void _startPlayback() {
    if (_isProcessing) return;
    _processBuffer();
  }

  Future<void> _processBuffer() async {
    if (_isProcessing) return;
    
    _isProcessing = true;
    _isPlaying = true;
    logService.info(_tag, 'Processing audio buffer');

    while (_audioBuffer.isNotEmpty) {
      // Take up to max buffer size worth of audio
      final chunkSize = _audioBuffer.length.clamp(0, _maxBufferSize);
      final chunk = _audioBuffer.sublist(0, chunkSize);
      _audioBuffer.removeRange(0, chunkSize);
      
      if (chunk.isEmpty) continue;
      
      logService.info(_tag, 'Playing audio chunk: ${chunk.length} bytes (remaining in buffer: ${_audioBuffer.length})');
      
      // Convert PCM16 to WAV format
      final wavData = _pcmToWav(Uint8List.fromList(chunk));
      logService.debug(_tag, 'Converted to WAV: ${wavData.length} bytes');
      
      // Play the audio with timeout
      try {
        await _player.setAudioSource(
          BytesAudioSource(wavData),
        );
        logService.debug(_tag, 'Audio source set, starting playback');
        await _player.play();
        logService.debug(_tag, 'Play started, waiting for completion');
        
        // Wait for playback to complete with timeout
        await _player.processingStateStream
            .firstWhere((state) => state == ProcessingState.completed)
            .timeout(_playbackTimeout, onTimeout: () {
              logService.warn(_tag, 'Playback timeout');
              return ProcessingState.completed;
            });
        logService.info(_tag, 'Chunk playback completed');
      } catch (e) {
        logService.error(_tag, 'Playback error: $e');
        // Continue processing even if playback fails
      }
      
      // If more data arrived while playing, continue
      if (_audioBuffer.isEmpty && !_responseComplete) {
        // Wait a bit for more data
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    _isPlaying = false;
    _isProcessing = false;
    _responseComplete = false;
    logService.info(_tag, 'Buffer processing complete');
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

  /// Stop all playback and clear buffer
  Future<void> stop() async {
    logService.info(_tag, 'Stopping playback');
    _bufferTimer?.cancel();
    _audioBuffer.clear();
    _isPlaying = false;
    _isProcessing = false;
    _responseComplete = false;
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
