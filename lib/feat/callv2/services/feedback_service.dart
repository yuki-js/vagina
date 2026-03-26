import 'dart:async';

import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:vagina/feat/callv2/services/call_service.dart';
import 'package:vagina/feat/callv2/services/playback_service.dart';
import 'package:vagina/feat/callv2/services/subservice.dart';

/// Unified feedback service for callv2 (audio + haptic)
///
/// Provides multi-sensory user feedback for call lifecycle events.
class FeedbackService implements SubService {
  final CallService _callService;
  final Set<String> _executingToolCallIds = <String>{};
  StreamSubscription<CallState>? _callStateSubscription;
  StreamSubscription<PlaybackServiceState>? _playbackStateSubscription;
  StreamSubscription<void>? _assistantAudioCompletedSubscription;
  StreamSubscription<bool>? _userSpeakingStateSubscription;
  CallState _lastObservedState;
  PlaybackServiceState _lastPlaybackState;
  bool _awaitingAssistantPlaybackCompletionFeedback = false;
  AudioPlayer? _dialTonePlayer;
  AudioPlayer? _endTonePlayer;
  AudioPlayer? _toolExecutingPlayer;

  FeedbackService(this._callService)
      : _lastObservedState = _callService.state,
        _lastPlaybackState = _callService.playbackService.state {
    _callStateSubscription = _callService.states.listen((state) {
      final previousState = _lastObservedState;
      _lastObservedState = state;
      unawaited(_handleCallStateChanged(previousState, state));
    });
    _playbackStateSubscription =
        _callService.playbackService.states.listen(_handlePlaybackStateChanged);

    if (_lastObservedState == CallState.connecting) {
      unawaited(playDialTone());
    }

    _bindRealtimeFeedback();
  }

  Future<void> _bindRealtimeFeedback() async {
    final realtimeService = _callService.realtimeService!;

    _assistantAudioCompletedSubscription =
        realtimeService.assistantAudioCompleted.listen((_) {
      unawaited(_handleAssistantAudioCompletedSignal());
    });
    _userSpeakingStateSubscription =
        realtimeService.userSpeakingStates.listen((isSpeaking) {
      if (!isSpeaking) {
        return;
      }
      unawaited(selectionClick());
    });
  }

  Future<void> _handleCallStateChanged(
    CallState previousState,
    CallState currentState,
  ) async {
    if (previousState != CallState.connecting &&
        currentState == CallState.connecting) {
      await playDialTone();
      await _enableWakeLock();
      return;
    }

    if (previousState == CallState.connecting &&
        currentState != CallState.connecting) {
      await stopDialTone();
    }

    if (previousState == CallState.active &&
        currentState == CallState.disposing) {
      await playCallEndTone();
    }
  }

  void _handlePlaybackStateChanged(PlaybackServiceState state) {
    final previousState = _lastPlaybackState;
    _lastPlaybackState = state;

    if (previousState != PlaybackServiceState.playing &&
        state == PlaybackServiceState.playing) {
      unawaited(selectionClick());
    }

    if (_awaitingAssistantPlaybackCompletionFeedback &&
        previousState != PlaybackServiceState.idle &&
        state == PlaybackServiceState.idle) {
      _awaitingAssistantPlaybackCompletionFeedback = false;
      unawaited(heavyImpact());
    }
  }

  Future<void> _handleAssistantAudioCompletedSignal() async {
    _awaitingAssistantPlaybackCompletionFeedback = true;
    if (_callService.playbackService.state == PlaybackServiceState.idle) {
      _awaitingAssistantPlaybackCompletionFeedback = false;
      await heavyImpact();
    }
  }

  void onToolExecutionStarted(String callId) {
    final wasEmpty = _executingToolCallIds.isEmpty;
    final added = _executingToolCallIds.add(callId);
    if (added && wasEmpty) {
      unawaited(playToolExecuting());
    }
  }

  void onToolExecutionCompleted(String callId) {
    _executingToolCallIds.remove(callId);
    if (_executingToolCallIds.isEmpty) {
      unawaited(stopToolExecuting());
    }
  }

  void onToolExecutionFailed(String callId) {
    _executingToolCallIds.remove(callId);
    if (_executingToolCallIds.isEmpty) {
      unawaited(stopToolExecuting());
    }
    unawaited(playToolError());
  }

  void onToolExecutionsCancelled({required bool playSound}) {
    final hadPendingToolCalls = _executingToolCallIds.isNotEmpty;
    _executingToolCallIds.clear();
    unawaited(stopToolExecuting());

    if (playSound && hadPendingToolCalls) {
      unawaited(playToolCancelled());
    }
  }

  // ==========================================================================
  // Wake-Lock Management
  // ==========================================================================

