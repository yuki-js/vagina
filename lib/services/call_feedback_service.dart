import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'log_service.dart';

/// Unified service for call feedback (audio + haptic)
///
/// Combines audio feedback and haptic feedback for call lifecycle events
/// to provide intuitive multi-sensory user feedback.
class CallFeedbackService {
  static const _tag = 'CallFeedback';

  final LogService _logService;
  AudioPlayer? _dialTonePlayer;
  AudioPlayer? _endTonePlayer;
  AudioPlayer? _toolExecutingPlayer;

  CallFeedbackService({LogService? logService})
      : _logService = logService ?? LogService();

  // ==========================================================================
  // Audio Feedback
  // ==========================================================================

  /// Play dial tone when call is connecting (loops until stopped)
  Future<void> playDialTone() async {
    try {
      _logService.debug(_tag, 'Playing dial tone');

      // Stop any existing dial tone
      await stopDialTone();

      _dialTonePlayer = AudioPlayer();
      await _dialTonePlayer!.setAsset('assets/audio/dial_tone.wav');
      await _dialTonePlayer!.setLoopMode(LoopMode.one);
      await _dialTonePlayer!.setVolume(0.3);
      await _dialTonePlayer!.play();

      _logService.info(_tag, 'Dial tone started');
    } catch (e) {
      _logService.error(_tag, 'Failed to play dial tone: $e');
    }
  }

  /// Stop dial tone
  Future<void> stopDialTone() async {
    if (_dialTonePlayer != null) {
      try {
        _logService.debug(_tag, 'Stopping dial tone');
        await _dialTonePlayer!.stop();
        await _dialTonePlayer!.dispose();
      } catch (e) {
        _logService.error(_tag, 'Error stopping dial tone: $e');
      } finally {
        _dialTonePlayer = null;
      }
    }
  }

  /// Play call end tone (single descending arpeggio)
  Future<void> playCallEndTone() async {
    try {
      _logService.debug(_tag, 'Playing call end tone');

      _endTonePlayer = AudioPlayer();
      await _endTonePlayer!.setAsset('assets/audio/call_end.wav');
      await _endTonePlayer!.setVolume(0.5);
      await _endTonePlayer!.play();

      _logService.info(_tag, 'Call end tone played');

      // Dispose after playing
      await Future.delayed(const Duration(milliseconds: 500));
      await _endTonePlayer!.dispose();
      _endTonePlayer = null;
    } catch (e) {
      _logService.error(_tag, 'Failed to play call end tone: $e');
    }
  }

  /// Start looping the tool executing sound
  Future<void> playToolExecuting() async {
    try {
      _logService.debug(_tag, 'Playing tool executing sound');

      // Stop any existing tool executing sound
      await stopToolExecuting();

      _toolExecutingPlayer = AudioPlayer();
      await _toolExecutingPlayer!.setAsset('assets/audio/tool_executing.wav');
      await _toolExecutingPlayer!.setLoopMode(LoopMode.one);
      await _toolExecutingPlayer!.setVolume(0.15);
      await _toolExecutingPlayer!.play();

      _logService.info(_tag, 'Tool executing sound started');
    } catch (e) {
      _logService.error(_tag, 'Tool executing sound error: $e');
    }
  }

  /// Stop the tool executing sound
  Future<void> stopToolExecuting() async {
    if (_toolExecutingPlayer != null) {
      try {
        _logService.debug(_tag, 'Stopping tool executing sound');
        await _toolExecutingPlayer!.stop();
        await _toolExecutingPlayer!.dispose();
      } catch (e) {
        _logService.error(_tag, 'Stop tool executing sound error: $e');
      } finally {
        _toolExecutingPlayer = null;
      }
    }
  }

  /// Play tool error sound (single shot)
  Future<void> playToolError() async {
    try {
      _logService.debug(_tag, 'Playing tool error sound');

      final player = AudioPlayer();
      await player.setAsset('assets/audio/tool_error.wav');
      await player.setVolume(0.4);
      await player.play();

      _logService.info(_tag, 'Tool error sound played');

      // Dispose after playing
      await Future.delayed(const Duration(milliseconds: 500));
      await player.dispose();
    } catch (e) {
      _logService.error(_tag, 'Tool error sound error: $e');
    }
  }

  /// Play tool cancelled sound (single shot)
  Future<void> playToolCancelled() async {
    try {
      _logService.debug(_tag, 'Playing tool cancelled sound');

      final player = AudioPlayer();
      await player.setAsset('assets/audio/tool_cancelled.wav');
      await player.setVolume(0.25);
      await player.play();

      _logService.info(_tag, 'Tool cancelled sound played');

      // Dispose after playing
      await Future.delayed(const Duration(milliseconds: 250));
      await player.dispose();
    } catch (e) {
      _logService.error(_tag, 'Tool cancelled sound error: $e');
    }
  }

  // ==========================================================================
  // Haptic Feedback
  // ==========================================================================

  /// Heavy impact haptic feedback
  ///
  /// Used when AI's response turn ends and user's turn begins.
  /// This provides a strong, clear signal that the user can now speak.
  Future<void> heavyImpact() async {
    try {
      await HapticFeedback.heavyImpact();
      _logService.debug(_tag, 'Heavy impact haptic triggered');
    } catch (e) {
      _logService.warn(_tag, 'Failed to trigger heavy impact haptic: $e');
    }
  }

  /// Selection click haptic feedback
  ///
  /// Used for VAD-related events:
  /// - When user speech is detected and recording begins
  /// - When user speech ends and AI audio starts
  Future<void> selectionClick() async {
    try {
      await HapticFeedback.selectionClick();
      _logService.debug(_tag, 'Selection click haptic triggered');
    } catch (e) {
      _logService.warn(_tag, 'Failed to trigger selection click haptic: $e');
    }
  }

  // ==========================================================================
  // Combined Feedback
  // ==========================================================================

  /// Trigger both audio and haptic feedback for call end
  Future<void> callEnded() async {
    await Future.wait([
      playCallEndTone(),
      heavyImpact(),
    ]);
  }

  /// Dispose of all audio players
  Future<void> dispose() async {
    await stopDialTone();
    await stopToolExecuting();

    if (_endTonePlayer != null) {
      try {
        await _endTonePlayer!.dispose();
      } catch (e) {
        _logService.error(_tag, 'Error disposing end tone player: $e');
      } finally {
        _endTonePlayer = null;
      }
    }
  }
}
