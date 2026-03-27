library;

/// Adapter-facing shared types that are still "models" (pure data).

enum RealtimeAdapterConnectionPhase {
  idle,
  connecting,
  connected,
  disconnecting,
  disconnected,
  failed,
}

final class RealtimeAdapterConnectionState {
  final RealtimeAdapterConnectionPhase phase;
  final String? message;
  final Object? error;

  const RealtimeAdapterConnectionState({
    required this.phase,
    this.message,
    this.error,
  });

  const RealtimeAdapterConnectionState.idle()
      : this(phase: RealtimeAdapterConnectionPhase.idle);

  const RealtimeAdapterConnectionState.connecting()
      : this(phase: RealtimeAdapterConnectionPhase.connecting);

  const RealtimeAdapterConnectionState.connected()
      : this(phase: RealtimeAdapterConnectionPhase.connected);

  const RealtimeAdapterConnectionState.disconnecting()
      : this(phase: RealtimeAdapterConnectionPhase.disconnecting);

  const RealtimeAdapterConnectionState.disconnected({String? message})
      : this(
          phase: RealtimeAdapterConnectionPhase.disconnected,
          message: message,
        );

  const RealtimeAdapterConnectionState.failed({
    String? message,
    Object? error,
  }) : this(
          phase: RealtimeAdapterConnectionPhase.failed,
          message: message,
          error: error,
        );

  bool get isConnected => phase == RealtimeAdapterConnectionPhase.connected;
}

final class RealtimeAdapterError {
  final String code;
  final String message;
  final Object? cause;

  const RealtimeAdapterError({
    required this.code,
    required this.message,
    this.cause,
  });
}
