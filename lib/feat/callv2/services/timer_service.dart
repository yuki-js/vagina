import 'dart:async';

import 'package:vagina/feat/callv2/models/realtime/realtime_thread.dart';
import 'package:vagina/feat/callv2/services/call_service.dart';
import 'package:vagina/feat/callv2/services/subservice.dart';

/// Lifecycle state for [TimerService].
enum TimerServiceState {
  uninitialized,
  idle,
  tracking,
  disposed,
}

/// Session-scoped timer service for call duration tracking and timeout detection.
///
/// Provides:
/// - Elapsed time tracking with 1-second granularity via stream
/// - Configurable silence timeout detection with auto-reset on activity
/// - Automatic call termination on silence timeout
/// - Automatic tracking start when CallService becomes active
///
/// Uses a single timer for both duration updates and timeout detection.
final class TimerService extends SubService {
  /// Minimum allowed silence timeout duration (5 seconds)
  static const Duration minSilenceTimeout = Duration(seconds: 5);

  final CallService _callService;
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  final StreamController<void> _timeoutController =
      StreamController<void>.broadcast();
  final StreamController<TimerServiceState> _stateController =
      StreamController<TimerServiceState>.broadcast();

  Timer? _timer;
  StreamSubscription<RealtimeThread>? _threadSubscription;
  StreamSubscription<void>? _assistantAudioCompletedSubscription;
  StreamSubscription<bool>? _userSpeakingSubscription;
  StreamSubscription<CallState>? _callStateSubscription;
  DateTime? _startedAt;
  DateTime? _lastActivityAt;
  Duration _silenceTimeout;
  TimerServiceState _state = TimerServiceState.uninitialized;

  TimerService(
    this._callService, {
    Duration silenceTimeout = const Duration(seconds: 180),
  }) : _silenceTimeout = silenceTimeout;

  TimerServiceState get state => _state;

  /// Computed elapsed time since tracking started.
  /// Returns [Duration.zero] if not tracking.
  Duration get elapsed {
    final startedAt = _startedAt;
    if (startedAt == null) {
      return Duration.zero;
    }
    return DateTime.now().difference(startedAt);
  }

  DateTime? get startedAt => _startedAt;

  Duration get silenceTimeout => _silenceTimeout;

  /// Stream of elapsed duration updates (emits every second).
  Stream<Duration> get durationUpdates => _durationController.stream;

  /// Stream that emits when silence timeout occurs.
  Stream<void> get timeoutEvents => _timeoutController.stream;

  /// Stream of state changes.
  Stream<TimerServiceState> get states => _stateController.stream;

  @override
  Future<void> start() async {
    await super.start();

    if (_state != TimerServiceState.uninitialized) {
      return;
    }

    logger.info('Starting TimerService with silence timeout: ${_silenceTimeout.inSeconds}s');
    _subscribeToCallServiceEvents();
    _setState(TimerServiceState.idle);
  }

