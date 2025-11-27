import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../services/log_service.dart';

/// Screen to reproduce the flutter_sound race condition bug
/// 
/// This screen demonstrates the SIGSEGV crash that occurs when
/// `feedFromStream()` is called rapidly and then `stopPlayer()` is called
/// while threads are still writing to the AudioTrack.
/// 
/// Bug details: See docs/FLUTTER_SOUND_RACE_CONDITION_BUG.md
class FlutterSoundBugReproScreen extends StatefulWidget {
  const FlutterSoundBugReproScreen({super.key});

  @override
  State<FlutterSoundBugReproScreen> createState() => _FlutterSoundBugReproScreenState();
}

class _FlutterSoundBugReproScreenState extends State<FlutterSoundBugReproScreen> {
  static const _tag = 'BugRepro';
  
  FlutterSoundPlayer? _player;
  bool _isRunning = false;
  bool _useSafeMode = true;
  int _feedCount = 0;
  String _status = 'Ready';
  final List<String> _logs = [];
  Timer? _feedTimer;
  
  // Queue for safe mode
  final List<Uint8List> _audioQueue = [];
  bool _isProcessingQueue = false;

  @override
  void dispose() {
    _feedTimer?.cancel();
    _player?.closePlayer();
    super.dispose();
  }

  void _log(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toString().substring(11, 23)}] $message');
      if (_logs.length > 100) {
        _logs.removeAt(0);
      }
    });
    logService.info(_tag, message);
  }

  /// Generate random PCM16 audio data (white noise)
  Uint8List _generateRandomPCM16(int sampleCount) {
    final random = Random();
    final data = Uint8List(sampleCount * 2); // 2 bytes per sample
    for (int i = 0; i < data.length; i += 2) {
      // Random 16-bit signed value, reduced amplitude
      int value = (random.nextInt(8000) - 4000);
      data[i] = value & 0xFF;
      data[i + 1] = (value >> 8) & 0xFF;
    }
    return data;
  }

  Future<void> _startPlayer() async {
    _player = FlutterSoundPlayer();
    await _player!.openPlayer();
    await _player!.startPlayerFromStream(
      codec: Codec.pcm16,
      sampleRate: 24000,
      numChannels: 1,
      bufferSize: 8192,
    );
    _log('Player started');
  }

  /// UNSAFE: Feed audio directly (will cause race condition)
  Future<void> _feedUnsafe(Uint8List data) async {
    if (_player == null) return;
    await _player!.feedUint8FromStream(data);
  }

  /// SAFE: Queue-based feed to prevent race condition
  Future<void> _feedSafe(Uint8List data) async {
    _audioQueue.add(data);
    await _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;
    
    try {
      while (_audioQueue.isNotEmpty && _isRunning && _player != null) {
        final chunk = _audioQueue.removeAt(0);
        await _player!.feedUint8FromStream(chunk);
        await Future.delayed(const Duration(milliseconds: 1));
      }
    } catch (e) {
      _log('Error in queue processing: $e');
    } finally {
      _isProcessingQueue = false;
    }
  }

  Future<void> _startTest() async {
    if (_isRunning) return;
    
    setState(() {
      _isRunning = true;
      _feedCount = 0;
      _logs.clear();
      _status = 'Starting...';
    });
    
    _log('Starting test with ${_useSafeMode ? "SAFE" : "UNSAFE"} mode');
    
    try {
      await _startPlayer();
      
      // Start rapid feeding
      _feedTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
        if (!_isRunning) {
          timer.cancel();
          return;
        }
        
        // Generate ~100ms of audio at 24kHz
        final audioData = _generateRandomPCM16(2400);
        _feedCount++;
        
        if (_useSafeMode) {
          await _feedSafe(audioData);
        } else {
          // This will cause race condition!
          await _feedUnsafe(audioData);
        }
        
        setState(() {
          _status = 'Feeding... (#$_feedCount)';
        });
      });
      
    } catch (e) {
      _log('Error: $e');
      setState(() {
        _status = 'Error: $e';
        _isRunning = false;
      });
    }
  }

  Future<void> _stopTest() async {
    _log('Stopping test...');
    _feedTimer?.cancel();
    _feedTimer = null;
    
    setState(() {
      _status = 'Stopping player...';
    });
    
    // This is where the crash happens in unsafe mode!
    // Threads may still be writing to AudioTrack when we call stop
    try {
      if (_useSafeMode) {
        // Wait for queue to finish
        setState(() {
          _isRunning = false;
        });
        await Future.delayed(const Duration(milliseconds: 100));
        while (_isProcessingQueue) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
      } else {
        // Don't wait - this causes the race condition
        setState(() {
          _isRunning = false;
        });
      }
      
      await _player?.stopPlayer();
      await _player?.closePlayer();
      _player = null;
      _log('Player stopped successfully');
      
      setState(() {
        _status = 'Stopped (no crash!)';
      });
    } catch (e) {
      _log('Error stopping: $e');
      setState(() {
        _status = 'Error: $e';
      });
    }
    
    setState(() {
      _isRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_sound Bug Repro'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _useSafeMode ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _useSafeMode ? Colors.green : Colors.red,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _useSafeMode 
                        ? '✅ Safe Mode (Queue-based)' 
                        : '⚠️ UNSAFE Mode (Will Crash!)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _useSafeMode ? Colors.green.shade900 : Colors.red.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _useSafeMode
                        ? 'Audio feed calls are serialized through a queue.'
                        : 'Direct feed calls cause race condition in AudioTrack.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _useSafeMode ? Colors.green.shade800 : Colors.red.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Mode toggle
            SwitchListTile(
              title: const Text('Safe Mode'),
              subtitle: const Text('Serialize feed calls through queue'),
              value: _useSafeMode,
              onChanged: _isRunning ? null : (value) {
                setState(() {
                  _useSafeMode = value;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: $_status'),
                  Text('Feed count: $_feedCount'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRunning ? null : _startTest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Start Test'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRunning ? _stopTest : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Stop (Trigger Bug)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'To reproduce the bug:\n'
                '1. Turn OFF Safe Mode\n'
                '2. Press Start Test\n'
                '3. Wait a few seconds\n'
                '4. Press Stop (Trigger Bug)\n'
                '5. App should crash with SIGSEGV',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            
            // Logs
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  reverse: true,
                  itemBuilder: (context, index) {
                    return Text(
                      _logs[_logs.length - 1 - index],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: Colors.green,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
