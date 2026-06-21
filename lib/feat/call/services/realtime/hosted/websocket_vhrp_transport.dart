// WebSocket implementation of [VhrpRealtimeTransport].
//
// API used from `web_socket_channel ^3.0.3`:
//   - [connectVhrpWebSocketChannel(uri, protocols: ...)] — constructs the
//     platform-appropriate channel (IO on native, HTML on web) and completes
//     the WS handshake via [channel.ready].
//   - [channel.ready] — Future that resolves once the WS handshake succeeds
//     (throws on failure), so we can distinguish "connected" from "failed".
//   - [channel.stream] — broadcast-like Stream of incoming frames.
//   - [channel.sink.add(Uint8List)] — sends a binary frame.
//   - [channel.sink.close()] — initiates a clean close handshake.
//
// Subprotocol negotiation:
//   [connectVhrpWebSocketChannel] accepts a [protocols] list.  The server is
//   expected to select `vhrp.cbor.v1`.  We pass `['vhrp.cbor.v1']` as the
//   sole subprotocol.
//
// Platform selection:
//   The connector uses conditional import to choose [IOWebSocketChannel] on
//   native/desktop and [HtmlWebSocketChannel] on the web platform, so the
//   same transport source compiles and runs on both.
//
// Text frame handling:
//   VHRP/1 sends only binary frames.  If a text frame arrives (String), we
//   drop it silently and emit a [VhrpTransportPhase.failed] state so the
//   adapter can log/recover.  This matches the spec contract: "Text frames are
//   never used."
//
// Reconnect responsibility:
//   This class manages a **single connection lifecycle**.  Reconnect loops,
//   backoff, and `session.open`/resume orchestration are the adapter's job
//   (next implementation step).  The adapter calls [connect] again on a fresh
//   [WebSocketVhrpTransport] instance (or after [disconnect]).

import 'dart:async';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'vhrp_transport.dart';
import 'websocket_vhrp_connector.dart';

/// Connector function signature: receives [uri] and [protocols], returns a
/// ready [WebSocketChannel].  Can be replaced in tests via constructor
/// injection.
typedef VhrpSocketConnector = Future<WebSocketChannel> Function(
  Uri uri, {
  List<String> protocols,
});

/// Default connector: delegates to [connectVhrpWebSocketChannel], which
/// selects the platform-appropriate implementation via conditional import.
Future<WebSocketChannel> _defaultConnector(
  Uri uri, {
  List<String> protocols = const [],
}) {
  return connectVhrpWebSocketChannel(uri, protocols: protocols);
}

/// Production WebSocket implementation of [VhrpRealtimeTransport].
///
/// Inject a custom [connector] in tests to avoid real network calls.
final class WebSocketVhrpTransport implements VhrpRealtimeTransport {
  final VhrpSocketConnector _connector;

  final StreamController<Uint8List> _inboundController =
      StreamController<Uint8List>.broadcast();
  final StreamController<VhrpTransportConnectionState> _stateController =
      StreamController<VhrpTransportConnectionState>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  VhrpTransportConnectionState _lastState =
      const VhrpTransportConnectionState.idle();
  bool _disposed = false;

  WebSocketVhrpTransport({VhrpSocketConnector? connector})
      : _connector = connector ?? _defaultConnector;

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

    if (_channel != null) {
      await disconnect();
    }

    _emitState(const VhrpTransportConnectionState.connecting());

    try {
      _channel = await _connector(uri, protocols: subprotocols);
      _subscription = _channel!.stream.listen(
        _handleFrame,
        onError: _handleStreamError,
        onDone: _handleStreamDone,
        cancelOnError: false,
      );
      _emitState(const VhrpTransportConnectionState.connected());
    } catch (error) {
      await _safeTearDownChannel();
      _emitState(
        VhrpTransportConnectionState.failed(
          message: 'WebSocket connect failed.',
          error: error,
        ),
      );
      rethrow;
    }
  }

  @override
  void sendBytes(Uint8List bytes) {
    _ensureNotDisposed();
    final channel = _channel;
    if (channel == null || !_lastState.isConnected) {
      throw StateError(
        'Cannot send bytes: VHRP transport is not connected '
        '(phase: ${_lastState.phase}).',
      );
    }
    channel.sink.add(bytes);
  }

  @override
  Future<void> disconnect() async {
    if (_disposed) return;
    if (_channel == null && _subscription == null) {
      _emitState(const VhrpTransportConnectionState.disconnected());
      return;
    }
    _emitState(const VhrpTransportConnectionState.disconnecting());
    await _safeTearDownChannel();
    _emitState(const VhrpTransportConnectionState.disconnected());
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _safeTearDownChannel();
    await _inboundController.close();
    await _stateController.close();
  }

  // ─── Private helpers ─────────────────────────────────────────────────────

  void _handleFrame(dynamic data) {
    if (data is Uint8List) {
      if (!_inboundController.isClosed) {
        _inboundController.add(data);
      }
      return;
    }
    if (data is List<int>) {
      // web_socket_channel may deliver List<int> on some platforms.
      if (!_inboundController.isClosed) {
        _inboundController.add(Uint8List.fromList(data));
      }
      return;
    }
    // Text frame — VHRP/1 never sends text.  Treat as a protocol violation
    // and fail the transport so the adapter triggers reconnect/recovery.
    _emitState(
      VhrpTransportConnectionState.failed(
        message: 'VHRP transport received an unexpected text frame; '
            'VHRP/1 uses binary frames only.',
        error: data,
      ),
    );
  }

  void _handleStreamError(Object error, [StackTrace? _]) {
    _emitState(
      VhrpTransportConnectionState.failed(
        message: 'VHRP transport stream error.',
        error: error,
      ),
    );
  }

  void _handleStreamDone() {
    if (_disposed) return;
    _emitState(
      const VhrpTransportConnectionState.disconnected(
        message: 'VHRP WebSocket closed.',
      ),
    );
  }

  Future<void> _safeTearDownChannel() async {
    try {
      await _subscription?.cancel();
    } finally {
      _subscription = null;
      final channel = _channel;
      _channel = null;
      if (channel != null) {
        try {
          await channel.sink.close();
        } catch (_) {
          // sink.close() may throw if the socket is already gone; ignore.
        }
      }
    }
  }

  void _emitState(VhrpTransportConnectionState state) {
    _lastState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('WebSocketVhrpTransport has been disposed.');
    }
  }
}
