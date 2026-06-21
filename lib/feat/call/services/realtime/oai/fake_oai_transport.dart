// Fake (in-memory) implementation of [OaiRealtimeTransport] for use in tests.
//
// Placement rationale:
//   Placed in lib/ alongside the real transport, mirroring the FakeVhrpTransport
//   pattern in hosted/.  Having the fake in lib/ makes it reachable from both
//   unit tests and the common-contract test suite without path games.
//
// What tests can do with this fake:
//   1. Inject server→client JSON events: `fake.injectInbound({...})` — the map
//      appears on [inboundMessages] exactly as if the server sent a JSON frame.
//   2. Capture client→server JSON:  `fake.sentMessages` — ordered list of every
//      [sendJson] call.
//   3. Simulate successful connect:  `await fake.connect(config)` succeeds by
//      default; override [connectBehavior] to throw.
//   4. Simulate connection failure:  `fake.connectBehavior = () async => throw
//      Exception('refused')`.
//   5. Simulate mid-session disconnect: `fake.simulateServerDisconnect()`.
//   6. Reset between tests: `await fake.reset()` clears all state.

import 'dart:async';

import 'realtime_connect_config.dart';
import 'realtime_connection_state.dart';
import 'realtime_transport.dart';

/// In-memory test double for [OaiRealtimeTransport].
///
/// All state transitions that the real [WebSocketOaiRealtimeTransport] emits
/// are reproduced faithfully so the adapter under test cannot tell the
/// difference.
final class FakeOaiTransport implements OaiRealtimeTransport {
  // ─── Configurable behaviour hooks ─────────────────────────────────────────

  /// Override to make [connect] throw.  Defaults to a no-op (success).
  Future<void> Function(OaiRealtimeConnectConfig config)? connectBehavior;

  // ─── Internal controllers ─────────────────────────────────────────────────

  StreamController<Map<String, dynamic>> _inboundController =
      StreamController<Map<String, dynamic>>.broadcast();
  StreamController<OaiRealtimeConnectionState> _stateController =
      StreamController<OaiRealtimeConnectionState>.broadcast();

  OaiRealtimeConnectionState _lastState =
      const OaiRealtimeConnectionState.idle();
  bool _disposed = false;

  /// All JSON payloads passed to [sendJson], in call order.
  final List<Map<String, dynamic>> sentMessages = [];

  /// The [OaiRealtimeConnectConfig] passed to the most recent [connect] call.
  OaiRealtimeConnectConfig? lastConnectConfig;

  // ─── OaiRealtimeTransport ─────────────────────────────────────────────────

  @override
  Stream<Map<String, dynamic>> get inboundMessages =>
      _inboundController.stream;

  @override
  OaiRealtimeConnectionState get connectionState => _lastState;

  @override
  Stream<OaiRealtimeConnectionState> get connectionStateUpdates =>
      _stateController.stream;

  @override
  Future<void> connect(OaiRealtimeConnectConfig config) async {
    _ensureNotDisposed();
    lastConnectConfig = config;
    _emitState(const OaiRealtimeConnectionState.connecting());

    final behavior = connectBehavior;
    if (behavior != null) {
      try {
        await behavior(config);
      } catch (error) {
        _emitState(
          OaiRealtimeConnectionState.failed(
            attempt: 1,
            message: 'Fake connect failed.',
            error: error,
          ),
        );
        rethrow;
      }
    }

    _emitState(const OaiRealtimeConnectionState.connected());
  }

  @override
  Future<void> sendJson(Map<String, dynamic> payload) async {
    _ensureNotDisposed();
    sentMessages.add(Map<String, dynamic>.unmodifiable(payload));
  }

  @override
  Future<void> disconnect() async {
    if (_disposed) return;
    _emitState(const OaiRealtimeConnectionState.disconnecting());
    _emitState(const OaiRealtimeConnectionState.disconnected());
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _inboundController.close();
    await _stateController.close();
  }

  // ─── Test-control API ─────────────────────────────────────────────────────

  /// Pushes [event] onto [inboundMessages] as if the server sent a JSON frame.
  ///
  /// The transport must be in the [connected] phase; calling this otherwise
  /// is a no-op.
  void injectInbound(Map<String, dynamic> event) {
    if (_disposed || !_lastState.isConnected) return;
    if (!_inboundController.isClosed) {
      _inboundController.add(Map<String, dynamic>.unmodifiable(event));
    }
  }

  /// Simulates the server closing the connection (clean close).
  void simulateServerDisconnect() {
    if (_disposed) return;
    _emitState(const OaiRealtimeConnectionState.disconnected());
  }

  /// Resets the fake to its initial state so it can be reused across tests.
  Future<void> reset() async {
    if (!_inboundController.isClosed) await _inboundController.close();
    if (!_stateController.isClosed) await _stateController.close();
    _inboundController =
        StreamController<Map<String, dynamic>>.broadcast();
    _stateController =
        StreamController<OaiRealtimeConnectionState>.broadcast();
    _lastState = const OaiRealtimeConnectionState.idle();
    _disposed = false;
    sentMessages.clear();
    lastConnectConfig = null;
    connectBehavior = null;
  }

  // ─── Private helpers ─────────────────────────────────────────────────────

  void _emitState(OaiRealtimeConnectionState state) {
    _lastState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('FakeOaiTransport has been disposed.');
    }
  }
}
