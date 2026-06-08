// Connection lifecycle primitives for the OpenAI Realtime binding.

enum OaiRealtimeConnectionPhase {
  idle,
  connecting,
  connected,
  reconnecting,
  disconnecting,
  disconnected,
  failed,
}

final class OaiRealtimeConnectionState {
  final OaiRealtimeConnectionPhase phase;
  final int attempt;
  final String? message;
  final Object? error;

  const OaiRealtimeConnectionState({
    required this.phase,
    this.attempt = 0,
    this.message,
    this.error,
  });

  const OaiRealtimeConnectionState.idle()
      : this(phase: OaiRealtimeConnectionPhase.idle);

  const OaiRealtimeConnectionState.connecting({int attempt = 1})
      : this(
          phase: OaiRealtimeConnectionPhase.connecting,
          attempt: attempt,
        );

  const OaiRealtimeConnectionState.connected({int attempt = 1})
      : this(
          phase: OaiRealtimeConnectionPhase.connected,
          attempt: attempt,
        );

  const OaiRealtimeConnectionState.reconnecting({required int attempt})
      : this(
          phase: OaiRealtimeConnectionPhase.reconnecting,
          attempt: attempt,
        );

  const OaiRealtimeConnectionState.disconnecting()
      : this(phase: OaiRealtimeConnectionPhase.disconnecting);

  const OaiRealtimeConnectionState.disconnected({String? message})
      : this(
          phase: OaiRealtimeConnectionPhase.disconnected,
          message: message,
        );

  const OaiRealtimeConnectionState.failed({
    required int attempt,
    String? message,
    Object? error,
  }) : this(
          phase: OaiRealtimeConnectionPhase.failed,
          attempt: attempt,
          message: message,
          error: error,
        );

  bool get isConnected => phase == OaiRealtimeConnectionPhase.connected;

  bool get isTerminal =>
      phase == OaiRealtimeConnectionPhase.disconnected ||
      phase == OaiRealtimeConnectionPhase.failed;
}

final class OaiRealtimeConnectionError {
  final String code;
  final String message;
  final Object? cause;

  const OaiRealtimeConnectionError({
    required this.code,
    required this.message,
    this.cause,
  });
}
