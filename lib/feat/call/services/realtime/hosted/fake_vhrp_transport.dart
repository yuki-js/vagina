// Fake (in-memory) implementation of [VhrpRealtimeTransport] for use in tests.
//
// Placement rationale:
//   Placed in `lib/feat/call/services/realtime/hosted/` (alongside the
//   production code) rather than `test/`.  This mirrors the OAI binding
//   pattern where transport fakes live next to the real implementation, making
//   them reachable from both unit tests and the upcoming common-contract test
//   suite without path games.  The file has no production dependency that
//   would bloat release builds — it only uses dart:async/dart:typed_data.
//
// What tests can do with this fake:
//   1. Inject server→client bytes:  `fake.injectInbound(bytes)` — the bytes
//      appear on [inboundBytes] exactly as if the server sent a binary frame.
//   2. Capture client→server bytes: `fake.sentBytes` — ordered list of every
//      [sendBytes] call.
//   3. Simulate successful connect:  `await fake.connect(uri)` succeeds by
//      default; override [connectBehavior] to throw.
//   4. Simulate connection failure:  `fake.connectBehavior = () async => throw
//      Exception('refused')`.
//   5. Simulate mid-session disconnect: `fake.simulateServerDisconnect()` —
//      emits the [disconnected] state so the adapter triggers reconnect.
//   6. Simulate stream error:        `fake.simulateStreamError(error)`.
//   7. Reset between tests:          `await fake.reset()` clears all state.

import 'dart:async';
import 'dart:typed_data';

import 'vhrp_transport.dart';

/// In-memory test double for [VhrpRealtimeTransport].
///
/// All state transitions that the real [WebSocketVhrpTransport] emits are
/// reproduced faithfully so the adapter under test cannot tell the difference.
final class FakeVhrpTransport implements VhrpRealtimeTransport {
  // ─── Configurable behaviour hooks ─────────────────────────────────────────

  /// Override to make [connect] throw.  Defaults to a no-op (success).
  Future<void> Function(Uri uri, List<String> subprotocols)? connectBehavior;

  // ─── Internal controllers ─────────────────────────────────────────────────

  StreamController<Uint8List> _inboundController =
      StreamController<Uint8List>.broadcast();
  StreamController<VhrpTransportConnectionState> _stateController =
      StreamController<VhrpTransportConnectionState>.broadcast();

  VhrpTransportConnectionState _lastState =
      const VhrpTransportConnectionState.idle();
  bool _disposed = false;

  /// All bytes passed to [sendBytes], in call order.
  final List<Uint8List> sentBytes = [];

  /// The [Uri] passed to the most recent [connect] call.  Null before first
  /// call.
  Uri? lastConnectedUri;

  /// Subprotocols passed to the most recent [connect] call.
  List<String> lastConnectedSubprotocols = [];

  // ─── VhrpRealtimeTransport ────────────────────────────────────────────────

  @override
  Stream<Uint8List> get inboundBytes => _inboundController.stream;

  @override
  VhrpTransportConnectionState get connectionState => _lastState;

  @override
  Stream<VhrpTransportConnectionState> get connectionStateUpdates =>
      _stateController.stream;

  @override
  Future<void> connect(Uri uri, {List<String> subprotocols = const []}) async {
    _ensureNotDisposed();

    lastConnectedUri = uri;
    lastConnectedSubprotocols = List.unmodifiable(subprotocols);

    _emitState(const VhrpTransportConnectionState.connecting());

    final behavior = connectBehavior;
    if (behavior != null) {
      try {
        await behavior(uri, subprotocols);
      } catch (error) {
        _emitState(
          VhrpTransportConnectionState.failed(
            message: 'Fake connect failed.',
            error: error,
          ),
        );
        rethrow;
      }
    }

    _emitState(const VhrpTransportConnectionState.connected());
  }

  @override
  void sendBytes(Uint8List bytes) {
    _ensureNotDisposed();
    if (!_lastState.isConnected) {
      throw StateError(
        'FakeVhrpTransport: sendBytes called while not connected '
        '(phase: ${_lastState.phase}).',
      );
    }
    sentBytes.add(bytes);
  }

  @override
  Future<void> disconnect() async {
    if (_disposed) return;
    _emitState(const VhrpTransportConnectionState.disconnecting());
    _emitState(const VhrpTransportConnectionState.disconnected());
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _inboundController.close();
    await _stateController.close();
  }

  // ─── Test-control API ─────────────────────────────────────────────────────

  /// Pushes [bytes] onto [inboundBytes] as if the server sent a binary frame.
  ///
  /// The transport must be in the [connected] phase; calling this otherwise
  /// has no effect (matches the real transport's behaviour where the stream
  /// only forwards bytes while open).
  void injectInbound(Uint8List bytes) {
    if (_disposed || !_lastState.isConnected) return;
    if (!_inboundController.isClosed) {
      _inboundController.add(bytes);
    }
  }

  /// Simulates the server closing the connection (clean close).
  ///
  /// Emits [VhrpTransportPhase.disconnected] exactly as the real transport
  /// does when the WebSocket [onDone] fires.
  void simulateServerDisconnect({String? message}) {
    if (_disposed) return;
    _emitState(
      VhrpTransportConnectionState.disconnected(
        message: message ?? 'Fake server closed the connection.',
      ),
    );
  }

  /// Simulates a mid-session stream error (e.g. network reset).
  ///
  /// Emits [VhrpTransportPhase.failed] so the adapter can trigger reconnect.
  void simulateStreamError(Object error) {
    if (_disposed) return;
    _emitState(
      VhrpTransportConnectionState.failed(
        message: 'Fake stream error.',
        error: error,
      ),
    );
  }

  /// Resets the fake to its initial state so it can be reused across tests.
  ///
  /// Opens fresh stream controllers, clears [sentBytes], resets state to
  /// [idle].
  Future<void> reset() async {
    if (!_inboundController.isClosed) await _inboundController.close();
    if (!_stateController.isClosed) await _stateController.close();
    _inboundController = StreamController<Uint8List>.broadcast();
    _stateController =
        StreamController<VhrpTransportConnectionState>.broadcast();
    _lastState = const VhrpTransportConnectionState.idle();
    _disposed = false;
    sentBytes.clear();
    lastConnectedUri = null;
    lastConnectedSubprotocols = [];
    connectBehavior = null;
  }

  // ─── Private helpers ─────────────────────────────────────────────────────

  void _emitState(VhrpTransportConnectionState state) {
    _lastState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('FakeVhrpTransport has been disposed.');
    }
  }
}
