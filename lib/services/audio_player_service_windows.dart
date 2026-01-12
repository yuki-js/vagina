import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'log_service.dart';

/// Windows-compatible audio player service using just_audio
/// 
/// This implementation provides audio playback specifically for Windows
/// where flutter_sound is not supported. It uses just_audio which has
/// full Windows support through its platform implementation.
class AudioPlayerServiceWindows {
  final LogService _logService;
  final AudioPlayer _player = AudioPlayer();
  final List<Uint8List> _audioQueue = [];
  bool _isPlaying = false;
  int _currentFileIndex = 0;

  AudioPlayerServiceWindows({LogService? logService})
      : _logService = logService ?? LogService() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _playNextInQueue();
      }
    });
  }

  /// Initialize the audio player
  Future<void> initialize() async {
    // Just_audio doesn't require explicit initialization
    // But we can set up the player configuration here
    await _player.setVolume(1.0);
  }

  /// Play PCM16 audio data
  /// 
  /// [audioData] - PCM16 audio data at 24kHz mono
  Future<void> play(Uint8List audioData) async {
    _audioQueue.add(audioData);
    
    if (!_isPlaying) {
      await _playNextInQueue();
    }
  }

  Future<void> _playNextInQueue() async {
    if (_audioQueue.isEmpty) {
      _isPlaying = false;
      return;
    }

    _isPlaying = true;
    final audioData = _audioQueue.removeAt(0);

    try {
      // Write PCM data to temporary WAV file
      final wavFile = await _createWavFile(audioData);
      
      // Play the file
      await _player.setFilePath(wavFile.path);
      await _player.play();
      
      // Clean up after playback
      _player.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed
      ).then((_) {
        wavFile.deleteSync();
      });
    } catch (e) {
      __logService.error('AudioPlayerWindows', 'Error playing audio: $e');
      _isPlaying = false;
      // Try next in queue
      await _playNextInQueue();
    }
  }

  /// Convert PCM16 data to WAV file
  Future<File> _createWavFile(Uint8List pcm16Data) async {
    final tempDir = await getTemporaryDirectory();
    final wavFilePath = path.join(
      tempDir.path,
      'audio_${_currentFileIndex++}_${DateTime.now().millisecondsSinceEpoch}.wav'
    );

    // Create WAV header for 24kHz mono PCM16
    const sampleRate = 24000;
    const numChannels = 1;
    const bitsPerSample = 16;
    final dataSize = pcm16Data.length;
    
    final header = ByteData(44);
    // "RIFF" chunk descriptor
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, 36 + dataSize, Endian.little); // File size - 8
    
    // "WAVE" format
    header.setUint8(8, 0x57);  // 'W'
    header.setUint8(9, 0x41);  // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'
    
    // "fmt " sub-chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Sub-chunk size
    header.setUint16(20, 1, Endian.little); // Audio format (PCM)
    header.setUint16(22, numChannels, Endian.little); // Number of channels
    header.setUint32(24, sampleRate, Endian.little); // Sample rate
    header.setUint32(28, sampleRate * numChannels * bitsPerSample ~/ 8, Endian.little); // Byte rate
    header.setUint16(32, numChannels * bitsPerSample ~/ 8, Endian.little); // Block align
    header.setUint16(34, bitsPerSample, Endian.little); // Bits per sample
    
    // "data" sub-chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataSize, Endian.little); // Data size

    // Combine header and PCM data
    final wavData = Uint8List(44 + dataSize);
    wavData.setRange(0, 44, header.buffer.asUint8List());
    wavData.setRange(44, 44 + dataSize, pcm16Data);

    // Write to file
    final file = File(wavFilePath);
    await file.writeAsBytes(wavData);
    
    return file;
  }

  /// Stop all playback and clear queue
  Future<void> stop() async {
    await _player.stop();
    _audioQueue.clear();
    _isPlaying = false;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _player.dispose();
    _audioQueue.clear();
  }
}