  Future<void> _enableWakeLock() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      // Log but don't fail - wake lock is nice-to-have
    }
  }

  Future<void> _disableWakeLock() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      // Log but don't fail
    }
  }

  // ==========================================================================
  // Audio Feedback
  // ==========================================================================

  Future<void> _playLoopingAudio({
    required Future<void> Function() stopExisting,
    required void Function(AudioPlayer player) assignPlayer,
    required String assetPath,
    required double volume,
  }) async {
    try {
      await stopExisting();

      final player = AudioPlayer();
      assignPlayer(player);
      await player.setAsset(assetPath);
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(volume);
      await player.play();
    } catch (e) {
      // Ignore errors in feedback
    }
  }

  Future<void> _playOneShotAudio({
    AudioPlayer? player,
    required void Function(AudioPlayer? player) assignPlayer,
    required String assetPath,
    required double volume,
    required int disposeDelayMs,
  }) async {
    try {
      final currentPlayer = player ?? AudioPlayer();
      assignPlayer(currentPlayer);
      await currentPlayer.setAsset(assetPath);
      await currentPlayer.setVolume(volume);
      await currentPlayer.play();

      await Future.delayed(Duration(milliseconds: disposeDelayMs));
      await _disposePlayer(
        currentPlayer,
        clearPlayer: () => assignPlayer(null),
        stopFirst: false,
      );
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _disposePlayer(
    AudioPlayer? player, {
    required void Function() clearPlayer,
    bool stopFirst = true,
  }) async {
    if (player == null) return;

    try {
      if (stopFirst) {
        await player.stop();
      }
      await player.dispose();
    } catch (e) {
      // Ignore errors
    } finally {
      clearPlayer();
    }
  }

  /// Play dial tone when call is connecting (loops until stopped)
  Future<void> playDialTone() => _playLoopingAudio(
        stopExisting: stopDialTone,
        assignPlayer: (player) => _dialTonePlayer = player,
        assetPath: 'assets/audio/dial_tone.wav',
        volume: 0.3,
      );

  /// Stop dial tone
  Future<void> stopDialTone() => _disposePlayer(
        _dialTonePlayer,
        clearPlayer: () => _dialTonePlayer = null,
      );

  /// Play call end tone (single descending arpeggio)
  Future<void> playCallEndTone() => _playOneShotAudio(
        player: _endTonePlayer ?? AudioPlayer(),
        assignPlayer: (player) => _endTonePlayer = player,
        assetPath: 'assets/audio/call_end.wav',
        volume: 0.5,
        disposeDelayMs: 500,
      );

  /// Start looping the tool executing sound
  Future<void> playToolExecuting() => _playLoopingAudio(
        stopExisting: stopToolExecuting,
        assignPlayer: (player) => _toolExecutingPlayer = player,
        assetPath: 'assets/audio/tool_executing.wav',
        volume: 0.15,
      );

  /// Stop the tool executing sound
  Future<void> stopToolExecuting() => _disposePlayer(
        _toolExecutingPlayer,
        clearPlayer: () => _toolExecutingPlayer = null,
      );

  /// Play tool error sound (single shot)
  Future<void> playToolError() => _playOneShotAudio(
        assignPlayer: (_) {},
        assetPath: 'assets/audio/tool_error.wav',
        volume: 0.4,
        disposeDelayMs: 500,
      );

  /// Play tool cancelled sound (single shot)
  Future<void> playToolCancelled() => _playOneShotAudio(
        assignPlayer: (_) {},
        assetPath: 'assets/audio/tool_cancelled.wav',
        volume: 0.25,
        disposeDelayMs: 250,
      );

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
    } catch (e) {
      // Ignore errors (no platform channels in tests)
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
    } catch (e) {
      // Ignore errors (no platform channels in tests)
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

  @override
  Future<void> start() async {
    // FeedbackService is initialized in constructor and starts
    // listening to call state immediately. No additional startup needed.
  }

  @override
  Future<void> dispose() async {
    await _disableWakeLock();
    await _callStateSubscription?.cancel();
    _callStateSubscription = null;
    await _playbackStateSubscription?.cancel();
    _playbackStateSubscription = null;
    await _assistantAudioCompletedSubscription?.cancel();
    _assistantAudioCompletedSubscription = null;
    await _userSpeakingStateSubscription?.cancel();
    _userSpeakingStateSubscription = null;
    _executingToolCallIds.clear();
    _awaitingAssistantPlaybackCompletionFeedback = false;
    await stopDialTone();
    await stopToolExecuting();
    await _disposePlayer(
      _endTonePlayer,
      clearPlayer: () => _endTonePlayer = null,
      stopFirst: false,
    );
  }
}
