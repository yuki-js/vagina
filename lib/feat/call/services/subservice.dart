import 'package:logging/logging.dart';

/// Base class for all services managed by [CallService].
///
/// Provides common lifecycle management with [start] and [dispose] methods,
/// along with automatic state validation to prevent use-after-dispose bugs.
///
/// Subclasses should call `super.start()` and `super.dispose()` at the
/// beginning of their overridden methods to leverage the built-in state
/// management.
abstract base class SubService {
  /// Logger instance automatically named after the concrete service type.
  ///
  /// Example: RecorderService will have logger name 'CallV2.RecorderService'.
  late final Logger logger = Logger('CallV2.$runtimeType');

  bool _started = false;
  bool _disposed = false;

  /// Returns true if this service has been started.
  bool get isStarted => _started;

  /// Returns true if this service has been disposed.
  bool get isDisposed => _disposed;

  /// Initialize and start the service.
  ///
  /// Called during call initialization to allocate resources and
  /// establish connections. This method is idempotent and automatically
  /// prevents starting after disposal.
  ///
  /// Subclasses should call `super.start()` first, then perform their
  /// service-specific initialization.
  ///
  /// Throws [StateError] if called after [dispose].
  Future<void> start() async {
    if (_disposed) {
      throw StateError('$runtimeType has already been disposed.');
    }
    if (_started) {
      return;
    }
    _started = true;
  }

  /// Clean up resources and dispose the service.
  ///
  /// Called during call termination to release resources and close
  /// connections. This method is idempotent and handles cleanup failures
  /// gracefully to ensure the service reaches a disposed state.
  ///
  /// Subclasses should call `super.dispose()` first, then perform their
  /// service-specific cleanup.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _started = false;
  }

  /// Throws [StateError] if this service has been disposed.
  ///
  /// Use this helper in public methods to ensure operations are not
  /// performed on a disposed service.
  void ensureNotDisposed() {
    if (_disposed) {
      throw StateError('$runtimeType has already been disposed.');
    }
  }
}
