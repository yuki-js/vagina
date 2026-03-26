/// Base interface for all services managed by [CallService].
///
/// Defines a common lifecycle contract with [start] and [dispose] methods
/// to ensure consistent resource management across all call-related services.
abstract interface class SubService {
  /// Initialize and start the service.
  ///
  /// Called during call initialization to allocate resources and
  /// establish connections. Implementations should be idempotent.
  Future<void> start();

  /// Clean up resources and dispose the service.
  ///
  /// Called during call termination to release resources and
  /// close connections. Implementations should handle cleanup failures
  /// gracefully to ensure the service reaches a disposed state.
  Future<void> dispose();
}