  /// Start elapsed time tracking and silence timeout detection.
  void startTracking() {
    ensureNotDisposed();

    if (_state == TimerServiceState.tracking) {
      logger.fine('Tracking already active');
      return;
    }

    logger.info('Starting time tracking');
    _setState(TimerServiceState.tracking);

    final now = DateTime.now();
    _startedAt = now;
    _lastActivityAt = now;

    // Start single timer for both duration updates and timeout detection
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _onTimerTick());
  }

  /// Stop elapsed time tracking and silence timeout detection.
  void stopTracking() {
    ensureNotDisposed();

    if (_state != TimerServiceState.tracking) {
      logger.fine('Tracking already stopped');
      return;
    }

    logger.info('Stopping time tracking (elapsed: ${elapsed.inSeconds}s)');
    _timer?.cancel();
    _timer = null;

    _setState(TimerServiceState.idle);
  }

  /// Reset the silence timeout timer.
  ///
  /// Call this whenever activity is detected (user speaking, assistant responding, etc.)
  /// to prevent the timeout from firing.
  void resetSilenceTimer() {
    ensureNotDisposed();

    if (_state != TimerServiceState.tracking) {
      return;
    }

    logger.fine('Resetting silence timer');
    _lastActivityAt = DateTime.now();
  }

  /// Update the silence timeout duration.
  ///
  /// If tracking is active, takes effect immediately.
  void setSilenceTimeout(Duration timeout) {
    ensureNotDisposed();
    
    if (timeout.isNegative) {
      logger.warning('Attempt to set negative silence timeout: $timeout');
      throw ArgumentError.value(
        timeout,
        'timeout',
        'Silence timeout cannot be negative',
      );
    }
    
    if (timeout < minSilenceTimeout) {
      logger.warning('Attempt to set silence timeout below minimum: $timeout (min: $minSilenceTimeout)');
      throw ArgumentError.value(
        timeout,
        'timeout',
        'Silence timeout must be at least ${minSilenceTimeout.inSeconds} seconds',
      );
    }
    
    logger.info('Setting silence timeout: ${timeout.inSeconds}s');
    _silenceTimeout = timeout;
  }

  @override
  Future<void> dispose() async {
    logger.info('Disposing TimerService (elapsed: ${elapsed.inSeconds}s)');
    await super.dispose();

    _timer?.cancel();
    _timer = null;
    _startedAt = null;
    _lastActivityAt = null;

    await _unsubscribeFromCallServiceEvents();

    _setState(TimerServiceState.disposed);

    await _durationController.close();
    await _timeoutController.close();
    await _stateController.close();
    
    logger.info('TimerService disposed successfully');
  }

  /// Subscribe to CallService event streams for automatic timer reset and tracking.
  void _subscribeToCallServiceEvents() {
    logger.fine('Subscribing to call service events');
    
    // Auto-start tracking when call becomes active
    _callStateSubscription = _callService.states.listen((callState) {
      if (callState == CallState.active && _state == TimerServiceState.idle) {
        logger.fine('Call became active, auto-starting tracking');
        startTracking();
      } else if (callState == CallState.disposing && _state == TimerServiceState.tracking) {
        logger.fine('Call disposing, auto-stopping tracking');
        stopTracking();
      }
    });

    final realtimeService = _callService.realtimeService;
    if (realtimeService == null) {
      logger.fine('No realtime service available, skipping event subscriptions');
      return;
    }

    // Reset on thread updates (message, function call, etc.)
    _threadSubscription = realtimeService.threadUpdates.listen((_) {
      if (_state == TimerServiceState.tracking) {
        resetSilenceTimer();
      }
    });

    // Reset on assistant audio completion
    _assistantAudioCompletedSubscription =
        realtimeService.assistantAudioCompleted.listen((_) {
      if (_state == TimerServiceState.tracking) {
        resetSilenceTimer();
      }
    });

    // Reset on user speaking
    _userSpeakingSubscription =
        realtimeService.userSpeakingStates.listen((isSpeaking) {
      if (isSpeaking && _state == TimerServiceState.tracking) {
        resetSilenceTimer();
      }
    });
  }

  /// Unsubscribe from CallService event streams.
  Future<void> _unsubscribeFromCallServiceEvents() async {
    logger.fine('Unsubscribing from call service events');
    await _callStateSubscription?.cancel();
    _callStateSubscription = null;
    await _threadSubscription?.cancel();
    _threadSubscription = null;
    await _assistantAudioCompletedSubscription?.cancel();
    _assistantAudioCompletedSubscription = null;
    await _userSpeakingSubscription?.cancel();
    _userSpeakingSubscription = null;
  }

  /// Called every second by the timer.
  /// Handles both duration updates and timeout detection.
  void _onTimerTick() {
    if (_state != TimerServiceState.tracking) {
      return;
    }

    final startedAt = _startedAt;
    final lastActivityAt = _lastActivityAt;
    if (startedAt == null || lastActivityAt == null) {
      return;
    }

    // Emit duration update
    final elapsed = DateTime.now().difference(startedAt);
    if (!_durationController.isClosed) {
      _durationController.add(elapsed);
    }

    // Check for silence timeout
    final timeSinceActivity = DateTime.now().difference(lastActivityAt);
    if (timeSinceActivity >= _silenceTimeout) {
      logger.warning(
          'Silence timeout detected: ${timeSinceActivity.inSeconds}s >= ${_silenceTimeout.inSeconds}s, ending call');
      if (!_timeoutController.isClosed) {
        _timeoutController.add(null);
      }
      unawaited(_callService.endCall(
        endContext: 'silence_timeout',
      ));
    }
  }

  void _setState(TimerServiceState next) {
    final previous = _state;
    _state = next;
    logger.info('State transition: $previous → $next');
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

}
