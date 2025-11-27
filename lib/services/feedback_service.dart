import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'log_service.dart';

/// Service for providing haptic and audio feedback to the user
class FeedbackService {
  static const _tag = 'FeedbackService';
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _hasVibrator = false;
  bool _initialized = false;
  
  /// Initialize the feedback service
  Future<void> init() async {
    if (_initialized) return;
    
    try {
      final hasVibrator = await Vibration.hasVibrator();
      _hasVibrator = hasVibrator == true;
      logService.info(_tag, 'Vibrator available: $_hasVibrator');
      _initialized = true;
    } catch (e) {
      logService.warn(_tag, 'Failed to check vibrator: $e');
      _hasVibrator = false;
      _initialized = true;
    }
  }
  
  /// Play a single knock (when user starts speaking, when AI audio arrives)
  /// Only haptic feedback - sound is intentionally disabled to avoid distraction
  Future<void> knockSingle() async {
    await _vibrate([50]);
  }
  
  /// Play a double knock (when AI response ends and it's user's turn)
  /// Only haptic feedback - sound is intentionally disabled to avoid distraction
  Future<void> knockDouble() async {
    await _vibrate([50, 100, 50]);
  }
  
  /// Play call start sound
  Future<void> playCallStart() async {
    await _vibrate([100]);
    await _playSound('call_start.wav');
  }
  
  /// Play call end sound (normal termination)
  Future<void> playCallEnd() async {
    await _vibrate([50, 50, 100]);
    await _playSound('call_end.wav');
  }
  
  /// Play error sound (connection error, etc.)
  Future<void> playCallError() async {
    await _vibrate([100, 100, 100, 100, 200]);
    await _playSound('call_error.wav');
  }
  
  /// Vibrate with the given pattern
  Future<void> _vibrate(List<int> pattern) async {
    if (!_hasVibrator) return;
    
    try {
      if (pattern.length == 1) {
        await Vibration.vibrate(duration: pattern[0]);
      } else {
        await Vibration.vibrate(pattern: pattern);
      }
    } catch (e) {
      logService.warn(_tag, 'Vibration failed: $e');
      // Fallback to HapticFeedback
      await HapticFeedback.mediumImpact();
    }
  }
  
  /// Play a sound from assets
  Future<void> _playSound(String filename) async {
    try {
      await _audioPlayer.play(AssetSource('sounds/$filename'));
    } catch (e) {
      logService.warn(_tag, 'Sound playback failed: $e');
    }
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}

/// Global singleton instance
final feedbackService = FeedbackService();
