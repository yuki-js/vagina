// Transport abstraction for the VHRP/1 (VAGINA Hosted Realtime Protocol)
// WebSocket binding.
//
// This layer owns connection lifecycle and **binary frame** I/O only.
// It does not interpret CBOR, does not perform session negotiation, and does
// not manage reconnect orchestration.
//
// Responsibility boundary (matches handoff doc section 7 and design decision 3):
//   - Transport: single-connection lifecycle + raw Uint8List send/receive.
//   - Adapter (next step): reconnect loop, session.open/session.ready,
//     resume logic, and CBOR codec invocation.
//
// The parallel to the OAI binding is intentional:
//   OaiRealtimeTransport  ←→  VhrpRealtimeTransport
//   WebSocketOaiRealtimeTransport  ←→  WebSocketVhrpTransport
//   (no OAI fake in lib/) ←→  FakeVhrpTransport  (test seam, hosted/ dir)

import 'dart:typed_data';

// ─────────────────────────────────────────────────────────────────────────────
// Connection state model
// ─────────────────────────────────────────────────────────────────────────────

/// Phase of a single VHRP WebSocket connection attempt.
///
/// Mirrors [OaiRealtimeConnectionPhase] so that the adapter can map these
/// states to [RealtimeAdapterConnectionState] symmetrically.
enum VhrpTransportPhase {
  /// No connection has been requested yet, or [dispose] was called.
  idle,

  /// [VhrpRealtimeTransport.connect] is in progress (TCP + TLS + WS upgrade).
  connecting,

  /// WebSocket handshake completed; the transport is ready to send/receive.
  connected,

  /// [VhrpRealtimeTransport.disconnect] is in progress.
  disconnecting,

  /// The connection was cleanly closed (by either side).
  disconnected,

  /// Connection attempt or runtime error; the socket is gone.
  failed,
}

/// Immutable snapshot of a VHRP transport connection.
///
/// Emitted on [VhrpRealtimeTransport.connectionStateUpdates] every time the
/// phase changes.  The adapter observes this stream to derive
/// [RealtimeAdapterConnectionState].
final class VhrpTransportConnectionState {
  final VhrpTransportPhase phase;
  final String? message;
  final Object? error;

  const VhrpTransportConnectionState({
    required this.phase,
    this.message,
    this.error,
  });

  const VhrpTransportConnectionState.idle()
      : this(phase: VhrpTransportPhase.idle);

  const VhrpTransportConnectionState.connecting()
      : this(phase: VhrpTransportPhase.connecting);

  const VhrpTransportConnectionState.connected()
      : this(phase: VhrpTransportPhase.connected);

  const VhrpTransportConnectionState.disconnecting()
      : this(phase: VhrpTransportPhase.disconnecting);

  const VhrpTransportConnectionState.disconnected({String? message})
      : this(phase: VhrpTransportPhase.disconnected, message: message);

  const VhrpTransportConnectionState.failed({String? message, Object? error})
      : this(
          phase: VhrpTransportPhase.failed,
          message: message,
          error: error,
        );

  bool get isConnected => phase == VhrpTransportPhase.connected;

  bool get isTerminal =>
      phase == VhrpTransportPhase.disconnected ||
      phase == VhrpTransportPhase.failed;

  @override
  String toString() =>
      'VhrpTransportConnectionState(phase: $phase, message: $message, '
      'error: $error)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Transport interface
// ─────────────────────────────────────────────────────────────────────────────

/// Binary-frame transport abstraction for VHRP/1.
///
/// Contract:
///   - [connect] opens a WebSocket to [uri], negotiating the given
///     [subprotocols] (VHRP/1 requires `vhrp.cbor.v1`).
///   - [inboundBytes] emits every binary frame the server sends.
///     The transport does not parse or validate the bytes; that is the codec's
///     responsibility.  If the server sends a text frame (which VHRP/1 does
///     not do), the transport silently drops it.
///   - [sendBytes] writes one binary frame.  Throws [StateError] when the
///     transport is not in the [VhrpTransportPhase.connected] phase.
///   - [disconnect] performs a clean close and is idempotent.
///   - [dispose] permanently tears down the transport (idempotent).  After
///     [dispose], all other methods throw [StateError].
///   - [connectionState] is the current snapshot; [connectionStateUpdates]
///     is a broadcast stream of every state transition (including the first
///     one emitted by [connect]).
///
/// **Reconnect responsibility**: this transport manages a *single* connection.
/// The adapter layer orchestrates reconnect loops and `session.open` /
/// `session.resumed` negotiation after each new connection is established.
abstract interface class VhrpRealtimeTransport {
  /// Broadcast stream of raw binary frames received from the server.
  ///
  /// The stream does NOT close when the WebSocket closes; the adapter listens
  /// to [connectionStateUpdates] to detect closure.
  Stream<Uint8List> get inboundBytes;

  /// Latest connection state snapshot.
  VhrpTransportConnectionState get connectionState;

  /// Broadcast stream of connection state transitions.
  Stream<VhrpTransportConnectionState> get connectionStateUpdates;

  /// Opens the WebSocket to [uri] and negotiates [subprotocols].
  ///
  /// Completes when the socket is open and ready to exchange frames.
  /// Throws on connection failure.
  Future<void> connect(Uri uri, {List<String> subprotocols});

  /// Sends [bytes] as a single binary WebSocket frame.
  ///
  /// Throws [StateError] if not [VhrpTransportPhase.connected].
  void sendBytes(Uint8List bytes);

  /// Closes the WebSocket cleanly.  Idempotent.
  Future<void> disconnect();

  /// Permanently disposes all resources.  Idempotent.  All methods throw
  /// [StateError] after disposal.
  Future<void> dispose();
}
